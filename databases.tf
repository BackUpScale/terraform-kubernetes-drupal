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
            cpu    = "1"
            memory = "1Gi"
          }
          limits = {
            # Generous cap; remove to run without limits
            cpu    = "2"
            memory = "2Gi"
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
            cpu    = "500m"
            memory = "768Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1.5Gi"
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
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
    })
  ]
}
