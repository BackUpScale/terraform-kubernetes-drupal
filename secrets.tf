resource "kubernetes_secret" "container_registry_secret" {
  metadata {
    name      = "gitlab-registry-secret"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = var.container_registry_credentials
  }

  type = "kubernetes.io/dockerconfigjson"
}
