# Homelab infrastructure (public GitHub)

IaC for a Proxmox-based home lab: VMs → Ansible inventory → Kubernetes → platform apps.

## Layout

```
homelab/
├── terraform/     # Proxmox VMs (uses sibling module ../../terraform-proxmox-vm-module)
├── ansible/       # kubeadm cluster bootstrap
├── k8s/           # manifests & Helm values (website, monitoring, …)
└── gitlab/        # notes / related deploy experiments
```

Related repos (siblings under `devops/`):

| Path | Hosting | Role |
|------|---------|------|
| `../terraform-proxmox-vm-module` | GitHub (public) | Reusable Terraform VM module |
| `../surfhouse` | GitLab (homelab) | Sample app + CI/CD |

## Suggested order

1. Prepare cloud image with qemu-guest-agent.
2. `cd terraform && cp terraform.tfvars.example terraform.tfvars` → fill secrets → `terraform apply`.
3. Inventory is written to `ansible/inventory.ini`.
4. `cd ../ansible && ansible-playbook k8s-cluster.yml`.
5. Deploy platform pieces from `k8s/` (Ingress, local-path, apps, monitoring).

## Secrets

Do not commit real passwords. Use:

- `terraform/terraform.tfvars` (gitignored) from `terraform.tfvars.example`
- `terraform/s3_backend_cred.sh` (gitignored) from `s3_backend_cred.sh.example`
- `k8s/02-monitoring/kube-prometheus-stack-secrets.yml` (gitignored) from `*.example`

## Homework / deep links

After the repo is on GitHub, link to folders, for example:

- Terraform: `.../tree/main/terraform`
- Ansible: `.../tree/main/ansible`
- Monitoring: `.../tree/main/k8s/02-monitoring`
