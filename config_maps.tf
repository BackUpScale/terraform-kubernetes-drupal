resource "kubernetes_config_map" "app_variables" {
  metadata {
    name      = "app-variables"
    namespace = kubernetes_namespace.drupal_namespace.metadata[0].name
  }
  data = {
    DATABASE_NAME                  = var.db_schema
    DATABASE_USER                  = var.db_username
    DATABASE_HOST                  = data.kubernetes_service.mariadb_primary.metadata[0].name
    DATABASE_PORT                  = var.db_port
    DRUPAL_TRUSTED_HOST_PATTERNS   = "${var.public_hostname}, ${var.private_hostname}"
    DRUPAL_REVERSE_PROXY_ADDRESSES = join(",", var.trusted_ip_address_ranges)
    # Exposes the private admin hostname to the Drupal application (as the
    # DRUPAL_ADMIN_HOSTNAME env var) so it can enforce host-based access control
    # for admin routes — e.g. an event subscriber that denies admin routes
    # served on any other host.
    DRUPAL_ADMIN_HOSTNAME = var.private_hostname
  }
}
