# terraform-azurerm-dns-relay

## DNS Relay for Azure Private Link DNS 

```hcl
module "uksouth_dns" {
  source = "https://github.com/georgegil/terraform-azurerm-dns-relay?ref=latest"

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
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

}
```

## Development

Feel free to create a branch and submit a pull request to make changes to the module.