# URGENT: Fix VM System Clocks

## Problem
All 8 VMs have system clocks 15-26 minutes AHEAD of real time.
This causes APT package installation failures and cascading deployment failures.

## Root Cause
Time synchronization (NTP) commands execute successfully but clocks remain wrong.
This indicates the issue is at the hypervisor/virtualization platform level.

## Required Actions

### 1. Check Hypervisor/Host Clock
```bash
# On the physical host running these VMs
date
hwclock --show
```

If the host clock is wrong, fix it there first.

### 2. Fix VM Clocks from Hypervisor
Depending on your virtualization platform:

**VMware ESXi:**
```bash
# Ensure VMware Tools time sync is enabled
vmware-toolbox-cmd timesync enable
vmware-toolbox-cmd timesync start
```

**KVM/QEMU:**
```bash
# On the host, for each VM
virsh domtime <vm-name> --now
```

**Hyper-V:**
```powershell
# Enable time synchronization
Get-VM | Enable-VMIntegrationService -Name "Time Synchronization"
```

**Azure VMs:**
```bash
# VMs sync from Azure infrastructure automatically
# If broken, recreate the VMs or contact Azure support
```

### 3. Verify Fix on Each VM
```bash
ssh ubuntu@172.17.152.102  # Repeat for all 8 VMs
date
timedatectl status | grep "System clock synchronized"
# Should show current time within 1 second of real time
```

### 4. After Clocks Are Fixed
Re-run the deployment:
```bash
# Trigger a new workflow run
git commit --allow-empty -m "Test: Clocks fixed - retry deployment"
git push origin feat/onprem-deployment
```

## Why This Matters
- ✅ APT packages will install normally
- ✅ No workarounds needed
- ✅ Deployment will be faster and more reliable
- ✅ No strange timing-related bugs

## Alternative if Clock Can't Be Fixed
See OPTION 2 and OPTION 3 in the main troubleshooting guide.
