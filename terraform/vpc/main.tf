# 1. Custom VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

# 2. Subnet for Web Tier (Private VMs behind ALB)
resource "google_compute_subnetwork" "web_subnet" {
  name                     = "${var.vpc_name}-web-subnet"
  ip_cidr_range            = var.web_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# 3. Subnet for App Tier (Private Application VMs)
resource "google_compute_subnetwork" "app_subnet" {
  name                     = "${var.vpc_name}-app-subnet"
  ip_cidr_range            = var.app_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# 4. Subnet for DB Tier (For VMs if manually hosting or private access)
resource "google_compute_subnetwork" "db_subnet" {
  name                     = "${var.vpc_name}-db-subnet"
  ip_cidr_range            = var.db_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# 5. Cloud Router (Needed for Cloud NAT)
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# 6. Cloud NAT (Outbound access for private subnets)
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.web_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.app_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.db_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
