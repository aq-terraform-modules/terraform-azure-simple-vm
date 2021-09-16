resource "azurerm_resource_group" "rg" {
  count    = var.create_rg ? 1 : 0
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    name = var.resource_group_name
    applicationRole = var.tag_applicationRole
  }
}

resource "azurerm_public_ip" "pip" {
  count               = var.is_public ? var.vm_count : 0
  name                = var.vm_count == 1 ? "${var.vm_name}-publicip" : "${var.vm_name}-${count.index+1}-publicip"
  resource_group_name = var.create_rg ? azurerm_resource_group.rg[0].name : var.resource_group_name
  location            = var.location
  allocation_method   = var.pip_allocation_method
  sku                 = var.pip_sku

  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    name = var.vm_count == 1 ? "${var.vm_name}-publicip" : "${var.vm_name}-${count.index+1}-publicip"
    applicationRole = var.tag_applicationRole
  }
}

resource "azurerm_network_interface" "nic" {
  count                         = var.vm_count
  name                          = var.vm_count == 1 ? "${var.vm_name}-nic" : "${var.vm_name}-${count.index+1}-nic"
  resource_group_name           = var.create_rg ? azurerm_resource_group.rg[0].name : var.resource_group_name
  location                      = var.location
  internal_dns_name_label       = var.vm_count == 1 ? "${var.vm_name}-nic" : "${var.vm_name}-${count.index+1}-nic"
  enable_accelerated_networking = var.enable_accelerated_networking

  ip_configuration {
    name                          = var.vm_count == 1 ? "${var.vm_name}-ipconf" : "${var.vm_name}-${count.index+1}-ipconf"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
    public_ip_address_id          = var.is_public ? azurerm_public_ip.pip[count.index].id : null
  }

  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    name = var.vm_count == 1 ? "${var.vm_name}-nic" : "${var.vm_name}-${count.index+1}-nic"
    applicationRole = var.tag_applicationRole
  }
}

resource "azurerm_virtual_machine" "vm" {
  count                            = var.vm_count
  name                             = var.vm_count == 1 ? var.vm_name : "${var.vm_name}-${count.index+1}"
  resource_group_name              = var.create_rg ? azurerm_resource_group.rg[0].name : var.resource_group_name
  location                         = var.location
  network_interface_ids            = [azurerm_network_interface.nic[count.index].id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id        = var.os_image_id
    publisher = var.os_image_id == "" ? var.os_image_publisher : ""
    offer     = var.os_image_id == "" ? var.os_image_offer : ""
    sku       = var.os_image_id == "" ? var.os_image_sku : ""
    version   = var.os_image_id == "" ? var.os_image_version : ""
  }

  storage_os_disk {
    name              = var.vm_count == 1 ? "${var.vm_name}-osdisk" : "${var.vm_name}-${count.index+1}-osdisk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = var.os_disk_type
  }

  os_profile {
    computer_name  = var.vm_count == 1 ? var.vm_name : "${var.vm_name}-${count.index+1}"
    admin_username = var.admin_username
    admin_password = var.os_type == "windows" ? var.admin_password : uuid()
    custom_data    = var.os_type == "windows" ? filebase64("${path.module}/files/ansiblewinrm.ps1") : null
  }

  dynamic "os_profile_linux_config" {
    for_each = var.os_type == "linux" ? [var.os_type] : []
    content {
      disable_password_authentication = false
      ssh_keys {
        path     = "/home/${var.admin_username}/.ssh/authorized_keys"
        key_data = var.ssh_public_key
      }
    }
  }

  dynamic "os_profile_windows_config" {
    for_each = var.os_type == "windows" ? [var.os_type] : []
    content {
      provision_vm_agent = true
    }
  }

  tags = {
    name = var.vm_count == 1 ? var.vm_name : "${var.vm_name}-${count.index+1}"
    os   = var.os_type
    applicationRole = var.tag_applicationRole
  }

  zones = var.zones

  lifecycle {
    ignore_changes = [tags, storage_image_reference, os_profile]
  }
}

# Dynamic public ip address will be got after it's assigned to a vm
# Use to output the public IP of the VM
data "azurerm_public_ip" "pip" {
  count               = length(azurerm_public_ip.pip)
  name                = azurerm_public_ip.pip[count.index].name
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_virtual_machine.vm]
}

data "azurerm_dns_zone" "public_dns_zone" {
  name                = var.public_dns_zone_name
  resource_group_name = var.service_rg_name
}

resource "azurerm_dns_a_record" "public_dns_zone_record" {
  name                = var.vm_count == 1 ? var.vm_name : "${var.vm_name}-${count.index+1}"
  zone_name           = data.azurerm_dns_zone.public_dns_zone.name
  resource_group_name = var.service_rg_name
  ttl                 = 600
  records             = [data.azurerm_public_ip.pip.ip_address]
}

resource "azurerm_virtual_machine_extension" "winrm_setup" {
  count                      = var.os_type == "windows" ? var.vm_count : 0
  name                       = "winrm_setup"
  virtual_machine_id         = azurerm_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = <<PROTECTEDSETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy unrestricted -NoProfile -NonInteractive -command \"Copy-Item -Path C:/AzureData/CustomData.bin -Destination C:/AzureData/ansiblewinrm.ps1; C:/AzureData/ansiblewinrm.ps1 -Verbose -ForceNewSSLCert; Remove-Item C:/AzureData/* -Recurse -Force\""
    }
  PROTECTEDSETTINGS
  lifecycle {
    ignore_changes = [tags]
  }
}
