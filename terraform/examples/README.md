# Terraform examples (homework demos)

Small artefacts that map Yandex Cloud homework items onto the Proxmox lab
**without** changing the live kubeadm nodes.

| File | Assignment | Purpose |
|------|------------|---------|
| `cloud-init-docker-compose.yaml` | 1 (ports) + 2 | user-data: UFW 22/80/443 + Docker + Compose |
| `../gitlab_http_backend_cred.sh.example` | remote state | GitLab Managed Terraform State |
| `../terraform.tfvars.ci.example` | CI | secrets injected as File variables (LockBox-style) |

## cloud-init notes

Existing cluster VMs already boot with cloud-init for **user / SSH / IP**
(see `terraform-proxmox-vm-module`). Docker on those nodes would conflict with
**containerd** (Ansible). Use the YAML above only on a **separate demo VM**
or paste it into the diploma report as the Assignment 2 artefact.
