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
}
