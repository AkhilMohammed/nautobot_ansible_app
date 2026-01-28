#!/usr/bin/env python3
"""
Terraform to Ansible Integration Script for Azure Managed Services
Extracts Terraform outputs and updates Ansible inventory and variables
"""

import json
import subprocess
import sys
import yaml
import os
from pathlib import Path

def run_command(cmd, cwd=None):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {cmd}")
        print(f"Error: {e.stderr}")
        sys.exit(1)

def get_terraform_outputs(terraform_dir, environment):
    """Get Terraform outputs as JSON"""
    print(f"📊 Fetching Terraform outputs for {environment}...")
    
    output = run_command("terraform output -json", cwd=terraform_dir)
    if not output:
        print("❌ No Terraform outputs found. Have you run 'terraform apply'?")
        sys.exit(1)
    
    return json.loads(output)

def create_ansible_inventory(outputs, environment, inventory_dir):
    """Create dynamic Ansible inventory from Terraform outputs"""
    print(f"📝 Generating Ansible inventory for {environment}...")
    
    ansible_data = outputs.get('ansible_inventory', {}).get('value', {})
    
    inventory = {
        'all': {
            'children': {
                'nautobot_web': {},
                'nautobot_worker': {},
                'nautobot_scheduler': {},
                environment: {
                    'children': ['nautobot_web', 'nautobot_worker', 'nautobot_scheduler']
                }
            }
        }
    }
    
    # Web servers
    if 'web_servers' in ansible_data:
        inventory['all']['children']['nautobot_web'] = {
            'hosts': {}
        }
        for idx, ip in enumerate(ansible_data['web_servers']['hosts'], 1):
            inventory['all']['children']['nautobot_web']['hosts'][f'{environment}-nautobot-web-{idx}'] = {
                'ansible_host': ip
            }
        inventory['all']['children']['nautobot_web']['vars'] = ansible_data['web_servers']['vars']
    
    # Worker servers
    if 'worker_servers' in ansible_data:
        inventory['all']['children']['nautobot_worker'] = {
            'hosts': {}
        }
        for idx, ip in enumerate(ansible_data['worker_servers']['hosts'], 1):
            inventory['all']['children']['nautobot_worker']['hosts'][f'{environment}-nautobot-worker-{idx}'] = {
                'ansible_host': ip
            }
        inventory['all']['children']['nautobot_worker']['vars'] = ansible_data['worker_servers']['vars']
    
    # Scheduler servers
    if 'scheduler_servers' in ansible_data:
        inventory['all']['children']['nautobot_scheduler'] = {
            'hosts': {}
        }
        for idx, ip in enumerate(ansible_data['scheduler_servers']['hosts'], 1):
            inventory['all']['children']['nautobot_scheduler']['hosts'][f'{environment}-nautobot-scheduler-{idx}'] = {
                'ansible_host': ip
            }
        inventory['all']['children']['nautobot_scheduler']['vars'] = ansible_data['scheduler_servers']['vars']
    
    # Write inventory file
    inventory_file = Path(inventory_dir) / f"{environment}_dynamic.yml"
    with open(inventory_file, 'w') as f:
        yaml.dump(inventory, f, default_flow_style=False, sort_keys=False)
    
    print(f"✅ Inventory written to: {inventory_file}")
    return inventory_file

def create_terraform_vars(outputs, environment, group_vars_dir):
    """Create Ansible variables file from Terraform outputs"""
    print(f"📝 Generating Terraform variables for Ansible...")
    
    ansible_data = outputs.get('ansible_inventory', {}).get('value', {})
    
    terraform_vars = {
        # PostgreSQL (Azure Managed)
        'terraform_postgresql_fqdn': outputs.get('postgresql_server_fqdn', {}).get('value'),
        'terraform_postgresql_database': outputs.get('postgresql_database_name', {}).get('value'),
        'terraform_postgresql_username': outputs.get('postgresql_admin_username', {}).get('value'),
        
        # Redis (Azure Managed)
        'terraform_redis_hostname': outputs.get('redis_hostname', {}).get('value'),
        'terraform_redis_ssl_port': outputs.get('redis_ssl_port', {}).get('value'),
        
        # Load Balancer
        'terraform_load_balancer_ip': outputs.get('load_balancer_public_ip', {}).get('value'),
        'terraform_load_balancer_fqdn': outputs.get('load_balancer_fqdn', {}).get('value'),
        
        # Storage Account
        'terraform_storage_account_name': outputs.get('storage_account_name', {}).get('value'),
        'terraform_storage_account_endpoint': outputs.get('storage_account_primary_blob_endpoint', {}).get('value'),
        
        # Key Vault
        'terraform_key_vault_name': outputs.get('key_vault_name', {}).get('value'),
        'terraform_key_vault_uri': outputs.get('key_vault_uri', {}).get('value'),
        
        # Resource Group
        'terraform_resource_group': outputs.get('resource_group_name', {}).get('value'),
        
        # Network
        'terraform_vnet_name': outputs.get('vnet_name', {}).get('value'),
        'terraform_vnet_id': outputs.get('vnet_id', {}).get('value'),
    }
    
    # Remove None values
    terraform_vars = {k: v for k, v in terraform_vars.items() if v is not None}
    
    # Write to group_vars
    vars_file = Path(group_vars_dir) / environment / "terraform.yml"
    vars_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(vars_file, 'w') as f:
        f.write("---\n")
        f.write("# Auto-generated from Terraform outputs\n")
        f.write("# DO NOT EDIT MANUALLY - Will be overwritten\n\n")
        yaml.dump(terraform_vars, f, default_flow_style=False, sort_keys=False)
    
    print(f"✅ Terraform variables written to: {vars_file}")
    return vars_file

def create_secrets_template(outputs, environment, group_vars_dir):
    """Create a template for secrets that need to be vaulted"""
    print(f"📝 Generating secrets template...")
    
    secrets_template = {
        '# Database password (from Azure Key Vault or Terraform)': None,
        'vault_database_password': 'CHANGE_ME',
        
        '# Redis password (from Azure Key Vault or Terraform)': None,
        'vault_redis_password': 'CHANGE_ME',
        
        '# Azure Storage Account Key': None,
        'vault_azure_storage_key': 'CHANGE_ME',
        
        '# Nautobot Secret Key': None,
        'vault_nautobot_secret_key': 'CHANGE_ME',
        
        '# Git credentials': None,
        'vault_git_username': 'CHANGE_ME',
        'vault_git_token': 'CHANGE_ME',
    }
    
    secrets_file = Path(group_vars_dir) / environment / "vault_template.yml"
    
    # Only create if it doesn't exist
    if not secrets_file.exists():
        with open(secrets_file, 'w') as f:
            f.write("---\n")
            f.write("# Secrets Template - Encrypt with ansible-vault\n")
            f.write("# Copy this to vault.yml and encrypt:\n")
            f.write("#   ansible-vault encrypt group_vars/{}/vault.yml\n\n".format(environment))
            
            for key, value in secrets_template.items():
                if value is None:
                    f.write(f"{key}\n")
                else:
                    f.write(f"{key}: '{value}'\n")
        
        print(f"✅ Secrets template written to: {secrets_file}")
        print(f"⚠️  Please update secrets and encrypt with: ansible-vault encrypt {secrets_file}")
    else:
        print(f"ℹ️  Secrets template already exists: {secrets_file}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 terraform_to_ansible.py <environment>")
        print("Example: python3 terraform_to_ansible.py dev")
        sys.exit(1)
    
    environment = sys.argv[1]
    
    if environment not in ['dev', 'test', 'prod']:
        print(f"❌ Invalid environment: {environment}")
        print("Valid environments: dev, test, prod")
        sys.exit(1)
    
    # Paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    terraform_dir = project_root / "terraform"
    inventory_dir = project_root / "inventory" / "vm"
    group_vars_dir = project_root / "group_vars"
    
    print(f"\n🚀 Terraform to Ansible Integration for {environment.upper()}")
    print("="* 60)
    
    # Get Terraform outputs
    outputs = get_terraform_outputs(terraform_dir, environment)
    
    # Create Ansible inventory
    create_ansible_inventory(outputs, environment, inventory_dir)
    
    # Create Terraform variables for Ansible
    create_terraform_vars(outputs, environment, group_vars_dir)
    
    # Create secrets template
    create_secrets_template(outputs, environment, group_vars_dir)
    
    print("\n✅ Integration complete!")
    print("\n📋 Next steps:")
    print(f"1. Review generated inventory: inventory/vm/{environment}_dynamic.yml")
    print(f"2. Update secrets: group_vars/{environment}/vault_template.yml")
    print(f"3. Encrypt secrets: ansible-vault encrypt group_vars/{environment}/vault.yml")
    print(f"4. Run Ansible: ansible-playbook -i inventory/vm/{environment}_dynamic.yml playbooks/deploy_vm_all.yml")

if __name__ == "__main__":
    main()
