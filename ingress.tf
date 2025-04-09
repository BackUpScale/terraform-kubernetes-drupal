resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true

  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  # Pin to a known-good version or "latest"
  # version    = "v10.8.0"

  # Key configuration: let Traefik create a type=LoadBalancer service
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # Redirect all HTTP to HTTPS ("web" -> "websecure")
  set {
    name  = "ports.web.redirectTo"
    value = "websecure"
  }

  # Enable TLS on the secure entrypoint
  set {
    name  = "ports.websecure.tls.enabled"
    value = "true"
  }

  # Let’s Encrypt ACME settings
  set {
    name  = "certificatesResolvers.default.acme.email"
    value = "you@example.com"     # <--- Your email
  }
  set {
    name  = "certificatesResolvers.default.acme.storage"
    value = "/acme.json"
  }
  set {
    name  = "certificatesResolvers.default.acme.httpChallenge.entryPoint"
    value = "web"
  }
}

#####################################################
# Drupal IngressRoute
#####################################################

# The IngressRoute CRD comes from Traefik, which the Helm chart installs
# This resource will expose your Drupal service at drupal.example.com.
resource "kubernetes_manifest" "drupal_ingressroute" {
  depends_on = [
    helm_release.traefik
  ]

  manifest = yamlencode({
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "drupal"
      namespace = "default"
    }
    spec = {
      entryPoints = ["web", "websecure"]
      routes = [{
        match = "Host(`drupal.example.com`)"  # <--- Change to your domain
        kind  = "Rule"
        services = [{
          name = "drupal-service"             # <--- The name of your Drupal Service
          port = 80
        }]
      }]
      tls = {
        certResolver = "default"
      }
    }
  })
}
