output "namespace" {
  description = "The Kubernetes namespace used for the Drupal deployment"
  value       = kubernetes_namespace.drupal_dashboard.metadata[0].name
}

output "service_cluster_ip" {
  description = "ClusterIP of the internal Drupal service"
  value       = kubernetes_service.drupal_service.spec[0].cluster_ip
}

# Probably not needed.
# output "drupal_ingress_host" {
#   description = "Host name used by the external Ingress"
#   value       = var.drupal_domain
# }
