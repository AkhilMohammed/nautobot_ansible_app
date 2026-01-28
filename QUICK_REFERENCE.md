# Nautobot Azure Deployment - Quick Reference

## 🚀 Quick Commands

### Deploy Everything
```bash
./scripts/deploy_full_stack.sh dev
```

### Deploy Infrastructure Only
```bash
cd terraform/environments/dev
terraform init
terraform apply
```

### Deploy Application Only
```bash
python3 scripts/update_inventory_from_terraform.py --environment dev
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml
```

### Scale VMs
```bash
# Scale web tier to 5 instances
./scripts/scale_vmss.sh dev web 5

# Scale worker tier to 3 instances
./scripts/scale_vmss.sh dev worker 3

# Update inventory after scaling
python3 scripts/update_inventory_from_terraform.py --environment dev
```

### Get Information
```bash
# Get Load Balancer IP
cd terraform/environments/dev && terraform output lb_public_ip

# Get all IPs
./scripts/get_vmss_ips.sh dev web
./scripts/get_vmss_ips.sh dev worker

# Show Terraform outputs
cd terraform/environments/dev && terraform output
```

### Destroy Infrastructure
```bash
./scripts/destroy_infrastructure.sh dev
```

## 📋 Pre-Deployment Checklist

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Terraform installed (>= 1.5.0)
- [ ] Ansible installed (>= 2.15.0)
- [ ] SSH key generated (`~/.ssh/nautobot-azure`)
- [ ] Copied `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Updated SSH public key in `terraform.tfvars`
- [ ] Updated SSH source IP in `terraform.tfvars`
- [ ] Configured Ansible vault passwords

## 🏗️ Architecture at a Glance

```
Internet → Load Balancer → Web VMSS (2-10) ─┐
                                             ├→ PostgreSQL VM
                            Worker VMSS (2-5)─┤
                            Scheduler VM ─────┴→ Redis VM
```

## 📊 Resource Overview

| Component | Type | Count | Size (Dev) | Auto-Scale |
|-----------|------|-------|------------|------------|
| Web | VMSS | 2-10 | B2ms | Yes |
| Worker | VMSS | 2-5 | B2ms | Yes |
| Scheduler | VM | 1 | B2s | No |
| PostgreSQL | VM | 1 | D2s_v3 | No |
| Redis | VM | 1 | B2s | No |

## 🔍 Common Tasks

### Check VM Status
```bash
az vm list -g rg-nautobot-dev --output table
```

### SSH to VM
```bash
# Get IP first
./scripts/get_vmss_ips.sh dev web
# Then SSH
ssh azureuser@<IP>
```

### View Logs
```bash
# Nautobot logs
sudo tail -f /opt/nautobot/logs/nautobot.log

# Service status
sudo systemctl status nautobot nginx

# Celery worker logs
sudo journalctl -u nautobot-worker -f
```

### Test Connectivity
```bash
ansible -i inventory/vm/dev.yml all -m ping
```

### Update Inventory
```bash
python3 scripts/update_inventory_from_terraform.py --environment dev
```

## 🐛 Troubleshooting

### Can't Connect to VMs
```bash
# Check NSG rules
az network nsg rule list --resource-group rg-nautobot-dev --nsg-name nsg-app-dev --output table

# Verify SSH key
ssh -i ~/.ssh/nautobot-azure azureuser@<IP> -v
```

### Load Balancer Not Working
```bash
# Check backend health
az network lb show --name lb-nautobot-dev --resource-group rg-nautobot-dev

# Test backend directly
curl -k https://<BACKEND_IP>
```

### Ansible Fails
```bash
# Verbose mode
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml -vvv

# Check specific host
ansible -i inventory/vm/dev.yml dev-nautobot-web-00 -m setup
```

### PostgreSQL Connection Issues
```bash
# Test from web VM
psql -h 10.0.3.10 -U nautobot -d nautobot

# Check PostgreSQL service
ssh azureuser@10.0.3.10
sudo systemctl status postgresql
```

## 📁 File Locations

| Path | Purpose |
|------|---------|
| `terraform/environments/dev/` | Terraform configs |
| `inventory/vm/dev.yml` | Ansible inventory |
| `playbooks/deploy_vm_all.yml` | Main deployment playbook |
| `scripts/deploy_full_stack.sh` | Complete deployment |
| `scripts/update_inventory_from_terraform.py` | Inventory updater |

## 🌐 Access URLs

| Service | URL |
|---------|-----|
| Nautobot Web | `https://<LB_IP>` |
| Nautobot API | `https://<LB_IP>/api/` |
| Admin | `https://<LB_IP>/admin/` |

## 💰 Cost Estimates

| Environment | Monthly Cost (USD) |
|-------------|-------------------|
| Dev | $200-300 |
| Test | $400-600 |
| Prod | $800-1200 |

## 🔐 Security Notes

- SSH access restricted by NSG (configure in `terraform.tfvars`)
- Data tier has no public IPs
- Secrets managed via Ansible Vault
- TLS/SSL enabled on Load Balancer
- Managed Identities for Azure resource access

## 📞 Support

- Documentation: `DEPLOYMENT_GUIDE.md`
- Architecture: `ARCHITECTURE.md`
- Issues: Open GitHub issue
- Urgent: Contact DevOps team

## ⚡ Performance Tips

1. Use Premium SSDs for database
2. Enable accelerated networking on VMs
3. Place VMs in same availability zone
4. Use connection pooling (PgBouncer)
5. Monitor and right-size VMs

## 🔄 Update Process

1. Update Terraform configs
2. Run `terraform plan`
3. Apply changes: `terraform apply`
4. Update inventory: `python3 scripts/update_inventory_from_terraform.py`
5. Deploy with Ansible
6. Test: `curl -k https://<LB_IP>/api/`

## 📦 Backup & Restore

### Backup PostgreSQL
```bash
ssh azureuser@10.0.3.10
sudo su - postgres
pg_dump nautobot > /tmp/nautobot_$(date +%Y%m%d).sql
```

### Restore PostgreSQL
```bash
sudo su - postgres
psql nautobot < /tmp/nautobot_backup.sql
```

## 🎯 Next Steps After Deployment

1. Create Nautobot superuser:
   ```bash
   ssh azureuser@<WEB_VM_IP>
   sudo -u nautobot /opt/nautobot/venv/bin/nautobot-server createsuperuser
   ```

2. Configure DNS (point to Load Balancer IP)

3. Install SSL certificate (replace self-signed)

4. Configure Nautobot settings

5. Import initial data

6. Setup monitoring

7. Configure backups

---

**Last Updated**: January 2026
**Version**: 1.0
