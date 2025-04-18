resource "kubernetes_cron_job" "drupal_cron" {
  metadata {
    name      = "drupal-cron"
    namespace = var.namespace
  }
  spec {
    schedule = "*/${var.cron_job_interval} * * * *"
    concurrency_policy = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit = 1
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            container {
              name  = "drupal-cron"
              image = var.cron_curl_image
              env {
                name = "CRON_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.drupal_secrets.metadata[0].name
                    key  = "cron_key"
                  }
                }
              }
              args = [
                "-s",
                "https://${var.canonical_hostname}/cron/$(CRON_KEY)",
              ]
            }
            restart_policy = "OnFailure"
          }
        }
      }
    }
  }
}
