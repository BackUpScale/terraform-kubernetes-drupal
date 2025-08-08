resource "helm_release" "mariadb" {
  name       = "mariadb"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "mariadb"
  version    = var.mariadb_helm_chart_version

  values = [
    yamlencode({
      auth = {
        rootPassword = var.db_admin_password
        database     = var.db_schema
        username     = var.db_username
        password     = var.db_password
        replicationPassword = var.db_replication_user_password
      }
      global = {
        defaultStorageClass = var.db_storage_class
      }
      architecture = "replication"
      primary = {
        persistence = {
          size = var.drupal_db_storage_size
        }
        extraFlags = "--transaction-isolation=READ-COMMITTED"
        resources = {
          requests = {
            cpu    = var.mariadb_primary_cpu_request
            memory = var.mariadb_primary_memory_request
          }
          limits = {
            cpu    = var.mariadb_primary_cpu_limit
            memory = var.mariadb_primary_memory_limit
          }
        }
      }
      secondary = {
        replicaCount = var.number_of_secondary_db_replicas
        persistence  = {
          size = var.drupal_db_storage_size
        }
        extraFlags = "--transaction-isolation=READ-COMMITTED"
        resources = {
          requests = {
            cpu    = var.mariadb_secondary_cpu_request
            memory = var.mariadb_secondary_memory_request
          }
          limits = {
            cpu    = var.mariadb_secondary_cpu_limit
            memory = var.mariadb_secondary_memory_limit
          }
        }
      }
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
        resources = {
          requests = {
            cpu    = var.mariadb_metrics_cpu_request
            memory = var.mariadb_metrics_memory_request
          }
          limits = {
            cpu    = var.mariadb_metrics_cpu_limit
            memory = var.mariadb_metrics_memory_limit
          }
        }
      }
    })
  ]
}
