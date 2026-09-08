# https://registry.terraform.io/providers/bpg/proxmox/latest/docs
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "proxmox" {
  endpoint = var.endpoint
  insecure = true
  username = var.proxmox_username
  password = var.main_password

  dynamic "ssh" {
    for_each = var.proxmox_ssh_private_key_path != null || var.proxmox_ssh_agent ? [1] : []
    content {
      username = var.proxmox_ssh_username
      agent = (
        var.proxmox_ssh_private_key_path == null && var.proxmox_ssh_agent
      ) ? true : null
      private_key = var.proxmox_ssh_private_key_path != null ? file(var.proxmox_ssh_private_key_path) : null
    }
  }
}
