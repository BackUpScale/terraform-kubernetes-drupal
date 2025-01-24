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

resource "kubernetes_secret" "drupal_secrets" {
  metadata {
    name      = var.drupal_secret_collection_name
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  data = {
    admin_passphrase = var.drupal_root_passphrase
    # TODO: Define the secret here.
    db-password =
  }
  type = "Opaque"
}
