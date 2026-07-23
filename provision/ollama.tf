resource "random_password" "ollama_root_password" {
  length  = 20
  special = true
}

resource "proxmox_virtual_environment_container" "ollama" {
  node_name    = var.proxmox_node
  vm_id        = 9100
  unprivileged = true

  initialization {
    hostname = "ollama"

    ip_config {
      ipv4 {
        address = "10.7.82.100/24"
        gateway = "10.7.82.1"
      }
    }

    dns {
      server = "10.5.110.3"
    }

    user_account {
      keys     = [trimspace(file("/home/nick/id_rsa_yubikey.pub"))]
      password = random_password.ollama_root_password.result
    }
  }

  network_interface {
    name   = "veth0"
    bridge = var.vm_bridge
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 12288
  }

  disk {
    datastore_id = "local-fast-zfs"
    size         = 40
  }

  features {
    nesting = true
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.debian_lxc_template.id
    type             = "debian"
  }

  start_on_boot = true
}

output "ollama_container_ip" {
  value       = "10.7.82.100"
  description = "The static IP address of the Ollama LXC container"
}
