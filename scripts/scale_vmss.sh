#!/bin/bash
# Scale VMSS instances
# Usage: ./scale_vmss.sh dev web 5

ENVIRONMENT="${1:-dev}"
COMPONENT="${2:-web}"  # web or worker
NEW_CAPACITY="${3:-2}"

RESOURCE_GROUP="rg-nautobot-${ENVIRONMENT}"
VMSS_NAME="vmss-nautobot-${COMPONENT}-${ENVIRONMENT}"

echo "Scaling $VMSS_NAME to $NEW_CAPACITY instances..."

az vmss scale \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VMSS_NAME" \
    --new-capacity "$NEW_CAPACITY"

echo "Waiting for scaling operation to complete..."
sleep 10

# Show new instances
echo -e "\nCurrent instances:"
az vmss list-instances \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VMSS_NAME" \
    --query '[].{Name:name, State:provisioningState, PrivateIP:networkProfile.networkInterfaces[0].ipConfigurations[0].privateIpAddress}' \
    --output table

echo -e "\nDon't forget to update Ansible inventory:"
echo "python3 scripts/update_inventory_from_terraform.py --environment $ENVIRONMENT"
