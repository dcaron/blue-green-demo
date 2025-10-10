#!/bin/bash
set -e

# Nexus Configuration Script for Tanzu Enterprise Java Repository Mirror
# This script configures Nexus to proxy the Tanzu Enterprise Java repository

NEXUS_URL="http://localhost:8082"
NEXUS_USER="admin"
CREDENTIALS_FILE="$(dirname "$0")/../credentials.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Nexus Tanzu Repository Setup ===${NC}\n"

# Check if credentials file exists
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo -e "${RED}Error: Credentials file not found at $CREDENTIALS_FILE${NC}"
    echo -e "${YELLOW}Please copy nexus/credentials.env.template to nexus/credentials.env and fill in your credentials${NC}"
    exit 1
fi

# Source credentials
source "$CREDENTIALS_FILE"

# Validate credentials are set
if [ -z "$TANZU_REPO_USERNAME" ] || [ -z "$TANZU_REPO_PASSWORD" ] || [ -z "$TANZU_REPO_URL" ]; then
    echo -e "${RED}Error: Required credentials not set in $CREDENTIALS_FILE${NC}"
    echo "Please ensure TANZU_REPO_USERNAME, TANZU_REPO_PASSWORD, and TANZU_REPO_URL are set"
    exit 1
fi

if [ "$TANZU_REPO_USERNAME" = "your-tanzu-username" ]; then
    echo -e "${RED}Error: Please update the credentials in $CREDENTIALS_FILE with your actual Tanzu credentials${NC}"
    exit 1
fi

# Wait for Nexus to be ready
echo "Waiting for Nexus to be ready..."
for i in {1..30}; do
    if curl -sf "$NEXUS_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}Nexus is ready!${NC}\n"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Nexus did not start in time${NC}"
        exit 1
    fi
    echo -n "."
    sleep 2
done

# Get initial admin password
echo "Retrieving Nexus admin password..."
NEXUS_ADMIN_PASSWORD=$(docker exec $(docker ps -qf "name=nexus") cat /nexus-data/admin.password 2>/dev/null || echo "")

if [ -z "$NEXUS_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Note: Initial admin password not found. Assuming Nexus is already configured.${NC}"
    read -sp "Enter Nexus admin password: " NEXUS_ADMIN_PASSWORD
    echo
fi

# Create the proxy repository
echo -e "\nCreating Tanzu Enterprise Java proxy repository..."

REPO_CONFIG=$(cat <<EOF
{
  "name": "tanzu-enterprise-maven",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "$TANZU_REPO_URL",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "authentication": {
      "type": "username",
      "username": "$TANZU_REPO_USERNAME",
      "password": "$TANZU_REPO_PASSWORD"
    }
  },
  "maven": {
    "versionPolicy": "RELEASE",
    "layoutPolicy": "STRICT"
  }
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -u "$NEXUS_USER:$NEXUS_ADMIN_PASSWORD" \
  -X POST "$NEXUS_URL/service/rest/v1/repositories/maven/proxy" \
  -H "Content-Type: application/json" \
  -d "$REPO_CONFIG")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ Tanzu Enterprise Java proxy repository created successfully${NC}"
elif [ "$HTTP_CODE" = "400" ] && echo "$BODY" | grep -q "already exists"; then
    echo -e "${YELLOW}⚠ Repository already exists${NC}"
else
    echo -e "${RED}✗ Failed to create repository (HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
    exit 1
fi

# Update maven-public group to include the new repository
echo -e "\nAdding Tanzu repository to maven-public group..."

# Get current maven-public configuration
CURRENT_CONFIG=$(curl -s -u "$NEXUS_USER:$NEXUS_ADMIN_PASSWORD" \
  "$NEXUS_URL/service/rest/v1/repositories/maven/group/maven-public")

# Check if tanzu repo is already in the group
if echo "$CURRENT_CONFIG" | grep -q "tanzu-enterprise-maven"; then
    echo -e "${YELLOW}⚠ Tanzu repository already in maven-public group${NC}"
else
    # Extract current members and add tanzu repo
    UPDATED_CONFIG=$(echo "$CURRENT_CONFIG" | jq '.group.memberNames += ["tanzu-enterprise-maven"]')

    RESPONSE=$(curl -s -w "\n%{http_code}" -u "$NEXUS_USER:$NEXUS_ADMIN_PASSWORD" \
      -X PUT "$NEXUS_URL/service/rest/v1/repositories/maven/group/maven-public" \
      -H "Content-Type: application/json" \
      -d "$UPDATED_CONFIG")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    if [ "$HTTP_CODE" = "204" ]; then
        echo -e "${GREEN}✓ maven-public group updated successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Could not update maven-public group (HTTP $HTTP_CODE)${NC}"
        echo "You may need to manually add the repository to the group via the UI"
    fi
fi

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "\nNexus is available at: ${GREEN}$NEXUS_URL${NC}"
echo -e "Default credentials: ${YELLOW}admin / $NEXUS_ADMIN_PASSWORD${NC}"
echo -e "\nTo use this repository in your Maven builds, add to your pom.xml:"
echo -e "${YELLOW}"
cat <<'EOF'

<repositories>
  <repository>
    <id>nexus</id>
    <url>http://localhost:8082/repository/maven-public/</url>
  </repository>
</repositories>

<pluginRepositories>
  <pluginRepository>
    <id>nexus</id>
    <url>http://localhost:8082/repository/maven-public/</url>
  </pluginRepository>
</pluginRepositories>
EOF
echo -e "${NC}"
echo -e "Or configure Maven settings.xml to use Nexus as a mirror (recommended)"
