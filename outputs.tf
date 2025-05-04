output "namespace" {
  description = "The Kubernetes namespace used for the Drupal deployment"
  value       = kubernetes_namespace.drupal_dashboard.metadata[0].name
}

output "service_cluster_ip" {
  description = "ClusterIP of the internal Drupal service"
  value       = kubernetes_service.drupal_service.spec[0].cluster_ip
}

output "service_public_ip" {
  description = "Public IP / hostname for the NGINX Ingress load balancer."
  # some clouds return .ip, others .hostname (e.g. AWS ELB); take whichever is set
  value = coalesce(
    data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip,
    data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
  )
}
