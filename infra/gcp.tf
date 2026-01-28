# =============================================================================
# GCP Resources - aackle
# =============================================================================

# Using the existing default network (not managing it with Terraform)
data "google_compute_network" "default" {
  name    = "default"
  project = var.gcp_project
}

data "google_compute_subnetwork" "default" {
  name    = "default"
  region  = "us-central1"
  project = var.gcp_project
}

# -----------------------------------------------------------------------------
# Compute Instance: aackle
# -----------------------------------------------------------------------------
resource "google_compute_instance" "aackle" {
  name         = "aackle"
  machine_type = "e2-micro"
  zone         = "us-central1-c"
  project      = var.gcp_project

  boot_disk {
    auto_delete = true
    device_name = "aackle"

    initialize_params {
      size  = 30
      type  = "pd-standard"
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = data.google_compute_network.default.self_link
    subnetwork = data.google_compute_subnetwork.default.self_link

    access_config {
      network_tier = "STANDARD"
    }
  }

  metadata = {
    enable-osconfig = "TRUE"
    ssh-keys        = "turbio:${var.ssh_public_key}"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  labels = {
    goog-ops-agent-policy = "v2-x86-template-1-4-0"
  }
}

# -----------------------------------------------------------------------------
# Firewall Rules
# -----------------------------------------------------------------------------

# Allow all traffic (priority 1 - highest)
resource "google_compute_firewall" "allow_all" {
  name     = "allow-all"
  network  = data.google_compute_network.default.self_link
  project  = var.gcp_project
  priority = 1

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Default rules (SSH, HTTP, HTTPS)
resource "google_compute_firewall" "default" {
  name     = "default"
  network  = data.google_compute_network.default.self_link
  project  = var.gcp_project
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# WireGuard
resource "google_compute_firewall" "wireguard" {
  name     = "wiregaurd"
  network  = data.google_compute_network.default.self_link
  project  = var.gcp_project
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["51820"]
  }

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "aackle_external_ip" {
  value = google_compute_instance.aackle.network_interface[0].access_config[0].nat_ip
}

output "aackle_internal_ip" {
  value = google_compute_instance.aackle.network_interface[0].network_ip
}
