variable "cluster_terraform_id" {
  description = "Normally, the Terraform ID of your cluster used as a dependency to be there before provisioning (e.g. `civo_kubernetes_cluster.mycluster.id`), but can be any dependency you want provisioned before this module (e.g. another module output you'd like provisioned first)."
}
variable "environment_is_production" {
  description = "Is this the Production environment? Used to determine the Let's Encrypt environment for fetching TLS certificates.  Say 'no' here during testing so you don't hit their Production usage limits."
  default = false
  type = bool
}
variable "private_hostname" {
  description = "The internal hostname for your Drupal site on your private network, accessible via your VPN, e.g. 'drupal.example.dev'."
  type = string
}
variable "public_hostname" {
  description = "Set this from your DNS record resource to ensure it exists before HTTPS certificate verification (e.g. `cloudflare_record.drupal_public_hostname.name`)"
  type = string
}
variable "drupal_files_storage_class" {
  description = "The Kubernetes storage class to use for your Drupal file system, which should support ReadWriteMany (RWX) if you want multiple replicas (the default)."
  type = string
  default = "default"
}
variable "drupal_files_access_mode" {
  description = "ReadWriteMany (RWX) if you want multiple replicas (default).  Otherwise, ReadWriteOnce (RWO) is fine."
  type = string
  default = "ReadWriteMany"
}
variable "namespace" {
  description = "The name of the namespace where Drupal resources will get provisioned."
  type = string
}
variable "container_registry_credentials" {
  description = "The credentials used to access the container registry. See README for details."
}
variable "db_storage_class" {
  description = "The Kubernetes storage class to use for the database. RWO support is sufficient because each DB replica has its own storage; RWX isn't necessary."
  type = string
  default = "default"
}
variable "db_admin_password" {
  description = "The root password for the DB server."
  sensitive = true
  type = string
}
variable "db_password" {
  description = "The password for the Drupal application user that has access to the Drupal DB/schema."
  sensitive = true
  type = string
}
variable "hash_salt" {
  description = "Set this to something that's cryptographically secure (e.g. `openssl rand -base64 64`). See https://git.drupalcode.org/project/drupal/-/blob/11.x/sites/default/default.settings.php?ref_type=heads#L272 for more information."
  sensitive = true
  type = string
}
variable "drupal_container_image_url" {
  description = "Name and tag for the built Drupal image"
  type        = string
}
variable "trusted_ip_address_ranges" {
  description = "The IP addresses to trust with headers containing source IP addresses from end-user clients. If not included, the Drupal logs will contain the proxy IP address, which is not the true source. Provide your proxy IP addresses here."
  type    = list(string)
  default = [
    "192.168.1.0/24",
  ]
}
variable "technical_contact_email" {
  description = "Provided to Let's Encrypt for TLS certificate notifications. It may have other uses in the future."
  type = string
}
variable "cron_key" {
  description = "The key part of the Cron URL you can find at /admin/config/system/cron, after the https://example.com/cron/"
  sensitive   = true
  type        = string
}
variable "firewall_id_annotation_key" {
  description = "Your cloud service provider's annotation key for setting the firewall ID"
  default = "kubernetes.civo.com/firewall-id"
  type = string
}
variable "firewall_id_annotation_value" {
  description = "Your preferred firewall's UUID to protect the site; required to prevent a new permissive firewall from being spun up"
  type        = string
}
variable "loadbalancer_algorithm_annotation_key" {
  description = "Your cloud service provider's annotation key for setting the load balancer algorithm"
  default     = "kubernetes.civo.com/loadbalancer-algorithm"
  type        = string
}
variable "loadbalancer_algorithm_annotation_value" {
  description = "The load balancer algorithm you'd like to use (e.g. round robin, least connections)"
  default     = "least_connections"
  type        = string
}
 variable "drupal_files_volume_name" {
   description = "The Kubernetes volume name of the Drupal file system."
   type    = string
   default = "drupal-files"
 }
variable "drupal_root_directory" {
  description = "The web directory (or 'docroot') of the Drupal site code."
  type    = string
  default = "/app/web"
}
variable "drupal_files_directory" {
  description = "The path to the Drupal file system from the Drupal root directory."
  type    = string
  default = "sites/default/files"
}
variable "drupal_files_storage_size" {
  description = "The size of the Drupal file system."
  type    = string
  default = "2Gi"
}
variable "drupal_files_pvc_name" {
  description = "The name of the Kubernetes persistent volume claim (PVC) for the Drupal file system."
  type    = string
  default = "drupal-files-pvc"
}
variable "mariadb_operator_chart_version" {
  description = "The Helm chart version for the MariaDB operator. See https://artifacthub.io/packages/helm/mariadb-operator/mariadb-operator"
  type    = string
  default = "25.8.3"
}
variable "mariadb_cpu_request" {
  description = "The minimum CPU requested by MariaDB pods."
  type = string
  default = "1"
}
variable "mariadb_memory_request" {
  description = "The minimum memory requested by MariaDB pods."
  type = string
  default = "1Gi"
}
variable "mariadb_cpu_limit" {
  description = "The maximum CPU limit of the MariaDB pods."
  type = string
  default = "2"
}
variable "mariadb_memory_limit" {
  description = "The maximum memory limit of MariaDB pods."
  type = string
  default = "2Gi"
}
variable "mariadb_metrics_cpu_request" {
  description = "The minimum CPU requested by the MariaDB metrics pod."
  type = string
  default = "50m"
}
variable "mariadb_metrics_memory_request" {
  description = "The minimum memory requested by the MariaDB metrics pod."
  type = string
  default = "128Mi"
}
variable "mariadb_metrics_cpu_limit" {
  description = "The maximum CPU limit of the MariaDB metrics pod."
  type = string
  default = "200m"
}
variable "mariadb_metrics_memory_limit" {
  description = "The maximum memory limit of the MariaDB metrics pod."
  type = string
  default = "256Mi"
}
variable "drupal_db_storage_size" {
  description = "The size of the Drupal database."
  type    = string
  default = "40Gi"
}
variable "db_port" {
  description = "The port number for the database."
  type = number
  default = 3306
}
variable "drupal_secret_collection_name" {
  description = "The name of the Kubernetes secret for holding Drupal configuration secrets."
  type    = string
  default = "drupal-secrets"
}
variable "db_username" {
  description = "The name of the Drupal application's user that accesses its DB schema on the DB server."
  type    = string
  default = "drupal"
}
variable "db_schema" {
  description = "The name of Drupal's DB schema/database within the DB server."
  type    = string
  default = "drupal"
}
variable "mariadb_number_of_replicas" {
  description = "Total number of database replicas. 3+ is recommended."
  type    = number
  default = 3
}
variable "drupal_replicas" {
  description = "Number of Drupal pod replicas"
  type        = number
  default     = 2
}
variable "drupal_cpu_request" {
  description = "The minimum CPU requested by each of the Drupal pods."
  type    = string
  default = "250m"
}
variable "drupal_memmory_request" {
  description = "The minimum memory requested by each of the Drupal pods."
  type    = string
  default = "1Gi"
}
variable "drupal_cpu_limit" {
  description = "The maximum CPU limit of the Drupal pods."
  type    = string
  default = "500m"
}
variable "drupal_memory_limit" {
  description = "The maximum memory limit of the Drupal pods."
  type    = string
  default = "2Gi"
}
variable "kubernetes_drupal_service_name" {
  description = "The name of the Kubernetes service that provides Drupal Web access."
  type    = string
  default = "drupal-service"
}
variable "http_port" {
  description = "The HTTP port number to provide the Drupal service."
  type = number
  default = 80
}
variable "https_port" {
  description = "The HTTPS port number to provide the Drupal service."
  type = number
  default = 443
}
variable "letsencrypt_staging_environment_name" {
  description = "The name & ID of Let's Encrypt's Staging environment for handling TLS certificates."
  type = string
  default = "staging"
}
variable "letsencrypt_production_environment_name" {
  description = "The name & ID of Let's Encrypt's Production environment for handling TLS certificates."
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
variable "nginx_ingress_helm_chart_version" {
  description = "See https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx"
  type = string
  default = "4.12.2"
}
variable "cert_manager_helm_chart_version" {
  description = "See https://artifacthub.io/packages/helm/cert-manager/cert-manager"
  type = string
  default = "1.17.2"
}
variable "vpn_range" {
  description = "VPN CIDR range for admin access to site"
  type    = string
  default = "100.64.0.0/10"
}
variable "client_ip_preservation_annotation_key" {
  description = "Cloud-provider-specific annotation key for preserving client IP addresses"
  type    = string
  default = "kubernetes.civo.com/loadbalancer-enable-proxy-protocol"
}
variable "client_ip_preservation_annotation_value" {
  description = "Cloud-provider-specific annotation value for preserving client IP addresses"
  type    = string
  default = "send-proxy-v2"
}
variable "drupal_config_overrides" {
  description = "Drupal config & settings overrides; see https://docs.platform.sh/development/variables.html#implementation-example for examples."
  type        = map(string)
  sensitive   = true
  default     = {}
}
variable "drupal_files_pv_dependency" {
  description = "A dependency required before the PVC gets set up. Using the ID of the k8s resource is simplest as long as it's the full path, which will create the dependency (e.g. an output from another module that's defined by `helm_release.longhorn.id`)."
  type        = string
  default     = null
}
