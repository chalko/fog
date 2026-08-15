# Data source to retrieve the long-lived token reviewer ServiceAccount token from K8s
data "kubernetes_secret" "vault_reviewer" {
  metadata {
    name      = "vault-reviewer-token"
    namespace = "kube-system"
  }
}

# 1. Enable K8s Auth Backend inside Vault
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

# 2. Configure K8s Client Info in Vault using values retrieved from K8s
resource "vault_kubernetes_auth_backend_config" "k8s" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://10.7.82.15:6443"
  kubernetes_ca_cert     = data.kubernetes_secret.vault_reviewer.data["ca.crt"]
  token_reviewer_jwt     = data.kubernetes_secret.vault_reviewer.data["token"]
  disable_iss_validation = true
}

# 3. Create Access Policy
resource "vault_policy" "k8s_read" {
  name   = "k8s-read"
  policy = <<EOT
path "secret/data/app/*" {
  capabilities = ["read"]
}
path "secret/data/infrastructure/*" {
  capabilities = ["read"]
}
EOT
}

# 4. Bind Policy to Kubernetes Service Account
resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "app-role"
  bound_service_account_names      = ["app-sa"]
  bound_service_account_namespaces = ["default", "external-dns", "gitea", "dolt"]
  token_policies                   = [vault_policy.k8s_read.name]
  token_ttl                        = 86400
}

# 5. Policy for Standalone AI/GPU Host (Haze)
resource "vault_policy" "haze_read" {
  name   = "haze-read"
  policy = <<EOT
path "secret/data/fog/haze/*" {
  capabilities = ["read"]
}
path "secret/data/app/haze/*" {
  capabilities = ["read"]
}
EOT
}

# 6. Enable AppRole Auth Backend for Standalone Hosts
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# 7. AppRole for Haze Node
resource "vault_approle_auth_backend_role" "haze_role" {
  backend        = vault_auth_backend.approle.path
  role_name      = "haze"
  token_policies = [vault_policy.haze_read.name]
  token_ttl      = 86400
}

# 8. Dedicated Least-Privilege Policy for Harbor Registry
resource "vault_policy" "harbor_policy" {
  name   = "harbor-read"
  policy = <<EOT
path "secret/data/app/harbor" {
  capabilities = ["read"]
}
path "secret/data/app/harbor/*" {
  capabilities = ["read"]
}
EOT
}

# 9. Bind Harbor Policy to Harbor ServiceAccount
resource "vault_kubernetes_auth_backend_role" "harbor_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "harbor-role"
  bound_service_account_names      = ["harbor-sa", "default"]
  bound_service_account_namespaces = ["harbor"]
  token_policies                   = [vault_policy.harbor_policy.name]
  token_ttl                        = 86400
}

# 10. Dedicated Least-Privilege Policy for Proxmox DNS Sync
resource "vault_policy" "proxmox_dns_sync_policy" {
  name   = "proxmox-dns-sync-read"
  policy = <<EOT
path "secret/data/app/proxmox-dns-sync" {
  capabilities = ["read"]
}
path "secret/data/infrastructure/pve" {
  capabilities = ["read"]
}
path "secret/data/infrastructure/pihole" {
  capabilities = ["read"]
}
EOT
}

# 11. Bind Proxmox DNS Sync Policy to ServiceAccount
resource "vault_kubernetes_auth_backend_role" "proxmox_dns_sync_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "proxmox-dns-sync-role"
  bound_service_account_names      = ["proxmox-dns-sync-sa", "default"]
  bound_service_account_namespaces = ["proxmox-dns-sync"]
  token_policies                   = [vault_policy.proxmox_dns_sync_policy.name]
  token_ttl                        = 86400
}

# 12. Dedicated Least-Privilege Policy for NetBox
resource "vault_policy" "netbox_policy" {
  name   = "netbox-read"
  policy = <<EOT
path "secret/data/app/netbox" {
  capabilities = ["read"]
}
path "secret/data/app/netbox/*" {
  capabilities = ["read"]
}
EOT
}

# 13. Bind NetBox Policy to ServiceAccount
resource "vault_kubernetes_auth_backend_role" "netbox_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "netbox-role"
  bound_service_account_names      = ["netbox-sa", "default"]
  bound_service_account_namespaces = ["netbox"]
  token_policies                   = [vault_policy.netbox_policy.name]
  token_ttl                        = 86400
}

# 14. Dedicated Least-Privilege Policy for LibreNMS
resource "vault_policy" "librenms_policy" {
  name   = "librenms-read"
  policy = <<EOT
path "secret/data/app/librenms" {
  capabilities = ["read"]
}
path "secret/data/app/librenms/*" {
  capabilities = ["read"]
}
EOT
}

# 15. Bind LibreNMS Policy to ServiceAccount
resource "vault_kubernetes_auth_backend_role" "librenms_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "librenms-role"
  bound_service_account_names      = ["librenms-sa", "default"]
  bound_service_account_namespaces = ["librenms"]
  token_policies                   = [vault_policy.librenms_policy.name]
  token_ttl                        = 86400
}

# 16. Dedicated Least-Privilege Policy for Oxidized
resource "vault_policy" "oxidized_policy" {
  name   = "oxidized-read"
  policy = <<EOT
path "secret/data/app/oxidized" {
  capabilities = ["read"]
}
path "secret/data/app/oxidized/*" {
  capabilities = ["read"]
}
EOT
}

# 17. Bind Oxidized Policy to ServiceAccount
resource "vault_kubernetes_auth_backend_role" "oxidized_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "oxidized-role"
  bound_service_account_names      = ["oxidized-sa", "default"]
  bound_service_account_namespaces = ["oxidized"]
  token_policies                   = [vault_policy.oxidized_policy.name]
  token_ttl                        = 86400
}




