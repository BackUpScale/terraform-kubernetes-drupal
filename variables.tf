# Mandatory inputs from parent module.
variable "cluster_terraform_id" {}
variable "environment" {}
variable "helm_chart_version" {}
variable "drupal_files_storage_class" {}
variable "drupal_dashboard_namespace" {}
variable "container_registry_credentials" {}
variable "firewall_id" {}
variable "network_id" {}
variable "db_region" {}

# Optionals with defaults.
 variable "drupal_files_volume_name" {
   type    = string
   default = "drupal-files"
 }
variable "drupal_root_directory" {
  type    = string
  default = "/opt/bitnami/drupal"
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
variable "drupal_secret_collection_name" {
  type    = string
  default = "drupal-secrets"
}

# Indicators.
variable "longhorn_ready" {
  description = "Indicator that Longhorn is ready and deployed."
  type        = string
}
