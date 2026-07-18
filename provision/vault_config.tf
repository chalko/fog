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
EOT
}

# 4. Bind Policy to Kubernetes Service Account
resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "app-role"
  bound_service_account_names      = ["app-sa"]
  bound_service_account_namespaces = ["default", "external-dns", "gitea"]
  token_policies                   = [vault_policy.k8s_read.name]
  token_ttl                        = 86400
}
