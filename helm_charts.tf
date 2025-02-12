resource "helm_release" "bitnami_drupal" {
  name       = "bitnami-drupal"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "drupal"
  version    = var.helm_chart_version

  # TODO: WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  #   * metrics.resources
  #   * resources
  # +info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
  # TODO: Set values as per
  # https://github.com/bitnami/charts/tree/main/bitnami/drupal#parameters
  values = [
    # Terraform planning diffs don't show up as nicely with YAML, but at least
    # we can place comments in here.  Temporarily switch to jsonencode() if you
    # need a cleaner diff.
    yamlencode({
      global = {
        security = {
          allowInsecureImages = true
        }
      }
      image = {
        registry   = "registry.gitlab.com"
        repository = "backupscale/infrastructure/drupal-dashboard-${var.environment}"
        tag        = "latest"
        pullPolicy = "Always"
        pullSecrets = [kubernetes_secret.container_registry_secret.metadata[0].name]
      }
      # We don't want the default PVC because we want the code in the image, not on the PVC.
      persistence = {
        enabled = false
      }
      # Add our own PVC for storing the Drupal file system.
      extraVolumes = [
        {
          name = var.drupal_files_volume_name
          persistentVolumeClaim = {
            claimName = var.drupal_files_pvc_name
          }
        }
      ]
      extraVolumeMounts = [
        {
          name      = var.drupal_files_volume_name
          mountPath = "${var.drupal_root_directory}/${var.drupal_files_directory}"
        }
      ]
      replicaCount = 2
      allowEmptyPassword = false
      mariadb = {
        enabled = false
      }
      externalDatabase = {
        host = var.db_host
        port = var.db_port
        user = var.db_username
        database = var.db_schema
        existingSecret = kubernetes_secret.drupal_secrets.metadata[0].name
      }
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    })
  ]
}
