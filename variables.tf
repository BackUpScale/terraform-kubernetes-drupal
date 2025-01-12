# Mandatory inputs from parent module.
variable "cluster_terraform_id" {}
variable "environment" {}
variable "helm_chart_version" {}

# Optionals with defaults.
variable "drupal_dashboard_namespace" {
  type    = string
  default = "dash"
}
