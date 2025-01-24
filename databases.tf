# Query small instance size
data "civo_size" "small" {
  filter {
    key      = "name"
    # `civo database size`
    values   = ["db.small"]
    match_by = "re"
  }
  filter {
    key    = "type"
    values = ["database"]
  }
}

# Query database version
data "civo_database_version" "mysql" {
  filter {
    key    = "engine"
    # `civo database engine`
    values = ["mysql"]
  }
}

resource "civo_database" "drupal_dashboard_db" {
  name    = "drupal-dashboard-db"
  size    = element(data.civo_size.small.sizes, 0).name
  engine  = element(data.civo_database_version.mysql.versions, 0).engine
  version = element(data.civo_database_version.mysql.versions, 0).version
  nodes   = 3
  firewall_id = var.firewall_id
  network_id = var.network_id
}

# Output important connection info to use in your Helm chart or other resources
output "db_host" {
  value = civo_database.drupal_dashboard_db.private_ipv4
}

output "db_port" {
  value = civo_database.drupal_dashboard_db.port
}

output "db_username" {
  value = civo_database.drupal_dashboard_db.username
}

# TODO: Convert to secret.
output "db_password" {
  value = civo_database.drupal_dashboard_db.password
  sensitive = true
}
