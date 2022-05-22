

################################################################################################################################
# Resource Group Creation
################################################################################################################################


# Create a resource group
resource "azurerm_resource_group" "rg" {
  name      = var.resource_group_name
  location  = var.resource_group_location
}


data "azurerm_subscription" "current" {
}


################################################################################################################################
# Virtual Network and Subnet Creation
################################################################################################################################


resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_group_name}-vnet"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [join("", tolist([var.IPAddressPrefix, ".0.0/16"])),var.IPv6AddressPrefix]

}

resource "azurerm_subnet" "mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".0.0/24"])),join("", tolist([var.IPv6SubnetPrefix, "1::/",var.IPv6SubnetMask]))]
}

resource "azurerm_subnet" "inside" {
  name                 = "inside"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".1.0/24"])),join("", tolist([var.IPv6SubnetPrefix, "2::/",var.IPv6SubnetMask]))]
}

resource "azurerm_subnet" "outside" {
  name                 = "outside"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".2.0/24"])),join("", tolist([var.IPv6SubnetPrefix, "3::/",var.IPv6SubnetMask]))]
}

################################################################################################################################
# Route Table Creation and Route Table Association
################################################################################################################################

resource "azurerm_route_table" "mgmt" {
  name                = "mgmt"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_route_table" "inside" {
  name                = "inside-rt"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name           = "Inside-Outside"
    address_prefix = join("", tolist([var.IPAddressPrefix, ".2.0/24"]))
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.fw-outside.private_ip_address
  }
     route {
    name           = "Inside-Outside-v6"
    address_prefix = join("", tolist([var.IPv6SubnetPrefix, "3::/",var.IPv6SubnetMask]))
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.fw-outside.private_ip_addresses[1]
  }
}

resource "azurerm_route_table" "outside" {
  name                = "outside-rt"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name           = "Outside-Inside"
    address_prefix = join("", tolist([var.IPAddressPrefix, ".1.0/24"]))
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.fw-inside.private_ip_address
  }
   route {
    name           = "Outside-Inside-v6"
    address_prefix = join("", tolist([var.IPv6SubnetPrefix, "2::/",var.IPv6SubnetMask]))
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.fw-inside.private_ip_addresses[1]
  }
}

resource "azurerm_subnet_route_table_association" "management" {
  subnet_id                 = azurerm_subnet.mgmt.id
  route_table_id            = azurerm_route_table.mgmt.id
}
resource "azurerm_subnet_route_table_association" "inside" {
  subnet_id                 = azurerm_subnet.inside.id
  route_table_id            = azurerm_route_table.inside.id
}
resource "azurerm_subnet_route_table_association" "outside" {
  subnet_id                 = azurerm_subnet.outside.id
  route_table_id            = azurerm_route_table.outside.id
}

################################################################################################################################
# Network Security Group Creation
################################################################################################################################

resource "azurerm_network_security_group" "allow-all" {
    name                = "fw-allow-all"
    location            = var.resource_group_location
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name                       = "TCP-Allow-SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = var.source-address
        destination_address_prefix = "*"
    }
}

################################################################################################################################
# Network Interface Creation, Public IP Creation and Network Security Group Association
################################################################################################################################

resource "azurerm_network_interface" "fw-mgmt" {
  name                      = "fw-mgmt"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  enable_ip_forwarding      = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "mgmt"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fw-mgmt-pip.id
    primary                       = true
  }
  ip_configuration {
    name                          = "mgmt-v6"
    private_ip_address_version    = "IPv6"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fw-mgmt-pip6.id
  }
}

resource "azurerm_public_ip" "fw-mgmt-pip" {
    name                         = "fw-mgmt-pip"
    location                     = var.resource_group_location
    resource_group_name          = azurerm_resource_group.rg.name
    sku                 = "Standard"
    allocation_method            = "Static"
}

#Create a v6 Public IP
resource "azurerm_public_ip" "fw-mgmt-pip6" {
    name                = "fw-mgmt-pip6"
    location            = var.resource_group_location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = "Standard"
    allocation_method   = "Static"
    ip_version = "IPv6"
}


resource "azurerm_network_interface_security_group_association" "mgmt-nic-nsg" {
  network_interface_id      = azurerm_network_interface.fw-mgmt.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}

resource "azurerm_network_interface" "ubuntu-in-mgmt" {
  name                      = "ubuntu-in-mgmt"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  enable_ip_forwarding      = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "ubuntu-in-mgmt"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu-in-mgmt-pip.id
  }
}

resource "azurerm_public_ip" "ubuntu-in-mgmt-pip" {
    name                         = "ubuntu-in-mgmt-pip"
    location                     = var.resource_group_location
    resource_group_name          = azurerm_resource_group.rg.name
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_network_interface_security_group_association" "in-mgmt-nic-nsg" {
  network_interface_id      = azurerm_network_interface.ubuntu-in-mgmt.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}

resource "azurerm_network_interface" "ubuntu-out-mgmt" {
  name                      = "ubuntu-out-mgmt"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  enable_ip_forwarding      = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "ubuntu-out-mgmt"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu-out-mgmt-pip.id
  }
}

resource "azurerm_public_ip" "ubuntu-out-mgmt-pip" {
    name                         = "ubuntu-out-mgmt-pip"
    location                     = var.resource_group_location
    resource_group_name          = azurerm_resource_group.rg.name
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_network_interface_security_group_association" "out-mgmt-nic-nsg" {
  network_interface_id      = azurerm_network_interface.ubuntu-out-mgmt.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}

resource "azurerm_network_interface" "fw-inside" {
  name                      = "fw-inside"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  depends_on                = [azurerm_network_interface.fw-mgmt]
  enable_ip_forwarding      = true
  enable_accelerated_networking = true
  ip_configuration {
    name                          = "fw-inside"
    subnet_id                     = azurerm_subnet.inside.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
    ip_configuration {
    name                          = "fw-inside-v6"
    private_ip_address_version    = "IPv6"
    subnet_id                     = azurerm_subnet.inside.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface" "fw-outside" {
  name                      = "fw-outside"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  depends_on                = [azurerm_network_interface.fw-inside]
  enable_ip_forwarding      = true
  enable_accelerated_networking = true
  ip_configuration {
    name                          = "fw-outside"
    subnet_id                     = azurerm_subnet.outside.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
  ip_configuration {
    name                          = "fw-outside-v6"
    private_ip_address_version    = "IPv6"
    subnet_id                     = azurerm_subnet.outside.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_network_interface" "ubuntu-out-outside" {
  name                      = "ubuntu-out-outside"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  enable_ip_forwarding      = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "ubuntu-out-outside"
    subnet_id                     = azurerm_subnet.outside.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
  ip_configuration {
    name                          = "ubuntu-out-outside-v6"
    private_ip_address_version    = "IPv6"
    subnet_id                     = azurerm_subnet.outside.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_network_interface" "ubuntu-in-inside" {
  name                      = "ubuntu-in-inside"
  location                  = var.resource_group_location
  resource_group_name       = azurerm_resource_group.rg.name
  enable_ip_forwarding      = true
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "ubuntu-in-inside"
    subnet_id                     = azurerm_subnet.inside.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
  ip_configuration {
    name                          = "ubuntu-in-inside-v6"
    private_ip_address_version    = "IPv6"
    subnet_id                     = azurerm_subnet.inside.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_storage_account" "fwsa" {
  name                = "fwsasavtorageipv6"
  resource_group_name = azurerm_resource_group.rg.name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}


resource "azurerm_storage_account" "fwsa1" {
  name                = "fwsasavtorageipv6"
  resource_group_name = azurerm_resource_group.rg.name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}


data "template_file" "day0_ubuntu_in" {
  template = "${file("customdata.tpl")}"

  vars = {
    destination_ip = "${azurerm_network_interface.ubuntu-out-outside.private_ip_address}"
    destination_ip6 = "${azurerm_network_interface.ubuntu-out-outside.private_ip_addresses[1]}"
    gw = "${azurerm_network_interface.fw-inside.private_ip_address}"
    gw6 = "${azurerm_network_interface.fw-inside.private_ip_addresses[1]}"
  }
}


data "template_cloudinit_config" "day0_ubuntu_in" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.day0_ubuntu_in.rendered}"
  }
}


data "template_file" "day0_ubuntu_out" {
  template = "${file("customdata.tpl")}"

  vars = {
    destination_ip = "${azurerm_network_interface.ubuntu-in-inside.private_ip_address}"
    destination_ip6 = "${azurerm_network_interface.ubuntu-in-inside.private_ip_addresses[1]}"
    gw = "${azurerm_network_interface.fw-outside.private_ip_address}"
    gw6 = "${azurerm_network_interface.fw-outside.private_ip_addresses[1]}"
  }
}

data "template_cloudinit_config" "day0_ubuntu_out" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.day0_ubuntu_out.rendered}"
  }
}

resource "azurerm_virtual_machine" "ubuntu-in" {
  name                  = "ubuntu-in-vm"
  location              = var.resource_group_location
  resource_group_name   = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_network_interface.ubuntu-in-mgmt,
    azurerm_network_interface.ubuntu-in-inside,
  ]
  
  primary_network_interface_id = azurerm_network_interface.ubuntu-in-mgmt.id
  network_interface_ids = [azurerm_network_interface.ubuntu-in-mgmt.id,azurerm_network_interface.ubuntu-in-inside.id]
  vm_size               = "Standard_D3_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "ubuntu-in-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }



  os_profile {
    computer_name  = "ubuntu-in"
    admin_username = "ubuntu"
    admin_password = "Cisco#12"
    custom_data = data.template_cloudinit_config.day0_ubuntu_in.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "devtest"
  }
}

resource "azurerm_virtual_machine" "ubuntu-out" {
  name                  = "ubuntu-out-vm"
  location              = var.resource_group_location
  resource_group_name   = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_network_interface.ubuntu-out-mgmt,
    azurerm_network_interface.ubuntu-out-outside,
  ]
  
  primary_network_interface_id = azurerm_network_interface.ubuntu-out-mgmt.id
  network_interface_ids = [azurerm_network_interface.ubuntu-out-mgmt.id,azurerm_network_interface.ubuntu-out-outside.id]
  vm_size               = "Standard_D3_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "ubuntu-out-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "ubuntu-out"
    admin_username = "ubuntu"
    admin_password = "Cisco#12"
    custom_data = data.template_cloudinit_config.day0_ubuntu_out.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "devtest"
  }
}


################################################################################################################################
# Cisco asav Instance Creation
################################################################################################################################
data "template_file" "asav_day0" {
  template = "${file("asav_day0_config")}"
}

resource "azurerm_virtual_machine" "asav" {
  name                  = "asav-vm"
  location              = var.resource_group_location
  resource_group_name   = azurerm_resource_group.rg.name
  
  depends_on = [
    azurerm_network_interface.fw-mgmt,
    azurerm_network_interface.fw-inside,
    azurerm_network_interface.fw-outside
  ]
  
  primary_network_interface_id = azurerm_network_interface.fw-mgmt.id
  network_interface_ids = [azurerm_network_interface.fw-mgmt.id,
                           azurerm_network_interface.fw-inside.id,azurerm_network_interface.fw-outside.id]
  vm_size               = var.VMSize


  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  boot_diagnostics {
    enabled = true
    storage_uri = azurerm_storage_account.fwsa.primary_blob_endpoint
  }
  storage_image_reference {
    #id = "/subscriptions/${var.resource_group_name}"
    #id = "${data.azurerm_subscription.current.id}/resourceGroups/${var.custom_image_resource_group_name}/providers/Microsoft.Compute/galleries/virtautomationimages/images/FTDv/versions/${var.image_version}"
    id = "/subscriptions/33d2517e-ca88-46aa-beb2-74ff1dd61b41/resourceGroups/virtual-automation-rg/providers/Microsoft.Compute/images/asav99-19-1-54"
  }
  storage_os_disk {
    name              = "asav-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.instancename
    admin_username = var.instanceusername
    admin_password = var.instancepassword
    #custom_data = data.template_file.asav_day0.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = false
    
  }
  
}
