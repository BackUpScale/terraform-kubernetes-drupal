resource "kubernetes_deployment" "drupal" {
  metadata {
    name      = "drupal"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
    labels = {
      app = "drupal"
    }
  }
  spec {
    replicas = var.drupal_replicas

    selector {
      match_labels = {
        app = "drupal"
      }
    }

    template {
      metadata {
        labels = {
          app = "drupal"
        }
      }
      spec {
        image_pull_secrets {
          name = kubernetes_secret.container_registry_secret.metadata[0].name
        }

        container {
          name  = "drupal"
          image = var.drupal_container_image_url
          image_pull_policy = "Always"
          port {
            container_port = 80
          }
          volume_mount {
            name       = var.drupal_files_volume_name
            mount_path = "${var.drupal_root_directory}/${var.drupal_files_directory}"
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "2Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "1Gi"
            }
          }

          env {
            name = "DB_NAME"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DATABASE_NAME"
              }
            }
          }
          env {
            name = "DB_USER"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DATABASE_USER"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.drupal_secrets.metadata[0].name
                key  = "DATABASE_PASSWORD"
              }
            }
          }
          env {
            name = "DB_HOST"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DATABASE_HOST"
              }
            }
          }
          env {
            name = "DB_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DATABASE_PORT"
              }
            }
          }
          env {
            name = "DRUPAL_HASH_SALT"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.drupal_secrets.metadata[0].name
                key  = "DRUPAL_HASH_SALT"
              }
            }
          }
          env {
            name = "TRUSTED_HOST_PATTERNS"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DRUPAL_TRUSTED_HOST_PATTERNS"
              }
            }
          }
          # env {
          #   name = "REVERSE_PROXY"
          #   value_from {
          #     config_map_key_ref {
          #       name = kubernetes_config_map.app_variables.metadata[0].name
          #       key  = "DRUPAL_REVERSE_PROXY"
          #     }
          #   }
          # }
          env {
            name = "REVERSE_PROXY_ADDRESSES"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DRUPAL_REVERSE_PROXY_ADDRESSES"
              }
            }
          }
        }

        volume {
          name = var.drupal_files_volume_name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.drupal_files_pvc.metadata[0].name
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      spec[0].template[0].metadata[0].annotations["kubectl.kubernetes.io/restartedAt"]
    ]
  }
}
