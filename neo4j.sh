#!/bin/bash

# Stop script on error
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=================================================="
echo "STARTING NEO4J COMMUNITY & APOC INSTALLATION"
echo "=================================================="

# 1. Prerequisites & Java 17 Installation (Required for Neo4j 5.x)
echo "[Step 1/7] Updating system and installing dependencies (Java 17, curl, gpg)..."
apt-get update -q
apt-get install -y curl wget gnupg openjdk-17-jdk software-properties-common

# 2. Add Neo4j Repository (Modern gpg keyring method)
echo "[Step 2/7] Adding Neo4j official GPG key and repository..."
# Remove old key if exists to avoid conflict
if [ -f /usr/share/keyrings/neo4j.gpg ]; then
    rm /usr/share/keyrings/neo4j.gpg
fi

# Download key and dearmor it to the keyring location
curl -fsSL https://debian.neo4j.com/neotechnology.gpg.key | gpg --dearmor -o /usr/share/keyrings/neo4j.gpg

# Add the repository to sources list
echo "deb [signed-by=/usr/share/keyrings/neo4j.gpg] https://debian.neo4j.com stable 5" | tee /etc/apt/sources.list.d/neo4j.list > /dev/null

# 3. Install Neo4j Community Edition
echo "[Step 3/7] Installing Neo4j Community Edition..."
apt-get update -q

# Prevent service auto-start during install to avoid systemd errors
printf '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

apt-get install -y neo4j

rm /usr/sbin/policy-rc.d

# Enable and start service
if systemctl --version &>/dev/null && [ -d /run/systemd/system ]; then
    systemctl enable neo4j
    systemctl start neo4j
else
    echo "Systemd not available. Starting Neo4j manually..."
    mkdir -p /var/run/neo4j
    chown neo4j:neo4j /var/run/neo4j
    chown -R neo4j:neo4j /var/lib/neo4j /var/log/neo4j
    su - neo4j -c "neo4j start"
fi

# 4. Download APOC Plugin
# We need to find the Neo4j version to download the matching APOC jar
NEO4J_VERSION=$(neo4j --version | cut -d' ' -f2 | cut -d'+' -f1)
echo "[Step 4/7] Detected Neo4j Version: $NEO4J_VERSION. Downloading matching APOC JAR..."

PLUGINS_DIR="/var/lib/neo4j/plugins"
# Construct URL for APOC Core (Compatible with Neo4j 5)
APOC_URL="https://github.com/neo4j/apoc/releases/download/${NEO4J_VERSION}/apoc-${NEO4J_VERSION}-core.jar"

echo "Downloading from: $APOC_URL"
wget -q --show-progress -O "${PLUGINS_DIR}/apoc.jar" "$APOC_URL"

# Set permissions for the plugin
chown neo4j:neo4j "${PLUGINS_DIR}/apoc.jar"
chmod 755 "${PLUGINS_DIR}/apoc.jar"

# 5. Configure Neo4j to allow APOC
echo "[Step 5/7] Configuring neo4j.conf to enable APOC procedures..."
CONFIG_FILE="/etc/neo4j/neo4j.conf"

# Add or update the configuration to allow unrestricted APOC access
if grep -q "dbms.security.procedures.unrestricted" "$CONFIG_FILE"; then
    sed -i 's/^#*dbms.security.procedures.unrestricted=.*/dbms.security.procedures.unrestricted=apoc.*/' "$CONFIG_FILE"
else
    echo "dbms.security.procedures.unrestricted=apoc.*" | tee -a "$CONFIG_FILE"
fi

# 6. Restart Neo4j
echo "[Step 6/7] Restarting Neo4j service to apply changes..."
if systemctl --version &>/dev/null && [ -d /run/systemd/system ]; then
    systemctl restart neo4j
else
    echo "Systemd not available. Restarting Neo4j manually..."
    su - neo4j -c "neo4j restart"
fi

# 7. Set Password (NEW STEP)
echo "[Step 7/7] Waiting for Neo4j to initialize to set the password..."

# Retry loop to wait for Neo4j to become ready before setting password
MAX_RETRIES=12
COUNT=0
PASSWORD_SET=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    # Try to change password using cypher-shell
    # "CHANGE NOT REQUIRED" prevents the user from being asked to change it again upon login
    echo "ALTER USER neo4j SET PASSWORD '12345678' CHANGE NOT REQUIRED;" | cypher-shell -u neo4j -p neo4j > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Password for user 'neo4j' has been set to '12345678'."
        PASSWORD_SET=true
        break
    fi
    
    echo "Waiting for Neo4j to be ready... (Attempt $((COUNT+1))/$MAX_RETRIES)"
    sleep 10
    COUNT=$((COUNT+1))
done

if [ "$PASSWORD_SET" = false ]; then
    echo "WARNING: Timed out waiting for Neo4j. Password might not have been set."
    echo "You can manually set it later using: cypher-shell -u neo4j -p neo4j"
fi


#ssh root@0d0068e8e59a "echo \"ALTER CURRENT USER SET PASSWORD FROM 'neo4j' TO '12345678';\" | cypher-shell -u neo4j -p neo4j -d system"
echo "=================================================="
echo "INSTALLATION COMPLETE!"
echo "=================================================="
echo "Neo4j is running on: http://localhost:7474"
echo "Username: neo4j"
echo "Password: 12345678"
echo "=================================================="