variable "resource_group_name" {
  default       = "seveluch-asav-group"
  description   = "Name of the resource group."
}

variable "resource_group_location" {
  default = "eastus"
  description   = "Location of the resource group."
}


variable "custom_image_resource_group_name" {
  default = "virtual-automation-rg"
  description   = "Location of the resource group."
}

variable "image_version" {
  default = "7.3.01238"
  description = "Version of the image"
}
variable "source-address" {
  type    = string
  default = "*"
}
variable "IPAddressPrefix" {
  default = "10.10"
}
variable "IPv6AddressPrefix" {
  default = "ace:cab:deca::/48"
}
variable "IPv6SubnetPrefix" {
  default = "ace:cab:deca:"
}
variable "IPv6SubnetMask" {
  default = "64"
}
variable "VMSize" {
  default = "Standard_D3_v2"
}
variable "instancename" {
  default = "cisco-asav"
}
variable "instanceusername" {
  default = "cisco"
}
variable "instancepassword" {
  default = "Azurecisco#12"
}
variable "day0-config" {
  default = "config.json"
}