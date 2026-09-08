output "vm_ids" {
  description = "IDs of created VMs by key"
  value       = { for k, vm in module.vms : k => vm.id }
}

output "vm_names" {
  description = "Names of created VMs by key"
  value       = { for k, vm in module.vms : k => vm.name }
}

output "vm_ipv4_addresses" {
  description = "LAN IPv4 per VM key (from QEMU guest agent), only addresses with prefix vm_output_ipv4_prefix"
  value = {
    for k, vm in module.vms : k => tolist(distinct([
      for ip in flatten(coalesce(vm.ipv4_addresses, [])) : ip
      if startswith(ip, var.vm_output_ipv4_prefix)
    ]))
  }
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}
