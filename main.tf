resource "azurerm_public_ip" "pip" {
  count = var.is_public ? 1 : 0
  name = "${var.vm_name}-publicip"
  resource_group_name = var.resource_group_name
  location = var.location
  allocation_method = var.pip_allocation_method
  sku = var.pip_sku

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "nic" {
  name = "${var.vm_name}-nic"
  resource_group_name = var.resource_group_name
  location = var.location
  internal_dns_name_label = "${var.vm_name}"
  enable_accelerated_networking = var.enable_accelerated_networking

  ip_configuration {
    name = "${var.vm_name}-ipconf"
    subnet_id = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
    public_ip_address_id = var.is_public ? azurerm_public_ip.pip[0].id : null
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_machine" "vm" {
  name = "${var.vm_name}"
  resource_group_name = var.resource_group_name
  location = var.location
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size = var.vm_size
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = var.os_image_id
    publisher = var.os_image_id == "" ? var.os_image_publisher : ""
    offer = var.os_image_id == "" ? var.os_image_offer : ""
    sku = var.os_image_id == "" ? var.os_image_sku : ""
    version = var.os_image_id == "" ? var.os_image_version : ""
  }

  storage_os_disk {
    name = "${var.vm_name}-osdisk"
    create_option = "FromImage"
    caching = "ReadWrite"
    managed_disk_type = var.os_disk_type
  }

  os_profile {
    computer_name = "${var.vm_name}"
    admin_username = var.admin_username
    admin_password = var.os_type == "windows" ? var.admin_password : null
  }

  dynamic os_profile_linux_config {
    for_each = var.os_type == "linux" ? [var.os_type] : []
    content {
      disable_password_authentication = true
      ssh_keys {
        path = "/home/${var.admin_username}/.ssh/authorized_keys"
        key_data = var.ssh_public_key
      }
    }
  }

  dynamic os_profile_windows_config {
    for_each = var.os_type == "windows" ? [var.os_type] : []
    content {
      provision_vm_agent = true
    }
  }

  zones = var.zones

  tags = var.tags

  lifecycle {
    ignore_changes = [tags,storage_image_reference]
  }
}

# Dynamic public ip address will be got after it's assigned to a vm
# Use to output the public IP of the VM
data "azurerm_public_ip" "pip" {
  count = length(azurerm_public_ip.pip)
  name = azurerm_public_ip.pip[count.index].name
  resource_group_name = var.resource_group_name
  depends_on = [azurerm_virtual_machine.vm]
}