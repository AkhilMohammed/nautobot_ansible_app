# 💰 Azure Cost Analysis - 7 Day Trial

## Azure Free Account

✅ **Yes, Azure gives $200 USD credit for 30 days** when you sign up for a free account.

## 7-Day Cost Breakdown

### Development Environment (Recommended for Testing)

#### Daily Costs
```
Component                           Daily Cost    7-Day Cost
─────────────────────────────────────────────────────────────
Azure PostgreSQL (B_Standard_B1ms)  $0.83        $5.81
  - Burstable tier, 2 vCores
  - 32GB storage
  
Azure Redis (Basic C0)              $0.53        $3.71
  - 250MB cache
  - No persistence
  
Web VM (1x Standard_B2s)            $1.50        $10.50
  - 2 vCPUs, 4GB RAM
  
Worker VM (1x Standard_B2s)         $1.50        $10.50
  - 2 vCPUs, 4GB RAM
  
Scheduler VM (1x Standard_B1s)      $0.67        $4.69
  - 1 vCPU, 1GB RAM
  
Load Balancer (Basic)               $0.17        $1.19
  
Storage Account                     $0.17        $1.19
  - LRS replication
  
Virtual Network                     FREE         FREE
Network Security Groups             FREE         FREE
Public IP                           $0.10        $0.70
─────────────────────────────────────────────────────────────
TOTAL PER DAY:                      $5.47
TOTAL FOR 7 DAYS:                              $38.29
─────────────────────────────────────────────────────────────
```

### ✅ **7-Day Development Cost: ~$38-40 USD**

### Test Environment (If you want to test)

```
Component                           Daily Cost    7-Day Cost
─────────────────────────────────────────────────────────────
PostgreSQL (GP_Standard_D2s_v3)     $4.80        $33.60
Redis (Standard C1)                 $2.17        $15.19
Web VMs (2x Standard_D2s_v3)        $8.00        $56.00
Worker VMs (2x Standard_D2s_v3)     $8.00        $56.00
Scheduler VM (1x Standard_B2s)      $1.50        $10.50
Load Balancer (Standard)            $0.83        $5.81
Storage + Network                   $0.30        $2.10
─────────────────────────────────────────────────────────────
TOTAL FOR 7 DAYS:                              $179.20
─────────────────────────────────────────────────────────────
```

### Production Environment (For reference only)

```
Component                           Daily Cost    7-Day Cost
─────────────────────────────────────────────────────────────
PostgreSQL (MO_Standard_E4s_v3 HA)  $15.00       $105.00
Redis (Premium P1)                  $8.37        $58.59
Web VMs (3x Standard_D4s_v3)        $18.00       $126.00
Worker VMs (3x Standard_D4s_v3)     $18.00       $126.00
Scheduler VMs (2x Standard_D2s_v3)  $8.00        $56.00
Load Balancer + Storage             $1.50        $10.50
─────────────────────────────────────────────────────────────
TOTAL FOR 7 DAYS:                              $482.09
─────────────────────────────────────────────────────────────
```

## 💡 Recommendations for Your 7-Day Trial

### ✅ Option 1: Development Environment (RECOMMENDED)
**Cost: ~$40 USD for 7 days**
- ✅ Fits easily within $200 free credit
- ✅ Leaves $160 for additional testing/mistakes
- ✅ Fully functional for testing all features
- ✅ Can test deployment, scaling, failover

**Use this command:**
```bash
./scripts/deploy_complete.sh dev deploy
```

### ⚠️ Option 2: Test Environment
**Cost: ~$180 USD for 7 days**
- ⚠️ Uses almost all $200 credit
- ✅ Better performance
- ✅ Tests HA features
- ⚠️ Little room for error/redeployment

### ❌ Option 3: Production Environment
**Cost: ~$480 USD for 7 days**
- ❌ EXCEEDS free credit
- ❌ You'll be charged ~$280 USD
- ❌ Not recommended for testing

## 🎯 Recommended Testing Strategy

### Days 1-5: Development Environment ($28)
```bash
# Deploy dev environment
./scripts/deploy_complete.sh dev deploy

# Test all features:
- Deploy web/worker/scheduler
- Test PostgreSQL connection
- Test Redis caching
- Test load balancer
- Scale web servers (1 → 2)
- Test failover
- Test Ansible updates
```

### Days 6-7: Test Environment ($51)
```bash
# Destroy dev
./scripts/deploy_complete.sh dev destroy

# Deploy test environment
./scripts/deploy_complete.sh test deploy

# Test production-like setup:
- Multiple web servers
- Performance testing
- Load testing
```

**Total Cost: ~$79 USD**
**Remaining Credit: $121 USD**

## 💸 Cost Optimization Tips

### 1. Stop VMs When Not Testing
```bash
# Stop all VMs (saves ~50% of VM costs)
az vm deallocate --resource-group dev-nautobot-rg --name dev-nautobot-web-vm-1
az vm deallocate --resource-group dev-nautobot-rg --name dev-nautobot-worker-vm-1
az vm deallocate --resource-group dev-nautobot-rg --name dev-nautobot-scheduler-vm-1

# Note: PostgreSQL and Redis continue to charge even when stopped
```

### 2. Use Smaller PostgreSQL SKU for Testing
Edit `terraform/environments/dev.tfvars`:
```hcl
# Change from B1ms to B1s (saves ~40%)
postgresql_sku = "B_Standard_B1s"  # $0.50/day instead of $0.83/day
```

### 3. Destroy Resources Daily if Not Testing
```bash
# Destroy at end of day
./scripts/deploy_complete.sh dev destroy

# Redeploy next morning (takes 15-20 min)
./scripts/deploy_complete.sh dev deploy
```

### 4. Skip Redis Initially
If you just want to test PostgreSQL and application deployment:
- Comment out Redis module in `terraform/main.tf`
- Saves $3.71 for 7 days

## 📊 Detailed Cost Calculator

### Minimal Development (Ultra-cheap for testing)

```hcl
# terraform/environments/dev.tfvars
postgresql_sku = "B_Standard_B1s"    # $0.50/day
redis_sku = "Basic"                  # $0.53/day
redis_capacity = 0                   

web_vm_count = 1
web_vm_size = "Standard_B1s"         # $0.67/day
worker_vm_count = 1
worker_vm_size = "Standard_B1s"      # $0.67/day
scheduler_vm_count = 1
scheduler_vm_size = "Standard_B1s"   # $0.67/day
```

**Ultra-minimal Cost:**
- Daily: $3.38
- 7 Days: **$23.66**
- Remaining: $176.34

## 🚀 Quick Start for Your Trial

### Step 1: Create Azure Free Account
```bash
# Go to: https://azure.microsoft.com/free/
# Sign up with credit card (won't be charged during trial)
# Get $200 credit for 30 days
```

### Step 2: Deploy Development Environment
```bash
cd /home/ubuntu/ansible/nautobot_ansible_app

# Set up credentials
cp .env.example .env
nano .env  # Add Azure credentials

# Deploy (this will cost ~$40 for 7 days)
./scripts/deploy_complete.sh dev deploy
```

### Step 3: Monitor Costs
```bash
# Check current spending
az consumption usage list \
  --start-date 2026-01-27 \
  --end-date 2026-02-03 \
  --query '[].{Cost:pretaxCost,Service:instanceName}' \
  --output table

# Set up cost alert
az consumption budget create \
  --budget-name "7day-trial-budget" \
  --amount 50 \
  --time-grain Monthly \
  --start-date 2026-01-27 \
  --end-date 2026-02-03
```

### Step 4: Clean Up When Done
```bash
# IMPORTANT: Destroy everything to stop charges
./scripts/deploy_complete.sh dev destroy

# Verify all resources deleted
az resource list --resource-group dev-nautobot-rg
```

## ✅ Final Answer

### For 7-Day Testing:

| Environment | 7-Day Cost | Fits in $200? | Recommended? |
|------------|-----------|---------------|--------------|
| **Dev (Minimal)** | **$24** | ✅ Yes (88% remaining) | ✅ **Best for testing** |
| **Dev (Standard)** | **$40** | ✅ Yes (80% remaining) | ✅ **Recommended** |
| Dev + Test | $79 | ✅ Yes (60% remaining) | ⚠️ If you want both |
| Test Only | $180 | ✅ Yes (10% remaining) | ⚠️ Risky, no buffer |
| Production | $480 | ❌ NO (-$280) | ❌ Don't do this |

### 🎯 My Recommendation:

**Use Development environment: $40 for 7 days**

You'll have:
- ✅ $160 remaining credit
- ✅ Fully functional Nautobot deployment
- ✅ All features working (PostgreSQL, Redis, Load Balancer)
- ✅ Room for mistakes and redeployments
- ✅ Can test scaling, updates, rollbacks

### 📝 Cost Tracking Commands

```bash
# Check your Azure credit remaining
az account show --query '{Name:name, Id:id, State:state}'

# Get cost estimate before deployment
az deployment group what-if \
  --resource-group dev-nautobot-rg \
  --template-file terraform/main.tf

# View current month spending
az consumption usage list --query '[].pretaxCost' | jq 'add'
```

## ⚠️ Important Notes

1. **PostgreSQL and Redis charge even when VMs are stopped**
   - Only way to stop charges is to delete them

2. **Always destroy resources when done testing**
   ```bash
   ./scripts/deploy_complete.sh dev destroy
   ```

3. **Set up billing alerts**
   - Go to Azure Portal → Cost Management → Budgets
   - Set alert at $50, $100, $150

4. **Network egress costs**
   - Downloading data from Azure costs extra
   - First 100GB/month is free
   - Should be minimal for testing

## 🎊 Summary

**YES, $200 is MORE than enough!**

- Development environment: **$40 for 7 days**
- You'll use only **20% of your $200 credit**
- **$160 remaining** for additional testing or mistakes

Go ahead and deploy! You're well within budget. 🚀
