# https://gateway.envoyproxy.io/latest/install/install-helm/
resource "helm_release" "envoy_gateway" {
  name       = "envoy-gateway"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "oci://docker.io/envoyproxy"
  version    = var.envoy_gateway_helm_chart_version
  chart      = "gateway-helm"
  values     = [yamlencode({
  })]
}

resource "kubectl_manifest" "envoy_proxy" {
  depends_on = [helm_release.envoy_gateway]
  yaml_body = <<YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-proxy-config
  namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 2
      envoyService:
        type: LoadBalancer
        externalTrafficPolicy: Local
        annotations:
          ${var.client_ip_preservation_annotation_key}: "${var.client_ip_preservation_annotation_value}"
          ${var.firewall_id_annotation_key}: "${var.firewall_id_annotation_value}"
          ${var.loadbalancer_algorithm_annotation_key}: "${var.loadbalancer_algorithm_annotation_value}"
YAML
}

# GatewayClass referencing the EnvoyProxy config
resource "kubectl_manifest" "gateway_class" {
  depends_on = [kubectl_manifest.envoy_proxy]
  yaml_body = <<YAML
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
    namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
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
  namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
  annotations:
    cert-manager.io/cluster-issuer: ${var.environment_is_production ? var.letsencrypt_production_environment_name : var.letsencrypt_staging_environment_name}
spec:
  gatewayClassName: envoy-gateway-class
  listeners:
    - name: http
      hostname: ${var.public_hostname}
      port: ${var.http_port}
      protocol: HTTP
      # HTTP listener on port 80 is needed for ACME HTTP-01 challenges.
      allowedRoutes:
        namespaces:
          from: All
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
YAML
}

resource "kubectl_manifest" "drupal_public_route" {
  depends_on = [kubectl_manifest.gateway]
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: drupal-public
  namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
spec:
  hostnames: [ "${var.public_hostname}" ]
  parentRefs:
    - name: drupal-gateway
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
      sectionName: https    # attach to HTTPS listener for normal traffic
    - name: drupal-gateway
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
      sectionName: http     # attach to HTTP listener to handle redirects
  rules:
    # Rule for HTTPS listener: forward all paths to Drupal service
    - matches:
        - path:
            type: PathPrefix
            value: "/"
      backendRefs:
        - name: ${var.kubernetes_drupal_service_name}
          port: ${var.http_port}
          kind: Service
    # Rule for HTTP listener: match all and redirect to HTTPS
    - matches:
        - path:
            type: PathPrefix
            value: "/"
      filters:
        - type: HTTPRedirect
          parameters:
            scheme: https
YAML
}

# Admin access via VPN only.
resource "kubectl_manifest" "drupal_admin_route" {
  depends_on = [kubectl_manifest.gateway]
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: drupal-admin
  namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
spec:
  hostnames: [ "${var.private_hostname}" ]
  parentRefs:
    - name: drupal-gateway
      namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
      # Explicitly bind to HTTP listener only because we're on the VPN.
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "/admin"
        - path:
            type: PathPattern
            value: "^/(core/(install|authorize|rebuild)|update)\\.php$"
        - path:
            type: PathPrefix
            value: ${var.additional_internal_only_drupal_path}
      backendRefs:
        - name: ${var.kubernetes_drupal_service_name}
          port: ${var.http_port}
          kind: Service
YAML
}

resource "kubectl_manifest" "admin_ip_allow" {
  depends_on = [kubectl_manifest.drupal_admin_route]
  yaml_body = <<YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: admin-ip-allowlist
  namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: drupal-admin
  authorization:
    defaultAction: Deny
    rules:
    - action: Allow
      principal:
        clientCIDRs:
        - ${var.vpn_range}
YAML
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_helm_chart_version
  depends_on = [helm_release.envoy_gateway]
  values = [yamlencode({
    installCRDs =  true
    controller = {
      config = {
        apiVersion = "controller.config.cert-manager.io/v1alpha1"
        kind = "ControllerConfiguration"
        enableGatewayAPI = true
      }
    }
  })]
}

resource "kubectl_manifest" "lets_encrypt_staging" {
  depends_on = [helm_release.cert_manager]
  yaml_body = <<YAML
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
          - http01:
              gatewayHTTPRoute:
                parentRefs:
                  - kind: Gateway
                    name: ${var.gateway_name}
                    namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
YAML
}
resource "kubectl_manifest" "lets_encrypt_production" {
  depends_on = [helm_release.cert_manager]
  yaml_body = <<YAML
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
          - http01:
          gatewayHTTPRoute:
            parentRefs:
              - kind: Gateway
                name: ${var.gateway_name}
                namespace: ${kubernetes_namespace.drupal_dashboard.metadata[0].name}
YAML
}
