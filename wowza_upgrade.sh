#!/bin/bash

# ==== Error Handler for better security ====
set -euo pipefail

# ==== Check for Root User ====
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# ==== Configuration ====
HOSTNAME=$(hostname)
WOWZA_DIR="/usr/local"
ENGINE_DIR="$WOWZA_DIR/WowzaStreamingEngine"
LOG_DIR="/var/log/wowza-upgrades"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/upgrade-$TIMESTAMP.log"
BACKUP_DIR="/byu/adm.cjr58/Wowza_Backups/$HOSTNAME-wowza-$TIMESTAMP"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========== WOWZA UPGRADE STARTED [$TIMESTAMP] =========="

# ==== Get Inputs ====
read -rp "Enter current Wowza version (e.g., 4.8.22+2): " CURRENT_VERSION
read -rp "Enter new Wowza version (e.g., 4.9.5+3): " NEW_VERSION

PATCH_FOLDER="WowzaStreamingEngine-Update-$NEW_VERSION"
PATCH_PATH="$ENGINE_DIR/updates/$PATCH_FOLDER"
PATCH_LINUX="$PATCH_PATH/linux"
OLD_ENGINE_PATH="$WOWZA_DIR/WowzaStreamingEngine-$CURRENT_VERSION"
NEW_ENGINE_PATH="$WOWZA_DIR/WowzaStreamingEngine-$NEW_VERSION"
UPDATE_RELEASE_FILE="$ENGINE_DIR/updates/$PATCH_FOLDER/jre/linux-x64/release"

# ==== Stop Services ====
echo "Stopping Wowza services..."
systemctl stop WowzaStreamingEngine || true
systemctl stop WowzaStreamingEngineManager || true

# ==== Backup Configuration ====
echo "Backing up Wowza configuration to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$ENGINE_DIR/conf" "$BACKUP_DIR/conf"
cp -a "$ENGINE_DIR/bin" "$BACKUP_DIR/bin"
cp -a "$ENGINE_DIR/manager/conf" "$BACKUP_DIR/manager_conf"
cp -a "$ENGINE_DIR/manager/bin" "$BACKUP_DIR/manager_bin"
cp -a "$ENGINE_DIR/logs" "$BACKUP_DIR/logs"
cp -a "$ENGINE_DIR/jre" "$BACKUP_DIR/jre"

# ==== Unmount NFS Mounts ====
echo "Unmounting NFS mounts..."
MOUNTS_TO_UNMOUNT=(
    "$ENGINE_DIR/content/CTL"
    "$ENGINE_DIR/content/s4-ingress"
    # Add more mount paths here if needed
)
for MOUNT_PATH in "${MOUNTS_TO_UNMOUNT[@]}"; do
    if mountpoint -q "$MOUNT_PATH"; then
        umount -l "$MOUNT_PATH"
        echo "Unmounted $MOUNT_PATH"
    else
        echo "Not mounted: $MOUNT_PATH"
    fi
done

# ==== Upgrade JRE from Update Pack ====
echo "Upgrading JRE from update pack..."
if [[ -d "$PATCH_PATH/jre" ]]; then
    echo "Found JRE at the following location: $PATCH_LINUX"
    if [[ -d "$ENGINE_DIR/jre" ]]; then
        echo "Removing the JRE directory: $ENGINE_DIR/jre"
        rm -rf "$ENGINE_DIR"/jre/*
    fi
    cp -a "$PATCH_PATH"/jre/linux-x64/* "$ENGINE_DIR/jre"
    echo "JRE upgraded successfully from $PATCH_PATH/jre to $ENGINE_DIR/jre"
    echo "Checking JRE version..."

else
    echo "Warning: JRE directory not found in $PATCH_PATH"
    exit 1
fi

# ==== Check if both release files exist ====
if [[ ! -f "$ENGINE_DIR/jre/release" ]]; then
    echo "Error: Current Java release file not found at ${ENGINE_DIR}/jre/release"
    exit 1
fi

if [[ ! -f "$UPDATE_RELEASE_FILE" ]]; then
    echo "Error: Update Java release file not found at $UPDATE_RELEASE_FILE"
    exit 1
fi

# ==== Extract versions from release files ====
echo "Extracting Java versions from release files..."
CURRENT_VERSION=$(grep '^JAVA_VERSION=' "${ENGINE_DIR}/jre/release" | cut -d'"' -f2)
UPDATE_VERSION=$(grep '^JAVA_VERSION=' "$UPDATE_RELEASE_FILE" | cut -d'"' -f2)

# ==== Output comparison ====
echo "Current Java version: $CURRENT_VERSION"
echo "Update Java version:  $UPDATE_VERSION"

# ==== Validate Java Versions ====
if [[ "$CURRENT_VERSION" == "$UPDATE_VERSION" ]]; then
    echo "Java versions match. Proceeding with the upgrade."
else
    echo "Java versions do not match. Current: $CURRENT_VERSION, Update: $UPDATE_VERSION"
    echo "Please ensure you have the correct update files."
    exit 1
fi

# ==== Prepare Patch Files ====
echo "Making patch scripts executable..."
chmod +x "$PATCH_LINUX"/*.sh

# ==== Run Upgrade Script with Logging ====
echo "Running Wowza patch script from: $PATCH_LINUX"
cd "$PATCH_LINUX"

UPGRADE_LOG="$LOG_DIR/patch-script-output-$TIMESTAMP.log"
if [[ -f update.sh ]]; then
    echo "Executing update.sh..."
    # Log the output of the update script
    ./update.sh 2>&1 | tee -a "$UPGRADE_LOG"
    echo "Wowza patch script finished."
else
    echo "Error: update.sh not found in $PATCH_LINUX"
    exit 1
fi

# ==== Migrate Old Engine Directory to reflect the New Version ====
echo "Migrating old engine directory to reflect the new version..."
mv "$OLD_ENGINE_PATH" "$NEW_ENGINE_PATH"

# ==== Update Symlinks ====
echo "Updating symlinks..."
ln -sfn "$NEW_ENGINE_PATH" "$ENGINE_DIR"
ln -sfn "$NEW_ENGINE_PATH/jre" "$NEW_ENGINE_PATH/java"

# ==== Validation ====
echo "Validating upgrade..."
if [[ -x "$ENGINE_DIR/bin/startup.sh" ]]; then
    echo "Validation passed: startup.sh is present and executable."
else
    echo "Validation failed: startup.sh missing or not executable."
    exit 1
fi

# Directories to fix ownership
DIRECTORIES=(
  "/usr/local/WowzaStreamingEngine/conf"
  "/usr/local/WowzaStreamingEngine/bin"
  "/usr/local/WowzaStreamingEngine/logs"
  "/usr/local/WowzaStreamingEngine/lib"
  "/usr/local/WowzaStreamingEngine/manager"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        echo "Setting ownership on $dir"
        chown -R "wowza:wowza" "$dir"

    else
        echo "Directory not found: $dir"
    fi
done

# Source and target file paths
FIREWALL_FILE="/etc/firewalld/services/wowza.xml"
UPDATE_FILE="/byu/adm.cjr58/Wowza_Config/firewalld/wowza.xml"

# Ensure SELinux tools are available
command -v restorecon >/dev/null 2>&1 || { echo "restorecon is required but not installed."; exit 1; }

# Check if the files differ
if ! cmp -s "$UPDATE_FILE" "$FIREWALL_FILE"; then
    echo "File differs: copying $FIREWALL_FILE to $UPDATE_FILE"
    
    # Backup old file
    cp -p "$FIREWALL_FILE" "$BACKUP_DIR/wowza.xml.bak.$(date +%F-%T)"
    
    # Copy the file
    cp "$UPDATE_FILE" "$FIREWALL_FILE"

    # Restore SELinux context
    restorecon -v "$FIREWALL_FILE"

    echo "Updated and restored SELinux context for $FIREWALL_FILE"
else
    echo "No changes in $FIREWALL_FILE. Skipping."
fi

sleep 5  # Allow time for the system to stabilize and ensure all processes are finished

# ==== Reboot System ====
echo "Rebooting system for update to take effect and Automount..."
reboot
