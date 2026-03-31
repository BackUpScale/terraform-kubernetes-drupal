# Requires Kubernetes v1.21+.
resource "kubernetes_cron_job_v1" "drupal_cron" {
  metadata {
    name      = "drupal-cron"
    namespace = kubernetes_namespace.drupal_namespace.metadata[0].name
  }
  spec {
    schedule = "*/${var.cron_job_interval} * * * *"
    concurrency_policy = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit = 1
    job_template {
      metadata {}
      spec {
        # 1 attempt (+ the curl retries) with 1 clear failure, and
        # 1 pod with logs for inspection.
        backoff_limit = 1
        # Keep pods/jobs for 1 week to leave time for inspection.
        ttl_seconds_after_finished = 604800
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
                # Suppress progress meter.
                "--silent",
                # Still print errors even though `--silent` is set.
                "--show-error",
                # Exit non-zero on HTTP 400/500 responses (so the Job properly fails),
                # but also return the content.
                "--fail-with-body",
                # Fail fast if TCP can't connect
                "--connect-timeout", "5",
                # Hard timeout of 30 minutes for entire request.
                "--max-time", "1800",
                # Optional: 1 retry in case of transient gateway blip
                "--retry", "1",
                "--retry-delay", "2",
                # Retry on various errors, esp. during gateway blips.
                "--retry-all-errors",
                # Allow redirect to HTTPS in case support that one day.
                "--location",
                # HTTP is relatively safe here because we're internal.
                "http://${var.private_hostname}/cron/$(CRON_KEY)",
              ]
            }
            # No “it ran twice in the same pod” confusion. Retries happen at
            # the Job level (BackoffLimit), which is visible/auditable.
            restart_policy = "Never"
          }
        }
      }
    }
  }
}
