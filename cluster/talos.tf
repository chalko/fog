# Create the cluster secrets (CAs, tokens, encryption keys)
resource "talos_machine_secrets" "this" {
  talos_version = "v1.9.1"
}

# Generate machine configuration for controlplane
data "talos_machine_configuration" "controlplane" {
  cluster_name     = "talos-k8s-cluster"
  cluster_endpoint = "https://10.7.82.15:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.9.1"

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "ens18"
              addresses = ["10.7.82.15/24"]
              routes    = [{ network = "0.0.0.0/0", gateway = "10.7.82.1" }]
            }
          ]
          nameservers = ["10.5.110.3", "8.8.8.8"]
        }
        time = {
          servers = ["10.5.110.3"]
        }
      }
    })
  ]
}

# Generate machine configuration for workers
data "talos_machine_configuration" "worker" {
  cluster_name     = "talos-k8s-cluster"
  cluster_endpoint = "https://10.7.82.15:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.9.1"

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "ens18"
              addresses = ["10.7.82.16/24"]
              routes    = [{ network = "0.0.0.0/0", gateway = "10.7.82.1" }]
            }
          ]
          nameservers = ["10.5.110.3", "8.8.8.8"]
        }
        time = {
          servers = ["10.5.110.3"]
        }
      }
    })
  ]
}

# Apply configurations to nodes
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                 = "10.7.82.15"
  depends_on           = [proxmox_virtual_environment_vm.k8s_nodes]
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                 = "10.7.82.16"
  depends_on           = [proxmox_virtual_environment_vm.k8s_nodes]
}

# Bootstrap the cluster on controlplane node
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "10.7.82.15"
  depends_on           = [talos_machine_configuration_apply.controlplane]
}

# Retrieve the kubeconfig
data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "10.7.82.15"
  depends_on           = [talos_machine_bootstrap.this]
}

# Write kubeconfig locally
resource "local_file" "kubeconfig" {
  content  = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/../kubeconfig"
}

# Retrieve talosconfig using talos_client_configuration
data "talos_client_configuration" "this" {
  cluster_name         = "talos-k8s-cluster"
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = ["10.7.82.15"]
  endpoints            = ["10.7.82.15"]
}

# Write talosconfig locally
resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/../talosconfig"
}
