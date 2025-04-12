resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "35.0.0"

  values = [
    yamlencode({
      ports = {
        web = {
          # This replaces ports.web.redirections.entryPoint.to, scheme, permanent
          redirections = {
            entryPoint = {
              to        = "websecure"
              scheme    = "https"
              permanent = "true"
            }
          }
        }
      }
      entryPoints = {
        web = {
          address = ":80"
        }
        websecure = {
          address = ":443"
        }
      }
      certificatesResolvers = {
        "${var.letsencrypt_staging_environment_name}" = {
          acme = {
            caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
            email    = var.technical_contact_email
            storage  = "/acme/acme-staging.json"
            httpChallenge = {
              entryPoint = "web"
            }
          }
        }
        "${var.letsencrypt_production_environment_name}" = {
          acme = {
            caServer = "https://acme-v02.api.letsencrypt.org/directory"
            email    = var.technical_contact_email
            storage  = "/acme/acme-production.json"
            httpChallenge = {
              entryPoint = "web"
            }
          }
        }
      }

      # Example: persist ACME JSON to a PVC
      persistence = {
        enabled      = true
        storageClass = var.acme_storage_class
        path         = "/acme"
      }

      # Any other Traefik values go here ...
      # globalArguments = [...]
      # entryPoints = ...
      # ...
    })
  ]
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
