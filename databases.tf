# resource "mysql_database" "drupal_dashboard_staging" {
#   count = var.environment_is_production ? 0 : 1
#
#   name = var.db_schema
#   lifecycle {
#     prevent_destroy = false
#   }
# }
# resource "mysql_database" "drupal_dashboard_prod" {
#   count = var.environment_is_production ? 1 : 0
#
#   name = var.db_schema
#   lifecycle {
#     prevent_destroy = true
#   }
# }
#
# resource "mysql_user" "drupal" {
#   user = var.db_username
#   host = "%"
#   plaintext_password = var.db_password
# }
#
# resource "mysql_grant" "drupal_grant" {
#   user       = mysql_user.drupal.user
#   host       = mysql_user.drupal.host
#   database   = var.environment_is_production ? mysql_database.drupal_dashboard_prod[0].name : mysql_database.drupal_dashboard_staging[0].name
#   privileges = [
#     "SELECT",
#     "INSERT",
#     "UPDATE",
#     "DELETE",
#     "CREATE",
#     "DROP",
#     "INDEX",
#     "ALTER",
#     "CREATE TEMPORARY TABLES",
#     "LOCK TABLES",
#     "TRIGGER",
#     "CREATE VIEW",
#   ]
# }

// mariadb.tf

# MariaDB Deployment
resource "kubernetes_deployment" "mariadb" {
  metadata {
    name      = "mariadb"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
    labels = {
      app = "mariadb"
    }
  }
  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "mariadb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mariadb"
        }
      }
      spec {
        container {
          name  = "mariadb"
          image = var.db_image

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_server_secrets.metadata[0].name
                key  = "database_admin_password"
              }
            }
          }
          env {
            name = "MYSQL_DATABASE"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DATABASE_NAME"
              }
            }
          }
          env {
            name = "MYSQL_USER"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_variables.metadata[0].name
                key  = "DATABASE_USER"
              }
            }
          }
          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.drupal_secrets.metadata[0].name
                key  = "DATABASE_PASSWORD"
              }
            }
          }

          port {
            container_port = var.db_port
          }

          volume_mount {
            name       = "mariadb-data"
            mount_path = "/var/lib/mysql"
          }
        }

        volume {
          name = "mariadb-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mariadb_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# MariaDB PVC
resource "kubernetes_persistent_volume_claim" "mariadb_pvc" {
  metadata {
    name      = "mariadb-data"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = var.db_storage_class
    resources {
      requests = {
        storage = var.drupal_db_storage_size
      }
    }
  }
}

# MariaDB Service
resource "kubernetes_service" "mariadb" {
  metadata {
    name      = "mariadb"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  spec {
    selector = {
      app = "mariadb"
    }
    port {
      port        = var.db_port
      target_port = var.db_port
    }
  }
}
