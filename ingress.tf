resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "35.0.0"

  # set {
  #   name  = "service.type"
  #   value = "LoadBalancer"
  # }
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
  # set {
  #   name  = "ports.websecure.tls.enabled"
  #   value = "true"
  # }
  # set {
  #   name  = "certificatesResolvers.default.acme.email"
  #   value = var.technical_contact_email
  # }
  # set {
  #   name  = "certificatesResolvers.letsencrypt.email"
  #   value = var.technical_contact_email
  # }
  # set {
  #   name  = "certificatesResolvers.default.acme.storage"
  #   value = "/acme.json"
  # }
  # set {
  #   name  = "certResolvers.letsencrypt.storage"
  #   value = "/acme.json"
  # }
  # set {
  #   name  = "certificatesResolvers.default.acme.httpChallenge.entryPoint"
  #   value = "web"
  # }
  set {
    name  = "certificatesResolvers.${var.letsencrypt_staging_environment_name}.acme.caServer"
    value = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
  set {
    name  = "certificatesResolvers.${var.letsencrypt_staging_environment_name}.acme.email"
    value = var.technical_contact_email
  }
  set {
    name  = "certificatesResolvers.${var.letsencrypt_production_environment_name}.acme.caServer"
    value = "https://acme-v02.api.letsencrypt.org/directory"
  }
  set {
    name  = "certificatesResolvers.${var.letsencrypt_production_environment_name}.acme.email"
    value = var.technical_contact_email
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.storageClass"
    value = var.acme_storage_class
  }
  # set {
  #   name  = "persistence.name"
  #   value = "acme"
  # }
  # set {
  #   name  = "persistence.accessMode"
  #   value = "ReadWriteOnce"
  # }
  # set {
  #   name  = "persistence.size"
  #   value = "1Gi"
  # }
  # set {
  #   name  = "persistence.path"
  #   value = "/acme.json"
  # }
}

# The IngressRoute CRD comes from Traefik, which the Helm chart installs
# This resource will expose your Drupal service at the route match.
# @see https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/
resource "kubernetes_manifest" "drupal_ingressroute" {
  # TODO: Remove this warning after a fix gets released.
  # Even with this explicit dependency, we still have problems:
  # `cannot create REST client: no client config` &
  # `API did not recognize GroupVersionKind from manifest (CRD may not be installed)`
  # So this resource must be commented out until the first `apply` completes,
  # and then run again afterwards.  This is because unknown values block
  # successful planning: https://github.com/hashicorp/terraform/issues/30937
  depends_on = [helm_release.traefik]
  manifest = {
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
        certResolver = var.environment_is_production ? var.letsencrypt_production_environment_name : var.letsencrypt_staging_environment_name
      }
    }
  }
}
