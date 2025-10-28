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
	LOGLEVEL=${LOGLEVEL:-1}
	NTPSERVER=${NTPSERVER:-pool.ntp.org}
	MULTICASTDNS=${MULTICASTDNS:-yes}
	
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
			log level = ${LOGLEVEL}\
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
IP.1 = ${actual_ip}
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
	echo "  - IP: ${actual_ip}"
	echo ""
	echo "WARNING: This is a self-signed certificate. Not recommended for production!"
	
	# Clean up
	rm -f /tmp/openssl-san.cnf
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
	echo "Configuring LAM for Samba AD..."
	
	# Ensure LAM config directory exists
	mkdir -p /var/lib/lam/config
	mkdir -p /var/lib/lam/sess
	mkdir -p /var/lib/lam/tmp
	chown -R www-data:www-data /var/lib/lam
	
	# Create LAM master configuration if it doesn't exist
	if [[ ! -f /var/lib/lam/config/lam.conf ]]; then
		echo "Creating LAM master configuration..."
		
		# Generate password hash (SHA256)
		LAM_PASS_HASH=$(echo -n "${LAM_PASSWORD}" | sha256sum | awk '{print $1}')
		
		cat > /var/lib/lam/config/lam.conf <<EOF
# LAM configuration
# This file is automatically generated by init.sh

# Master password (SHA256 hash)
Passwd: {SHA256}${LAM_PASS_HASH}

# Session timeout (default: 30 minutes)
sessionTimeout: 30

# Allowed hosts (empty = all hosts)
allowedHosts: 

# Log level (default: 4)
logLevel: 4

# Log destination
logDestination: SYSLOG

# License information
licenseEmailFrom: 
licenseEmailTo: 

# LAM Pro license (if applicable)
license: 

# Password reset allowed hosts
passwordResetAllowedHosts: 

# Password reset settings
passwordResetAllowSpecificPassword: false
passwordResetForcePasswordChange: true
passwordResetDefaultPasswordOutput: 2

EOF
		chown www-data:www-data /var/lib/lam/config/lam.conf
		chmod 600 /var/lib/lam/config/lam.conf
	fi
	
	# Create LAM server profile configuration
	if [[ ! -f /var/lib/lam/config/lam.conf.sample ]]; then
		echo "Creating LAM server profile..."
		
		cat > /var/lib/lam/config/lam.conf.sample <<EOF
# LAM server profile for Samba AD
# This file is automatically generated by init.sh

# Server settings
ServerURL: ldaps://127.0.0.1:636
Admins: cn=Administrator,cn=Users,${DOMAIN_DC}
Passwd: {SHA256}$(echo -n "${LAM_PASSWORD}" | sha256sum | awk '{print $1}')

# Tree settings
treesuffix: ${DOMAIN_DC}

# Default language
defaultLanguage: en_GB.utf8:UTF-8:English (UK)

# Script settings
scriptPath: 
scriptServer: 
scriptRights: 

# Tool settings
tools: tool_hide_pwdChange tool_hide_tests

# Module settings
modules: posixAccount_user_minUID:10000
modules: posixAccount_user_maxUID:30000
modules: posixAccount_host_minMachine:50000
modules: posixAccount_host_maxMachine:60000
modules: posixGroup_group_minGID:10000
modules: posixGroup_group_maxGID:30000

# Active account types
activeTypes: user,group

# User type settings
types: suffix_user: cn=Users,${DOMAIN_DC}
types: attr_user: #uid;#givenName;#sn;#uidNumber;#gidNumber
types: modules_user: inetOrgPerson,posixAccount,shadowAccount

# Group type settings
types: suffix_group: cn=Users,${DOMAIN_DC}
types: attr_group: #cn;#gidNumber;#memberUID;#description
types: modules_group: posixGroup

# Security settings
followReferrals: false
pagedResults: false
referentialIntegrityOverlay: false
hideInvalidDNs: false

# Search settings
searchLimit: 0

# Time zone
timeZone: UTC

# Access level
accessLevel: 100

# Login method
loginMethod: list
loginSearchSuffix: ${DOMAIN_DC}
loginSearchFilter: uid=%USER%
loginSearchDN: 
loginSearchPassword: 

# HTTP authentication
httpAuthentication: false

# Two factor authentication
twoFactorAuthentication: none
twoFactorAuthenticationURL: 
twoFactorAuthenticationInsecure: false
twoFactorAuthenticationLabel: 

# Remote script server
scriptServer: 

# Password policy
pwdPolicyMinLength: 
pwdPolicyMinLowercase: 
pwdPolicyMinUppercase: 
pwdPolicyMinNumeric: 
pwdPolicyMinSymbolic: 
pwdPolicyMinClasses: 

# LDAP cache timeout
lamProMailSubject: 

# Default NIS domain (if using NIS schema)
# domains: domain=${URDOMAIN}

EOF
		chown www-data:www-data /var/lib/lam/config/lam.conf.sample
		chmod 600 /var/lib/lam/config/lam.conf.sample
	fi
	
	echo "LAM configuration complete"
	echo "LAM web interface will be available at http://<host-ip>:8080"
	echo "Default LAM password: ${LAM_PASSWORD}"
}

appStart () {
	/usr/bin/supervisord > /var/log/supervisor/supervisor.log 2>&1 &
	if [ "${1}" = "true" ]; then
		echo "Sleeping 10 before checking on Domain Users of gid 3000000 and setting up sshPublicKey"
		sleep 10
		fixDomainUsersGroup
		setupSSH
		echo "Regenerating TLS certificate with IP address..."
		regenerateSambaTLSCertificate
		echo "Sleeping additional 5 seconds before configuring LAM..."
		sleep 5
		configureLAM
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
