output "public_ip_adress" {
  value = "${azurerm_linux_virtual_machine.dev-vm.name}: ${data.azurerm_public_ip.dev-ip-data.ip_address}"
}
