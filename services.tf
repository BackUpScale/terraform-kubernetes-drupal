// service.tf

resource "kubernetes_service" "drupal_service" {
  metadata {
    name      = "drupal-service"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  spec {
    selector = {
      app = "drupal"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}
