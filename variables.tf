# Mandatory inputs from parent module.
variable "cluster_terraform_id" {}
variable "environment" {}
variable "helm_chart_version" {}
variable "drupal_files_storage_class" {}

# Optionals with defaults.
variable "drupal_dashboard_namespace" {
  type    = string
  default = "dash"
}
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

# Indicators.
variable "longhorn_ready" {
  description = "Indicator that Longhorn is ready and deployed."
  type        = string
}
