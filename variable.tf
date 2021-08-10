variable "vm_name" {
  description = "Name of the VM"
}

variable "resource_group_name" {
  description = "Resource group contains the VM"
}

variable "location" {
  description = "Location of the VM"
}

variable "subnet_id" {
  description = "Subnet of the VM"
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking or not"
  type        = bool
  default     = false
}

variable "private_ip_address_allocation" {
  description = "Type of address allocation"
  default     = "Dynamic"
}

variable "vm_size" {
  description = "Default size of the VM"
  default     = "Standard_B2s"
}

variable "os_image_id" {
  description = "ID of the custom OS image"
  default = ""
}

variable "os_image_publisher" {
  description = "Publisher of the OS image"
  default     = ""
}

variable "os_image_offer" {
  description = "Offer of the OS image"
  default     = ""
}

variable "os_image_sku" {
  description = "SKU of the OS image"
  default     = ""
}

variable "os_image_version" {
  description = "Version of the OS image"
  default     = "latest"
}

variable "os_disk_type" {
  description = "Defines the type of storage account to be created. Valid options are Standard_LRS, Standard_ZRS, Standard_GRS, Standard_RAGRS, Premium_LRS."
  default     = "Standard_LRS"
}

variable "admin_username" {
  description = "Admin username of the VM"
}

variable "admin_password" {
  description = "Admin password of the Windows VM"
  default = ""
}

variable "ssh_public_key" {
  description = "Public key for SSH"
  default = ""
}

variable "os_type" {
  description = "Type of the OS"
}

variable "is_public" {
  description = "Define if the VM is public or not"
  type = bool
  default = false
}

variable "pip_allocation_method" {
  description = "Allocation method for public ip"
  default = "Static"
}

variable "pip_sku" {
  description = "Defines the SKU of the Public IP. Accepted values are Basic and Standard. Defaults to Basic."
  default     = "Basic"
}

variable "tags" {
  description = "Tag for resources"
  type = map(any)
  default = {}
}

variable "zones" {
  description = "Availability Zones for the VM"
  type = list(any)
  default = []
}