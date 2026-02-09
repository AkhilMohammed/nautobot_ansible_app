# SSH Key Setup for CI/CD Automation

## Overview
The CI/CD pipeline uses SSH key-based authentication to deploy to all target VMs. This requires a **one-time setup** to distribute the public key.

## One-Time Setup Required

### Automated Setup (Recommended)

Run this interactive script on the runner VM (kubnernetes-wk-node2):

```bash
cd /home/ubuntu/nautobot_ansible_app
bash scripts/setup_ssh_onetime.sh
```

This script will:
1. Generate the SSH key if needed
2. Offer automated or manual deployment options
3. Verify SSH access to all VMs
4. Provide clear status for each VM

### Quick Manual Setup

If you have console/SSH access to each VM, run this **one command on each target VM**:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAy5LAcJQcXjuRadqRZU32WhEIn0CSSyoWCx8IsyLpEr ansible-ci' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
```

### Target VMs 
Run the above command on these IPs:
- `172.17.152.103` (onprem-k8s-web-01)
- `172.17.152.104` (onprem-k8s-web-02)
- `172.17.152.105` (onprem-k8s-worker-01)
- `172.17.152.106` (onprem-k8s-worker-02)
- `172.17.152. 107` (onprem-postgres-01)
- `172.17.152.108` (onprem-redis-01)
- `172.17.152.109` (onprem-k8s-master)

## Verification

Verify SSH access from the runner:

```bash
cd /home/ubuntu/nautobot_ansible_app
bash scripts/ensure_ssh_access.sh
```

You should see ✅ for all VMs.

## What Happens After Setup

Once SSH keys are deployed:

1. ✅ GitHub Actions workflow can access all VMs automatically
2. ✅ No passwords needed for deployments
3. ✅ Secure key-based authentication
4. ✅ CI/CD pipeline runs fully automated

## Troubleshooting

### SSH access still failing?

1. Check SSH key permissions on runner:
   ```bash
   ls -la ~/.ssh/ansible-ci*
   # Should show: -rw------- for private key, -rw-r--r-- for public key
   ```

2. Check authorized_keys on target VM:
   ```bash
   ssh ubuntu@172.17.152.103  # Use password if needed
   cat ~/.ssh/authorized_keys
   # Should contain the ansible-ci public key
   ```

3. Test SSH manually:
   ```bash
   ssh -i ~/.ssh/ansible-ci ubuntu@172.17.152.103
   # Should connect without password
   ```

## Security Notes

- The CI SSH key is stored in `group_vars/dev/ansible-ci` (encrypted in transit via Git)
- Only used for deployment automation
- Public key is safe to distribute
- Private key should remain on the runner only

## Need Help?

If automated deployment isn't working:
1. The workflow will show clear error messages
2. Check the "ensure_ssh_access" job logs in GitHub Actions
3. Run the manual verification script to see exactly which VMs need attention
