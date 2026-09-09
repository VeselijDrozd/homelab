#!/usr/bin/env sh
# Shared setup for GitLab CI Terraform jobs. Source from repository root:
#   . terraform/ci/setup.sh
set -eu

TF_DIR="${TF_DIR:-terraform}"
KEYS_DIR="${KEYS_DIR:-/tmp/tf-ci-keys}"
STATE_NAME="${TF_STATE_NAME:-homelab}"
ROOT_DIR="${CI_PROJECT_DIR:-$(pwd)}"

# Always use the in-repo CLI config (Yandex provider mirror). Do not rely on
# YAML ${CI_PROJECT_DIR} expansion inside the job container.
TF_CLI_CONFIG_FILE="${ROOT_DIR}/terraform/ci/terraformrc"
export TF_CLI_CONFIG_FILE
if [ ! -f "${TF_CLI_CONFIG_FILE}" ]; then
  echo "ERROR: missing ${TF_CLI_CONFIG_FILE}" >&2
  exit 1
fi
echo "Using TF_CLI_CONFIG_FILE=${TF_CLI_CONFIG_FILE}"

mkdir -p "${KEYS_DIR}"
cd "${ROOT_DIR}"

if [ -z "${TF_VARS_FILE:-}" ]; then
  echo "ERROR: CI/CD File variable TF_VARS_FILE is required (contents of terraform.tfvars)." >&2
  exit 1
fi
if [ -z "${SSH_PUBLIC_KEY:-}" ]; then
  echo "ERROR: CI/CD File variable SSH_PUBLIC_KEY is required." >&2
  exit 1
fi

cp "${TF_VARS_FILE}" "${TF_DIR}/terraform.tfvars"
cp "${SSH_PUBLIC_KEY}" "${KEYS_DIR}/id.pub"

if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  cp "${SSH_PRIVATE_KEY}" "${KEYS_DIR}/id"
  chmod 600 "${KEYS_DIR}/id"
fi

# Optional private CA for self-signed GitLab HTTPS (File variable GITLAB_CA_CERT).
if [ -n "${GITLAB_CA_CERT:-}" ]; then
  export SSL_CERT_FILE="${GITLAB_CA_CERT}"
fi

# GitLab Managed Terraform State via job token (same project).
export TF_HTTP_ADDRESS="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${STATE_NAME}"
export TF_HTTP_LOCK_ADDRESS="${TF_HTTP_ADDRESS}/lock"
export TF_HTTP_UNLOCK_ADDRESS="${TF_HTTP_ADDRESS}/lock"
export TF_HTTP_USERNAME="gitlab-ci-token"
export TF_HTTP_PASSWORD="${CI_JOB_TOKEN}"
export TF_HTTP_LOCK_METHOD="POST"
export TF_HTTP_UNLOCK_METHOD="DELETE"
export TF_HTTP_RETRY_WAIT_MIN="5"

terraform -chdir="${TF_DIR}" init -input=false -reconfigure
