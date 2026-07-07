# 1. Cloud Armor Security Policy (WAF)
resource "google_compute_security_policy" "waf" {
  name        = "prod-waf-policy"
  description = "Basic WAF protection for PROD environment"

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
        expression = "evalprodePreconfiguredExpr('sqli-v33-stable') || evalprodePreconfiguredExpr('xss-v33-stable')"
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
  account_id   = "prod-vm-service-account"
  display_name = "PROD VM Service Account"
}

# Secret Manager Secrets
resource "google_secret_manager_secret" "db_password" {
  secret_id = "prod-db-password"
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
  secret_id = "prod-openai-api-key"
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
  secret_id = "prod-discord-bot-token"
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
  secret_id = "prod-encryption-key"
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
  secret_id = "prod-google-client-secret"
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
  secret_id = "prod-discord-client-secret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "discord_client_secret_version" {
  secret      = google_secret_manager_secret.discord_client_secret.id
  secret_data = var.discord_client_secret
}

resource "google_secret_manager_secret" "frontend_env" {
  secret_id = "prod-frontend-env"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "frontend_env_version" {
  secret      = google_secret_manager_secret.frontend_env.id
  secret_data = var.frontend_env
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

resource "google_secret_manager_secret_iam_member" "frontend_env_accessor" {
  secret_id = google_secret_manager_secret.frontend_env.id
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
  name_prefix  = "prod-api-template-"
  machine_type = "e2-small"
  region       = var.region
  tags         = ["api-server"]

  network_interface {
    network    = var.vpc_id
    subnetwork = var.app_subnet_id
    # No public IP (associate_public_ip_address = false)
  }

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = replace(<<-EOT
    #!/bin/bash
    
    # 1. Update and install dependencies
    apt-get update
    apt-get install -y python3 python3-pip python3-venv git postgresql-client curl
    
    # 2. Install Node.js & PM2
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    npm install -g pm2
    
    # 3. Setup app directory and clone public repo
    mkdir -p /opt/app
    cd /opt/app
    rm -rf ai-email-agent-with-gcp
    git clone https://github.com/khoiteychin/ai-email-agent-with-gcp.git
    cd ai-email-agent-with-gcp/backend
    
    # 4. Fetch secrets from Secret Manager
    DB_PASSWORD=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.db_password.secret_id}" --project="${var.project_id}")
    OPENAI_API_KEY=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.openai_api_key.secret_id}" --project="${var.project_id}")
    DISCORD_BOT_TOKEN=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.discord_bot_token.secret_id}" --project="${var.project_id}")
    ENCRYPTION_KEY=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.encryption_key.secret_id}" --project="${var.project_id}")
    GOOGLE_CLIENT_SECRET=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.google_client_secret.secret_id}" --project="${var.project_id}")
    DISCORD_CLIENT_SECRET=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.discord_client_secret.secret_id}" --project="${var.project_id}")

    # 5. Export Environment variables and save to .env
    cat <<EOF > /opt/app/ai-email-agent-with-gcp/backend/.env
DATABASE_URL="postgresql+asyncpg://${var.db_user}:$${DB_PASSWORD}@${var.db_private_ip}/${var.db_name}"
DATABASE_URL_SYNC="postgresql://${var.db_user}:$${DB_PASSWORD}@${var.db_private_ip}/${var.db_name}"
ENVIRONMENT="production"
FIREBASE_PROJECT_ID="${var.project_id}"
OPENAI_API_KEY="$${OPENAI_API_KEY}"
DISCORD_BOT_TOKEN="$${DISCORD_BOT_TOKEN}"
ENCRYPTION_KEY="$${ENCRYPTION_KEY}"
GMAIL_PUBSUB_TOPIC="${google_pubsub_topic.gmail_topic.id}"
GOOGLE_CLIENT_ID="${var.google_client_id}"
GOOGLE_CLIENT_SECRET="$${GOOGLE_CLIENT_SECRET}"
DISCORD_CLIENT_ID="${var.discord_client_id}"
DISCORD_CLIENT_SECRET="$${DISCORD_CLIENT_SECRET}"
EOF
    
    # Still export them for the migration script that runs right after
    set -a
    source /opt/app/ai-email-agent-with-gcp/backend/.env
    set +a
    
    # 6. Setup Python virtual environment
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    
    # Run Database Migration
    python app/run_migration.py
        
    # 7. Setup Next.js Frontend
    cd /opt/app/ai-email-agent-with-gcp/frontend
    
    # Fetch frontend env from Secret Manager
    gcloud secrets versions access latest --secret="${google_secret_manager_secret.frontend_env.secret_id}" --project="${var.project_id}" > .env
    echo "" >> .env
    echo "NEXT_PUBLIC_API_URL=https://${var.domain_name}/api/v1" >> .env
    
    npm install --legacy-peer-deps
    npm run build
    
    # 8. Start apps via PM2 using ecosystem.config.js
    cat << 'EOF' > /opt/app/ai-email-agent-with-gcp/ecosystem.config.js
module.exports = {
  apps : [
    {
      name: "email-api",
      script: "run.py",
      cwd: "/opt/app/ai-email-agent-with-gcp/backend",
      interpreter: "/opt/app/ai-email-agent-with-gcp/backend/venv/bin/python"
    },
    {
      name: "email-worker",
      script: "run_worker.py",
      cwd: "/opt/app/ai-email-agent-with-gcp/backend",
      interpreter: "/opt/app/ai-email-agent-with-gcp/backend/venv/bin/python"
    },
    {
      name: "email-frontend",
      script: "npm",
      args: "start",
      cwd: "/opt/app/ai-email-agent-with-gcp/frontend"
    }
  ]
}
EOF

    cd /opt/app/ai-email-agent-with-gcp
    pm2 start ecosystem.config.js 
    # Save PM2 state to resurrect on reboot
    pm2 save
    env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root
  EOT
  , "\r\n", "\n")

  lifecycle {
    create_before_destroy = true
  }
}

# 5. Managed Instance Group (MIG) for API Servers
resource "google_compute_region_instance_group_manager" "api_mig" {
  name               = "prod-api-mig"
  region             = var.region
  base_instance_name = "prod-api"
  target_size        = 1 # Start with 1 instance

  version {
    instance_template = google_compute_instance_template.api_template.id
  }

  named_port {
    name = "http-api"
    port = 3001
  }

  named_port {
    name = "http-web"
    port = 3000
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.api_health.id
    initial_delay_sec = 600
  }
}

# 6. Autoscaler for API Servers
resource "google_compute_region_autoscaler" "api_autoscaler" {
  name   = "prod-api-autoscaler"
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
  name                = "prod-api-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 3001
    request_path = "/health"
  }
}

resource "google_compute_health_check" "web_health" {
  name                = "prod-web-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 3000
    request_path = "/login"
  }
}


# 9. Global HTTP(S) Load Balancer configuration
# Reserve static public IP
resource "google_compute_global_address" "lb_ip" {
  name = "prod-lb-ip"
}

# Managed SSL Certificate
resource "google_compute_managed_ssl_certificate" "cert" {
  name = "prod-ssl-cert"

  managed {
    domains = [var.domain_name]
  }
}

# URL Map
resource "google_compute_url_map" "url_map" {
  name            = "prod-url-map"
  default_service = google_compute_backend_service.web_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.web_backend.id

    path_rule {
      paths   = ["/api/v1/*", "/docs", "/openapi.json", "/health"]
      service = google_compute_backend_service.api_backend.id
    }
  }
}

# Backend Service for API
resource "google_compute_backend_service" "api_backend" {
  name                  = "prod-api-backend-service"
  protocol              = "HTTP"
  port_name             = "http-api"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.api_health.id]
  security_policy       = google_compute_security_policy.waf.id
  enable_cdn            = false

  backend {
    group = google_compute_region_instance_group_manager.api_mig.instance_group
  }
}

# Backend Service for Web
resource "google_compute_backend_service" "web_backend" {
  name                  = "prod-web-backend-service"
  protocol              = "HTTP"
  port_name             = "http-web"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.web_health.id]
  security_policy       = google_compute_security_policy.waf.id
  enable_cdn            = true

  backend {
    group = google_compute_region_instance_group_manager.api_mig.instance_group
  }
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "prod-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# Forwarding Rule
resource "google_compute_global_forwarding_rule" "https_forwarding" {
  name                  = "prod-https-forwarding-rule"
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
    ports    = ["3000", "3001"]
  }

  target_tags = ["api-server"]
}
