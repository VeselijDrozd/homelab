# homelab / terraform

Terraform root for Proxmox VMs. Uses the sibling module:

```hcl
source = "../../terraform-proxmox-vm-module"
```

Module source (pinned for CI):

```hcl
source = "git::https://github.com/VeselijDrozd/terraform-proxmox-vm-module.git?ref=v1.1.2"
```

Local sibling checkout still works if you temporarily switch `source` to `../../terraform-proxmox-vm-module`.

## Remote state (GitLab)

Default backend is GitLab Managed Terraform State (`backend "http"`). See root [`README.md`](../README.md) for migrate + CI variables.

Local helper:

```bash
cp gitlab_http_backend_cred.sh.example gitlab_http_backend_cred.sh
source ./gitlab_http_backend_cred.sh
terraform init -migrate-state   # first time from local backend
```

Optional MinIO/S3 credentials template remains in `s3_backend_cred.sh.example` if you prefer an S3-compatible backend later.

## Что делает проект

- подготавливает образы в datastore Proxmox:
  - **`url`** — Proxmox сам скачивает файл (`proxmox_download_file`);
  - **`local_path`** — Terraform заливает файл с машины, где запущен `terraform` (`proxmox_virtual_environment_file`, для больших файлов нужен SSH к узлу, см. ниже);
- создает ВМ из:
  - одиночных описаний в `vms`
  - групповых описаний в `vm_groups` + `count`
- разворачивает группы в плоский список ВМ и передает каждую ВМ в модуль

## Требования

- Terraform `>= 1.3`
- доступ к Proxmox API
- провайдер `bpg/proxmox`
- если хотя бы один образ задан через **`local_path`**: SSH к узлу Proxmox (часто тот же пользователь `root`, что и для загрузки по SSH), в `terraform.tfvars` — `proxmox_ssh_private_key_path` и/или `proxmox_ssh_agent = true`

## Быстрый старт

1. Создайте рабочий файл переменных:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Заполните минимум:
- `endpoint`
- `proxmox_username`
- `main_password`
- `vm_pass`
- `pc_public_key_path`
- при **`local_path`** у образа: `proxmox_ssh_private_key_path` (или `proxmox_ssh_agent`) и при необходимости `proxmox_ssh_username`

3. Запуск:

```bash
terraform init
terraform plan
terraform apply
```

## Структура конфигурации

### `images`

Карта образов в datastore Proxmox. Для каждого ключа нужно указать **ровно одно**: `url` **или** `local_path`.

- `datastore_id` — куда положить файл
- `node_name` — узел Proxmox
- `file_name` — имя файла в datastore (при `local_path` можно задать другое имя, чем у исходного файла). Для **`content_type = import`** Proxmox проверяет расширение: **`.img` часто отклоняется**; используйте **`.qcow2`** или **`.raw`** в соответствии с реальным форматом диска.
- `content_type` — опционально (`import` по умолчанию)
- `url` — URL, который **сервер Proxmox** скачивает сам
- `local_path` — **абсолютный путь** к файлу на **машине с Terraform**; загрузка идёт через провайдер (для дисков обычно нужен SSH в блоке `provider "proxmox" { ssh { ... } }`)
- `upload_timeout_seconds` — опционально (`7200`), только для `local_path`
- `overwrite` — опционально (`true`)

Скачивание с Ubuntu:

```hcl
images = {
  ubuntu_jammy = {
    datastore_id = "local"
    node_name    = "pve"
    url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    file_name    = "jammy-server-cloudimg-amd64.qcow2"
  }
}
```

Локальный образ (нужны `proxmox_ssh_*` в корне `terraform.tfvars`):

```hcl
proxmox_ssh_private_key_path = "/home/user/.ssh/id_ed25519"
proxmox_ssh_username         = "root"

images = {
  ubuntu_jammy = {
    datastore_id = "local"
    node_name    = "pve"
    local_path   = "/home/user/images/jammy-with-qemu-agent.img"
    file_name    = "jammy-with-qemu-agent.qcow2"
  }
}
```

**Переход `url` ↔ `local_path`** для того же ключа образа меняет тип ресурса в state; может понадобиться `terraform state rm` старого ресурса образа или осознанный `replace`.

### `vms` (одиночные ВМ)

`vms` — карта, где каждый ключ это отдельная ВМ с индивидуальными параметрами.

Обязательные поля:
- `image_key`, `vm_id`, `name`, `node_name`
- `disk_datastore_id`, `initialization_datastore_id`, `bridge`

Часто используемые опциональные:
- `cpu_cores`, `memory_dedicated`, `memory_floating`
- `tags`, `agent_enabled`, `ipv4_address`, `username`

Пример:

```hcl
vms = {
  monitor = {
    image_key                   = "ubuntu_jammy"
    vm_id                       = 4500
    name                        = "monitor-vm"
    node_name                   = "pve"
    cpu_cores                   = 2
    memory_dedicated            = 2048
    memory_floating             = 2048
    disk_datastore_id           = "local-zfs"
    initialization_datastore_id = "local-zfs"
    bridge                      = "vmbr0"
    tags                        = ["terraform", "monitoring"]
  }
}
```

### `vm_groups` (группы ВМ)

`vm_groups` — шаблон для создания N однотипных ВМ.

Поля группы:
- `count` - количество ВМ
- `vm_id_start` - стартовый VMID (дальше автоинкремент)
- `name_prefix` - префикс имени (`app-vm-01`, `app-vm-02`, ...)
- `config` - общие параметры ВМ (почти те же поля, что в `vms`, кроме `vm_id` и `name`)

Пример:

```hcl
vm_groups = {
  app = {
    count       = 3
    vm_id_start = 4301
    name_prefix = "app-vm"
    config = {
      image_key                   = "ubuntu_jammy"
      node_name                   = "pve"
      agent_enabled               = true
      disk_datastore_id           = "local-zfs"
      initialization_datastore_id = "local-zfs"
      bridge                      = "vmbr0"
      tags                        = ["terraform", "app"]
    }
  }
}
```

### Приоритет `vm_groups` и `vms`

Сначала разворачиваются `vm_groups`, затем мержатся с `vms`.
Если ключ совпадает, запись из `vms` перезапишет сгенерированную групповую.

### Ansible inventory

После `terraform apply` генерируется INI-файл (`ansible_inventory_path`). Группы хостов
берутся из ключей `vm_groups` / `vms` (например `k8s_master-01` → группа `k8s_master`).

Вложенность задаётся через `ansible_inventory_hierarchy`:

```hcl
ansible_inventory_path       = "../ansible/inventory.ini"
ansible_ssh_private_key_file = "/home/user/.ssh/id_ed25519"

ansible_inventory_hierarchy = {
  homelab = ["k8s", "gitlab"]
  k8s     = ["k8s_master", "k8s_worker"]
  gitlab  = ["gitlab_server", "gitlab_runner"]
}
```

Результат:

```ini
[homelab:children]
k8s
gitlab

[k8s:children]
k8s_master
k8s_worker

[gitlab:children]
gitlab_server
gitlab_runner

[k8s_master]
k8s-master-vm-01 ansible_host=10.10.10.124 ansible_user=ubuntu
```

Использование:

```bash
ansible-playbook k8s-cluster.yml --limit k8s
ansible-playbook gitlab-server.yml --limit gitlab
ansible-playbook site.yml --limit homelab
```

Устаревший вариант `ansible_inventory_parent_group` по-прежнему работает, если
`ansible_inventory_hierarchy` пуст: все VM-группы становятся прямыми детьми одного родителя.

## Outputs

- `vm_ids` - map VMID по ключам ВМ
- `vm_names` - map имён ВМ по ключам
- `vm_ipv4_addresses` - map: ключ ВМ → список IPv4 из QEMU agent, **только** с префиксом `vm_output_ipv4_prefix` (по умолчанию `10.10.10.`), без `127.0.0.1`

## Файлы проекта

- `providers.tf` - провайдер и авторизация Proxmox
- `variables.tf` - все входные переменные и типы
- `main.tf` - загрузка образов + вызов внешнего модуля
- `outputs.tf` - итоговые значения
- `terraform.tfvars.example` - безопасный шаблон переменных

## Безопасность

- не коммитьте реальные секреты в `terraform.tfvars`
- не храните ключи/пароли в shell-скриптах в репозитории
- убедитесь, что `.gitignore` исключает `*.tfvars`, state-файлы и локальные креды
