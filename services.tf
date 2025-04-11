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
  depends_on = [helm_release.mariadb]
}
