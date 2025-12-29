resource "kubernetes_secret" "container_registry_secret" {
  metadata {
    name      = "gitlab-registry-secret"
    namespace = kubernetes_namespace.drupal_namespace.metadata[0].name
  }
  data = {
    ".dockerconfigjson" = var.container_registry_credentials
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_secret" "drupal_secrets" {
  metadata {
    name      = var.drupal_secret_collection_name
    namespace = kubernetes_namespace.drupal_namespace.metadata[0].name
  }
  data = {
    MARIADB_ROOT_PASSWORD = var.db_admin_password
    DATABASE_PASSWORD     = var.db_password
    DRUPAL_HASH_SALT      = var.hash_salt
    cron_key              = var.cron_key
  }
  type = "Opaque"
}

# Sanitize configuration overrides so we can pass them via the environment.
locals {
  # 1) `:`  → `__`
  uncoloned_environment_variable_definitions = {
    for key, value in var.drupal_config_overrides :
    replace(key, ":", "__") => value
  }
  # 2) `.`  → `__DOT__`
  sanitized_environment_variable_definitions = {
    for key, value in local.uncoloned_environment_variable_definitions :
    replace(key, ".", "__DOT__") => value
  }
}
resource "kubernetes_secret" "drupal_config_overrides" {
  metadata {
    name      = "drupal-config-overrides"
    namespace = kubernetes_namespace.drupal_namespace.metadata[0].name
  }
  data = local.sanitized_environment_variable_definitions
  type = "Opaque"
}
