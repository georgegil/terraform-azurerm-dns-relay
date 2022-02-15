variable "vm_prefix" {
  type        = string
  description = "Name of the VMSS"
}

variable "rg_name" {
  type        = string
  description = "Resource Group Name where VMSS will be deployed."
}

variable "location" {
  type        = string
  description = "Geographic location where VNET will be deployed. Allowed values are: `South Central US, East US 2, West US 2, UK South, West Europe, East Asia, Australia East, Australia Southeast, Southeast Asia, UK West.`"
}

variable "vm_sku" {
  type        = string
  default     = "Standard_B2ms"
  description = "The size of the VM's in the VMSS"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "The number of VM's to provision in the VMSS"
}
variable "admin_username" {
  type        = string
  default     = "adminperson"
  description = "The usename to which the public key is being bound to"
}

variable "ssh_key" {
  type        = string
  description = "SSH public key being used when authentication to an instance in the VMSS"
}

variable "os" {
  type = map(string)

  default = {
    "publisher" = "Canonical"
    "offer"     = "UbuntuServer"
    "sku"       = "16.04-LTS"
    "version"   = "latest"
  }

  description = "Operating system being provisioned in the VMSS"
}

variable "subnet_id" {
  type        = string
  description = "Subnet the instance of the VMSS should be privisioned in"
}

variable "dns_servers" {
  type        = list(string)
  description = "Custom DNS servers to which DNS queries are being forwarded to"
}


variable "syslog_server" {
  type        = string
  description = "syslog servers"
}

variable "vnet_cidr" {
  type        = string
  description = "VNET CIDR which is being used to setup a reverce DNS lookup zone"
}

variable "egress" {
  type        = bool
  default     = false
  description = "Privisions a NAT gateway if the transit VNET being provisioned does not have egress capability"
}
