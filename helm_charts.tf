resource "helm_release" "bitnami_drupal" {
  name       = "bitnami-drupal"
  namespace  = kubernetes_namespace.drupal_dashboard.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "drupal"
  version    = var.helm_chart_version

  # TODO: Set values as per
  # https://github.com/bitnami/charts/tree/main/bitnami/drupal#parameters
  values = [
    # Terraform planning diffs don't show up as nicely with YAML, but at least
    # we can place comments in here.  Temporarily switch to jsonencode() if you
    # need a cleaner diff.
    yamlencode({
      image = {
        registry   = "registry.gitlab.com"
        repository = "backupscale/infrastructure/drupal-dashboard-${var.environment}:latest"
        pullPolicy = "Always"
        image_pull_secrets = [kubernetes_secret.container_registry_secret.metadata[0].name]
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
        host = civo_database.drupal_dashboard_db.private_ipv4
        port = civo_database.drupal_dashboard_db.port
        user = civo_database.drupal_dashboard_db.username
        database = civo_database.drupal_dashboard_db.name
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
