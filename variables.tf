# Mandatory inputs from parent module.
variable "cluster_terraform_id" {}
variable "environment_is_production" {
  default = false
  type = bool
}
variable "private_hostname" {
  type = string
}
variable "public_hostname" {
  description = "Set this from your DNS record resource to ensure it exists before HTTPS certificate verification (e.g. `cloudflare_record.drupal_public_hostname.name`)"
  type = string
}
variable "drupal_files_storage_class" {}
variable "namespace" {}
variable "container_registry_credentials" {}
variable "db_storage_class" {}
variable "db_admin_password" {
  sensitive = true
  type = string
}
variable "db_password" {
  sensitive = true
  type = string
}
variable "hash_salt" {
  sensitive = true
  type = string
}
variable "drupal_container_image_url" {
  description = "Name and tag for the built Drupal image"
  type        = string
}
variable "reverse_proxy_address_ranges" {
  type    = list(string)
}
variable "technical_contact_email" {
  type = string
}
variable "acme_storage_class" {
  type = string
}
variable "cron_key" {
  description = "The key part of the Cron URL you can find at /admin/config/system/cron, after the https://dashboard.backupscale.com/cron/"
  sensitive   = true
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
variable "db_username" {
  type    = string
  default = "dashboard"
}
variable "db_schema" {
  type    = string
  default = "drupal"
}
variable "drupal_replicas" {
  description = "Number of Drupal pod replicas"
  type        = number
  default     = 2
}
variable "kubernetes_drupal_service_name" {
  type    = string
  default = "drupal-service"
}
variable "http_port" {
  type = number
  default = 80
}
variable "letsencrypt_staging_environment_name" {
  type = string
  default = "staging"
}
variable "letsencrypt_production_environment_name" {
  type = string
  default = "production"
}
variable "cron_curl_image" {
  description = "Container image to use for curl when running Cron jobs"
  type        = string
  default     = "byrnedo/alpine-curl:3.19"
}
variable "cron_job_interval" {
  description = "Every number of minutes that cron will run"
  type        = number
  default     = 60
}


# Indicators.
variable "longhorn_ready" {
  description = "Indicator that Longhorn is ready and deployed."
  type        = string
}
