resource "kubernetes_config_map" "app_variables" {
  metadata {
    name      = "app-variables"
    namespace = kubernetes_namespace.drupal_dashboard.metadata[0].name
  }
  data = {
    DATABASE_NAME = var.db_schema
    DATABASE_USER = var.db_username
    DATABASE_HOST = data.kubernetes_service.mariadb_primary.metadata[0].name
    DATABASE_PORT = var.db_port
    DRUPAL_TRUSTED_HOST_PATTERNS = "${var.public_hostname}, ${var.private_hostname}"
    DRUPAL_REVERSE_PROXY_ADDRESSES = join(",", var.trusted_ip_address_ranges)
  }
}
