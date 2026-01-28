# Load Balancer Module - Azure Load Balancer for Nautobot Web tier

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = var.lb_sku
  zones               = var.availability_zones

  tags = merge(var.tags, {
    Component = "LoadBalancer"
  })
}

# Load Balancer
resource "azurerm_lb" "nautobot" {
  name                = "lb-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.lb_sku

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lb.id
  }

  tags = var.tags
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "nautobot" {
  name            = "BackendPool"
  loadbalancer_id = azurerm_lb.nautobot.id
}

# Health Probe - HTTPS
resource "azurerm_lb_probe" "https" {
  name                = "HealthProbeHTTPS"
  loadbalancer_id     = azurerm_lb.nautobot.id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Health Probe - HTTP (for redirect check)
resource "azurerm_lb_probe" "http" {
  name                = "HealthProbeHTTP"
  loadbalancer_id     = azurerm_lb.nautobot.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load Balancing Rule - HTTPS
resource "azurerm_lb_rule" "https" {
  name                           = "LBRuleHTTPS"
  loadbalancer_id                = azurerm_lb.nautobot.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nautobot.id]
  probe_id                       = azurerm_lb_probe.https.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = "SourceIPProtocol"
}

# Load Balancing Rule - HTTP (will redirect to HTTPS by nginx)
resource "azurerm_lb_rule" "http" {
  name                           = "LBRuleHTTP"
  loadbalancer_id                = azurerm_lb.nautobot.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nautobot.id]
  probe_id                       = azurerm_lb_probe.http.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = "SourceIPProtocol"
}

# Outbound Rule for SNAT
resource "azurerm_lb_outbound_rule" "nautobot" {
  name                    = "OutboundRule"
  loadbalancer_id         = azurerm_lb.nautobot.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.nautobot.id

  frontend_ip_configuration {
    name = "LoadBalancerFrontEnd"
  }
}
