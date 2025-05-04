resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.nginx_ingress_helm_chart_version

  values = [yamlencode({
    controller = {
      replicaCount = 2
      service = {
        type = "LoadBalancer"
        annotations = {
          (var.client_ip_preservation_annotation_key) = var.client_ip_preservation_annotation_value
          (var.firewall_id_annotation_key)            = var.firewall_id_annotation_value
          (var.loadbalancer_algorithm_annotation_key) = var.loadbalancer_algorithm_annotation_value
        }
        externalTrafficPolicy = "Local"
        ports = {
          http  = var.http_port
          https = var.https_port
        }
      }
      config = {
        use-forwarded-headers = "true"
        use-proxy-protocol = "true"
        proxy-real-ip-cidr = join(",", var.trusted_ip_address_ranges)
      }
    }
  })]
}
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace         = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository        = "https://charts.jetstack.io"
  chart             = "cert-manager"
  version           = var.cert_manager_helm_chart_version
  set {
    name  = "installCRDs"
    value = "true"
  }
}
resource "kubectl_manifest" "le_staging" {
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
              ingress:
                class: nginx
YAML
}
resource "kubectl_manifest" "le_production" {
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
              ingress:
                class: nginx
YAML
}
resource "kubernetes_ingress_v1" "drupal_public" {
  metadata {
    name      = "drupal-public"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      "cert-manager.io/cluster-issuer" = var.environment_is_production ? var.letsencrypt_production_environment_name : var.letsencrypt_staging_environment_name
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts      = [var.public_hostname]
      secret_name = "drupal-tls"
    }
    rule {
      host = var.public_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.kubernetes_drupal_service_name
              port {
                number = var.http_port
              }
            }
          }
        }
      }
    }
  }
}
resource "kubernetes_ingress_v1" "drupal_admin" {
  metadata {
    name      = "drupal-admin"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/force-ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/whitelist-source-range" = var.vpn_range
      "cert-manager.io/cluster-issuer" = var.environment_is_production ? var.letsencrypt_production_environment_name : var.letsencrypt_staging_environment_name
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [var.public_hostname]
      secret_name = "drupal-admin-tls"
    }
    rule {
      host = var.public_hostname
      http {
        path {
          path      = "/admin"
          path_type = "Prefix"
          backend {
            service {
              name = var.kubernetes_drupal_service_name
              port {
                number = var.http_port
              }
            }
          }
        }
        path {
          path      = "/core/(install|update|authorize|rebuild).php"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = var.kubernetes_drupal_service_name
              port {
                number = var.http_port
              }
            }
          }
        }
      }
    }
  }
}
