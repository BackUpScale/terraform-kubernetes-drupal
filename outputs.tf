output "namespace" {
  description = "The Kubernetes namespace used for the Drupal deployment"
  value       = kubernetes_namespace.drupal_dashboard.metadata[0].name
}

output "service_cluster_ip" {
  description = "ClusterIP of the internal Drupal service"
  value       = kubernetes_service.drupal_service.spec[0].cluster_ip
}

output "service_public_ip" {
  description = "Public hostname of the Envoy Gateway load balancer"
  depends_on = [data.kubernetes_resources.envoy_lb_service]
  value = coalesce(
    try(local.envoy_service.status.loadBalancer.ingress[0].hostname, null),
    try(local.envoy_service.status.loadBalancer.ingress[0].ip, null)
  )
}
