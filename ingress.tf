resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "35.0.0"

  # Key configuration: let Traefik create a type=LoadBalancer service
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # Redirect all HTTP to HTTPS ("web" -> "websecure")
  set {
    name  = "ports.web.redirections.entryPoint.to"
    value = "websecure"
  }
  set {
    name  = "ports.web.redirections.entryPoint.scheme"
    value = "https"
  }
  set {
    name  = "ports.web.redirections.entryPoint.permanent"
    value = "true"
  }

  # Enable TLS on the secure entrypoint
  set {
    name  = "ports.websecure.tls.enabled"
    value = "true"
  }

  # Let’s Encrypt ACME settings
  set {
    name  = "certificatesResolvers.default.acme.email"
    value = var.technical_contact_email
  }
  set {
    name  = "certificatesResolvers.default.acme.storage"
    value = "/acme.json"
  }
  set {
    name  = "certificatesResolvers.default.acme.httpChallenge.entryPoint"
    value = "web"
  }
  set {
    name  = "certificatesResolvers.staging.acme.caServer"
    value = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
  set {
    name  = "certificatesResolvers.production.acme.caServer"
    value = "https://acme-v02.api.letsencrypt.org/directory"
  }
}

# The IngressRoute CRD comes from Traefik, which the Helm chart installs
# This resource will expose your Drupal service at the route match.
# @see https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/
resource "kubernetes_manifest" "drupal_ingressroute" {
  depends_on = [helm_release.traefik]
  manifest = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "drupal"
      namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
    }
    spec = {
      entryPoints = ["web", "websecure"]
      routes = [{
        match = "Host(`${var.canonical_hostname}`)"
        kind  = "Rule"
        services = [{
          name = var.kubernetes_drupal_service_name
          port = var.http_port
        }]
      }]
      tls = {
        certResolver = var.environment_is_production ? "production" : "staging"
      }
    }
  })
}
