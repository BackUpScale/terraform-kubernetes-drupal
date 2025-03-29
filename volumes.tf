resource "kubernetes_persistent_volume_claim" "drupal_files_pvc" {
  metadata {
    name      = var.drupal_files_pvc_name
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = var.drupal_files_storage_class
    resources {
      requests = {
        storage = var.drupal_files_storage_size
      }
    }
  }
  depends_on = [var.longhorn_ready]
}
