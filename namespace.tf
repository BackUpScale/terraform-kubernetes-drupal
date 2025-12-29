resource "kubernetes_namespace" "drupal_namespace" {
  metadata {
    name = var.namespace
  }
  depends_on = [var.cluster_terraform_id]
}

moved {
  from = kubernetes_namespace.drupal_dashboard
  to   = kubernetes_namespace.drupal_namespace
}
