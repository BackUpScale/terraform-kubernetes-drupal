resource "kubernetes_service" "drupal_service" {
  metadata {
    name      = var.kubernetes_drupal_service_name
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  spec {
    selector = {
      app = "drupal"
    }
    port {
      port        = var.http_port
      target_port = var.http_port
    }
    type = "ClusterIP"
  }
}
data "kubernetes_service" "mariadb_primary" {
  metadata {
    name      = "mariadb-primary"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  depends_on = [kubectl_manifest.mariadb_grant]
}
data "kubernetes_resources" "envoy_lb_service" {
  api_version = "v1"
  kind        = "Service"
  namespace   = kubernetes_namespace.drupal_dashboard.metadata[0].name
  label_selector = "app.kubernetes.io/component=proxy,app.kubernetes.io/managed-by=envoy-gateway"
}

locals {
  envoy_service = one(data.kubernetes_resources.envoy_lb_service.objects)
}
