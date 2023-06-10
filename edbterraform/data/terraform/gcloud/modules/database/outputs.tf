output "instance_type" {
  value = google_sql_database_instance.instance.settings[0].tier
}
output "region" {
  value = google_sql_database_instance.instance.region
}
output "username" {
  value = google_sql_user.user.name
}
output "password" {
  value = google_sql_user.user.password
}
output "private_ip" {
  value = google_sql_database_instance.instance.private_ip_address
}
output "public_ip" {
  value = google_sql_database_instance.instance.public_ip_address
}
output "port" {
  value = var.port
}
output "version" {
  value = google_sql_database_instance.instance.database_version
}
output "dbname" {
  value = google_sql_database.db.name
}
output "tags" {
  value = var.tags
}
output "labels" {
  value = google_sql_database_instance.instance.settings[0].user_labels
}
