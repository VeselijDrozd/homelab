locals {
  images_by_url = {
    for k, v in var.images : k => v
    if v.local_path == null || trimspace(v.local_path) == ""
  }

  images_by_local = {
    for k, v in var.images : k => v
    if v.local_path != null && trimspace(v.local_path) != ""
  }

  local_image_abs_paths = {
    for k, v in local.images_by_local : k => abspath(v.local_path)
  }

  image_volume_ids = merge(
    { for k in keys(local.images_by_url) : k => proxmox_download_file.images[k].id },
    { for k in keys(local.images_by_local) : k => proxmox_virtual_environment_file.images_local[k].id }
  )

  # Expand grouped VM definitions (count + shared config) into concrete VM objects.
  vms_from_groups = merge([
    for group_key, group in var.vm_groups : {
      for idx in range(group.count) :
      format("%s-%02d", group_key, idx + 1) => merge(group.config, {
        vm_id = group.vm_id_start + idx
        name  = format("%s-%02d", group.name_prefix, idx + 1)
      })
    }
  ]...)

  # Explicit vms entries override generated group entries on key conflicts.
  vms_expanded = merge(local.vms_from_groups, var.vms)
}

resource "proxmox_download_file" "images" {
  for_each = local.images_by_url

  content_type = each.value.content_type
  datastore_id = each.value.datastore_id
  node_name    = each.value.node_name
  url          = each.value.url
  file_name    = each.value.file_name
  overwrite    = coalesce(each.value.overwrite, true)
}

resource "proxmox_virtual_environment_file" "images_local" {
  for_each = local.images_by_local

  datastore_id   = each.value.datastore_id
  node_name      = each.value.node_name
  content_type   = each.value.content_type
  overwrite      = coalesce(each.value.overwrite, true)
  timeout_upload = coalesce(each.value.upload_timeout_seconds, 7200)

  source_file {
    path      = local.local_image_abs_paths[each.key]
    file_name = each.value.file_name
  }

  lifecycle {
    precondition {
      condition     = var.proxmox_ssh_private_key_path != null || var.proxmox_ssh_agent
      error_message = "When any image uses local_path, configure SSH on the provider: proxmox_ssh_private_key_path and/or proxmox_ssh_agent = true (see README)."
    }
  }
}

module "vms" {
  for_each = local.vms_expanded

  # Public module (works in GitLab CI). Local alternative:
  # source = "../../terraform-proxmox-vm-module"
  source = "git::https://github.com/VeselijDrozd/terraform-proxmox-vm-module.git?ref=v1.1.2"

  image_id       = local.image_volume_ids[each.value.image_key]
  ssh_public_key = trimspace(file(var.pc_public_key_path))
  vm_password    = var.vm_pass
  config = {
    vm_id                       = each.value.vm_id
    name                        = each.value.name
    node_name                   = each.value.node_name
    description                 = each.value.description
    tags                        = each.value.tags
    on_boot                     = each.value.on_boot
    startup_order               = each.value.startup_order
    startup_up_delay            = each.value.startup_up_delay
    startup_down_delay          = each.value.startup_down_delay
    agent_enabled               = each.value.agent_enabled
    cpu_cores                   = each.value.cpu_cores
    cpu_type                    = each.value.cpu_type
    memory_dedicated            = each.value.memory_dedicated
    memory_floating             = each.value.memory_floating
    disk_datastore_id           = each.value.disk_datastore_id
    disk_interface              = each.value.disk_interface
    disk_size                   = try(each.value.disk_size, null)
    initialization_datastore_id = each.value.initialization_datastore_id
    ipv4_address                = each.value.ipv4_address
    username                    = each.value.username
    bridge                      = each.value.bridge
  }
}
