#!/bin/bash

# Variables
SSHD_CONFIG="/etc/ssh/sshd_config"
DUO_CONFIG_LINES=(
    " "
    "#Duo 2FA login"
    "ForceCommand /usr/sbin/login_duo"
    "PermitTunnel no"
    "AllowTcpForwarding no"
    " "
)

# Backup sshd_config before modifying
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"

# Create a temporary file to hold the new sshd_config
TEMP_FILE=$(mktemp)

# Loop through the configuration lines and insert them at the top of the temp file
for line in "${DUO_CONFIG_LINES[@]}"; do
    # Check if the line exists either as-is or commented out (with a leading #)
    if ! grep -Eq "^[^#]*$line" "$SSHD_CONFIG"; then
        echo "$line" >> "$TEMP_FILE"
        echo "Added: $line"
    else
        echo "Already exists (uncommented or commented): $line"
    fi
done

# Append the original sshd_config to the temp file (new lines will be inserted at the top)
cat "$SSHD_CONFIG" >> "$TEMP_FILE"

# Overwrite sshd_config with the modified file
mv "$TEMP_FILE" "$SSHD_CONFIG"

exit 0
