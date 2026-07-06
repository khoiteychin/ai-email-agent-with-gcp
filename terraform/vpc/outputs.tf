output "vpc_id" {
  value       = google_compute_network.vpc.id
  description = "The ID of the VPC"
}

output "vpc_name" {
  value       = google_compute_network.vpc.name
  description = "The Name of the VPC"
}

output "web_subnet_id" {
  value       = google_compute_subnetwork.web_subnet.id
  description = "The ID of the Web Subnet"
}

output "app_subnet_id" {
  value       = google_compute_subnetwork.app_subnet.id
  description = "The ID of the App Subnet"
}

output "db_subnet_id" {
  value       = google_compute_subnetwork.db_subnet.id
  description = "The ID of the DB Subnet"
}
