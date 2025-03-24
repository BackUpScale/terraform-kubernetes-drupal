# alocals {
#   volume_mount_base_path = "/volume"
#   drupal_files_full_path = "${local.volume_mount_base_path}/${var.volume_subdirectory_for_drupal_files}"
#   precreate_subpath_job_name = "precreate-drupal-file-system-subpath"
#   precreate_subpath_volume_mame = "drupal-files-volume"
# }
# # Create unprivileged subdirectory for the Drupal file system.
# resource "kubernetes_job" "precreate_drupal_file_system_subpath" {
#   metadata {
#     name      = local.precreate_subpath_job_name
#     namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
#   }
#
#   spec {
#     template {
#       metadata {
#         name = local.precreate_subpath_job_name
#       }
#       spec {
#         restart_policy = "OnFailure"
#         container {
#           name    = "mkdir-subdir"
#           image   = "busybox"
#           command = [
#             "sh",
#             "-c",
#             <<-EOT
#               mkdir --parents ${local.drupal_files_full_path}
#               # Fix permissions because Bitnami container uses UID 1001.
#               chown --recursive 1001:1001 ${local.drupal_files_full_path}
#             EOT
#           ]
#
#           volume_mount {
#             name       = local.precreate_subpath_volume_mame
#             mount_path = local.volume_mount_base_path
#           }
#           # If necessary to ensure we can write in the volume's root directory:
#           # security_context {
#           #   run_as_user = 0
#           # }
#         }
#         volume {
#           name = local.precreate_subpath_volume_mame
#           persistent_volume_claim {
#             claim_name = kubernetes_persistent_volume_claim.drupal_files_pvc.metadata[0].name
#           }
#         }
#       }
#     }
#   }
# }
