resource "kubernetes_namespace" "drupal_dashboard" {
  metadata {
    name = var.namespace
  }
  depends_on = [var.cluster_terraform_id]
}
