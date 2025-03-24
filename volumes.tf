# resource "kubernetes_persistent_volume_claim" "drupal_files_pvc" {
#   metadata {
#     name      = var.drupal_files_pvc_name
#     namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
#   }
#   spec {
#     access_modes = ["ReadWriteMany"]
#     resources {
#       requests = {
#         storage = var.drupal_files_storage_size
#       }
#     }
#     storage_class_name = var.drupal_files_storage_class
#   }
#   depends_on = [var.longhorn_ready]
# }
