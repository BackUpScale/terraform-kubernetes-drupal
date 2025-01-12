resource "kubernetes_namespace" "drupal_dashboard" {
  metadata {
    name = var.drupal_dashboard_namespace
  }
  depends_on = [var.cluster_terraform_id]
}
