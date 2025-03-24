# resource "mysql_database" "drupal_dashboard_staging" {
#   count = var.environment_is_production ? 0 : 1
#
#   name = var.db_schema
#   lifecycle {
#     prevent_destroy = false
#   }
# }
# resource "mysql_database" "drupal_dashboard_prod" {
#   count = var.environment_is_production ? 1 : 0
#
#   name = var.db_schema
#   lifecycle {
#     prevent_destroy = true
#   }
# }
#
# resource "mysql_user" "drupal" {
#   user = var.db_username
#   host = "%"
#   plaintext_password = var.db_password
# }
#
# resource "mysql_grant" "drupal_grant" {
#   user       = mysql_user.drupal.user
#   host       = mysql_user.drupal.host
#   database   = var.environment_is_production ? mysql_database.drupal_dashboard_prod[0].name : mysql_database.drupal_dashboard_staging[0].name
#   privileges = [
#     "SELECT",
#     "INSERT",
#     "UPDATE",
#     "DELETE",
#     "CREATE",
#     "DROP",
#     "INDEX",
#     "ALTER",
#     "CREATE TEMPORARY TABLES",
#     "LOCK TABLES",
#     "TRIGGER",
#     "CREATE VIEW",
#   ]
# }
