#!/usr/bin/env python3
"""
Update Ansible Inventory from Terraform Output
This script reads Terraform JSON output and updates the Ansible inventory
"""

import json
import sys
import yaml
from pathlib import Path
import subprocess
import argparse

def get_terraform_output(environment='dev'):
    """Get Terraform output as JSON"""
    terraform_dir = Path(__file__).parent.parent / 'terraform' / 'environments' / environment
    
    try:
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            cwd=terraform_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running terraform output: {e.stderr}")
        sys.exit(1)
    except FileNotFoundError:
        print("Terraform not found. Please install Terraform.")
        sys.exit(1)

def get_vmss_instances(resource_group, vmss_name):
    """Get VM Scale Set instance IPs using Azure CLI"""
    try:
        result = subprocess.run(
            ['az', 'vmss', 'list-instances', 
             '--resource-group', resource_group,
             '--name', vmss_name,
             '--query', '[].{name:name, ip:networkProfile.networkInterfaces[0].ipConfigurations[0].privateIpAddress}',
             '--output', 'json'],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting VMSS instances: {e.stderr}")
        return []
    except FileNotFoundError:
        print("Azure CLI not found. Please install az cli.")
        return []

def create_ansible_inventory(tf_output, environment='dev'):
    """Create Ansible inventory structure from Terraform output"""
    
    # Extract values from Terraform output
    resource_group = tf_output.get('resource_group_name', {}).get('value', '')
    postgres_ip = tf_output.get('postgres_private_ip', {}).get('value', '')
    redis_ip = tf_output.get('redis_private_ip', {}).get('value', '')
    scheduler_ip = tf_output.get('scheduler_private_ip', {}).get('value', '')
    web_vmss_name = tf_output.get('web_vmss_name', {}).get('value', '')
    worker_vmss_name = tf_output.get('worker_vmss_name', {}).get('value', '')
    
    # Get VMSS instances
    web_instances = get_vmss_instances(resource_group, web_vmss_name)
    worker_instances = get_vmss_instances(resource_group, worker_vmss_name)
    
    # Build inventory structure
    inventory = {
        'all': {
            'children': {
                f'{environment}_vm': {
                    'hosts': {},
                    'vars': {
                        'resource_group': resource_group,
                        'postgres_host': postgres_ip,
                        'redis_host': redis_ip,
                    }
                }
            }
        }
    }
    
    hosts = inventory['all']['children'][f'{environment}_vm']['hosts']
    
    # Add PostgreSQL host
    if postgres_ip:
        hosts[f'{environment}-nautobot-postgres'] = {
            'ansible_host': postgres_ip,
            'ansible_user': 'azureuser',
            'deploy_env': environment,
            'deployment_type': 'vm',
            'component': 'postgres',
            'ansible_python_interpreter': '/usr/bin/python3'
        }
    
    # Add Redis host
    if redis_ip:
        hosts[f'{environment}-nautobot-redis'] = {
            'ansible_host': redis_ip,
            'ansible_user': 'azureuser',
            'deploy_env': environment,
            'deployment_type': 'vm',
            'component': 'redis',
            'ansible_python_interpreter': '/usr/bin/python3'
        }
    
    # Add Scheduler host
    if scheduler_ip:
        hosts[f'{environment}-nautobot-scheduler'] = {
            'ansible_host': scheduler_ip,
            'ansible_user': 'azureuser',
            'deploy_env': environment,
            'deployment_type': 'vm',
            'component': 'scheduler',
            'ansible_python_interpreter': '/usr/bin/python3'
        }
    
    # Add Web VMSS instances
    for idx, instance in enumerate(web_instances):
        if instance.get('ip'):
            hosts[f'{environment}-nautobot-web-{idx:02d}'] = {
                'ansible_host': instance['ip'],
                'ansible_user': 'azureuser',
                'deploy_env': environment,
                'deployment_type': 'vm',
                'component': 'web',
                'vmss_name': web_vmss_name,
                'vmss_instance': instance.get('name', ''),
                'ansible_python_interpreter': '/usr/bin/python3'
            }
    
    # Add Worker VMSS instances
    for idx, instance in enumerate(worker_instances):
        if instance.get('ip'):
            hosts[f'{environment}-nautobot-worker-{idx:02d}'] = {
                'ansible_host': instance['ip'],
                'ansible_user': 'azureuser',
                'deploy_env': environment,
                'deployment_type': 'vm',
                'component': 'worker',
                'vmss_name': worker_vmss_name,
                'vmss_instance': instance.get('name', ''),
                'ansible_python_interpreter': '/usr/bin/python3'
            }
    
    return inventory

def main():
    parser = argparse.ArgumentParser(description='Update Ansible inventory from Terraform')
    parser.add_argument('--environment', '-e', default='dev', 
                       choices=['dev', 'test', 'prod'],
                       help='Environment (dev, test, prod)')
    parser.add_argument('--output', '-o',
                       help='Output file path (default: inventory/vm/{env}.yml)')
    
    args = parser.parse_args()
    
    # Get Terraform output
    print(f"Reading Terraform output for {args.environment}...")
    tf_output = get_terraform_output(args.environment)
    
    # Create inventory
    print("Creating Ansible inventory...")
    inventory = create_ansible_inventory(tf_output, args.environment)
    
    # Determine output path
    if args.output:
        output_path = Path(args.output)
    else:
        output_path = Path(__file__).parent.parent / 'inventory' / 'vm' / f'{args.environment}.yml'
    
    # Backup existing inventory
    if output_path.exists():
        backup_path = output_path.with_suffix('.yml.backup')
        print(f"Backing up existing inventory to {backup_path}")
        output_path.rename(backup_path)
    
    # Write new inventory
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        yaml.dump(inventory, f, default_flow_style=False, sort_keys=False)
    
    print(f"\n✅ Inventory updated: {output_path}")
    print(f"\nHosts configured:")
    for host_name in inventory['all']['children'][f'{args.environment}_vm']['hosts'].keys():
        host = inventory['all']['children'][f'{args.environment}_vm']['hosts'][host_name]
        component = host.get('component', 'unknown')
        ip = host.get('ansible_host', 'N/A')
        print(f"  - {host_name:30s} ({component:10s}) -> {ip}")
    
    print(f"\nNext steps:")
    print(f"  1. Test connectivity: ansible -i {output_path} all -m ping")
    print(f"  2. Deploy: ansible-playbook -i {output_path} playbooks/deploy_vm_all.yml")

if __name__ == '__main__':
    main()
