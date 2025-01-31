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
  # TODO: Remove this when it inherits from the provider.
  # TODO: Also remove the variable including from root module call.
  region = var.db_region
  name    = "drupal-dashboard-db"
  size    = element(data.civo_size.small.sizes, 0).name
  engine  = element(data.civo_database_version.mysql.versions, 0).engine
  version = element(data.civo_database_version.mysql.versions, 0).version
  nodes   = 3
  firewall_id = var.firewall_id
  network_id = var.network_id
}
