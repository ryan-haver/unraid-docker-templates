#!/bin/bash

# Deployment script for Samba AD + LAM to Unraid
# Usage: ./deploy.sh [unraid-ip]

set -e

# Configuration
UNRAID_IP="${1:-192.168.1.110}"
TEMPLATE_NAME="samba-ad-lam-combined.xml"
REMOTE_PATH="//tower/flash/config/plugins/dockerMan/templates-user/"
LOCAL_TEMPLATE="./${TEMPLATE_NAME}"

echo "============================================"
echo "Deploying to Unraid"
echo "============================================"
echo "Unraid IP: ${UNRAID_IP}"
echo "Template: ${TEMPLATE_NAME}"
echo "============================================"
echo ""

# Check if template exists
if [ ! -f "${LOCAL_TEMPLATE}" ]; then
    echo "ERROR: Template file not found: ${LOCAL_TEMPLATE}"
    exit 1
fi

# Test connectivity
echo "Testing connectivity to Unraid..."
if ! ping -c 1 -W 2 "${UNRAID_IP}" > /dev/null 2>&1; then
    echo "WARNING: Cannot ping Unraid at ${UNRAID_IP}"
    echo "Continuing anyway..."
fi

# Copy template to Unraid
echo ""
echo "Copying template to Unraid..."
if command -v smbclient &> /dev/null; then
    # Use smbclient if available
    echo "Using SMB to copy template..."
    # Note: Adjust this for your Unraid credentials
    # smbclient "${REMOTE_PATH}" -U username -c "put ${LOCAL_TEMPLATE}"
    echo "Please manually copy ${LOCAL_TEMPLATE} to ${REMOTE_PATH} on Unraid"
else
    echo "Please manually copy ${LOCAL_TEMPLATE} to:"
    echo "  ${REMOTE_PATH}"
    echo ""
    echo "On Windows, use:"
    echo "  Copy-Item \"${LOCAL_TEMPLATE}\" \"\\\\${UNRAID_IP}\\flash\\config\\plugins\\dockerMan\\templates-user\\${TEMPLATE_NAME}\" -Force"
    echo ""
    echo "On Linux/Mac, use:"
    echo "  scp \"${LOCAL_TEMPLATE}\" root@${UNRAID_IP}:/boot/config/plugins/dockerMan/templates-user/${TEMPLATE_NAME}"
fi

echo ""
echo "============================================"
echo "Deployment Instructions"
echo "============================================"
echo ""
echo "1. Copy template to Unraid (see above)"
echo ""
echo "2. In Unraid WebUI:"
echo "   - Go to Docker tab"
echo "   - Click 'Add Container'"
echo "   - Select template: ${TEMPLATE_NAME}"
echo "   - Configure required variables:"
echo "     • Container IP Address (e.g., 192.168.1.200)"
echo "     • Host IP Address (same as Container IP)"
echo "     • Domain Name (e.g., example.com)"
echo "     • Domain Admin Password (strong password)"
echo "     • LAM Master Password (for web interface)"
echo "     • DNS Forwarder (e.g., 192.168.1.1)"
echo "   - Click 'Apply'"
echo ""
echo "3. Wait 2-3 minutes for provisioning"
echo ""
echo "4. Access LAM web interface:"
echo "   http://[CONTAINER-IP]:8080"
echo ""
echo "5. Verify Samba AD DC:"
echo "   docker exec samba-ad-lam domain info"
echo ""
echo "============================================"
