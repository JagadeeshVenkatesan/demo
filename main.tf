provider "azurerm" {
  subscription_id ="de7365e2-8329-48fc-8273-4ab1574e6b4b"
  client_id       ="53b4a79e-e1eb-4415-aa11-7a3fee9e09fc"
  client_secret   ="LxW..Ur3yvn0YFc4Gb~H69l1yeJkYADoKL"
  tenant_id       ="687f51c3-0c5d-4905-84f8-97c683a5b9d1"
  features {}
}
resource "azurerm_resource_group" "main" {
  name     = "Jagadeesh"
  location = "West US 2"
}

resource "azurerm_network_interface" "main" {
  name                = "win_vm_nic"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  name                = "WindowsServer"
  resource_group_name = "${azurerm_resource_group.main.name}"
  location            = "${azurerm_resource_group.main.location}"
  size                = "Standard_F2"
  admin_username      = "sysadmin"
  admin_password      = "Oneindia$123"
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]
  availability_set_id = azurerm_availability_set.main.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}



resource "azurerm_windows_virtual_machine_scale_set" "main" {
  name                = "vmss"
  resource_group_name = "${azurerm_resource_group.main.name}"
  location            = "${azurerm_resource_group.main.location}"
  sku                 = "Standard_F2"
  instances           = 1
  admin_password      = "Oneindia$123"
  admin_username      = "sysadmin"
  
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "rs5-pro"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vmss_NIC"
    primary = true

    ip_configuration {
      name      = "vmss_NIC_ip"
      primary   = true
      subnet_id = azurerm_subnet.main.id
    }
  }
}


resource "azurerm_virtual_network" "main" {
  name                = "myvnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "main" {
  name                 = "internal"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix     = "10.0.2.0/24"
}


resource "azurerm_public_ip" "main" {
  name                = "PublicIPForLB"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_lb" "main" {
  name                = "LoadBalancer"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  resource_group_name = "${azurerm_resource_group.main.name}"
  loadbalancer_id     = azurerm_lb.main.id
  name                = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  network_interface_id    = azurerm_network_interface.main.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_lb_nat_rule" "main" {
  resource_group_name            = "${azurerm_resource_group.main.name}"
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "win_vm_rdp"
  protocol                       = "Tcp"
  frontend_port                  = 5000
  backend_port                   = 3389
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_network_interface_nat_rule_association" "main" {
  network_interface_id  = azurerm_network_interface.main.id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.main.id
}


resource "azurerm_availability_set" "main" {
  name                = "availability_set"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  managed             = "true"
  platform_update_domain_count = 20
  platform_fault_domain_count  = 3
}


resource "azurerm_app_service_plan" "main" {
  name                = "appserviceplan"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "main" {
  name                = "app-service-Jagadeesh"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  app_service_plan_id = azurerm_app_service_plan.main.id

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  app_settings = {
    "SOME_KEY" = "some-value"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "Server=some-server.mydomain.com;Integrated Security=SSPI"
  }
}