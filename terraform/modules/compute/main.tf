# Compute Module - VMs and VM Scale Sets for Nautobot

# User-assigned Managed Identity for VMs
resource "azurerm_user_assigned_identity" "nautobot" {
  name                = "id-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# SSH Key for VMs
resource "azurerm_ssh_public_key" "nautobot" {
  name                = "ssh-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  public_key          = var.admin_ssh_public_key

  tags = var.tags
}

# === PostgreSQL VM ===
resource "azurerm_network_interface" "postgres" {
  name                = "nic-postgres-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_data_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.postgres_private_ip
  }

  tags = var.tags
}

resource "azurerm_managed_disk" "postgres_data" {
  name                 = "disk-postgres-data-${var.environment}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.postgres_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.postgres_disk_size_gb

  tags = merge(var.tags, {
    Component = "PostgreSQL"
    DataDisk  = "true"
  })
}

resource "azurerm_linux_virtual_machine" "postgres" {
  name                = "vm-postgres-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.postgres_vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.postgres.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-postgres-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.nautobot.id]
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  tags = merge(var.tags, {
    Component = "PostgreSQL"
    Ansible   = "vm_postgres"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "postgres" {
  managed_disk_id    = azurerm_managed_disk.postgres_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.postgres.id
  lun                = 0
  caching            = "ReadWrite"
}

# === Redis VM ===
resource "azurerm_network_interface" "redis" {
  name                = "nic-redis-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_data_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.redis_private_ip
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "redis" {
  name                = "vm-redis-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.redis_vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.redis.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-redis-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.nautobot.id]
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  tags = merge(var.tags, {
    Component = "Redis"
    Ansible   = "vm_redis"
  })
}

# === Nautobot Scheduler VM ===
resource "azurerm_network_interface" "scheduler" {
  name                = "nic-scheduler-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_app_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "scheduler" {
  name                = "vm-nautobot-scheduler-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.scheduler_vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.scheduler.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-scheduler-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.nautobot.id]
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-scheduler.yaml", {
    admin_username = var.admin_username
  }))

  tags = merge(var.tags, {
    Component = "Scheduler"
    Ansible   = "vm_nautobot_scheduler"
  })
}

# === Nautobot Web VM Scale Set ===
resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name                = "vmss-nautobot-web-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.web_vm_size
  instances           = var.web_instance_count
  admin_username      = var.admin_username
  upgrade_mode        = "Manual"

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name    = "nic-web"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.subnet_app_id
      load_balancer_backend_address_pool_ids = [var.lb_backend_pool_id]
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.nautobot.id]
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-web.yaml", {
    admin_username = var.admin_username
  }))

  tags = merge(var.tags, {
    Component = "Web"
    Ansible   = "vm_nautobot_app"
  })
}

# Auto-scaling for Web VMSS
resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "autoscale-web-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web.id

  profile {
    name = "AutoScale"

    capacity {
      default = var.web_instance_count
      minimum = var.web_min_instances
      maximum = var.web_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags
}

# === Nautobot Worker VM Scale Set ===
resource "azurerm_linux_virtual_machine_scale_set" "worker" {
  name                = "vmss-nautobot-worker-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.worker_vm_size
  instances           = var.worker_instance_count
  admin_username      = var.admin_username
  upgrade_mode        = "Manual"

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name    = "nic-worker"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.subnet_app_id
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.nautobot.id]
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-worker.yaml", {
    admin_username = var.admin_username
  }))

  tags = merge(var.tags, {
    Component = "Worker"
    Ansible   = "vm_nautobot_worker"
  })
}

# Auto-scaling for Worker VMSS
resource "azurerm_monitor_autoscale_setting" "worker" {
  name                = "autoscale-worker-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.worker.id

  profile {
    name = "AutoScale"

    capacity {
      default = var.worker_instance_count
      minimum = var.worker_min_instances
      maximum = var.worker_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.worker.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.worker.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags
}
