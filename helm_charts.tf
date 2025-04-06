# resource "helm_release" "bitnami_drupal" {
#   name       = "bitnami-drupal"
#   namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "drupal"
#   version    = var.helm_chart_version
#   # depends_on = [kubernetes_job.precreate_drupal_file_system_subpath]
#
#   # TODO: WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
#   #   * metrics.resources
#   #   * resources
#   # +info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
#   # TODO: Set values as per
#   # https://github.com/bitnami/charts/tree/main/bitnami/drupal#parameters
#     values = [
#       # Terraform planning diffs don't show up as nicely with YAML, but at least
#       # we can place comments in here.  Temporarily switch to jsonencode() if you
#       # need a cleaner diff.
#       yamlencode({
#         global = {
#           security = {
#             allowInsecureImages = true
#           }
#         }
#         image = {
#           registry   = "registry.gitlab.com"
#           repository = "backupscale/infrastructure/drupal-dashboard-${var.environment}"
#           tag        = "latest"
#           pullPolicy = "Always"
#           pullSecrets = [kubernetes_secret.container_registry_secret.metadata[0].name]
#           debug = true
#         }
#         # Do we want the default PVC?
#         persistence = {
#           enabled = true
#           accessModes = ["ReadWriteMany"]
#         }
#         extraEnvVars = [
#           {
#             name  = "DRUPAL_SKIP_BOOTSTRAP"
#             value = "no"
#           }
#         ]
#         # Temporarily disable probes to allow for DB import before starting?
#         livenessProbe = {
#           enabled = true
#         }
#         readinessProbe = {
#           enabled = true
#         }
#         # Add our own PVC for storing the Drupal file system.
#         # extraVolumes = [
#         #   {
#         #     name = var.drupal_files_volume_name
#         #     persistentVolumeClaim = {
#         #       claimName = kubernetes_persistent_volume_claim.drupal_files_pvc.metadata[0].name
#         #     }
#         #   }
#         # ]
#         # extraVolumeMounts = [
#         #   {
#         #     name      = var.drupal_files_volume_name
#         #     mountPath = "${var.drupal_root_directory}/${var.drupal_files_directory}"
#         #     # Add dedicated subpath due to lack of permissions on lost+found folder.
#         #     subPath   = var.volume_subdirectory_for_drupal_files
#         #   }
#         # ]
#         replicaCount = 1
#         allowEmptyPassword = false
#         # https://github.com/bitnami/charts/tree/main/bitnami/drupal#database-parameters
#         mariadb = {
#           architecture = "replication"
#           auth = {
#             rootPassword = var.db_admin_password
#             database = var.db_schema
#             username = var.db_username
#             password = var.db_password
#           }
#           primary = {
#             persistence = {
#               storageClass = var.db_storage_class
#               size = var.drupal_db_storage_size
#             }
#           }
#           secondary = {
#             replicaCount = 2
#             persistence = {
#               storageClass = var.db_storage_class
#               size = var.drupal_db_storage_size
#             }
#           }
#         }
#         drupalSkipInstall = true
#         resources = {
#           limits = {
#             cpu    = "500m"
#             memory = "5Gi"
#           }
#           requests = {
#             cpu    = "250m"
#             memory = "512Mi"
#           }
#         }
#         # metrics = {
#         #   enabled = true
#         #   serviceMonitor = {
#         #     enabled = true
#         #   }
#         # }
#       })
#     ]
#   }

resource "helm_release" "mariadb" {
  name       = "mariadb"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  # https://artifacthub.io/packages/helm/bitnami/mariadb
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "mariadb"
  version    = "20.4.2"

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
    value = "2"
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
