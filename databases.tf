resource "helm_release" "mariadb" {
  name       = "mariadb"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "mariadb"
  version    = var.mariadb_helm_chart_version

  set {
    name  = "auth.rootPassword"
    value = var.db_admin_password
  }
  set {
    name  = "auth.database"
    value = var.db_schema
  }
  set {
    name  = "auth.username"
    value = var.db_username
  }
  set {
    name  = "auth.password"
    value = var.db_password
  }
  set {
    name = "global.defaultStorageClass"
    value = var.db_storage_class
  }
  set {
    name  = "architecture"
    value = "replication"
  }
  set {
    name  = "primary.persistence.size"
    value = var.drupal_db_storage_size
  }
  set {
    name  = "secondary.persistence.size"
    value = var.drupal_db_storage_size
  }
  set {
    name  = "secondary.replicaCount"
    value = var.number_of_secondary_db_replicas
  }
  set {
    name  = "metrics.enabled"
    value = "true"
  }
  set {
    name  = "metrics.serviceMonitor.enabled"
    value = "true"
  }
}
