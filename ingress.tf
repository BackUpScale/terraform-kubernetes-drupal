resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "35.0.0"

  # https://doc.traefik.io/traefik/
  # https://artifacthub.io/packages/helm/traefik/traefik/?modal=values
  # https://github.com/traefik/traefik-helm-chart/blob/master/EXAMPLES.md
  values = [
    yamlencode({
      ports = {
        web = {
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
            storage  = "/data/acme.json"
            httpChallenge = {
              entryPoint = "web"
            }
          }
        }
        "${var.letsencrypt_production_environment_name}" = {
          acme = {
            caServer = "https://acme-v02.api.letsencrypt.org/directory"
            email    = var.technical_contact_email
            storage  = "/data/acme.json"
            httpChallenge = {
              entryPoint = "web"
            }
          }
        }
      }
      persistence = {
        enabled      = true
        storageClass = var.acme_storage_class
        path         = "/data"
      }
      # Give the application user write access to the data file.  See:
      # https://github.com/traefik/traefik-helm-chart/issues/396#issuecomment-1873454777
      podSecurityContext = {
        fsGroup = 65532
        fsGroupChangePolicy = "OnRootMismatch"
        runAsGroup = 65532
        runAsNonRoot = true
        runAsUser = 65532
      }
      deployment = {
        initContainers = [
          {
            name  = "volume-permissions"
            image = "busybox:latest"
            command = [
              "sh",
              "-c",
              "ls -alF /; touch /data/acme.json; chmod -v 600 /data/acme.json; ls -alF /data/acme.json"
            ]
            securityContext = {
              runAsNonRoot = true
              runAsGroup = 65532
              runAsUser = 65532
            }
            volumeMounts = [
              {
                name      = "data"
                mountPath = "/data"
              }
            ]
          }
        ]
      }
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
      # TODO: Pass in hostname from DNS record to wait until it's up?
      routes = [{
        match = "Host(`${var.public_hostname}`)"
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
