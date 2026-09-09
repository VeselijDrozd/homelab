# Homelab infrastructure

IaC for a Proxmox-based home lab:

**Terraform (VMs) → Ansible (kubeadm) → Kubernetes apps (website, monitoring)**

| Remote | URL / role |
|--------|------------|
| **GitLab** | `homelab/homelab` — CI + Managed Terraform State (primary) |
| **GitHub** | [VeselijDrozd/homelab](https://github.com/VeselijDrozd/homelab) — public mirror |

Default branch: **`main`**.

## Layout

```
homelab/
├── .gitlab-ci.yml
├── terraform/
│   ├── backend.tf              # GitLab HTTP remote state
│   ├── main.tf                 # images + VM module (git ref v1.1.2)
│   ├── ci/
│   │   ├── setup.sh            # CI init, secrets, TF_HTTP_*, mirror
│   │   └── terraformrc         # Yandex provider mirror (geo-block workaround)
│   ├── examples/               # homework: cloud-init Docker/Compose + UFW
│   ├── gitlab_http_backend_cred.sh.example
│   ├── terraform.tfvars.example
│   └── terraform.tfvars.ci.example
├── ansible/                    # kubeadm cluster bootstrap
└── k8s/
    ├── 00-prereqisites/        # ingress-nginx values, …
    ├── 01-website/             # static site + MariaDB/API manifests (copies)
    └── 02-monitoring/          # kube-prometheus-stack + Grafana ingress
```

Related repos:

| Path | Hosting | Role |
|------|---------|------|
| [`terraform-proxmox-vm-module`](https://github.com/VeselijDrozd/terraform-proxmox-vm-module) | GitHub | Reusable Proxmox VM module |
| `surfhouse` | GitLab `homelab/surfhouse` | Landing + Flask API + MariaDB deploy CI |

Canonical website/API/DB manifests for CI live in **surfhouse** (`surfhouse/k8s/`).  
`k8s/01-website/` keeps copies for manual apply from this repo — see [`k8s/01-website/README.md`](k8s/01-website/README.md).

## Quick start (laptop)

1. Cloud image with qemu-guest-agent on Proxmox (or let Terraform download via `url=`).
2. Terraform:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars   # fill secrets
   cp gitlab_http_backend_cred.sh.example gitlab_http_backend_cred.sh
   source ./gitlab_http_backend_cred.sh           # GitLab state
   # if registry.terraform.io is geo-blocked:
   export TF_CLI_CONFIG_FILE=$PWD/ci/terraformrc
   terraform init
   terraform plan
   terraform apply
   ```
3. Inventory: `ansible/inventory.ini` (generated).
4. Cluster: `cd ../ansible && ansible-playbook k8s-cluster.yml`.
5. Platform: apply/Helm from `k8s/` (Ingress, local-path, website, monitoring).
6. App CI: push/build in **surfhouse** (Registry + deploy to `website` namespace).

More Terraform detail: [`terraform/README.md`](terraform/README.md).

## Secrets (never commit)

| File / variable | Purpose |
|-----------------|--------|
| `terraform/terraform.tfvars` | Proxmox + VM definitions (from `*.example`) |
| `terraform/gitlab_http_backend_cred.sh` | PAT for local state access |
| `terraform/s3_backend_cred.sh` | Optional MinIO backend (from `*.example`) |
| `k8s/02-monitoring/*secrets*.yml` | Grafana admin password overlay |
| GitLab CI File vars | See below |

Homework demos (user-data Docker/Compose + ports 22/80/443): [`terraform/examples/`](terraform/examples/).

---

## GitLab Managed State

- Backend: `backend "http"` → project **ID 3** / state name **`homelab`** (adjust in cred script if needed).
- UI: **Operate → Terraform states**.
- Local: `source gitlab_http_backend_cred.sh` then `terraform init`  
  (`GITLAB_URL=http://gitlab.homelab.local`, PAT with scope `api`).

First-time migration from an old local state (already done in this lab):

```bash
source ./gitlab_http_backend_cred.sh
terraform init -migrate-state
```

---

## GitLab CI (Terraform)

Pipeline: **`fmt` → `validate` → `plan` → manual `apply`**.

### CI/CD variables

| Variable | Type | Notes |
|----------|------|--------|
| `TF_VARS_FILE` | **File** (not Masked) | Full tfvars; CI key paths `/tmp/tf-ci-keys/…` — see `terraform.tfvars.ci.example` |
| `SSH_PUBLIC_KEY` | **File** | → `/tmp/tf-ci-keys/id.pub` |
| `SSH_PRIVATE_KEY` | **File** | → `/tmp/tf-ci-keys/id` |
| `GITLAB_CA_CERT` | File, optional | Only if GitLab HTTPS uses a private CA |

Type must be **File**: with type Variable, `setup.sh` treats the value as a path and `cp` fails.

State in CI uses `CI_JOB_TOKEN` (no PAT in the pipeline).

### Runner requirements

- Reach Proxmox API (`https://…:8006`)
- Reach GitHub (module `git::https://github.com/…`)
- Provider installs via **Yandex mirror** (`terraform/ci/terraformrc`) — official `registry.terraform.io` is often geo-blocked (RU)

### Jobs

| Job | When | Action |
|-----|------|--------|
| `terraform:fmt` | MR + `main` | `fmt -check` |
| `terraform:validate` | MR + `main` | `init` + `validate` |
| `terraform:plan` | MR + `main` | plan artifact |
| `terraform:apply` | `main` only | **manual** apply |

`apply` stays **Blocked/manual** until you press ▶ — intentional.

### Images in CI tfvars

Prefer `url=` for cloud images so the runner does not need a local `.img`.  
Switching `local_path` ↔ `url` in an existing state can rewrite image resources — review the plan carefully.

---

## Kubernetes apps (overview)

| Stack | Namespace / path | Notes |
|-------|------------------|--------|
| Website | `website` / `k8s/01-website` | nginx static; API + MariaDB deployed mainly via **surfhouse** CI |
| Monitoring | `monitoring` / `k8s/02-monitoring` | kube-prometheus-stack, Grafana `grafana.local` |

Surfhouse public URLs (typical): `http://surfhouse.local/` and `http://surfhouse.local/api/hits`  
(DB password: GitLab Variable `DB_PASSWORD` in the **surfhouse** project → Secret `surfhouse-db`).
