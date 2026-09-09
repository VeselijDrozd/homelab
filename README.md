# Homelab infrastructure

IaC for a Proxmox-based home lab: VMs → Ansible inventory → Kubernetes → platform apps.

Hosting:

| Remote | Role |
|--------|------|
| GitHub (`VeselijDrozd/homelab`) | public mirror / history |
| GitLab (homelab) | **source of truth for CI** + Managed Terraform State |

## Layout

```
homelab/
├── .gitlab-ci.yml   # Terraform fmt → validate → plan → manual apply
├── terraform/       # Proxmox VMs + remote state (GitLab HTTP backend)
├── ansible/         # kubeadm cluster bootstrap
├── k8s/             # manifests & Helm values (website, monitoring, …)
└── gitlab/          # notes / related deploy experiments
```

Related repos:

| Path | Hosting | Role |
|------|---------|------|
| `../terraform-proxmox-vm-module` | GitHub (public) | Reusable Terraform VM module (also pulled by git ref in CI) |
| `../surfhouse` | GitLab (homelab) | Sample app + deploy CI |

## Suggested order

1. Prepare cloud image with qemu-guest-agent.
2. `cd terraform && cp terraform.tfvars.example terraform.tfvars` → fill secrets → `terraform apply`.
3. Inventory is written to `ansible/inventory.ini`.
4. `cd ../ansible && ansible-playbook k8s-cluster.yml`.
5. Deploy platform pieces from `k8s/` (Ingress, local-path, apps, monitoring).

## Secrets

Do not commit real passwords. Use:

- `terraform/terraform.tfvars` (gitignored) from `terraform.tfvars.example`
- `terraform/gitlab_http_backend_cred.sh` (gitignored) from `gitlab_http_backend_cred.sh.example`
- `terraform/s3_backend_cred.sh` (gitignored) from `s3_backend_cred.sh.example` (optional MinIO)
- `k8s/02-monitoring/kube-prometheus-stack-secrets.yml` (gitignored) from `*.example`

Homework demos (cloud-init Docker/Compose + UFW ports): [`terraform/examples/`](terraform/examples/).

---

## GitLab CI / remote state

Phases 1–2: **Managed Terraform State** + pipeline `fmt` → `validate` → `plan` → **manual** `apply`.

### 1. Create GitLab project

Create an empty project (e.g. `homelab/homelab` or `homelab/infra`). Note the numeric **Project ID**.

Add GitLab remote (keep GitHub if you want):

```bash
cd /path/to/homelab
git remote add gitlab git@gitlab.homelab.local:GROUP/homelab.git
# first push after commit:
git push -u gitlab master
```

### 2. Migrate local state → GitLab (once, from your laptop)

```bash
cd terraform
cp gitlab_http_backend_cred.sh.example gitlab_http_backend_cred.sh
# edit URL, PROJECT_ID, username, PAT (scope: api)
source ./gitlab_http_backend_cred.sh
terraform init -migrate-state
```

Confirm in GitLab UI: **Operate → Terraform states** (state name `homelab`).

If GitLab uses a private CA: `export SSL_CERT_FILE=/path/to/ca.pem` before `init`.

### 3. CI/CD variables (Settings → CI/CD → Variables)

| Variable | Type | Protected | Notes |
|----------|------|-----------|--------|
| `TF_VARS_FILE` | File | yes | Full `terraform.tfvars` for the runner; see `terraform/terraform.tfvars.ci.example` |
| `SSH_PUBLIC_KEY` | File | yes | Public key → `/tmp/tf-ci-keys/id.pub` |
| `SSH_PRIVATE_KEY` | File | yes | Private key (needed if `local_path` image upload / inventory SSH path) |
| `GITLAB_CA_CERT` | File | optional | Homelab CA if API HTTPS is self-signed |

`CI_JOB_TOKEN` is used automatically for state auth (no PAT in CI).

Runner must reach **Proxmox API**, **GitHub** (module source), and a Terraform
provider mirror. Official `registry.terraform.io` is often **geo-blocked**; CI
uses `terraform/ci/terraformrc` → `https://terraform-mirror.yandexcloud.net/`.
Locally you can `export TF_CLI_CONFIG_FILE=$PWD/terraform/ci/terraformrc` before
`terraform init` if you hit the same error.

### 4. Pipeline behaviour

| Job | When | Action |
|-----|------|--------|
| `terraform:fmt` | MR + default branch | `terraform fmt -check` |
| `terraform:validate` | MR + default branch | `init` + `validate` |
| `terraform:plan` | MR + default branch | `plan` artifact (`tfplan`, `tfplan.txt`) |
| `terraform:apply` | default branch only | **manual** apply of the plan artifact |

### 5. Images in CI

Prefer `url=` for cloud images in `TF_VARS_FILE` so the runner does not need a local `.img`. Switching `local_path` ↔ `url` for an existing image may require state surgery — do it carefully on a laptop first.

More Terraform detail: [`terraform/README.md`](terraform/README.md).
