# Enable Service Networking API
resource "google_project_service" "servicenetworking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud SQL Admin API
resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# 1. Reserve internal IP range for Private Service Access
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "prod-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_id
  depends_on    = [google_project_service.servicenetworking]
}

# 2. Establish private connection to service networking
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  depends_on              = [google_project_service.servicenetworking]
}

# 3. Create Cloud SQL Instance (PostgreSQL)
resource "google_sql_database_instance" "postgres" {
  name             = var.db_instance_name
  database_version = "POSTGRES_15"
  region           = var.region

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.sqladmin
  ]

  settings {
    tier = "db-f1-micro" # Small/Development size, adjust for production

    ip_configuration {
      ipv4_enabled    = false # Disable public IP
      private_network = var.vpc_id
    }

    backup_configuration {
      enabled = true
    }
  }
}

# 4. Create Database
resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# 5. Create Database User
resource "google_sql_user" "db_user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}
