# resource "kubernetes_ingress" "drupal_ingress" {
#   metadata {
#     name      = "drupal-ingress"
#     namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
#     annotations = {
#       "kubernetes.io/ingress.class" = "civo"
#       "cert-manager.io/cluster-issuer" = "letsencrypt-${var.environment}"
#       "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
#     }
#   }
#   spec {
#     tls {
#       hosts       = [var.drupal_domain]
#       secret_name = "drupal-tls"
#     }
#     rule {
#       host = var.drupal_domain
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
#           backend {
#             service {
#               name = kubernetes_service.drupal_service.metadata[0].name
#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }
