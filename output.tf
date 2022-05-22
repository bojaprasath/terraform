output "resource_group_name" {
    value = azurerm_resource_group.rg.name
}

output "azurerm_virtual_network" {
    value = azurerm_virtual_network.vnet.name
}

output "azurerm_ftdv_public_ip" {
    value = azurerm_public_ip.fw-mgmt-pip.ip_address
}

output "azurerm_ftdv_public_ipv6" {
    value = azurerm_public_ip.fw-mgmt-pip6.ip_address
}

output "azurerm_ubuntu_in_public_ip" {
    value = azurerm_public_ip.ubuntu-in-mgmt-pip.ip_address
}
output "azurerm_ubuntu_out_public_ip" {
    value = azurerm_public_ip.ubuntu-out-mgmt-pip.ip_address
}
