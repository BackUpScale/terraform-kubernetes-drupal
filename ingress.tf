locals {
  tls_certificate_data_path = "${var.tls_certificate_data_directory}/${var.tls_certificate_data_filename}"
}
resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_helm_chart_version

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
          address = ":${var.http_port}"
        }
        websecure = {
          address = ":${var.https_port}"
        }
      }
      certificatesResolvers = {
        (var.letsencrypt_staging_environment_name) = {
          acme = {
            caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
            email    = var.technical_contact_email
            storage  = local.tls_certificate_data_path
            httpChallenge = {
              entryPoint = "web"
            }
          }
        }
        (var.letsencrypt_production_environment_name) = {
          acme = {
            caServer = "https://acme-v02.api.letsencrypt.org/directory"
            email    = var.technical_contact_email
            storage  = local.tls_certificate_data_path
            httpChallenge = {
              entryPoint = "web"
            }
          }
        }
      }
      persistence = {
        enabled      = true
        storageClass = var.acme_storage_class
        path         = var.tls_certificate_data_directory
      }
      # Give the application user write access to the data file.  See:
      # https://github.com/traefik/traefik-helm-chart/issues/396#issuecomment-1873454777
      podSecurityContext = {
        fsGroup = var.traefik_user_id
        fsGroupChangePolicy = "OnRootMismatch"
        runAsGroup = var.traefik_user_id
        runAsNonRoot = true
        runAsUser = var.traefik_user_id
      }
      deployment = {
        initContainers = [
          {
            name  = "volume-permissions"
            image = "busybox:latest"
            command = [
              "sh",
              "-c",
              "ls -alF /; touch ${local.tls_certificate_data_path}; chmod -v 600 ${local.tls_certificate_data_path}; ls -alF ${local.tls_certificate_data_path}"
            ]
            securityContext = {
              runAsNonRoot = true
              runAsGroup = var.traefik_user_id
              runAsUser = var.traefik_user_id
            }
            volumeMounts = [
              {
                name      = "data"
                mountPath = var.tls_certificate_data_directory
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
      routes = [
        {
          match = "Host(`${var.public_hostname}`) && (PathPrefix(`/admin`) || Path(`/core/install.php`) || Path(`/update.php`) || Path(`/core/authorize.php`) || Path(`/core/rebuild.php`))"
          kind  = "Rule"
          middlewares = [
            {
              name = "admin-ip-allow-list"
            }
          ]
          services = [{
            name = var.kubernetes_drupal_service_name
            port = var.http_port
          }]
        },
        {
          match = "Host(`${var.public_hostname}`)"
          kind  = "Rule"
          services = [
            {
              name = var.kubernetes_drupal_service_name
              port = var.http_port
            }
          ]
        }
      ]
      tls = {
        certResolver = var.environment_is_production ? var.letsencrypt_production_environment_name : var.letsencrypt_staging_environment_name
      }
    }
  }
}

resource "kubernetes_manifest" "admin_ip_allowlist" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "admin-ip-allow-list"
      namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
    }
    spec = {
      ipAllowList = {
        sourceRange = [
          var.vpn_range,
        ]
      }
    }
  }
}
