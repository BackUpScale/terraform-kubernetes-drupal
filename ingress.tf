# https://gateway.envoyproxy.io/latest/install/install-helm/
resource "helm_release" "envoy_gateway" {
  name       = "envoy-gateway"
  namespace  = kubernetes_namespace.drupal_namespace.metadata[0].name
  repository = "oci://docker.io/envoyproxy"
  version    = var.envoy_gateway_helm_chart_version
  chart      = "gateway-helm"

}

resource "kubectl_manifest" "envoy_proxy" {
  depends_on = [helm_release.envoy_gateway]
  yaml_body  = <<YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-proxy-config
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 2
      # Voluntary disruptions (node drains) must leave at least one proxy pod
      # serving.
      envoyPDB:
        minAvailable: 1
      envoyService:
        type: LoadBalancer
        # Cluster, not Local: client IPs reach Envoy via PROXY protocol (see
        # the allow-proxy-protocol ClientTrafficPolicy), so Local adds nothing,
        # while it makes the external load balancer blackhole any node without
        # a ready local proxy pod for the length of its health-check lag.
        externalTrafficPolicy: Cluster
        annotations:
          ${var.client_ip_preservation_annotation_key}: "${var.client_ip_preservation_annotation_value}"
          ${var.firewall_id_annotation_key}: "${var.firewall_id_annotation_value}"
          ${var.loadbalancer_algorithm_annotation_key}: "${var.loadbalancer_algorithm_annotation_value}"
YAML
}

# GatewayClass referencing the EnvoyProxy config
resource "kubectl_manifest" "gateway_class" {
  depends_on = [kubectl_manifest.envoy_proxy]
  yaml_body  = <<YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: envoy-gateway-class
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: envoy-proxy-config
    namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
YAML
}

resource "kubectl_manifest" "gateway" {
  depends_on = [
    kubectl_manifest.gateway_class,
    kubectl_manifest.lets_encrypt_staging,
    kubectl_manifest.lets_encrypt_production
  ]
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: ${var.gateway_name}
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
  annotations:
    cert-manager.io/cluster-issuer: ${var.environment_is_production ? var.letsencrypt_production_environment_name : var.letsencrypt_staging_environment_name}
spec:
  gatewayClassName: envoy-gateway-class
  listeners:
    - name: http
      port: ${var.http_port}
      protocol: HTTP
      # HTTP listener on port 80 is needed for ACME HTTP-01 challenges.
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      hostname: ${var.public_hostname}
      port: ${var.https_port}
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: drupal-tls
%{~for extra in var.extra_public_hostnames}
    - name: ${extra.listener_name}
      hostname: ${extra.hostname}
      port: ${var.https_port}
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: ${extra.tls_secret_name}
%{~endfor}
YAML
  # Block until the gateway is programmed and its load-balancer address is
  # assigned. Envoy Gateway copies the LB Service's address into
  # status.addresses once the cloud controller provisions it, so without this
  # barrier a first apply reads the proxy Service too early and the
  # service_public_ip output (and the DNS record consuming it) fails until a
  # second apply.
  wait_for {
    condition {
      type   = "Programmed"
      status = "True"
    }
    field {
      key        = "status.addresses.[0].value"
      value      = ".+"
      value_type = "regex"
    }
  }
}

resource "kubectl_manifest" "drupal_public_route" {
  depends_on = [kubectl_manifest.gateway]
  yaml_body  = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${var.drupal_public_route_name}
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  hostnames: [ "${var.public_hostname}"%{for extra in var.extra_public_hostnames}, "${extra.hostname}"%{endfor} ]
  parentRefs:
    - name: ${var.gateway_name}
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
      sectionName: https
%{~for extra in var.extra_public_hostnames}
    - name: ${var.gateway_name}
      sectionName: ${extra.listener_name}
%{~endfor}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "/"
      backendRefs:
        - name: ${var.kubernetes_drupal_service_name}
          port: ${var.http_port}
          kind: Service
YAML
}

resource "kubectl_manifest" "allow_proxy_protocol" {
  depends_on = [kubectl_manifest.drupal_public_route]
  yaml_body  = <<YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: allow-proxy-protocol
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: ${var.gateway_name}
  # Interpret the (required) PROXY protocol header from the external load
  # balancer and put the client address into X-Forwarded-For; Drupal's flood
  # control depends on the real client IP. Successor to the deprecated
  # enableProxyProtocol (removed upstream in 1.11).
  proxyProtocol: {}
YAML
}

resource "kubectl_manifest" "https_redirect_route" {
  depends_on = [kubectl_manifest.gateway]
  yaml_body  = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: https-redirect-route
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  parentRefs:
    - name: ${var.gateway_name}
      sectionName: http
  hostnames: ["${var.public_hostname}"%{for extra in var.extra_public_hostnames}, "${extra.hostname}"%{endfor}]
  rules:
    - filters:
      - type: RequestRedirect
        requestRedirect:
          scheme: https
          statusCode: 301
YAML
}

resource "kubectl_manifest" "drupal_public_admin_route_to_deny" {
  depends_on = [kubectl_manifest.gateway]
  yaml_body  = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${var.drupal_public_admin_route_name_to_deny}
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  hostnames: [ "${var.public_hostname}"%{for extra in var.extra_public_hostnames}, "${extra.hostname}"%{endfor} ]
  parentRefs:
    - name: ${var.gateway_name}
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
      sectionName: https
%{~for extra in var.extra_public_hostnames}
    - name: ${var.gateway_name}
      sectionName: ${extra.listener_name}
%{~endfor}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "/admin"
        - path:
            type: RegularExpression
            value: "^/(core/(install|authorize|rebuild)|update)\\.php$"
%{~for match in var.additional_internal_only_drupal_paths}
        - path:
            type: ${match.type}
            value: "${match.value}"
%{~endfor}
      backendRefs:
        - name: ${var.kubernetes_drupal_service_name}
          port: ${var.http_port}
          kind: Service
YAML
}

resource "kubectl_manifest" "deny_drupal_public_admin_route" {
  depends_on = [kubectl_manifest.drupal_public_route]
  yaml_body  = <<YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: deny-drupal-public-admin-route
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: ${var.drupal_public_admin_route_name_to_deny}
  authorization:
    defaultAction: Deny
YAML
}

# Admin access via VPN only.
resource "kubectl_manifest" "drupal_admin_route" {
  depends_on = [kubectl_manifest.gateway]
  yaml_body  = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: drupal-admin
  namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
spec:
  hostnames: ["${var.private_hostname}"]
  parentRefs:
    - name: ${var.gateway_name}
      namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "/"
      backendRefs:
        - name: ${var.kubernetes_drupal_service_name}
          port: ${var.http_port}
          kind: Service
YAML
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.drupal_namespace.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_helm_chart_version
  depends_on = [helm_release.envoy_gateway]
  values = [yamlencode({
    crds = {
      enabled = true
    }
    config = {
      apiVersion       = "controller.config.cert-manager.io/v1alpha1"
      kind             = "ControllerConfiguration"
      enableGatewayAPI = true
    }
    # Certificate expiry/readiness metrics are the only place renewal
    # failures are visible in advance: behind a proxying edge (e.g.
    # Cloudflare), external monitors only ever see the edge's own
    # certificate. Prometheus only discovers ServiceMonitors carrying the
    # stack release's label.
    prometheus = {
      enabled = true
      servicemonitor = {
        enabled = true
        labels = {
          release = var.prometheus_release_name
        }
      }
    }
  })]
}

# The token Secret lives in the module namespace because cert-manager runs
# there, and ClusterIssuer secret references resolve in cert-manager's own
# ("cluster resource") namespace.
resource "kubernetes_secret" "cert_manager_cloudflare_api_token" {
  # Gated on the plan-known boolean, not on the token value: the token may be
  # an apply-time unknown (e.g. minted by the Cloudflare provider), and count
  # cannot depend on unknown values.
  count = var.cert_manager_cloudflare_dns01_enabled ? 1 : 0
  metadata {
    name      = "cert-manager-cloudflare-api-token"
    namespace = kubernetes_namespace.drupal_namespace.metadata[0].name
  }
  data = {
    "api-token" = var.cert_manager_cloudflare_dns01_api_token
  }
  lifecycle {
    precondition {
      condition     = var.cert_manager_cloudflare_dns01_api_token != null
      error_message = "cert_manager_cloudflare_dns01_api_token must be set when cert_manager_cloudflare_dns01_enabled is true."
    }
  }
}

resource "kubectl_manifest" "lets_encrypt_staging" {
  depends_on = [helm_release.cert_manager, kubernetes_secret.cert_manager_cloudflare_api_token]
  yaml_body  = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: ${var.letsencrypt_staging_environment_name}
    spec:
      acme:
        email: ${var.technical_contact_email}
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: acme-staging-key
        solvers:
%{~if var.cert_manager_cloudflare_dns01_enabled}
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cert-manager-cloudflare-api-token
                  key: api-token
%{~else}
          - http01:
              gatewayHTTPRoute:
                parentRefs:
                  - kind: Gateway
                    name: ${var.gateway_name}
                    namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
%{~endif}
YAML
}
resource "kubectl_manifest" "lets_encrypt_production" {
  depends_on = [helm_release.cert_manager, kubernetes_secret.cert_manager_cloudflare_api_token]
  yaml_body  = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: ${var.letsencrypt_production_environment_name}
    spec:
      acme:
        email: ${var.technical_contact_email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: acme-prod-key
        solvers:
%{~if var.cert_manager_cloudflare_dns01_enabled}
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cert-manager-cloudflare-api-token
                  key: api-token
%{~else}
          - http01:
              gatewayHTTPRoute:
                parentRefs:
                  - kind: Gateway
                    name: ${var.gateway_name}
                    namespace: ${kubernetes_namespace.drupal_namespace.metadata[0].name}
%{~endif}
YAML
}
