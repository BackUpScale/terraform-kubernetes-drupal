# Mandatory inputs from parent module.
variable "cluster_terraform_id" {}
variable "environment" {}
variable "environment_is_production" {}
variable "host_names" {
  type        = string
}
variable "helm_chart_version" {}
variable "drupal_files_storage_class" {}
variable "namespace" {}
variable "container_registry_credentials" {}
variable "db_storage_class" {}
variable "db_admin_password" {}
# variable "db_host" {}
variable "db_password" {}
variable "hash_salt" {}
variable "drupal_container_image_url" {
  description = "Name and tag for the built Drupal image"
  type        = string
}
variable "db_image" {
  description = "Docker image for MariaDB"
  type        = string
}

# Optionals with defaults.
 variable "drupal_files_volume_name" {
   type    = string
   default = "drupal-files"
 }
variable "drupal_root_directory" {
  type    = string
  default = "/app/web"
}
variable "drupal_files_directory" {
  type    = string
  default = "sites/default/files"
}
variable "drupal_files_storage_size" {
  type    = string
  default = "2Gi"
}
variable "drupal_files_pvc_name" {
  type    = string
  default = "drupal-files-pvc"
}
variable "drupal_db_storage_size" {
  type    = string
  default = "40Gi"
}
variable "db_port" {
  type = number
  default = 3306
}
variable "drupal_secret_collection_name" {
  type    = string
  default = "drupal-secrets"
}
variable "db_server_secrets_name" {
  type = string
  default = "db-server-secrets"
}
variable "db_username" {
  type    = string
  default = "dashboard"
}
variable "db_schema" {
  type    = string
  default = "drupal"
}
variable "volume_subdirectory_for_drupal_files" {
  type    = string
  default = "drupal-file-system"
}
variable "drupal_replicas" {
  description = "Number of Drupal pod replicas"
  type        = number
  default     = 2
}
# variable "db_import_config_map_name" {
#   type    = string
#   default = "drupal-db-import"
# }

# Indicators.
variable "longhorn_ready" {
  description = "Indicator that Longhorn is ready and deployed."
  type        = string
}
