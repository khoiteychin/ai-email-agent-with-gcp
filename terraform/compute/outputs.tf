output "load_balancer_ip" {
  value       = google_compute_global_address.lb_ip.address
  description = "The static public IP address of the External Load Balancer"
}
