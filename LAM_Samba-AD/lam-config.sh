#!/bin/bash

# LAM Configuration Management Script
# Provides helper functions for managing LAM after deployment

DOMAIN_DC=${DOMAIN_DC:-"dc=example,dc=com"}
LAM_CONFIG_DIR=${LAM_CONFIG_DIR:-"/var/lib/lam/config"}

show_usage() {
    echo "LAM Configuration Helper"
    echo ""
    echo "Usage: lam-config.sh [command]"
    echo ""
    echo "Commands:"
    echo "  show-config     Display current LAM configuration"
    echo "  reset-password  Reset LAM master password"
    echo "  test-ldap       Test LDAP connection"
    echo "  show-url        Display LAM web interface URL"
    echo ""
}

show_config() {
    echo "Current LAM Configuration:"
    echo "=========================="
    if [ -f "${LAM_CONFIG_DIR}/lam.conf" ]; then
        grep -E "^(ServerURL|Admins|treesuffix):" "${LAM_CONFIG_DIR}/lam.conf" | sed 's/^/  /'
    else
        echo "  Configuration file not found!"
    fi
    echo ""
}

reset_password() {
    echo -n "Enter new LAM master password: "
    read -s NEW_PASS
    echo ""
    echo -n "Confirm password: "
    read -s CONFIRM_PASS
    echo ""
    
    if [ "${NEW_PASS}" != "${CONFIRM_PASS}" ]; then
        echo "Passwords do not match!"
        exit 1
    fi
    
    # Update password in config
    PASS_HASH=$(echo -n "${NEW_PASS}" | sha256sum | cut -d' ' -f1 | base64)
    sed -i "s/^Passwd: .*/Passwd: {SSHA}${PASS_HASH}/" "${LAM_CONFIG_DIR}/lam.conf"
    
    echo "Password updated successfully!"
}

test_ldap() {
    echo "Testing LDAP connection to Samba AD..."
    echo ""
    
    ldapsearch -x -H ldaps://127.0.0.1:636 -b "${DOMAIN_DC}" -LLL "(objectClass=domain)" dn
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ LDAP connection successful!"
    else
        echo ""
        echo "✗ LDAP connection failed!"
        echo "Check Samba AD DC status: domain info"
    fi
}

show_url() {
    if [ -n "${HOSTIP}" ]; then
        echo "LAM Web Interface:"
        echo "  URL: http://${HOSTIP}:8080"
        echo ""
        echo "Default credentials:"
        echo "  Username: admin"
        echo "  Password: (set via LAM_PASSWORD environment variable)"
    else
        echo "Container IP not configured. Set HOSTIP environment variable."
    fi
}

case "${1}" in
    show-config)
        show_config
        ;;
    reset-password)
        reset_password
        ;;
    test-ldap)
        test_ldap
        ;;
    show-url)
        show_url
        ;;
    *)
        show_usage
        ;;
esac
