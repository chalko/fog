variable "proxmox_node" {
  type        = string
  default     = "pve"
  description = "The name of the Proxmox node to deploy VMs to"
}

variable "vm_bridge" {
  type        = string
  default     = "vmbr0"
  description = "The network bridge to attach the VM to"
}

variable "ssh_public_keys" {
  type        = list(string)
  default     = []
  description = "List of SSH public keys to inject into the VM"
}

variable "k8s_nodes" {
  type = map(object({
    vmid   = number
    cores  = number
    memory = number
    disk   = number
  }))
  default = {
    "k8s-control-01" = { vmid = 9010, cores = 2, memory = 4096, disk = 20 }
    "k8s-worker-01"  = { vmid = 9020, cores = 2, memory = 4096, disk = 40 }
  }
  description = "Map of Kubernetes nodes to deploy on Proxmox"
}
