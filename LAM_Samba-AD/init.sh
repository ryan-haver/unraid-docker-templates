#!/bin/bash

set -e

waitForNetwork() {
	echo "Waiting for network interface to be ready..."
	local hostip="${1:-NONE}"
	echo "DEBUG: Expected HOSTIP=$hostip"
	
	local max_wait=30
	local waited=0
	
	while [ $waited -lt $max_wait ]; do
		# Check if we have a non-loopback interface with an IP address (recalculate every iteration)
		local has_ip=$(ip -4 addr show 2>/dev/null | grep -v "127.0.0.1" | grep "inet " | wc -l)
		
		# If we have any IP, we're ready (HOSTIP is just a hint for the container, actual IP may differ)
		if [ $has_ip -gt 0 ]; then
			local current_ip=$(ip -4 addr show 2>/dev/null | grep -v "127.0.0.1" | grep "inet " | head -1 | awk '{print $2}' | cut -d'/' -f1)
			echo "Network interface ready: found IP $current_ip"
			if [ "$hostip" != "NONE" ] && [ "$current_ip" != "$hostip" ]; then
				echo "NOTE: Actual IP ($current_ip) differs from expected HOSTIP ($hostip) - this is normal with DHCP/MACVLAN"
			fi
			return 0
		fi
		
		if [ $waited -eq 0 ]; then
			echo "DEBUG: Waiting for network interface to appear..."
		fi
		
		sleep 1
		waited=$((waited + 1))
	done
	
	echo "WARNING: No network interface found after ${max_wait}s"
	echo "Current network status:"
	ip addr show 2>/dev/null || echo "Cannot show IP addresses"
	return 0
}

appSetup () {

	# Set variables early so waitForNetwork can use them
	HOSTIP=${HOSTIP:-NONE}

	# Wait for network to be ready (critical for MACVLAN)
	waitForNetwork "$HOSTIP"

	# Set remaining variables
	DOMAIN=${DOMAIN:-SAMDOM.LOCAL}
	DOMAINPASS=${DOMAINPASS:-youshouldsetapassword^123}
	JOIN=${JOIN:-false}
	JOINSITE=${JOINSITE:-NONE}
	MULTISITE=${MULTISITE:-false}
	NOCOMPLEXITY=${NOCOMPLEXITY:-false}
	INSECURELDAP=${INSECURELDAP:-false}
	DNSFORWARDER=${DNSFORWARDER:-NONE}
	HOSTIP=${HOSTIP:-NONE}
	RPCPORTS=${RPCPORTS:-"49152-49172"}
	DOMAIN_DC=${DOMAIN_DC:-${DOMAIN_DC}}
	LAM_PASSWORD=${LAM_PASSWORD:-lam}
	LAM_LDAP_METHOD=${LAM_LDAP_METHOD:-ldaps}
	LAM_SESSION_TIMEOUT=${LAM_SESSION_TIMEOUT:-30}
	LAM_LANGUAGE=${LAM_LANGUAGE:-en_GB.utf8:UTF-8:English (UK)}
	LAM_TIMEZONE=${LAM_TIMEZONE:-UTC}
	LAM_USER_UID_RANGE=${LAM_USER_UID_RANGE:-10000-30000}
	LAM_GROUP_GID_RANGE=${LAM_GROUP_GID_RANGE:-10000-30000}
	LAM_MACHINE_UID_RANGE=${LAM_MACHINE_UID_RANGE:-50000-60000}
	LAM_SEARCH_LIMIT=${LAM_SEARCH_LIMIT:-0}
	LAM_PWD_POLICY=${LAM_PWD_POLICY:-8:1:1:1:0}
	LOGLEVEL=${LOGLEVEL:-1}
	NTPSERVER=${NTPSERVER:-pool.ntp.org}
	MULTICASTDNS=${MULTICASTDNS:-yes}
	REGENERATE_CERT=${REGENERATE_CERT:-true}
	
	LDOMAIN=${DOMAIN,,}
	UDOMAIN=${DOMAIN^^}
	URDOMAIN=${UDOMAIN%%.*}

	# If multi-site, we need to connect to the VPN before joining the domain
	if [[ ${MULTISITE,,} == "true" ]]; then
		/usr/sbin/openvpn --config /docker.ovpn &
		VPNPID=$!
		echo "Sleeping 30s to ensure VPN connects ($VPNPID)";
		sleep 30
	fi

	# Set host ip option
	if [[ "$HOSTIP" != "NONE" ]]; then
		HOSTIP_OPTION="--host-ip=$HOSTIP"
	else
		HOSTIP_OPTION=""
	fi

	# Set proper hostname for Samba (use HOSTNAME variable if provided, otherwise default to {DOMAIN}DC)
	# This prevents DNS registration errors with random Docker container IDs
	# NetBIOS name is auto-derived from hostname (first 15 chars, uppercase)
	if [[ -z "$HOSTNAME" ]] || [[ "$HOSTNAME" == "NONE" ]]; then
		HOSTNAME="${URDOMAIN}DC"
	fi
	echo "Setting hostname to: $HOSTNAME"
	hostname "$HOSTNAME"
	echo "$HOSTNAME" > /etc/hostname
	echo "127.0.0.1 localhost $HOSTNAME $HOSTNAME.${LDOMAIN}" > /etc/hosts
	if [[ "$HOSTIP" != "NONE" ]]; then
		echo "$HOSTIP $HOSTNAME.$LDOMAIN $HOSTNAME" >> /etc/hosts
	fi

	# Set up samba
	mv /etc/krb5.conf /etc/krb5.conf.orig
	echo "[libdefaults]" > /etc/krb5.conf
	echo "    dns_lookup_realm = false" >> /etc/krb5.conf
	echo "    dns_lookup_kdc = true" >> /etc/krb5.conf
	echo "    default_realm = ${UDOMAIN}" >> /etc/krb5.conf
	# If the finished file isn't there, this is brand new, we're not just moving to a new container
	FIRSTRUN=false
	if [[ ! -f /etc/samba/external/smb.conf ]]; then
		FIRSTRUN=true
		mv /etc/samba/smb.conf /etc/samba/smb.conf.orig
		if [[ ${JOIN,,} == "true" ]]; then
			if [[ ${JOINSITE} == "NONE" ]]; then
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend=SAMBA_INTERNAL
			else
				samba-tool domain join ${LDOMAIN} DC -U"${URDOMAIN}\administrator" --password="${DOMAINPASS}" --dns-backend=SAMBA_INTERNAL --site=${JOINSITE}
			fi
		else
			samba-tool domain provision --use-rfc2307 --domain=${URDOMAIN} --realm=${UDOMAIN} --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass=${DOMAINPASS} ${HOSTIP_OPTION}
			if [[ ${NOCOMPLEXITY,,} == "true" ]]; then
				samba-tool domain passwordsettings set --complexity=off
				samba-tool domain passwordsettings set --history-length=0
				samba-tool domain passwordsettings set --min-pwd-age=0
				samba-tool domain passwordsettings set --max-pwd-age=0
			fi
		fi
		sed -i "/\[global\]/a \
			\\\tidmap_ldb:use rfc2307 = yes\\n\
			wins support = yes\\n\
			template shell = /bin/bash\\n\
			template homedir = /home/%U\\n\
			idmap config ${URDOMAIN} : schema_mode = rfc2307\\n\
			idmap config ${URDOMAIN} : unix_nss_info = yes\\n\
			idmap config ${URDOMAIN} : backend = ad\\n\
			rpc server dynamic port range = ${RPCPORTS}\\n\
			log level = ${LOGLEVEL} dns:0\\n\
			tls enabled = yes\\n\
			tls keyfile = /var/lib/samba/private/tls/key.pem\\n\
			tls certfile = /var/lib/samba/private/tls/cert.pem\\n\
			tls cafile = /var/lib/samba/private/tls/ca.pem\\n\
			ldap ssl = start tls\\n\
			ldap ssl ads = yes\
			" /etc/samba/smb.conf
		sed -i "s/LOCALDC/${URDOMAIN}DC/g" /etc/samba/smb.conf
		if [[ $DNSFORWARDER != "NONE" ]]; then
			sed -i "/dns forwarder/d" /etc/samba/smb.conf
			sed -i "/\[global\]/a \
				\\\tdns forwarder = ${DNSFORWARDER}\
				" /etc/samba/smb.conf
		fi
		if [[ ${INSECURELDAP,,} == "true" ]]; then
			sed -i "/\[global\]/a \
				\\\tldap server require strong auth = no\
				" /etc/samba/smb.conf
		fi
		if [[ ${MULTICASTDNS,,} == "yes" ]] || [[ ${MULTICASTDNS,,} == "true" ]]; then
			sed -i "/\[global\]/a \
				\\\tmulticast dns register = yes\
				" /etc/samba/smb.conf
		fi
		# Once we are set up, we'll make a file so that we know to use it if we ever spin this up again
		cp -f /etc/samba/smb.conf /etc/samba/external/smb.conf
	else
		cp -f /etc/samba/external/smb.conf /etc/samba/smb.conf
	fi
	
	# Create PHP-FPM socket directory
	mkdir -p /run/php
	chown www-data:www-data /run/php
        
	# Set up supervisor
	echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf
	echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf
	echo "" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:ntpd]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=/usr/sbin/ntpd -c /etc/ntpd.conf -n" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:samba]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=/usr/sbin/samba -i" >> /etc/supervisor/conf.d/supervisord.conf
	
	# Add PHP-FPM and Nginx for LAM
	echo "" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:php-fpm]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=/usr/sbin/php-fpm8.1 -F" >> /etc/supervisor/conf.d/supervisord.conf
	echo "" >> /etc/supervisor/conf.d/supervisord.conf
	echo "[program:nginx]" >> /etc/supervisor/conf.d/supervisord.conf
	echo "command=/usr/sbin/nginx -g 'daemon off;'" >> /etc/supervisor/conf.d/supervisord.conf
	
	if [[ ${MULTISITE,,} == "true" ]]; then
		if [[ -n $VPNPID ]]; then
			kill $VPNPID
		fi
		echo "" >> /etc/supervisor/conf.d/supervisord.conf
		echo "[program:openvpn]" >> /etc/supervisor/conf.d/supervisord.conf
		echo "command=/usr/sbin/openvpn --config /docker.ovpn" >> /etc/supervisor/conf.d/supervisord.conf
	fi

	echo "server 127.127.1.0" > /etc/ntpd.conf
	echo "fudge  127.127.1.0 stratum 10" >> /etc/ntpd.conf
	echo "server 0.${NTPSERVER}     iburst prefer" >> /etc/ntpd.conf
	echo "server 1.${NTPSERVER}     iburst prefer" >> /etc/ntpd.conf
	echo "server 2.${NTPSERVER}     iburst prefer" >> /etc/ntpd.conf
	echo "driftfile       /var/lib/ntp/ntp.drift" >> /etc/ntpd.conf
	echo "logfile         /var/log/ntp" >> /etc/ntpd.conf
	echo "ntpsigndsocket  /usr/local/samba/var/lib/ntp_signd/" >> /etc/ntpd.conf
	echo "restrict default kod nomodify notrap nopeer mssntp" >> /etc/ntpd.conf
	echo "restrict 127.0.0.1" >> /etc/ntpd.conf
	echo "restrict 0.${NTPSERVER}   mask 255.255.255.255    nomodify notrap nopeer noquery" >> /etc/ntpd.conf
	echo "restrict 1.${NTPSERVER}   mask 255.255.255.255    nomodify notrap nopeer noquery" >> /etc/ntpd.conf
	echo "restrict 2.${NTPSERVER}   mask 255.255.255.255    nomodify notrap nopeer noquery" >> /etc/ntpd.conf
	echo "tinker panic 0" >> /etc/ntpd.conf

	appStart ${FIRSTRUN}
}

regenerateSambaTLSCertificate () {
	echo "Regenerating Samba TLS certificate with IP address SAN..."
	
	# Get the actual IP address
	local actual_ip=$(ip -4 addr show | grep -v "127.0.0.1" | grep "inet " | head -1 | awk '{print $2}' | cut -d'/' -f1)
	
	if [[ -z "$actual_ip" ]]; then
		echo "WARNING: Could not detect IP address, skipping certificate regeneration"
		return 1
	fi
	
	local cert_dir="/var/lib/samba/private/tls"
	local key_file="${cert_dir}/key.pem"
	local cert_file="${cert_dir}/cert.pem"
	local ca_file="${cert_dir}/ca.pem"
	
	# Backup original certificate
	if [[ -f "$cert_file" ]] && [[ ! -f "${cert_file}.original" ]]; then
		cp "$cert_file" "${cert_file}.original"
		echo "Original certificate backed up to ${cert_file}.original"
	fi
	
	# Create OpenSSL config for certificate with SANs
	cat > /tmp/openssl-san.cnf <<EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
CN = ${HOSTNAME}.${LDOMAIN}
O = ${UDOMAIN}
OU = Domain Controllers

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = ${HOSTNAME}.${LDOMAIN}
DNS.2 = ${LDOMAIN}
DNS.3 = ${HOSTNAME}
DNS.4 = localhost
IP.1 = ${actual_ip}
IP.2 = 127.0.0.1
EOF
	
	echo "Generating new private key and certificate..."
	# Generate new private key
	openssl genrsa -out "${key_file}.new" 4096 2>/dev/null
	
	# Generate new self-signed certificate with SANs
	openssl req -new -x509 -days 3650 -key "${key_file}.new" -out "${cert_file}.new" \
		-config /tmp/openssl-san.cnf -extensions v3_req 2>/dev/null
	
	# Replace old certificate and key
	mv "${key_file}.new" "$key_file"
	mv "${cert_file}.new" "$cert_file"
	
	# Copy cert as CA (self-signed)
	cp "$cert_file" "$ca_file"
	
	# Set proper permissions
	chmod 600 "$key_file"
	chmod 644 "$cert_file"
	chmod 644 "$ca_file"
	
	echo "Certificate regenerated successfully with:"
	echo "  - DNS: ${HOSTNAME}.${LDOMAIN}"
	echo "  - DNS: ${LDOMAIN}"
	echo "  - DNS: ${HOSTNAME}"
	echo "  - DNS: localhost"
	echo "  - IP: ${actual_ip}"
	echo "  - IP: 127.0.0.1"
	echo ""
	echo "WARNING: This is a self-signed certificate. Not recommended for production!"
	
	# Restart Samba to load the new certificate
	echo "Restarting Samba to load new certificate..."
	supervisorctl restart samba
	sleep 3
	echo "Samba restarted with new certificate"
	
	# Clean up
	rm -f /tmp/openssl-san.cnf
}

configureLDAPS () {
	echo "Configuring LDAPS (SSL/TLS on port 636)..."
	
	# Verify TLS certificate exists
	if [[ ! -f "/var/lib/samba/private/tls/cert.pem" ]]; then
		echo "WARNING: TLS certificate not found, LDAPS may not work properly"
		return 1
	fi
	
	# Test if LDAPS is responding
	local max_attempts=10
	local attempt=0
	
	while [[ $attempt -lt $max_attempts ]]; do
		if timeout 5 openssl s_client -connect 127.0.0.1:636 -verify_return_error < /dev/null > /dev/null 2>&1; then
			echo "LDAPS is responding on port 636"
			return 0
		fi
		
		echo "Waiting for LDAPS to become available (attempt $((attempt + 1))/$max_attempts)..."
		sleep 2
		((attempt++))
	done
	
	echo "WARNING: LDAPS does not appear to be responding on port 636"
	echo "This may be normal - some Samba versions don't enable LDAPS by default"
	return 1
}

fixDomainUsersGroup () {
	GIDNUMBER=$(ldbedit -H /var/lib/samba/private/sam.ldb -e cat "samaccountname=domain users" | { grep ^gidNumber: || true; })
	if [ -z "${GIDNUMBER}" ]; then
		echo "dn: CN=Domain Users,CN=Users,${DOMAIN_DC}
changetype: modify
add: gidNumber
gidNumber: 3000000" | ldbmodify -H /var/lib/samba/private/sam.ldb
		net cache flush
	fi
}

setupSSH () {
	echo "dn: CN=sshPublicKey,CN=Schema,CN=Configuration,${DOMAIN_DC}
changetype: add
objectClass: top
objectClass: attributeSchema
attributeID: 1.3.6.1.4.1.24552.500.1.1.1.13
cn: sshPublicKey
name: sshPublicKey
lDAPDisplayName: sshPublicKey
description: MANDATORY: OpenSSH Public key
attributeSyntax: 2.5.5.10
oMSyntax: 4
isSingleValued: FALSE
objectCategory: CN=Attribute-Schema,CN=Schema,CN=Configuration,${DOMAIN_DC}
searchFlags: 8
schemaIDGUID:: cjDAZyEXzU+/akI0EGDW+g==" > /tmp/Sshpubkey.attr.ldif
	echo "dn: CN=ldapPublicKey,CN=Schema,CN=Configuration,${DOMAIN_DC}
changetype: add
objectClass: top
objectClass: classSchema
governsID: 1.3.6.1.4.1.24552.500.1.1.2.0
cn: ldapPublicKey
name: ldapPublicKey
description: MANDATORY: OpenSSH LPK objectclass
lDAPDisplayName: ldapPublicKey
subClassOf: top
objectClassCategory: 3
objectCategory: CN=Class-Schema,CN=Schema,CN=Configuration,${DOMAIN_DC}
defaultObjectCategory: CN=ldapPublicKey,CN=Schema,CN=Configuration,${DOMAIN_DC}
mayContain: sshPublicKey
schemaIDGUID:: +8nFQ43rpkWTOgbCCcSkqA==" > /tmp/Sshpubkey.class.ldif
	ldbadd -H /var/lib/samba/private/sam.ldb /var/lib/samba/private/sam.ldb /tmp/Sshpubkey.attr.ldif --option="dsdb:schema update allowed"=true
	ldbadd -H /var/lib/samba/private/sam.ldb /var/lib/samba/private/sam.ldb /tmp/Sshpubkey.class.ldif --option="dsdb:schema update allowed"=true
}

configureLAM () {
	echo "Configuring LAM for Samba AD with comprehensive automation..."
	
	# Ensure LAM config directory exists
	mkdir -p /var/lib/lam/config
	mkdir -p /var/lib/lam/sess
	mkdir -p /var/lib/lam/tmp
	chown -R www-data:www-data /var/lib/lam
	
	# Parse configuration variables
	echo "Parsing LAM configuration from template variables..."
	
	# Parse UID/GID ranges
	local user_uid_min=$(echo "${LAM_USER_UID_RANGE}" | cut -d'-' -f1)
	local user_uid_max=$(echo "${LAM_USER_UID_RANGE}" | cut -d'-' -f2)
	local group_gid_min=$(echo "${LAM_GROUP_GID_RANGE}" | cut -d'-' -f1)
	local group_gid_max=$(echo "${LAM_GROUP_GID_RANGE}" | cut -d'-' -f2)
	local machine_uid_min=$(echo "${LAM_MACHINE_UID_RANGE}" | cut -d'-' -f1)
	local machine_uid_max=$(echo "${LAM_MACHINE_UID_RANGE}" | cut -d'-' -f2)
	
	# Parse password policy
	local pwd_min_length=$(echo "${LAM_PWD_POLICY}" | cut -d':' -f1)
	local pwd_min_lower=$(echo "${LAM_PWD_POLICY}" | cut -d':' -f2)
	local pwd_min_upper=$(echo "${LAM_PWD_POLICY}" | cut -d':' -f3)
	local pwd_min_numeric=$(echo "${LAM_PWD_POLICY}" | cut -d':' -f4)
	local pwd_min_symbols=$(echo "${LAM_PWD_POLICY}" | cut -d':' -f5)
	
	# Determine LDAP connection method
	local server_url
	local use_tls="no"
	local ignore_tls_errors="false"
	
	case "${LAM_LDAP_METHOD,,}" in
		"ldaps")
			server_url="ldaps://127.0.0.1:636"
			use_tls="no"  # TLS is built into LDAPS
			ignore_tls_errors="true"  # For self-signed certificates
			echo "LAM configured for LDAPS (SSL/TLS on port 636)"
			;;
		"starttls")
			server_url="ldap://127.0.0.1:389"
			use_tls="yes"  # Use StartTLS
			ignore_tls_errors="true"  # For self-signed certificates
			echo "LAM configured for LDAP with StartTLS (port 389)"
			;;
		"ldap"|"plain")
			server_url="ldap://127.0.0.1:389"
			use_tls="no"  # Plain LDAP (insecure)
			ignore_tls_errors="false"
			echo "LAM configured for plain LDAP (port 389) - WARNING: Insecure!"
			;;
		*)
			# Default to LDAPS
			server_url="ldaps://127.0.0.1:636"
			use_tls="no"
			ignore_tls_errors="true"
			echo "LAM configured for LDAPS (default) - unknown method: ${LAM_LDAP_METHOD}"
			;;
	esac
	
	echo "LAM Configuration Summary:"
	echo "  - LDAP Method: ${LAM_LDAP_METHOD} (${server_url})"
	echo "  - Session Timeout: ${LAM_SESSION_TIMEOUT} minutes"
	echo "  - Language: ${LAM_LANGUAGE}"
	echo "  - Timezone: ${LAM_TIMEZONE}"
	echo "  - User UID Range: ${user_uid_min}-${user_uid_max}"
	echo "  - Group GID Range: ${group_gid_min}-${group_gid_max}"
	echo "  - Machine UID Range: ${machine_uid_min}-${machine_uid_max}"
	echo "  - Password Policy: Min ${pwd_min_length} chars, ${pwd_min_lower} lower, ${pwd_min_upper} upper, ${pwd_min_numeric} numeric, ${pwd_min_symbols} symbols"
	
	# Create LAM master configuration if it doesn't exist
	if [[ ! -f /var/lib/lam/config/lam.conf ]]; then
		echo "Creating LAM master configuration..."
		
		# Generate password hash (SHA256)
		LAM_PASS_HASH=$(echo -n "${LAM_PASSWORD}" | sha256sum | awk '{print $1}')
		
		cat > /var/lib/lam/config/lam.conf <<EOF
# LAM Master Configuration
# Automatically generated from Docker template variables

# Master password (SHA256 hash)
Passwd: {SHA256}${LAM_PASS_HASH}

# Session timeout in minutes
sessionTimeout: ${LAM_SESSION_TIMEOUT}

# Allowed hosts (empty = all hosts allowed)
allowedHosts: 

# Log level (0=disabled, 1=errors, 2=warnings, 3=info, 4=debug)
logLevel: 2

# Log destination
logDestination: SYSLOG

# License information (LAM Pro)
licenseEmailFrom: 
licenseEmailTo: 
license: 

# Password reset settings
passwordResetAllowedHosts: 
passwordResetAllowSpecificPassword: false
passwordResetForcePasswordChange: true
passwordResetDefaultPasswordOutput: 2

# Security settings
encryptSession: true
httpAuthentication: false

EOF
		chown www-data:www-data /var/lib/lam/config/lam.conf
		chmod 600 /var/lib/lam/config/lam.conf
		echo "LAM master configuration created with session timeout: ${LAM_SESSION_TIMEOUT} minutes"
	else
		echo "LAM master configuration already exists - skipping"
	fi
	
	# Create comprehensive LAM server profile configuration
	echo "Creating comprehensive LAM server profile from template variables..."
	
	cat > /var/lib/lam/config/lam.conf.sample <<EOF
# LAM Server Profile for Samba Active Directory
# Automatically generated from Docker template variables
# Configuration Date: $(date)

# ===== SERVER CONNECTION SETTINGS =====
ServerURL: ${server_url}
useTLS: ${use_tls}
Admins: cn=Administrator,cn=Users,${DOMAIN_DC}
Passwd: {SHA256}$(echo -n "${LAM_PASSWORD}" | sha256sum | awk '{print $1}')

# ===== LDAP TREE SETTINGS =====
treesuffix: ${DOMAIN_DC}

# ===== INTERFACE SETTINGS =====
defaultLanguage: ${LAM_LANGUAGE}
timeZone: ${LAM_TIMEZONE}

# ===== SCRIPT SETTINGS =====
scriptPath: 
scriptServer: 
scriptRights: 

# ===== TOOL SETTINGS =====
tools: tool_hide_pwdChange tool_hide_tests

# ===== UID/GID MANAGEMENT =====
# User account UID range
modules: posixAccount_user_minUID:${user_uid_min}
modules: posixAccount_user_maxUID:${user_uid_max}

# Machine account UID range  
modules: posixAccount_host_minMachine:${machine_uid_min}
modules: posixAccount_host_maxMachine:${machine_uid_max}

# Group GID range
modules: posixGroup_group_minGID:${group_gid_min}
modules: posixGroup_group_maxGID:${group_gid_max}

# ===== ACCOUNT TYPE CONFIGURATION =====
activeTypes: user,group

# User account type settings
types: suffix_user: cn=Users,${DOMAIN_DC}
types: attr_user: #uid;#givenName;#sn;#uidNumber;#gidNumber;#mail;#telephoneNumber
types: modules_user: inetOrgPerson,posixAccount,shadowAccount

# Group account type settings
types: suffix_group: cn=Users,${DOMAIN_DC}
types: attr_group: #cn;#gidNumber;#memberUID;#description
types: modules_group: posixGroup

# Computer account type settings (if computers are managed)
# types: suffix_host: cn=Computers,${DOMAIN_DC}
# types: attr_host: #uid;#cn;#description
# types: modules_host: account,posixAccount

# ===== SECURITY AND CONNECTION SETTINGS =====
followReferrals: false
pagedResults: false
referentialIntegrityOverlay: false
hideInvalidDNs: false

# TLS/SSL settings
ignoreTLSErrors: ${ignore_tls_errors}

# ===== SEARCH SETTINGS =====
searchLimit: ${LAM_SEARCH_LIMIT}

# ===== ACCESS CONTROL =====
accessLevel: 100

# ===== LOGIN SETTINGS =====
loginMethod: list
loginSearchSuffix: ${DOMAIN_DC}
loginSearchFilter: uid=%USER%
loginSearchDN: 
loginSearchPassword: 

# ===== AUTHENTICATION =====
httpAuthentication: false

# ===== TWO-FACTOR AUTHENTICATION =====
twoFactorAuthentication: none
twoFactorAuthenticationURL: 
twoFactorAuthenticationInsecure: false
twoFactorAuthenticationLabel: 

# ===== PASSWORD POLICY =====
pwdPolicyMinLength: ${pwd_min_length}
pwdPolicyMinLowercase: ${pwd_min_lower}
pwdPolicyMinUppercase: ${pwd_min_upper}
pwdPolicyMinNumeric: ${pwd_min_numeric}
pwdPolicyMinSymbolic: ${pwd_min_symbols}
pwdPolicyMinClasses: 3

# ===== ORGANIZATIONAL SETTINGS =====
# Default organizational units structure for Samba AD
# These match typical Samba AD DC structure

# Default groups for new users
modules: inetOrgPerson_user_defaultGroups: cn=Domain Users,cn=Users,${DOMAIN_DC}

# Shell settings for Unix attributes
modules: posixAccount_user_defaultShell: /bin/bash
modules: posixAccount_user_homeDirectory_placeholder: /home/%USER%

# ===== ADVANCED SETTINGS =====
# LDAP cache timeout
lamProMailSubject: 

# Custom scripts (disabled by default)
scriptServer: 

# Domain integration
domains: domain=${URDOMAIN}

# ===== NOTIFICATION SETTINGS =====
# Email notifications (configure if needed)
# mailServer: 
# mailUser: 
# mailPassword: 

EOF
	
	chown www-data:www-data /var/lib/lam/config/lam.conf.sample
	chmod 600 /var/lib/lam/config/lam.conf.sample
	
	echo "LAM server profile created successfully!"
	echo "Configuration details:"
	echo "  - Base DN: ${DOMAIN_DC}"
	echo "  - Admin DN: cn=Administrator,cn=Users,${DOMAIN_DC}"
	echo "  - User Container: cn=Users,${DOMAIN_DC}"
	echo "  - Group Container: cn=Users,${DOMAIN_DC}"
	echo "  - User UID Range: ${user_uid_min}-${user_uid_max}"
	echo "  - Group GID Range: ${group_gid_min}-${group_gid_max}"
	echo "  - Machine UID Range: ${machine_uid_min}-${machine_uid_max}"
	
	echo "LAM configuration complete"
	echo "LAM web interface will be available at http://<host-ip>:8080"
	echo "Default LAM password: ${LAM_PASSWORD}"
	echo ""
	echo "=== LAM QUICK START GUIDE ==="
	echo "1. Open LAM at http://<container-ip>:8080"
	echo "2. Login with password: ${LAM_PASSWORD}"
	echo "3. LAM is pre-configured for your Samba AD domain:"
	echo "   - Server: ${server_url}"
	echo "   - Base DN: ${DOMAIN_DC}"
	echo "   - Admin: cn=Administrator,cn=Users,${DOMAIN_DC}"
	echo "4. All UID/GID ranges and policies are set from template"
	echo "5. Ready to manage users, groups, and computers!"
	echo "=========================="
}

validateLAMConfiguration () {
	echo "Validating LAM configuration..."
	
	# Check master config
	if [[ ! -f /var/lib/lam/config/lam.conf ]]; then
		echo "ERROR: LAM master configuration missing!"
		return 1
	fi
	
	# Check server profile
	if [[ ! -f /var/lib/lam/config/lam.conf.sample ]]; then
		echo "ERROR: LAM server profile missing!"
		return 1
	fi
	
	# Check permissions
	if [[ $(stat -c %U /var/lib/lam/config/lam.conf) != "www-data" ]]; then
		echo "WARNING: LAM master config ownership incorrect - fixing..."
		chown www-data:www-data /var/lib/lam/config/lam.conf
	fi
	
	if [[ $(stat -c %U /var/lib/lam/config/lam.conf.sample) != "www-data" ]]; then
		echo "WARNING: LAM server profile ownership incorrect - fixing..."
		chown www-data:www-data /var/lib/lam/config/lam.conf.sample
	fi
	
	# Validate configuration content
	local config_errors=0
	
	if ! grep -q "treesuffix: ${DOMAIN_DC}" /var/lib/lam/config/lam.conf.sample; then
		echo "ERROR: Base DN not properly configured in LAM profile"
		((config_errors++))
	fi
	
	if ! grep -q "ServerURL: " /var/lib/lam/config/lam.conf.sample; then
		echo "ERROR: Server URL not configured in LAM profile"
		((config_errors++))
	fi
	
	if ! grep -q "sessionTimeout: ${LAM_SESSION_TIMEOUT}" /var/lib/lam/config/lam.conf; then
		echo "ERROR: Session timeout not properly configured"
		((config_errors++))
	fi
	
	if [[ $config_errors -eq 0 ]]; then
		echo "LAM configuration validation passed!"
		
		# Create default server profile as active profile
		if [[ ! -f /var/lib/lam/config/lam.conf.default ]]; then
			echo "Creating default active LAM profile..."
			cp /var/lib/lam/config/lam.conf.sample /var/lib/lam/config/lam.conf.default
			chown www-data:www-data /var/lib/lam/config/lam.conf.default
			chmod 600 /var/lib/lam/config/lam.conf.default
			echo "Default LAM profile created - LAM ready to use!"
		fi
		
		return 0
	else
		echo "LAM configuration validation failed with $config_errors errors"
		return 1
	fi
}

appStart () {
	/usr/bin/supervisord > /var/log/supervisor/supervisor.log 2>&1 &
	if [ "${1}" = "true" ]; then
		echo "Sleeping 10 before checking on Domain Users of gid 3000000 and setting up sshPublicKey"
		sleep 10
		fixDomainUsersGroup
		setupSSH
		if [[ ${REGENERATE_CERT,,} == "true" ]]; then
			echo "Regenerating TLS certificate with IP address..."
			regenerateSambaTLSCertificate
			# Test LDAPS connectivity after certificate regeneration
			echo "Testing LDAPS connectivity..."
			configureLDAPS
		else
			echo "Certificate regeneration disabled (REGENERATE_CERT=false)"
			echo "Using Samba's default self-signed certificate (hostname + domain only)"
			# Still test LDAPS with default certificate
			echo "Testing LDAPS connectivity with default certificate..."
			configureLDAPS
		fi
		echo "Sleeping additional 5 seconds before configuring LAM..."
		sleep 5
		configureLAM
		echo "Validating LAM configuration..."
		validateLAMConfiguration
	fi
	while [ ! -f /var/log/supervisor/supervisor.log ]; do
		echo "Waiting for log files..."
		sleep 1
	done
	sleep 3
	tail -F /var/log/supervisor/*.log
}

appSetup

exit 0
