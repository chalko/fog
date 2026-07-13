resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name    = "jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_vm" "k8s_nodes" {
  for_each    = var.k8s_nodes
  name        = each.key
  description = "Kubernetes Node - Managed by Terraform/OpenTofu"
  tags        = ["terraform", "k8s", "ubuntu"]
  node_name   = var.proxmox_node
  vm_id       = each.value.vmid

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = false
  }

  network_device {
    bridge = var.vm_bridge
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = each.value.disk
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "ubuntu"
      keys     = concat([trimspace(file(pathexpand("~/.ssh/id_rsa_yubikey.pub")))], var.ssh_public_keys)
    }
  }
}
