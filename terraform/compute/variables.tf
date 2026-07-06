variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "The GCP Region"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC network"
}

variable "web_subnet_id" {
  type        = string
  description = "The ID of the Web subnet"
}

variable "app_subnet_id" {
  type        = string
  description = "The ID of the App subnet"
}

variable "db_private_ip" {
  type        = string
  description = "The private IP address of the database"
}

variable "db_user" {
  type        = string
  default     = "postgres"
}

variable "db_name" {
  type        = string
  default     = "ai_email_manager"
}

variable "db_password" {
  type        = string
  sensitive   = true
}

variable "domain_name" {
  type        = string
  default     = "api.emailkhanh.freeddns.org"
  description = "The domain name for the Load Balancer SSL certificate"
}

variable "openai_api_key" {
  type        = string
  sensitive   = true
  default     = ""
}

variable "discord_bot_token" {
  type        = string
  sensitive   = true
  default     = ""
}

variable "encryption_key" {
  type        = string
  sensitive   = true
  description = "Encryption key for Fernet crypto"
}

variable "google_client_id" {
  type        = string
  default     = ""
  description = "Google OAuth Client ID for Gmail"
}

variable "google_client_secret" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Google OAuth Client Secret for Gmail"
}

variable "discord_client_id" {
  type        = string
  default     = ""
  description = "Discord Application Client ID"
}

variable "discord_client_secret" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Discord Application Client Secret"
}
