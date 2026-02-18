#!/bin/bash
# Script to run SonarQube analysis locally or in CI/CD

set -e

# Default values
SONARQUBE_URL="${SONARQUBE_URL:-http://172.17.152.204:9000}"
SONARQUBE_TOKEN="${SONARQUBE_TOKEN:-}"
PROJECT_KEY="nautobot-ansible-app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}SonarQube Code Quality Analysis${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check if SonarQube is accessible
echo -e "${YELLOW}Checking SonarQube server...${NC}"
if curl -s -f "${SONARQUBE_URL}/api/system/status" > /dev/null; then
    echo -e "${GREEN}✓ SonarQube server is accessible${NC}"
else
    echo -e "${RED}✗ Cannot reach SonarQube at ${SONARQUBE_URL}${NC}"
    echo -e "${YELLOW}Make sure SonarQube is running and accessible${NC}"
    exit 1
fi

# Check if sonar-scanner is installed
if ! command -v sonar-scanner &> /dev/null; then
    echo -e "${YELLOW}sonar-scanner not found. Installing...${NC}"
    
    # Download and install sonar-scanner
    SCANNER_VERSION="5.0.1.3006"
    SCANNER_DIR="sonar-scanner-${SCANNER_VERSION}-linux"
    
    if [ ! -d "/tmp/${SCANNER_DIR}" ]; then
        cd /tmp
        wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
        unzip -q "sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
        rm "sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
    fi
    
    export PATH="/tmp/${SCANNER_DIR}/bin:$PATH"
    echo -e "${GREEN}✓ sonar-scanner installed${NC}"
fi

# Check if token is provided
if [ -z "$SONARQUBE_TOKEN" ]; then
    echo -e "${YELLOW}Warning: No SONARQUBE_TOKEN provided${NC}"
    echo -e "${YELLOW}Running with default admin credentials (admin/admin)${NC}"
    echo -e "${YELLOW}To use token authentication:${NC}"
    echo -e "${YELLOW}  export SONARQUBE_TOKEN='your-token-here'${NC}"
    echo ""
    AUTH_PARAMS="-Dsonar.login=admin -Dsonar.password=admin"
else
    AUTH_PARAMS="-Dsonar.token=${SONARQUBE_TOKEN}"
fi

# Run SonarQube scanner
echo -e "${YELLOW}Running SonarQube analysis...${NC}"
echo ""

cd "$(dirname "$0")/.."

sonar-scanner \
    -Dsonar.host.url="${SONARQUBE_URL}" \
    ${AUTH_PARAMS} \
    -Dsonar.projectKey="${PROJECT_KEY}" \
    -Dsonar.working.directory=.scannerwork

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Analysis Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "View results at: ${GREEN}${SONARQUBE_URL}/dashboard?id=${PROJECT_KEY}${NC}"
echo ""
