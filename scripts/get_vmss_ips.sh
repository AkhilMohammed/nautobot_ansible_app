#!/bin/bash
# Get VM IPs from Azure VMSS
# Usage: ./get_vmss_ips.sh dev web
#        ./get_vmss_ips.sh dev worker

ENVIRONMENT="${1:-dev}"
COMPONENT="${2:-web}"  # web or worker

RESOURCE_GROUP="rg-nautobot-${ENVIRONMENT}"
VMSS_NAME="vmss-nautobot-${COMPONENT}-${ENVIRONMENT}"

echo "Getting IP addresses for $VMSS_NAME in $RESOURCE_GROUP..."

az vmss list-instances \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VMSS_NAME" \
    --query '[].{Name:name, PrivateIP:networkProfile.networkInterfaces[0].ipConfigurations[0].privateIpAddress}' \
    --output table
