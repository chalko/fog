# AGENTS.md

Welcome to the `fog` home lab repository.

## Project Overview
This repository contains Infrastructure as Code (IaC) configuration for setting up and managing a home lab environment consisting of Proxmox VE, Docker hosts, and a Kubernetes cluster.

## Rules & Guidelines
1. **Secrets Management**:
   - Never commit plaintext secrets to this repository.
   - Use `pass` (password-store) to manage secrets.
   - Use cache files in `/dev/shm/fog/*.env` for active shell sessions to avoid tapping the YubiKey repeatedly.
2. **Infrastructure as Code (IaC)**:
   - Prefer declarative structures (Terraform, Ansible, Kubernetes YAML, Docker Compose).
