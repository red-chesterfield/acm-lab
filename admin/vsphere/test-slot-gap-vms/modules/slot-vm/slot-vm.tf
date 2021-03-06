terraform {
  required_version = ">= 0.14.0"
  required_providers {
    vsphere = {
      version = ">= 2.0.0"
    }
  }
}

# Notes:
# While this TF config is in a module deemed test-slot specific by its name, it is
# inching ever closer to being a pretty generic "clone vm from other vm/template"
# thing.

# Var.network_names is the list of networks to which NICs are attached, in NIC order.
# There could be dup names in this list.  Resolve them to a corresponding list of
# network resource ids that preserves the NIC ordering.

data vsphere_network net {
  for_each      = toset(var.network_names)
  datacenter_id = var.datacenter_id
  name          = each.key
}

locals {
   network_ids = [for nn in var.network_names : data.vsphere_network.net[nn].id]
}

locals {

  signature = format("%s/%s/%s", var.template_name, var.vm_name, var.slot_nr)

  # It seems Cores-per-socket isn't preserved in an OVA and thus probably not in the
  # tempalte we're cloningg.  Nonetheless, just becasue, we'd like to have the VM
  # have fewer processors (sockets) than cores. So we pick the largest of a list
  # of possible cores- per-processor count that works out evenly.  (Doing this in a
  # vactor way to avoid long utly conditional and because  it was fun to think
  # APL-like :-) )

  total_cores   = data.vsphere_virtual_machine.template.num_cpus
  total_is_even = (local.total_cores % 2) == 0
  num_cores_per_socket = local.total_is_even ? local.multi_socket_cps : local.total_cores

  try_core_counts   = local.total_is_even ? [for i in range(1, 20) : i] : []
  valid_core_counts = [for c in local.try_core_counts : ((local.total_cores % c) == 0 ? c : 0)]
  multi_socket_cps  = local.total_is_even ? max(local.valid_core_counts ...) : 0

}

data vsphere_virtual_machine template {
  datacenter_id = var.datacenter_id
  name          = var.template_name
}

resource vsphere_virtual_machine vm {

  name = var.vm_name

  # Placement within VCenter hierarchy:
  folder           = var.folder_path
  resource_pool_id = var.resource_pool_id
  datastore_id     = var.datastore_id

  # To target to a particular host, provide the equiv of this in place
  # of the resource_pool_id property above:
  # resource_pool_id = data.vsphere_host.host.resource_pool_id
  # host_system_id   = data.vsphere_host.host.id

  # Clone this VM from the specified VM/template
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  # The replaces_trigger concept seems cool, and we would like to use it to cause automatic
  # automatic replacement of the VM if eg. the template changes.  But it doesn't really work
  # out at all in a scenario where you need to import existing stuff to recreate tfstate.
  # The imported resources don't have a replaces-trigger value (I guess the import wuldn't
  # know how to compute the value) and thus the next terraform apply will end up destroying
  # and recreating the VM.
  #
  # Even if that wasn't an issue, we'd probably still have trouble making this work after
  # an import since we do full (vs. linked) clones to create the VMs.  Once the VM is created,
  # there isn't any property that tracks the template from which it was created (though I
  # suppose we could add a custom attribute for that).
  #
  # Anyway, for now, no-op the replaces trigger.

  # replace_trigger = sha1(local.signature)
  replace_trigger = ""

  annotation = data.vsphere_virtual_machine.template.annotation

  # Make the VM like the template from which its cloned:
  num_cpus              = data.vsphere_virtual_machine.template.num_cpus
  num_cores_per_socket  = local.num_cores_per_socket
  memory                = data.vsphere_virtual_machine.template.memory
  guest_id              = data.vsphere_virtual_machine.template.guest_id
  alternate_guest_name  = data.vsphere_virtual_machine.template.alternate_guest_name
  hardware_version      = data.vsphere_virtual_machine.template.hardware_version
  firmware              = data.vsphere_virtual_machine.template.firmware
  scsi_type             = data.vsphere_virtual_machine.template.scsi_type
  scsi_bus_sharing      = data.vsphere_virtual_machine.template.scsi_bus_sharing
  hv_mode               = data.vsphere_virtual_machine.template.hv_mode
  vvtd_enabled          = data.vsphere_virtual_machine.template.vvtd_enabled
  ept_rvi_mode          = data.vsphere_virtual_machine.template.ept_rvi_mode
  nested_hv_enabled     = data.vsphere_virtual_machine.template.nested_hv_enabled
  latency_sensitivity   = data.vsphere_virtual_machine.template.latency_sensitivity
  enable_logging        = data.vsphere_virtual_machine.template.enable_logging
  swap_placement_policy = data.vsphere_virtual_machine.template.swap_placement_policy

  cpu_performance_counters_enabled = data.vsphere_virtual_machine.template.cpu_performance_counters_enabled

  enable_disk_uuid = true  # Bug? Why do we set to true vs. copy from template?

  wait_for_guest_net_timeout  = 0
  wait_for_guest_net_routable = false

  # Note: local.network_ids mst be in the order that interfaces appear in the template.

  dynamic network_interface {
    for_each = data.vsphere_virtual_machine.template.network_interfaces
    iterator = this_net
    content {
      network_id   = local.network_ids[this_net.key]
      adapter_type = this_net.value.adapter_type
    }
  }

  dynamic disk {
    for_each = data.vsphere_virtual_machine.template.disks
    iterator = this_disk
    content {
      label              = "disk${this_disk.key}"  # Use "diskn" to allow terraforom import.
      unit_number        = this_disk.value.unit_number
      size               = this_disk.value.size
      thin_provisioned   = true
      # thin_provisioned = this_disk.value.thin_provisioned
    }

  }

  # While template we use is delivered/imported into VSphere as an OVA, it doesn't have vapp
  # properties defined in it, per se, because the VM/OVA is not built using VSphere.  Bbut its
  # emabled to accept guestInfo properties none-the-less, which happily we can set via
  # extra_config.

  # vapp {
  #   properties = {
  #     "guestinfo.acmLab.slotNr"  = var.slot_nr
  #   }
  # }

  extra_config = {
    "guestinfo.acmLab.slotNr"  = var.slot_nr
  }

  lifecycle {
    ignore_changes = [annotation]
  }
}
