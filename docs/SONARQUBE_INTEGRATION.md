# SonarQube Integration Guide

## Overview

This guide explains how to integrate SonarQube code quality analysis with the Nautobot Ansible deployment project.

**SonarQube Instance Details:**
- **URL:** http://172.17.152.204:9000
- **Default Login:** admin/admin
- **Version:** 10.3.0 Community Edition
- **Database:** PostgreSQL (production-ready)

---

## Table of Contents

1. [First-Time Setup](#first-time-setup)
2. [Running Analysis Locally](#running-analysis-locally)
3. [Azure Pipelines Integration](#azure-pipelines-integration)
4. [GitHub Actions Integration](#github-actions-integration)
5. [Understanding Results](#understanding-results)
6. [Quality Gates](#quality-gates)

---

## First-Time Setup

### 1. Access SonarQube UI

Navigate to: http://172.17.152.204:9000

**First Login:**
- Username: `admin`
- Password: `admin`

**⚠️ IMPORTANT:** Change the default password immediately:
1. Click on "A" (admin avatar) → My Account
2. Security → Change Password
3. Set a strong password

### 2. Create Authentication Token

For CI/CD integration, create an authentication token:

1. Log in to SonarQube
2. Click on "A" (admin avatar) → My Account
3. Security → Generate Tokens
4. Token Name: `nautobot-ansible-ci`
5. Type: `Project Analysis Token` (or Global)
6. Click **Generate**
7. **Copy the token immediately** (it won't be shown again)

Example token: `sqp_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0`

### 3. Create Project in SonarQube

**Option A: Manual Creation**
1. In SonarQube, click **Create Project**
2. Project key: `nautobot-ansible-app`
3. Display name: `Nautobot Ansible Application`
4. Click **Setup**

**Option B: Auto-creation**
The project will be created automatically on first scan.

---

## Running Analysis Locally

### Quick Start

```bash
# Run with default credentials
./scripts/run_sonarqube_scan.sh

# Or with authentication token
export SONARQUBE_TOKEN='your-token-here'
./scripts/run_sonarqube_scan.sh
```

### Manual Execution

If you prefer running sonar-scanner manually:

```bash
# Install sonar-scanner (if not already installed)
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip sonar-scanner-cli-5.0.1.3006-linux.zip
sudo mv sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner
sudo ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

# Run analysis
cd /home/ubuntu/nautobot_ansible_app
sonar-scanner \
  -Dsonar.host.url=http://172.17.152.204:9000 \
  -Dsonar.token=YOUR_TOKEN_HERE \
  -Dsonar.projectKey=nautobot-ansible-app
```

### View Results

After the scan completes:
- Visit: http://172.17.152.204:9000/dashboard?id=nautobot-ansible-app
- Review code smells, bugs, vulnerabilities, and security hotspots

---

## Azure Pipelines Integration

### 1. Add SonarQube Token to Azure DevOps

1. Go to Azure DevOps → Pipelines → Library
2. Select variable group: `nautobot-azure-secrets`
3. Add new variable:
   - Name: `SONARQUBE_TOKEN`
   - Value: `sqp_your_token_here`
   - **Check "Keep this value secret"**
4. Save

### 2. Update azure-pipelines.yml

Add this job to the **Build** stage in `azure-pipelines.yml`:

```yaml
- stage: Build
  displayName: 'Build and Test'
  jobs:
    - job: Validate
      # ... existing validation steps ...

    # ADD THIS NEW JOB
    - job: CodeQuality
      displayName: 'SonarQube Code Quality Analysis'
      dependsOn: Validate
      steps:
        - bash: |
            set -e
            echo "Installing SonarQube Scanner..."
            
            SCANNER_VERSION="5.0.1.3006"
            cd /tmp
            wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
            unzip -q "sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
            export PATH="/tmp/sonar-scanner-${SCANNER_VERSION}-linux/bin:$PATH"
            
            echo "Running SonarQube analysis..."
            cd $(Build.SourcesDirectory)
            
            sonar-scanner \
              -Dsonar.host.url=http://172.17.152.204:9000 \
              -Dsonar.token=$(SONARQUBE_TOKEN) \
              -Dsonar.projectKey=nautobot-ansible-app \
              -Dsonar.projectName="Nautobot Ansible Application" \
              -Dsonar.projectVersion=$(Build.BuildNumber) \
              -Dsonar.sources=playbooks,roles,group_vars,host_vars,scripts \
              -Dsonar.exclusions="**/*.pyc,**/__pycache__/**,**/node_modules/**,**/.terraform/**,**/venv/**" \
              -Dsonar.python.version=3.11 \
              -Dsonar.working.directory=$(Build.SourcesDirectory)/.scannerwork
            
            echo "SonarQube analysis complete!"
          displayName: 'Run SonarQube Analysis'
          env:
            SONARQUBE_TOKEN: $(SONARQUBE_TOKEN)
          continueOnError: true  # Don't fail pipeline if quality gate fails initially

    - job: Package
      # ... existing packaging steps ...
      dependsOn: 
        - Validate
        - CodeQuality
```

### 3. Enable Quality Gate (Optional)

To **fail the pipeline** if code quality doesn't meet standards:

```yaml
- bash: |
    # Wait for quality gate result
    sleep 10
    
    QUALITY_GATE=$(curl -s -u "$(SONARQUBE_TOKEN):" \
      "http://172.17.152.204:9000/api/qualitygates/project_status?projectKey=nautobot-ansible-app" \
      | jq -r '.projectStatus.status')
    
    echo "Quality Gate Status: $QUALITY_GATE"
    
    if [ "$QUALITY_GATE" != "OK" ]; then
      echo "Quality gate failed!"
      exit 1
    fi
  displayName: 'Check Quality Gate'
  env:
    SONARQUBE_TOKEN: $(SONARQUBE_TOKEN)
```

---

## GitHub Actions Integration

If you decide to use GitHub Actions instead of Azure Pipelines:

Create `.github/workflows/sonarqube.yml`:

```yaml
name: SonarQube Analysis

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

jobs:
  sonarqube:
    name: SonarQube Code Quality
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for better analysis
      
      - name: SonarQube Scan
        uses: sonarsource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONARQUBE_TOKEN }}
          SONAR_HOST_URL: http://172.17.152.204:9000
        with:
          args: >
            -Dsonar.projectKey=nautobot-ansible-app
            -Dsonar.projectName='Nautobot Ansible Application'
            -Dsonar.python.version=3.11
      
      - name: SonarQube Quality Gate
        uses: sonarsource/sonarqube-quality-gate-action@master
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONARQUBE_TOKEN }}
          SONAR_HOST_URL: http://172.17.152.204:9000
```

Don't forget to add `SONARQUBE_TOKEN` to GitHub Secrets:
- Go to: Repository → Settings → Secrets and variables → Actions
- New repository secret: `SONARQUBE_TOKEN`

---

## Understanding Results

### Metrics Explained

1. **Bugs** 🐛
   - Code that is demonstrably wrong or highly likely to yield unexpected behavior
   - **Target:** 0 bugs

2. **Code Smells** 👃
   - Maintainability issues that make code harder to understand and maintain
   - **Target:** < 5% debt ratio

3. **Vulnerabilities** 🔒
   - Security-related issues that could be exploited
   - **Target:** 0 vulnerabilities

4. **Security Hotspots** 🔥
   - Security-sensitive code that needs manual review
   - **Target:** Review all hotspots

5. **Coverage** 📊
   - Percentage of code covered by tests
   - **Target:** > 80% (when tests are added)

6. **Duplications** 📋
   - Percentage of duplicated code blocks
   - **Target:** < 3%

### Issue Severities

- **Blocker:** Must be fixed immediately
- **Critical:** Should be fixed ASAP
- **Major:** Should be addressed
- **Minor:** Can be addressed over time
- **Info:** For information only

---

## Quality Gates

### Default Quality Gate

SonarQube's default quality gate requires:
- 0 new bugs
- 0 new vulnerabilities
- 0 new security hotspots
- New code coverage > 80%
- New code duplications < 3%
- Technical debt ratio < 5%

### Custom Quality Gate for Ansible

Create a custom quality gate specifically for Ansible projects:

1. In SonarQube: Administration → Quality Gates
2. Click **Create**
3. Name: `Ansible Quality Gate`
4. Add conditions:
   ```
   - Reliability Rating on New Code ≤ A
   - Security Rating on New Code ≤ A
   - Maintainability Rating on New Code ≤ A
   - Coverage on New Code ≥ 0% (no tests yet)
   - Duplicated Lines on New Code ≤ 3%
   ```
5. Set as default for your project

---

## Best Practices

### 1. Regular Scans

Run SonarQube analysis:
- **On every commit** (via CI/CD)
- **Before merging PRs**
- **On scheduled intervals** (daily/weekly)

### 2. Address Issues Early

- Fix **Blocker** and **Critical** issues immediately
- Address **Major** issues before releasing
- Plan time to reduce **Minor** issues and code smells

### 3. Monitor Trends

- Check the **Activity** tab for historical trends
- Monitor **Technical Debt** over time
- Set goals for improvement

### 4. Use Branch Analysis (Requires Developer Edition)

For PR-specific analysis, consider:
- Branch analysis shows issues introduced in PR
- Helps prevent new issues from being merged
- Community Edition: Only main branch analysis

### 5. Integrate with Development Workflow

```bash
# Before committing
./scripts/run_sonarqube_scan.sh

# Review results
firefox http://172.17.152.204:9000/dashboard?id=nautobot-ansible-app

# Fix issues, then commit
git add .
git commit -m "fix: address sonarqube issues"
```

---

## Troubleshooting

### Issue: SonarQube server not accessible

```bash
# Check if SonarQube is running
ssh ubuntu@172.17.152.109 "kubectl get pods -n sonarqube"

# Check service
ssh ubuntu@172.17.152.109 "kubectl get svc -n sonarqube"

# View logs
ssh ubuntu@172.17.152.109 "kubectl logs -n sonarqube -l app=sonarqube --tail=50"
```

### Issue: Authentication failed

```bash
# Test with curl
curl -u admin:admin http://172.17.152.204:9000/api/system/status

# Or with token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://172.17.152.204:9000/api/system/status
```

### Issue: Project not found

The project is auto-created on first scan. If issues persist:
1. Manually create project in SonarQube UI
2. Ensure project key matches: `nautobot-ansible-app`

### Issue: Scanner fails to download

```bash
# Pre-download scanner
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
sudo unzip sonar-scanner-cli-5.0.1.3006-linux.zip
sudo ln -s /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/
```

---

## Configuration Files Reference

### sonar-project.properties

Located at project root, contains:
- Project identification
- Source directories
- Exclusions
- Language-specific settings

### .sonarqube/ (Auto-generated)

Contains scanner cache and temporary files. Add to `.gitignore`:

```bash
echo ".scannerwork/" >> .gitignore
echo ".sonarqube/" >> .gitignore
```

---

## Advanced Features

### 1. Custom Rules

Add project-specific rules:
1. Administration → Rules
2. Create → Custom Rule
3. Define pattern and severity

### 2. Issue Tracking Integration

Link to Jira/Azure DevOps:
1. Administration → Configuration → ALM Integrations
2. Configure your ALM tool
3. Link project to board

### 3. Webhooks

Trigger actions after analysis:
1. Administration → Configuration → Webhooks
2. Create webhook
3. URL: Your endpoint (e.g., Slack notification)

### 4. PDF Reports (Requires Enterprise Edition)

Generate executive reports showing:
- Quality trends
- Issue breakdown
- Technical debt metrics

---

## Quick Reference

```bash
# Run local scan
./scripts/run_sonarqube_scan.sh

# View results
http://172.17.152.204:9000/dashboard?id=nautobot-ansible-app

# Check quality gate status
curl -u admin:admin http://172.17.152.204:9000/api/qualitygates/project_status?projectKey=nautobot-ansible-app

# Restart SonarQube (if needed)
ssh ubuntu@172.17.152.109 "kubectl rollout restart deployment/sonarqube -n sonarqube"
```

---

## Additional Resources

- **SonarQube Documentation:** https://docs.sonarqube.org/latest/
- **Ansible Best Practices:** https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
- **Python Analysis:** https://docs.sonarqube.org/latest/analyzing-source-code/languages/python/
- **Quality Gates:** https://docs.sonarqube.org/latest/user-guide/quality-gates/

---

## Support

For issues or questions:
1. Check SonarQube logs: `kubectl logs -n sonarqube -l app=sonarqube`
2. Review scanner output in `.scannerwork/report-task.txt`
3. Consult SonarQube Community Forum: https://community.sonarsource.com/
