terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -------------------------------
# Firewall rule (SSH + Locust)
# -------------------------------
resource "google_compute_firewall" "loadgen_firewall" {
  name    = "allow-loadgen"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "8089"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["loadgen"]
}

# -------------------------------
# Compute Engine VM
# -------------------------------
resource "google_compute_instance" "loadgen_vm" {
  name         = var.vm_name
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["loadgen"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  # ---- SSH key injection ----
  metadata = {
    ssh-keys = "ansible:${file("~/.ssh/ansible_vm.pub")}"
  }

  # ---- Enable passwordless sudo for Ansible ----
  metadata_startup_script = <<-EOF
    #!/bin/bash
    useradd -m -s /bin/bash ansible || true
    usermod -aG sudo ansible
    echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
    chmod 440 /etc/sudoers.d/ansible
  EOF
}

# -------------------------------
# Output external IP
# -------------------------------
output "loadgen_external_ip" {
  value = google_compute_instance.loadgen_vm.network_interface[0].access_config[0].nat_ip
}
