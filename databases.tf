resource "mysql_database" "drupal_dashboard" {
  name = var.db_schema
  lifecycle {
    prevent_destroy = var.prevent_db_destruction
  }
}

resource "mysql_user" "drupal" {
  user = var.db_username
  host = "%"
  plaintext_password = var.db_password
}

resource "mysql_grant" "drupal_grant" {
  user       = mysql_user.drupal.user
  host       = mysql_user.drupal.host
  database   = mysql_database.drupal_dashboard.name
  privileges = [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE",
    "CREATE",
    "DROP",
    "INDEX",
    "ALTER",
    "CREATE TEMPORARY TABLES",
    "LOCK TABLES",
    "TRIGGER",
    "CREATE VIEW",
  ]
}
