# terraform-azurerm-dns-relay

```hcl
module "uksouth_dns" {
  source = "./vmss-module"

  providers = {
    azurerm = azurerm.transit
  }

  vm_prefix      = "gbazddns"
  rg_name        = azurerm_resource_group.rg-dns-svc.name
  location       = "UK South"
  vm_sku         = "Standard_B1ms"
  instance_count = 1
  ssh_key        = var.ssh_key
  subnet_id      = module.uksouth-transit.platforms_subnet.id
  dns_servers    = ["10.8.8.19", "10.11.8.20"]
  syslog_server  = "10.8.27.136"
  vnet_cidr      = module.uksouth-transit.vnet.address_space[0]
  egress         = false

  os = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

}

```