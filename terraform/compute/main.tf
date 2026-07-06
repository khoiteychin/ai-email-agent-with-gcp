# 1. Cloud Armor Security Policy (WAF)
resource "google_compute_security_policy" "waf" {
  name        = "uat-waf-policy"
  description = "Basic WAF protection for UAT environment"

  # Default rule: allow all traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  # Block known SQL injection / XSS using preconfigured WAF rules
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable') || evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block SQLi and XSS"
  }
}

# Enable Identity Toolkit API (for Identity Platform)
resource "google_project_service" "identitytoolkit" {
  provider           = google-beta
  project            = var.project_id
  service            = "identitytoolkit.googleapis.com"
  disable_on_destroy = false
}

# 2. Identity Platform configuration (Enabling Auth)
resource "google_identity_platform_config" "gcip_config" {
  provider   = google-beta
  project    = var.project_id
  depends_on = [google_project_service.identitytoolkit]

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = true
    }
  }
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable Pub/Sub API
resource "google_project_service" "pubsub" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# Create Pub/Sub Topic for Gmail Notifications
resource "google_pubsub_topic" "gmail_topic" {
  name       = "gmail-notifications"
  depends_on = [google_project_service.pubsub]
}

# Create Pub/Sub Subscription for Backend Worker
resource "google_pubsub_subscription" "gmail_sub" {
  name  = "gmail-notifications-sub"
  topic = google_pubsub_topic.gmail_topic.name

  # Message retention (e.g. 7 days)
  message_retention_duration = "604800s"
  retain_acked_messages      = false
  ack_deadline_seconds       = 20

  expiration_policy {
    # Never expire subscription
    ttl = ""
  }
}

# Grant Gmail API permission to publish to the Topic
resource "google_pubsub_topic_iam_member" "gmail_publisher" {
  topic  = google_pubsub_topic.gmail_topic.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:gmail-api-push@system.gserviceaccount.com"
}


# 3. IAM Service Account for VMs
resource "google_project_iam_member" "gcip_admin" {
  project = var.project_id
  role    = "roles/firebase.admin"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_service_account" "vm_sa" {
  account_id   = "uat-vm-service-account"
  display_name = "UAT VM Service Account"
}

# Secret Manager Secrets
resource "google_secret_manager_secret" "db_password" {
  secret_id = "uat-db-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

resource "google_secret_manager_secret" "openai_api_key" {
  secret_id = "uat-openai-api-key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "openai_api_key_version" {
  secret      = google_secret_manager_secret.openai_api_key.id
  secret_data = var.openai_api_key
}

resource "google_secret_manager_secret" "discord_bot_token" {
  secret_id = "uat-discord-bot-token"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "discord_bot_token_version" {
  secret      = google_secret_manager_secret.discord_bot_token.id
  secret_data = var.discord_bot_token
}

resource "google_secret_manager_secret" "encryption_key" {
  secret_id = "uat-encryption-key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "encryption_key_version" {
  secret      = google_secret_manager_secret.encryption_key.id
  secret_data = var.encryption_key
}

resource "google_secret_manager_secret" "google_client_secret" {
  secret_id = "uat-google-client-secret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "google_client_secret_version" {
  secret      = google_secret_manager_secret.google_client_secret.id
  secret_data = var.google_client_secret
}

resource "google_secret_manager_secret" "discord_client_secret" {
  secret_id = "uat-discord-client-secret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "discord_client_secret_version" {
  secret      = google_secret_manager_secret.discord_client_secret.id
  secret_data = var.discord_client_secret
}

# IAM Permissions for Service Account to access Secrets
resource "google_secret_manager_secret_iam_member" "db_password_accessor" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "openai_api_key_accessor" {
  secret_id = google_secret_manager_secret.openai_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "discord_bot_token_accessor" {
  secret_id = google_secret_manager_secret.discord_bot_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "encryption_key_accessor" {
  secret_id = google_secret_manager_secret.encryption_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "google_client_secret_accessor" {
  secret_id = google_secret_manager_secret.google_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "discord_client_secret_accessor" {
  secret_id = google_secret_manager_secret.discord_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_sa.email}"
}

# Grant VM Service Account permission to subscribe to Pub/Sub
resource "google_pubsub_subscription_iam_member" "vm_subscriber" {
  subscription = google_pubsub_subscription.gmail_sub.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.vm_sa.email}"
}

# 4. Instance Template for API Web Server VMs
resource "google_compute_instance_template" "api_template" {
  name_prefix  = "uat-api-template-"
  machine_type = "e2-small"
  region       = var.region

  network_interface {
    network    = var.vpc_id
    subnetwork = var.app_subnet_id
    # No public IP (associate_public_ip_address = false)
  }

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip git postgresql-client
    
    # Setup app directory
    mkdir -p /opt/app
    cd /opt/app
    
    # Note: In real setup, you would clone your Git repository here.
    # We will write a placeholder startup logging.
    echo "Starting UAT API server..."
    
    # Fetch secrets from Secret Manager
    DB_PASSWORD=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.db_password.secret_id}" --project="${var.project_id}")
    OPENAI_API_KEY=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.openai_api_key.secret_id}" --project="${var.project_id}")
    DISCORD_BOT_TOKEN=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.discord_bot_token.secret_id}" --project="${var.project_id}")
    ENCRYPTION_KEY=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.encryption_key.secret_id}" --project="${var.project_id}")
    GOOGLE_CLIENT_SECRET=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.google_client_secret.secret_id}" --project="${var.project_id}")
    DISCORD_CLIENT_SECRET=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.discord_client_secret.secret_id}" --project="${var.project_id}")

    # Environment variables
    export DATABASE_URL="postgresql+asyncpg://${var.db_user}:$${DB_PASSWORD}@${var.db_private_ip}/${var.db_name}"
    export DATABASE_URL_SYNC="postgresql://${var.db_user}:$${DB_PASSWORD}@${var.db_private_ip}/${var.db_name}"
    export ENVIRONMENT="production"
    export FIREBASE_PROJECT_ID="${var.project_id}"
    export OPENAI_API_KEY="$${OPENAI_API_KEY}"
    export DISCORD_BOT_TOKEN="$${DISCORD_BOT_TOKEN}"
    export ENCRYPTION_KEY="$${ENCRYPTION_KEY}"
    export GMAIL_PUBSUB_TOPIC="${google_pubsub_topic.gmail_topic.id}"
    export GOOGLE_CLIENT_ID="${var.google_client_id}"
    export GOOGLE_CLIENT_SECRET="$${GOOGLE_CLIENT_SECRET}"
    export DISCORD_CLIENT_ID="${var.discord_client_id}"
    export DISCORD_CLIENT_SECRET="$${DISCORD_CLIENT_SECRET}"
    
    echo "Starting UAT API server and Background Worker..."
    # Startup python server and worker commands would go here
    # e.g. 
    # pm2 start run.py --name "api" --interpreter python3
    # pm2 start run_worker.py --name "worker" --interpreter python3
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

# 5. Managed Instance Group (MIG) for API Servers
resource "google_compute_region_instance_group_manager" "api_mig" {
  name               = "uat-api-mig"
  region             = var.region
  base_instance_name = "uat-api"
  target_size        = 1 # Start with 1 instance

  version {
    instance_template = google_compute_instance_template.api_template.id
  }

  named_port {
    name = "http"
    port = 3001
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.api_health.id
    initial_delay_sec = 180
  }
}

# 6. Autoscaler for API Servers
resource "google_compute_region_autoscaler" "api_autoscaler" {
  name   = "uat-api-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.api_mig.id

  autoscaling_policy {
    max_replicas    = 1 # Set to 1 as requested to control costs for now, can be increased easily
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.6
    }
  }
}

# 7. Health Check for API Server
resource "google_compute_health_check" "api_health" {
  name                = "uat-api-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 3001
    request_path = "/health"
  }
}


# 9. Global HTTP(S) Load Balancer configuration
# Reserve static public IP
resource "google_compute_global_address" "lb_ip" {
  name = "uat-lb-ip"
}

# Managed SSL Certificate
resource "google_compute_managed_ssl_certificate" "cert" {
  name = "uat-ssl-cert"

  managed {
    domains = [var.domain_name]
  }
}

# URL Map
resource "google_compute_url_map" "url_map" {
  name            = "uat-url-map"
  default_service = google_compute_backend_service.api_backend.id
}

# Backend Service (with Cloud CDN and Cloud Armor enabled)
resource "google_compute_backend_service" "api_backend" {
  name                  = "uat-api-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.api_health.id]
  security_policy       = google_compute_security_policy.waf.id
  enable_cdn            = true

  backend {
    group = google_compute_region_instance_group_manager.api_mig.instance_group
  }
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "uat-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# Forwarding Rule
resource "google_compute_global_forwarding_rule" "https_forwarding" {
  name                  = "uat-https-forwarding-rule"
  ip_address            = google_compute_global_address.lb_ip.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
  load_balancing_scheme = "EXTERNAL"
}

# 10. Firewall rule: Allow Load Balancer health check and traffic into VM
resource "google_compute_firewall" "allow_lb" {
  name          = "allow-lb-to-api"
  network       = var.vpc_id
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] # GCP LB IP ranges

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  target_tags = ["api-server"]
}
