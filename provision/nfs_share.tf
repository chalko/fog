variable "proxmox_host_ip" {
  type        = string
  default     = "10.7.82.10"
  description = "The IP address of the Proxmox host (NFS server)"
}

variable "laptop_ip" {
  type        = string
  default     = "10.111.45.32"
  description = "The IP address of the laptop to authorize for mounting the NFS share"
}

variable "zfs_share_path" {
  type        = string
  default     = "local-fast-zfs/users/nick/wiki"
  description = "The ZFS dataset path to share"
}

locals {
  # Dynamically pull the K8s node IPs from the existing var.k8s_nodes map
  k8s_node_ips = [for node in var.k8s_nodes : node.ip]
  
  # Concatenate the K8s node IPs and the laptop IP, then join them with colons for ZFS sharenfs configuration
  authorized_clients = join(":", concat(local.k8s_node_ips, [var.laptop_ip]))
}

resource "terraform_data" "proxmox_nfs_share" {
  # Trigger configuration when the path or allowed clients change
  triggers_replace = [
    var.zfs_share_path,
    local.authorized_clients
  ]

  connection {
    type        = "ssh"
    host        = var.proxmox_host_ip
    user        = "root"
    agent       = true
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      # Ensure dataset parent directories exist and create the dataset if missing
      "zfs list ${var.zfs_share_path} || zfs create -p ${var.zfs_share_path}",
      # Configure ZFS sharenfs property securely with all_squash mapping to UID/GID 1000
      "zfs set sharenfs=\"rw=@${local.authorized_clients},all_squash,anonuid=1000,anongid=1000,async\" ${var.zfs_share_path}",
      # Restrict file permissions locally on the Proxmox host to nick:nick (1000:1000)
      "chown -R 1000:1000 /${var.zfs_share_path}",
      "chmod 770 /${var.zfs_share_path}",
      # Reload exports to apply
      "/usr/sbin/exportfs -ra"
    ]
  }
}
