output "db_private_ip" {
  value       = google_sql_database_instance.postgres.private_ip_address
  description = "The Private IP address of the Cloud SQL instance"
}

output "db_instance_name" {
  value       = google_sql_database_instance.postgres.name
  description = "The name of the database instance"
}
