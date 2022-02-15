locals {
  vnet_cidr        = split(".", split("/", var.vnet_cidr)[0])
  reverse_dns_cidr = "${local.vnet_cidr[2]}.${local.vnet_cidr[1]}.${local.vnet_cidr[0]}"
}

resource "azurerm_lb" "lb" {
  name                = var.vm_prefix
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = var.vm_prefix
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

}

resource "azurerm_lb_backend_address_pool" "lbbepool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = var.vm_prefix
}

resource "azurerm_lb_rule" "lbrule_tcp" {
  resource_group_name            = var.rg_name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "${var.vm_prefix}_TCP"
  protocol                       = "tcp"
  frontend_port                  = "53"
  backend_port                   = "53"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbbepool.id
  frontend_ip_configuration_name = var.vm_prefix
  probe_id                       = azurerm_lb_probe.lbprobe.id
}
resource "azurerm_lb_rule" "lbrule_udp" {
  resource_group_name            = var.rg_name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "${var.vm_prefix}_UDP"
  protocol                       = "udp"
  frontend_port                  = "53"
  backend_port                   = "53"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbbepool.id
  frontend_ip_configuration_name = var.vm_prefix
  probe_id                       = azurerm_lb_probe.lbprobe.id
}

resource "azurerm_lb_probe" "lbprobe" {
  name                = var.vm_prefix
  resource_group_name = var.rg_name
  loadbalancer_id     = azurerm_lb.lb.id
  port                = 53
  protocol            = "Tcp"
  interval_in_seconds = 15
}

resource "azurerm_public_ip_prefix" "pip" {
  count               = var.egress ? 1 : 0
  name                = "${var.vm_prefix}-pip"
  resource_group_name = var.rg_name
  location            = var.location
  prefix_length       = 29
  availability_zone   = var.location != "East Asia" && var.location != "Australia Southeast" ? "1" : "No-Zone"
}

resource "azurerm_nat_gateway" "nat" {
  count                   = var.egress ? 1 : 0
  name                    = "${var.vm_prefix}-nat-gateway"
  resource_group_name     = var.rg_name
  location                = var.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = var.location != "East Asia" && var.location != "Australia Southeast" ? ["1"] : null
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "natgateway" {
  count               = var.egress ? 1 : 0
  nat_gateway_id      = azurerm_nat_gateway.nat[0].id
  public_ip_prefix_id = azurerm_public_ip_prefix.pip[0].id
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  count          = var.egress ? 1 : 0
  subnet_id      = var.subnet_id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}

resource "azurerm_storage_account" "main" {
  name                     = var.vm_prefix
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_virtual_machine_scale_set" "vm" {

  depends_on = [azurerm_subnet_nat_gateway_association.nat]

  name                = var.vm_prefix
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = var.vm_sku
  instances           = var.instance_count
  admin_username      = var.admin_username
  health_probe_id     = azurerm_lb_probe.lbprobe.id
  upgrade_mode        = "Automatic"
  custom_data = base64encode(templatefile("${path.module}/dns_config.tpl", {
    dns1             = var.dns_servers[0],
    dns2             = var.dns_servers[1],
    reverse_dns_cidr = local.reverse_dns_cidr,
    lb_ip            = split(".", azurerm_lb.lb.private_ip_address)[3],
    vm_prefix        = var.vm_prefix,
    syslog_server = var.syslog_server }
  ))
  zones = var.location != "East Asia" && var.location != "Australia Southeast" ? [1, 2, 3] : null

  automatic_os_upgrade_policy {
    disable_automatic_rollback  = true
    enable_automatic_os_upgrade = false
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 20
    pause_time_between_batches              = "PT0S"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_key
  }

  source_image_reference {
    publisher = var.os.publisher
    offer     = var.os.offer
    sku       = var.os.sku
    version   = var.os.version
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name                      = "nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.nsg.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbbepool.id]
    }
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

}

# resource "azurerm_virtual_machine_scale_set_extension" "patching" {
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vm.id
#   name                         = "OSPatchingForLinux"
#   publisher                    = "Microsoft.OSTCExtensions"
#   type                         = "OSPatchingForLinux"
#   type_handler_version         = "1.0"
#   auto_upgrade_minor_version   = true
#   settings = jsonencode({
#     "disabled" : "False",
#     "stop" : "False",
#     "rebootAfterPatch" : "Auto",
#     "intervalOfWeeks" : "4",
#     "dayOfWeek" : "Saturday",
#     "startTime" : "18:00",
#     "category" : "ImportantAndRecommended",
#     "installDuration" : "12:00"
#   })

# }

# resource "azurerm_virtual_machine_scale_set_extension" "dependency" {
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vm.id
#   name                         = "DependencyAgentLinux"
#   publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
#   type                         = "DependencyAgentLinux"
#   type_handler_version         = "9.5"
#   auto_upgrade_minor_version   = true
# }

# resource "azurerm_virtual_machine_scale_set_extension" "OmsAgentForLinux" {
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vm.id
#   name                         = "OmsAgentForLinux"
#   publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
#   type                         = "OmsAgentForLinux"
#   type_handler_version         = "1.13"
#   auto_upgrade_minor_version   = true
#   settings = jsonencode({
#     "workspaceId" : "${azurerm_log_analytics_workspace.law.id}"
#   })
#   protectedSettings= jsonencode({
#       "workspaceKey": "${azurerm_log_analytics_workspace.law.primary_shared_key}"
#     })
# }

resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = var.vm_prefix
  location            = var.location
  resource_group_name = var.rg_name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vm.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vm.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 60
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT30M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vm.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }

}

resource "azurerm_network_security_group" "nsg" {
  name                = var.vm_prefix
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "allow-dns-tcp-inbound"
    priority                   = 221
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["53"]
    source_address_prefixes    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    destination_address_prefix = "*"
    access                     = "Allow"
    direction                  = "Inbound"
  }
  security_rule {
    name                       = "allow-dns-UDP-inbound"
    priority                   = 222
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["53"]
    source_address_prefixes    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    destination_address_prefix = "*"
    access                     = "Allow"
    direction                  = "Inbound"
  }
  security_rule {
    name                       = "allow-ssh-inbound"
    priority                   = 130
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    destination_address_prefix = "*"
    access                     = "Allow"
    direction                  = "Inbound"
  }

}
