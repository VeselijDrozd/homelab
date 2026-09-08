variable "endpoint" {
  description = "Hostname or IP of Proxmox server"
  type        = string
}

variable "proxmox_username" {
  description = "User for Proxmox API"
  type        = string
}

variable "main_password" {
  description = "Password for Proxmox API"
  type        = string
  sensitive   = true
}

variable "vm_pass" {
  description = "Default password for VM user account"
  type        = string
  sensitive   = true
}

variable "pc_public_key_path" {
  description = "Path to SSH public key file for VM user"
  type        = string
}

variable "vm_output_ipv4_prefix" {
  description = "Only addresses starting with this string are included in output vm_ipv4_addresses (QEMU agent often reports 127.0.0.1 plus LAN)."
  type        = string
  default     = "10.10.10."
}

variable "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file (INI)"
  type        = string
  default     = "inventory.ini"
}

variable "ansible_ssh_private_key_file" {
  description = "SSH private key path written to [all:vars] in the inventory (optional)"
  type        = string
  default     = null
}

variable "ansible_inventory_parent_group" {
  description = "Deprecated: use ansible_inventory_hierarchy. If hierarchy is empty and this is set, adds a single [NAME:children] with all VM host groups as direct children."
  type        = string
  default     = null
}

variable "ansible_inventory_hierarchy" {
  description = "Nested Ansible inventory groups: parent group name => list of child group names. Child groups may be meta-groups (other keys in this map) or VM host groups derived from vm_groups/vms."
  type        = map(list(string))
  default     = {}
}

variable "proxmox_ssh_username" {
  description = "SSH user on Proxmox nodes (used for uploading local disk images to datastore)"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to PEM private key for SSH uploads. Required (or set proxmox_ssh_agent) when any image uses local_path."
  type        = string
  default     = null
}

variable "proxmox_ssh_agent" {
  description = "Use SSH agent for Proxmox uploads instead of proxmox_ssh_private_key_path"
  type        = bool
  default     = false
}

variable "images" {
  description = "Image definitions: either url (Proxmox downloads) or local_path (Terraform uploads from this machine)"
  type = map(object({
    content_type           = optional(string, "import")
    datastore_id           = string
    node_name              = string
    file_name              = string
    url                    = optional(string)
    local_path             = optional(string)
    upload_timeout_seconds = optional(number, 7200)
    overwrite              = optional(bool, true)
  }))

  validation {
    condition = alltrue([
      for _, img in var.images :
      (img.url != null && trimspace(img.url) != "" && (img.local_path == null || trimspace(img.local_path) == "")) ||
      (img.local_path != null && trimspace(img.local_path) != "" && (img.url == null || trimspace(img.url) == ""))
    ])
    error_message = "Each image must set exactly one of: url, or local_path (not both, not neither)."
  }
}

variable "vms" {
  description = "VM definitions keyed by logical name"
  type = map(object({
    image_key                   = string
    vm_id                       = number
    name                        = string
    node_name                   = string
    description                 = optional(string, "Managed by Terraform")
    tags                        = optional(list(string), [])
    on_boot                     = optional(bool, true)
    startup_order               = optional(string, "3")
    startup_up_delay            = optional(string, "60")
    startup_down_delay          = optional(string, "60")
    agent_enabled               = optional(bool, true)
    cpu_cores                   = optional(number, 2)
    cpu_type                    = optional(string, "x86-64-v2-AES")
    memory_dedicated            = optional(number, 2048)
    memory_floating             = optional(number, 2048)
    disk_datastore_id           = string
    disk_interface              = optional(string, "scsi0")
    disk_size                   = optional(number)
    initialization_datastore_id = string
    ipv4_address                = optional(string, "dhcp")
    username                    = optional(string, "ubuntu")
    ansible_group               = optional(string)
    bridge                      = string
  }))
  default = {}
}

variable "vm_groups" {
  description = "VM groups with count and shared configuration"
  type = map(object({
    count       = number
    vm_id_start = number
    name_prefix = string
    config = object({
      image_key                   = string
      node_name                   = string
      description                 = optional(string, "Managed by Terraform")
      tags                        = optional(list(string), [])
      on_boot                     = optional(bool, true)
      startup_order               = optional(string, "3")
      startup_up_delay            = optional(string, "60")
      startup_down_delay          = optional(string, "60")
      agent_enabled               = optional(bool, true)
      cpu_cores                   = optional(number, 2)
      cpu_type                    = optional(string, "x86-64-v2-AES")
      memory_dedicated            = optional(number, 2048)
      memory_floating             = optional(number, 2048)
      disk_datastore_id           = string
      disk_interface              = optional(string, "scsi0")
      disk_size                   = optional(number)
      initialization_datastore_id = string
      ipv4_address                = optional(string, "dhcp")
      username                    = optional(string, "ubuntu")
      ansible_group               = optional(string)
      bridge                      = string
    })
  }))
  default = {}
}