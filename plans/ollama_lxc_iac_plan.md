# Ollama LXC Infrastructure as Code (IaC) Expansion Plan

Currently, the Proxmox LXC container for Ollama is defined in Terraform ([ollama.tf](file:///home/nick/src/fog/provision/ollama.tf)), which handles the provisioning of system resources (CPU, RAM, storage, network). However, the internal software configuration (Ollama installation, systemd overrides, and model caching) is still done manually. 

This plan details how to codify the internal setup of the container.

---

## Option 1: Terraform Connection + `remote-exec` Provisioner (Self-Contained)

This option keeps everything within Terraform. After the container is provisioned, Terraform uses SSH to run commands inside the LXC.

### Setup Configuration
Modify [provision/ollama.tf](file:///home/nick/src/fog/provision/ollama.tf) to add a `connection` block and a `remote-exec` provisioner:

```hcl
resource "proxmox_virtual_environment_container" "ollama" {
  # ... existing configuration ...

  # Connection block to authenticate via SSH using root password or key
  connection {
    type     = "ssh"
    user     = "root"
    password = random_password.ollama_root_password.result
    host     = "10.7.82.100"
  }

  # Provisioner to install Ollama, configure systemd, and pre-pull models
  provisioner "remote-exec" {
    inline = [
      # 1. Install Ollama
      "curl -fsSL https://ollama.com/install.sh | sh",
      
      # 2. Configure Ollama to listen on all interfaces (OLLAMA_HOST=0.0.0.0)
      "mkdir -p /etc/systemd/system/ollama.service.d",
      "echo '[Service]' > /etc/systemd/system/ollama.service.d/override.conf",
      "echo 'Environment=\"OLLAMA_HOST=0.0.0.0\"' >> /etc/systemd/system/ollama.service.d/override.conf",
      
      # 3. Reload systemd and restart Ollama
      "systemctl daemon-reload",
      "systemctl restart ollama",
      
      # 4. Wait for Ollama service to start and pull initial models
      "sleep 5",
      "ollama pull llama3.2:1b",
      "ollama pull nomic-embed-text"
    ]
  }
}
```

---

## Option 2: Terraform + Ansible Playbook (Recommended for Maintainability)

This option decouples the infrastructure provisioning (Terraform) from the configuration management (Ansible).

### 1. Define the Ansible Playbook (`provision/ansible/playbooks/ollama_setup.yml`)
```yaml
- name: Configure Ollama LXC
  hosts: ollama
  become: yes
  tasks:
    - name: Download and install Ollama
      shell: curl -fsSL https://ollama.com/install.sh | sh
      args:
        creates: /usr/local/bin/ollama

    - name: Create systemd override directory
      file:
        path: /etc/systemd/system/ollama.service.d
        state: directory
        mode: '0755'

    - name: Create systemd override configuration
      copy:
        dest: /etc/systemd/system/ollama.service.d/override.conf
        content: |
          [Service]
          Environment="OLLAMA_HOST=0.0.0.0"
        mode: '0644'
      notify: Reload systemd

    - name: Start and enable Ollama service
      systemd:
        name: ollama
        state: started
        enabled: yes

    - name: Pre-pull utility models
      command: "ollama pull {{ item }}"
      loop:
        - llama3.2:1b
        - nomic-embed-text
      register: pull_result
      changed_when: "'success' in pull_result.stdout"

  handlers:
    - name: Reload systemd
      systemd:
        daemon_reload: yes
        state: restarted
        name: ollama
```

### 2. Connect via Terraform Trigger
Add a `local-exec` provisioner to [provision/ollama.tf](file:///home/nick/src/fog/provision/ollama.tf) to invoke the playbook after VM provisioning:
```hcl
resource "null_resource" "ansible_provision" {
  depends_on = [proxmox_virtual_environment_container.ollama]

  provisioner "local-exec" {
    command = "ansible-playbook -i '10.7.82.100,' -u root --private-key ~/.ssh/id_rsa provision/ansible/playbooks/ollama_setup.yml"
  }
}
```

---

## Advantages of Codifying this Configuration
1.  **Repeatability**: If the LXC container dies or the disk is corrupted, running `terraform apply` recreates the container and configures it back to its ready state with the models pre-loaded.
2.  **Explicit Documentation**: Anyone looking at the repository immediately understands how Ollama is configured inside the container without logging in to inspect the filesystem.
