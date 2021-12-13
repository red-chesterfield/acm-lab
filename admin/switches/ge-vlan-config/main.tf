
# Defines VLAN, non-Fog port connections and inter-switch trunk connections.
# (Basically: Everything but the fog-machine-to-slot configs.)

terraform {
  required_version = ">= 0.15.0"
}

terraform {
  required_providers {
    junos = {
      source = "jeremmfr/junos"
    }
  }
}

provider junos {
  # First switch in rack A36

  alias     = "sw_ge_1"
  ip        = "acm-2300-1g.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # Second switch in rack A36

  alias     = "sw_ge_2"
  ip        = "acm-2300-1g-2.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A37

  alias     = "sw_ge_3"
  ip        = "acm-2300-1g-3.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A38

  alias     = "sw_ge_4"
  ip        = "acm-2300-1g-4.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}

provider junos {
  # First (only) switch in rack A35. Acts as "root" switch.

  alias     = "sw_ge_5"
  ip        = "acm-2300-1g-5.mgmt.acm.lab.eng.rdu2.redhat.com"
  username  = var.switch_username
  password  = var.switch_password
}


#=== Config Locals ===

locals {

  # Add future switches 4, 5 to this list when future == now.
  sw_ge_numbers = [1, 2, 3, 4, 5]

  #--- VLANs ---

  # Test-slot VLANs

  first_test_slot_nr = 0
  last_test_slot_nr  = 24
  maint_slot_nr      = 49

  slot_list = concat(range(local.first_test_slot_nr, local.last_test_slot_nr+1), [local.maint_slot_nr])

  base_test_slot_vlan_id = 200

  # Patterns for test-slot VLAN names, named after slot:

  data_vlan_name_pattern  = "test-slot-%02d-data"
  data_vlan_descr_pattern = "Test slot %02d data network VLAN"

  prov_vlan_name_pattern  = "test-slot-%02d-prov"
  prov_vlan_descr_pattern = "Test slot %02d provisioning network VLAN"

  # Other non-slot-related 1Gb VLANs:

  other_vlans = {
    rh-network-158 = {
      id = 158,
      description = "Red Hat Lab Netowrk VLAN (10.1.158.0/24)"
    }
    pvt-net-172-18-1 = {
      id = 400
      description = "General-use Cross-Lab Private 1Gb Network VLAN (172.18.1.0/24)"
    }
    not-in-use = {
      id = 499
      description = "VLAN for 1Gb NICs not yet on any other 1Gb network"
    }
  }

  rh_network_vlan_name = "rh-network-158"


  #--- Special machine connection to the switches  ---
  # (For machines other than the slot-related Fog machines)

  # VSphere hosts get access to all active (non-excluded) test slot VLANs.
  # (Future: define additional variables for other classes of machines.)
  vlans_for_vsphere_hosts = local.non_excluded_test_slot_vlan_names

  # Libvirt/KVM machines get NIC2 access-mode connections to ??? 1Gb Network
  # Proposal:  Connect them to a non-slot 172.31.99.0/24 data network?
  # TEMPORARY: CONNECT TO MAINT PROV NETWORK DURING MACHINE CHECKOUT
  vlans_for_libvirt_hosts = ["test-slot-49-prov"]

  # VSphere Vapor and Mist hosts are connected into 1Gb Swithc 1 thusly:

  sw_ge_1_non_slot_machines = {
    mist_01 = {
      name  = "Mist01"  # Name of machine to use in description
      nics  = [2]       # The ordinal of the NICs connected (parallel to ports array)
      ports = [40]      # Ordinals of the switch ports to which NICs are connected
      vlans = local.vlans_for_vsphere_hosts   # VLANs to allow
    }
    mist_02  = {name="Mist02",  nics=[2], ports=[41], vlans=local.vlans_for_vsphere_hosts}
    mist_03  = {name="Mist03",  nics=[2], ports=[42], vlans=local.vlans_for_vsphere_hosts}
    mist_04  = {name="Mist04",  nics=[2], ports=[43], vlans=local.vlans_for_vsphere_hosts}
    mist_05  = {name="Mist05",  nics=[2], ports=[44], vlans=local.vlans_for_vsphere_hosts}
    vapor_01 = {name="Vapor01", nics=[2], ports=[45], vlans=local.vlans_for_vsphere_hosts}
    vapor_02 = {name="Vapor02", nics=[2], ports=[46], vlans=local.vlans_for_vsphere_hosts}
  }

  sw_ge_4_non_slot_machines = {
    mist_08  = {name="Mist08",  nics=[2], ports=[18], vlans=local.vlans_for_libvirt_hosts}
    mist_09  = {name="Mist09",  nics=[2], ports=[19], vlans=local.vlans_for_libvirt_hosts}
    mist_10  = {name="Mist10",  nics=[2], ports=[20], vlans=local.vlans_for_libvirt_hosts}
    mist_11  = {name="Mist11",  nics=[2], ports=[21], vlans=local.vlans_for_libvirt_hosts}
    mist_12  = {name="Mist12",  nics=[2], ports=[22], vlans=local.vlans_for_libvirt_hosts}
  }

  sw_ge_5_non_slot_machines = {
    vapor_01 = {name="Future Vapor01", nics=[2], ports=[0],  vlans=local.vlans_for_vsphere_hosts}
    vapor_02 = {name="Future Vapor02", nics=[2], ports=[1],  vlans=local.vlans_for_vsphere_hosts}
    mist_01  = {name="Future Mist01",  nics=[2], ports=[2],  vlans=local.vlans_for_vsphere_hosts}
    mist_02  = {name="Future Mist02",  nics=[2], ports=[3],  vlans=local.vlans_for_vsphere_hosts}
    mist_03  = {name="Future Mist03",  nics=[2], ports=[4],  vlans=local.vlans_for_vsphere_hosts}
    mist_04  = {name="Future Mist04",  nics=[2], ports=[5],  vlans=local.vlans_for_vsphere_hosts}
    mist_05  = {name="Future Mist05",  nics=[2], ports=[6],  vlans=local.vlans_for_vsphere_hosts}
    steam_01 = {name="Steam01",        nics=[2], ports=[7],  vlans=local.vlans_for_libvirt_hosts}
    steam_02 = {name="Steam02",        nics=[2], ports=[8],  vlans=local.vlans_for_libvirt_hosts}
    mist_06  = {name="Mist06",         nics=[2], ports=[9],  vlans=local.vlans_for_libvirt_hosts}
    mist_07  = {name="Mist07",         nics=[2], ports=[10], vlans=local.vlans_for_libvirt_hosts}
  }

  # Note: Add map entries to this map for any new switches that have
  # some non-slot-resident machines connected to them.
  machine_connections = {
    sw_ge_1 = local.sw_ge_1_non_slot_machines
    sw_ge_4 = local.sw_ge_4_non_slot_machines
    sw_ge_5 = local.sw_ge_5_non_slot_machines
  }

  #--- Port configs for other special ports ---

  # There are a bunch of unused ports on the switches.

  sw_ge_1_unused_ports = [36, 37, 38, 39]
  sw_ge_2_unused_ports = [36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]

  # NB: List of unused ports for Switch #2 is probably incomplete.
  #     Switch has only fog19 to 24, so all ports 12 to 47 are unused.
  sw_ge_3_unused_ports = range(36, 47+1)

  sw_ge_4_unused_ports = range(23, 47+1)
  sw_ge_5_unused_ports = range(11, 46+1)

  # Note: Add map entries to this map for any new switches:
  unused_ports = {
    sw_ge_1 = local.sw_ge_1_unused_ports
    sw_ge_2 = local.sw_ge_2_unused_ports
    sw_ge_3 = local.sw_ge_3_unused_ports
    sw_ge_4 = local.sw_ge_4_unused_ports
    sw_ge_5 = local.sw_ge_5_unused_ports
  }

  # Infra-Switch connections:
  #
  # Switch 1: Connected to Switch 2, Switch 3
  #
  # Switch 2: Connected to Switch 1
  # Switch 3: Connected to Switch 1, switch 4
  # Switch 4: Connected to Switch 3

  # Switch 1 has an uplink to RH network, and connections to switchs 2 and 3.

  sw_ge_1_special_port_configs = [
    {
      port_name = "ge-0/0/47"
      description = "Uplink to RH network 10.1.158.0 subnet"
      vlans = [local.rh_network_vlan_name]
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 2"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/2"
      description = "Link to 1Gb switch 5"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Switch 2 has a connection to Switch 1

  sw_ge_2_special_port_configs = [
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 1"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/2"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Switch 3 has a connection to Switch 1.

  sw_ge_3_special_port_configs = [
    {
      port_name = "xe-0/1/2"
      description = "Link to 1Gb switch 5"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb Switch 4"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Switch 4 has a connection to Switch 3.

  sw_ge_4_special_port_configs = [
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb switch 3"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/2"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Switch 5 has connections to Switch 1 and Switch 3.

  sw_ge_5_special_port_configs = [
    {
      port_name = "ge-0/0/47"
      description = "Future: Uplink to RH network 10.1.158.0 subnet"
      vlans = [local.rh_network_vlan_name]
    },
    {
      port_name = "xe-0/1/2"
      description = "Link to 1Gb switch 1"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/3"
      description = "Link to 1Gb Switch 3"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/0"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    },
    {
      port_name = "xe-0/1/1"
      description = "Future ineter-switch link"
      vlans = local.all_vlan_names
    }
  ]

  # Note: Add map entries to this map for any new switches:
  special_ports = {
    sw_ge_1 = local.sw_ge_1_special_port_configs
    sw_ge_2 = local.sw_ge_2_special_port_configs
    sw_ge_3 = local.sw_ge_3_special_port_configs
    sw_ge_4 = local.sw_ge_4_special_port_configs
    sw_ge_5 = local.sw_ge_5_special_port_configs
  }
}


#=== Compile-It Locals/Logic for defining VLANs ===

locals {

  # The things generated by these locals is applied across all switches.

  # Generate the set of per-test-slot VLAN definitions.

  test_slot_data_vlans = {
    for sn in local.slot_list:
      format(local.data_vlan_name_pattern, sn) => {
        id = local.base_test_slot_vlan_id + (sn * 2)
        description = format(local.data_vlan_descr_pattern, sn)
      }
  }

  test_slot_prov_vlans = {
    for sn in local.slot_list:
      format(local.prov_vlan_name_pattern, sn) => {
        id = local.base_test_slot_vlan_id + (sn * 2) + 1
        description = format(local.prov_vlan_descr_pattern, sn)
      }
  }

  test_slot_vlans = merge(local.test_slot_data_vlans, local.test_slot_prov_vlans)

  # Logic/variables for dealing with TF dependency issues when deleting VLAN.

  # Set local.exclude_vlans to VLANs you want to delete and then do a TF apply before
  # changing config to actually remove the VLAN.  The first apply will update the
  # port configus to remove use of the VLAN.
  #
  # If not in a VLAN-removal scenario, set local.exclude_vlans to an empty list.
  #
  # See the 10G switch TF config for additional info/whining about this.

  # exclude_vlans = ["pvt_net_vlan_352"]
  exclude_vlans = []

  # Local.all_vlan_defs holds definition info ror all VLANs, including the ones we are
  # trying to delete. Local.all_vlans is the subset of all_vlan_defs that excludes the
  # onces we are trying to delete and is the variable that should be the source of
  # VLAN defs for ports.

  all_vlan_defs = merge(local.test_slot_vlans, local.other_vlans)
  all_vlans = {
    for k,v in local.all_vlan_defs: k => {
      id = v.id
      description = v.description
    } if !contains(local.exclude_vlans, k)
  }
  all_vlan_names = [for k,v in local.all_vlans: replace(k, "_", "-")]

  non_excluded_test_slot_vlans = {
    for k,v in local.test_slot_vlans: k => {
      id = v.id
      description = v.description
    } if !contains(local.exclude_vlans, k)
  }
  non_excluded_test_slot_vlan_names = [for k,v in local.non_excluded_test_slot_vlans: replace(k, "_", "-")]

  # Contributes to the import_info output by import.sh:

  vlan_import_info_nested = [
    for n in local.sw_ge_numbers: [
      for v in local.all_vlan_names: {
        resource = format("junos_vlan.sw_ge_%d_vlan[\"%s\"]", n, v)
        id = replace(v, "_", "-")
      }
    ]
  ]
  vlan_import_info = flatten(local.vlan_import_info_nested)

}


#=== Compile-It Locals/Logic for port connections ===

locals {

  #------------------------------------------------------------------
  # "Compile" machine-connection/switch port info into usable form.
  #------------------------------------------------------------------

  # The configuration local variables in the section Config Locals above define the physcial
  # connections in various waus chosen to result in an easy/compact way of spec'ing these.
  #
  # But in order to actually define port configs via TF for_each iteratoin, those compact
  # defintiions need to be "compiled" -- converted and aggregated -- into a map of maps
  # where the outer map has one entry per switch, and the inner map for that switch has
  # one entry per port to be configured.  That's what the following hunks of logic does,
  # with slight vartions needed for each of the input local vars.

  # It seems not possible to do this kind of compiling in one fell swoop because sometimes
  # the nesting means the fell swoop would require the key expression for the inner map to
  # be insdie a nested for, which TF doesn't seem to allow, at least not syntatically.
  # And trying a big fell swoop would probably make this impossible to debug (not that it
  # isn't challenging already).
  #
  # So instead we convert the various inputs into a common intermediate form, which is
  # ten easily converted into a map of maps. This approach is inspired by the following
  # G issue command and related discussion:
  # https://github.com/hashicorp/terraform/issues/22263#issuecomment-581205359)


  # Convert special machine (eg. mists/vapors) connections to intermediate form.

  # This converts local.machine_connections, which looks like this:
  #
  # macine_connections = {
  #   sw_ge_1 = {
  #     mist_01  = {
  #       name  = "Mist01"
  #       nics  = [2]
  #       ports = [40]
  #       vlans = [
  #         "test-slot-00-data",
  #         "test-slot-00-prov",
  #         "test-slot-01-data",
  #         "test-slot-01-prov",
  #         ...
  #         "test-slot-49-data",
  #         "test-slot-49-prov",
  #       ]
  #     },
  #     mist_02  = {
  #       name  = "Mist02"
  #       nics  = [2]
  #       ports = [41]
  #       vlans = [
  #         "test-slot-00-data",
  #         "test-slot-00-prov",
  #         "test-slot-01-data",
  #         "test-slot-01-prov",
  #         ...
  #         "test-slot-49-data",
  #         "test-slot-49-prov",
  #       ]
  #     },
  #   },
  #   sw_ge_2 = {
  #     ...
  #   }
  # }
  #
  # Into something that looks like this:
  #
  # machine_spc_intermediate = {
  #   sw_ge_1 = [
  #     {
  #       key   = "ge-0/0/40"
  #       value = {
  #         description = "Mist01 1G NIC 2"
  #         vlans = [
  #           "test-slot-00-data",
  #           "test-slot-00-prov",
  #           "test-slot-01-data",
  #           "test-slot-01-prov",
  #           ...
  #         ]
  #       }
  #     },
  #     {
  #       key   = "ge-0/0/41"
  #       value = {
  #         description = "Mist02 1G NIC 2"
  #         vlans = [
  #           "test-slot-00-data",
  #           "test-slot-00-prov",
  #           "test-slot-01-data",
  #           "test-slot-01-prov",
  #           ...
  #         ]
  #       }
  #     },
  #     ...
  #   ],
  #   sw_ge_2 = [
  #     ...
  #   ]
  # }

  machine_spc_intermediate = {
    for sw_n,sw_mc in local.machine_connections: sw_n => flatten([
      for mn,mv in sw_mc: [
        for i in range(length(mv.ports)): {
          key = format("ge-0/0/%s", mv.ports[i])
          value = {
            description = format("%s 1G NIC %d", mv.name, mv.nics[i])
            vlans = sw_mc[mn].vlans
            # Note: Currently, all ports for a machine have the same VLANs.
          }
        }
      ]
    ])
  }

  # Convert unused port defintiions to intermediate form.

  unused_spc_intermediate = {
    for sw_n,sw_upl in local.unused_ports: sw_n => flatten([
      for upn in sw_upl: [{
        key = format("ge-0/0/%s", upn)
        value = {
          description = ""
          vlans = [local.rh_network_vlan_name]
        }
      }]
    ])
  }

  # Convert special port configs into intermediate form.

  special_spc_intermediate = {
    for sw_n,sw_pcl in local.special_ports: sw_n => flatten([
      for pci in sw_pcl: [{
        key = pci.port_name
        value = {
          description = pci.description
          vlans = pci.vlans
        }
      }]
    ])
  }


  # Combine the above intermediate forms and convert the result into  the map of maps
  # we'll use to for-each in the per-switch junos.physcial_interface resources.

  sw_ge_names = [for n in local.sw_ge_numbers: format("sw_ge_%d", n)]
  spc_intermediate = {
    for sw_n in local.sw_ge_names: sw_n => concat(
      lookup(local.machine_spc_intermediate, sw_n, []),
      lookup(local.unused_spc_intermediate, sw_n, []),
      lookup(local.special_spc_intermediate, sw_n, [])
    )
  }

  switch_port_configs = {
    for sw_n,sw_pcl in local.spc_intermediate: sw_n => {
      for e in sw_pcl: e.key =>  e.value
    }
  }

  #----------------------------------------------
  # Compute port-config import info.
  #----------------------------------------------

  # Contributes to the import_info output by import.sh:
  switch_port_import_info = flatten([
    for sw_n,sw_pcm in local.switch_port_configs: [
      for pn,pc in sw_pcm: {
        resource = format("junos_interface_physical.%s_port[\"%s\"]", sw_n, pn)
        id = pn
      }
    ]
  ])

  #----------------------------------------------------------------------------
  # Combine all import-info parts into a single thing referenced as an output.
  #----------------------------------------------------------------------------
  # Combine all import info into a single thing referenced as an ooutput.

  import_info = concat(local.vlan_import_info, local.switch_port_import_info)

}

# Resource defintiions are in main-resources.tf to make it easier to omit them
# (eg by renaming the file to *.aside") when debugging all of the "math" done by
# the locals above via outputs.
