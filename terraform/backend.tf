# Remote state: GitLab Managed Terraform State (HTTP backend).
# Address / credentials are supplied at `terraform init` time via:
#   - local:  source ./gitlab_http_backend_cred.sh
#   - CI:     .gitlab-ci.yml (CI_JOB_TOKEN + project API URL)
#
# Do not put tokens or passwords in this file.
terraform {
  backend "http" {
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}
