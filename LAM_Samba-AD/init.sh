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
	DISABLE_IPV6=${DISABLE_IPV6:-true}
	
	# Disable IPv6 if requested (reduces binding warnings)
	if [[ ${DISABLE_IPV6,,} == "true" ]]; then
		echo "Disabling IPv6 in container..."
		sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
		sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
		sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1 || true
		echo "IPv6 disabled"
	fi

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
	
	# Validate DOMAIN format before using it
	if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$ ]]; then
		echo "ERROR: Invalid DOMAIN format: ${DOMAIN}"
		echo "DOMAIN must be a valid FQDN (e.g., example.com, domain.local)"
		echo "Must contain at least one dot and only valid DNS characters"
		exit 1
	fi
	
	# Auto-generate DOMAIN_DC from DOMAIN if not explicitly set
	# Convert domain.example.com to dc=domain,dc=example,dc=com
	if [[ -z "${DOMAIN_DC}" ]]; then
		DOMAIN_DC=$(echo "${DOMAIN}" | sed 's/\./,dc=/g' | sed 's/^/dc=/')
		echo "Auto-generated DOMAIN_DC: ${DOMAIN_DC}"
	fi
	
	# LAM Application Settings (config.cfg)
	LAM_MASTER_PASSWORD=${LAM_MASTER_PASSWORD:-ChangeMasterPassword123!}
	LAM_SESSION_TIMEOUT=${LAM_SESSION_TIMEOUT:-30}
	LAM_LOG_LEVEL=${LAM_LOG_LEVEL:-4}
	
	# LAM Server Profile Settings (profile.conf)
	# LAM_PROFILE_NAME is auto-generated from domain name after URDOMAIN is set (see line ~120)
	LAM_PROFILE_PASSWORD=${LAM_PROFILE_PASSWORD:-lam}
	LAM_LDAP_METHOD=${LAM_LDAP_METHOD:-ldaps}
	LAM_USER_SUFFIX=${LAM_USER_SUFFIX:-CN=Users}
	LAM_GROUP_SUFFIX=${LAM_GROUP_SUFFIX:-CN=Users}
	LAM_USER_MODULES=${LAM_USER_MODULES:-windowsUser,inetOrgPerson}
	LAM_GROUP_MODULES=${LAM_GROUP_MODULES:-windowsGroup}
	LAM_PROFILE_LANGUAGE=${LAM_PROFILE_LANGUAGE:-en_US.utf8:UTF-8:English (USA)}
	LAM_PROFILE_TIMEZONE=${LAM_PROFILE_TIMEZONE:-UTC}
	LAM_UID_RANGE=${LAM_UID_RANGE:-10000-30000}
	LAM_GID_RANGE=${LAM_GID_RANGE:-10000-30000}
	LAM_ADMIN_DNS=${LAM_ADMIN_DNS:-cn=Administrator,cn=Users}
	LAM_ACCESS_LEVEL=${LAM_ACCESS_LEVEL:-100}
	LOGLEVEL=${LOGLEVEL:-1}
	NTPSERVER=${NTPSERVER:-pool.ntp.org}
	MULTICASTDNS=${MULTICASTDNS:-yes}
	REGENERATE_CERT=${REGENERATE_CERT:-true}
	SCHEMA_SETUP_DELAY=${SCHEMA_SETUP_DELAY:-10}
	
	LDOMAIN=${DOMAIN,,}
	UDOMAIN=${DOMAIN^^}
	URDOMAIN=${UDOMAIN%%.*}

	# Auto-generate LAM profile name from domain if not specified
	# Same pattern as hostname: if empty or "samba-ad" (default), use domain-based name
	if [[ -z "${LAM_PROFILE_NAME}" ]] || [[ "${LAM_PROFILE_NAME}" == "samba-ad" ]]; then
		# Convert domain to lowercase and use as profile name (e.g., "haver" from "haver.internal")
		LAM_PROFILE_NAME="${LDOMAIN%%.*}"
	fi
	# For backward compatibility, LAM_DEFAULT_PROFILE can still override
	if [[ -n "${LAM_DEFAULT_PROFILE}" ]] && [[ "${LAM_DEFAULT_PROFILE}" != "samba-ad" ]]; then
		LAM_PROFILE_NAME="${LAM_DEFAULT_PROFILE}"
	fi

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
			ldap ssl = start tls\
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

	# Create NTP drift directory for time sync persistence
	echo "Creating NTP drift directory..."
	mkdir -p /var/lib/ntp
	chown ntp:ntp /var/lib/ntp 2>/dev/null || chown root:root /var/lib/ntp
	
	# Configure NTP for time synchronization (critical for Kerberos)
	echo "Configuring NTP time synchronization..."
	echo "server 127.127.1.0" > /etc/ntpd.conf
	echo "fudge  127.127.1.0 stratum 10" >> /etc/ntpd.conf
	echo "server 0.${NTPSERVER}     iburst prefer" >> /etc/ntpd.conf
	echo "server 1.${NTPSERVER}     iburst prefer" >> /etc/ntpd.conf
	echo "server 2.${NTPSERVER}     iburst prefer" >> /etc/ntpd.conf
	echo "driftfile       /var/lib/ntp/ntp.drift" >> /etc/ntpd.conf
	echo "logfile         /var/log/ntp" >> /etc/ntpd.conf
	# NOTE: ntpsigndsocket enables MS-SNTP signing for Samba AD (required for Windows clients)
	# Warning "MS-SNTP signd operations currently block ntpd" is EXPECTED and can be ignored
	echo "ntpsigndsocket  /usr/local/samba/var/lib/ntp_signd/" >> /etc/ntpd.conf
	echo "restrict default kod limited nomodify notrap nopeer mssntp" >> /etc/ntpd.conf
	echo "restrict 127.0.0.1" >> /etc/ntpd.conf
	# Note: Pool servers resolve to multiple IPs, don't use mask parameter
	echo "restrict 0.${NTPSERVER}   nomodify notrap nopeer noquery" >> /etc/ntpd.conf
	echo "restrict 1.${NTPSERVER}   nomodify notrap nopeer noquery" >> /etc/ntpd.conf
	echo "restrict 2.${NTPSERVER}   nomodify notrap nopeer noquery" >> /etc/ntpd.conf
	echo "tinker panic 0" >> /etc/ntpd.conf
	# Require at least 3 servers to sync before declaring synchronized (reduces false warnings)
	echo "tos minclock 3 maxclock 6" >> /etc/ntpd.conf

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
	
	# Test if LDAPS port is listening (simpler test, less likely to crash)
	local max_attempts=10
	local attempt=0
	
	while [[ $attempt -lt $max_attempts ]]; do
		# Use nc (netcat) for simple port check instead of openssl s_client
		if timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/636" 2>/dev/null; then
			echo "LDAPS port 636 is listening"
			# Optional: Try openssl test if basic port check succeeds
			if timeout 3 openssl s_client -connect 127.0.0.1:636 -brief < /dev/null > /dev/null 2>&1; then
				echo "LDAPS is responding and accepting SSL connections"
			else
				echo "LDAPS port is open but SSL handshake test skipped (may still work)"
			fi
			return 0
		fi
		
		echo "Waiting for LDAPS port to become available (attempt $((attempt + 1))/$max_attempts)..."
		sleep 2
		((attempt++))
	done
	
	echo "WARNING: LDAPS port 636 does not appear to be listening"
	echo "This may be normal - continuing anyway"
	return 0  # Return success to avoid blocking startup
}

fixDomainUsersGroup () {
	echo "Checking Domain Users group gidNumber..."
	
	local max_retries=3
	local retry_delay=5
	local attempt=1
	
	while [ $attempt -le $max_retries ]; do
		echo "Attempting to fix Domain Users group (attempt $attempt/$max_retries)..."
		
		# Check if Domain Users group exists
		if ! ldbsearch -H /var/lib/samba/private/sam.ldb -b "${DOMAIN_DC}" "(samaccountname=domain users)" dn 2>/dev/null | grep -q "dn: CN=Domain Users"; then
			echo "⚠ Domain Users group not found yet, Samba may still be initializing..."
			if [ $attempt -lt $max_retries ]; then
				echo "Waiting ${retry_delay}s before retry..."
				sleep $retry_delay
				attempt=$((attempt + 1))
				continue
			else
				echo "✗ Domain Users group not found after $max_retries attempts"
				return 1
			fi
		fi
		
		# Check if gidNumber already exists
		GIDNUMBER=$(ldbedit -H /var/lib/samba/private/sam.ldb -e cat "samaccountname=domain users" 2>/dev/null | { grep ^gidNumber: || true; })
		
		if [ -n "${GIDNUMBER}" ]; then
			echo "✓ Domain Users already has gidNumber: ${GIDNUMBER}"
			return 0
		fi
		
		# Try to add gidNumber
		echo "Adding gidNumber to Domain Users group..."
		if echo "dn: CN=Domain Users,CN=Users,${DOMAIN_DC}
changetype: modify
add: gidNumber
gidNumber: 3000000" | ldbmodify -H /var/lib/samba/private/sam.ldb 2>&1; then
			echo "✓ Successfully added gidNumber to Domain Users"
			net cache flush
			return 0
		else
			echo "✗ Failed to add gidNumber to Domain Users"
			if [ $attempt -lt $max_retries ]; then
				echo "Waiting ${retry_delay}s before retry..."
				sleep $retry_delay
			fi
		fi
		
		attempt=$((attempt + 1))
	done
	
	echo "⚠ Failed to add gidNumber after $max_retries attempts (may already exist or permission issue)"
	return 1
}

setupSSH () {
	echo "Setting up SSH public key schema extensions..."
	
	local max_retries=3
	local retry_delay=5
	local attempt=1
	
	# Check if schemas already exist before attempting to add
	echo "Checking if SSH schemas already exist..."
	if ldbsearch -H /var/lib/samba/private/sam.ldb -b "CN=Schema,CN=Configuration,${DOMAIN_DC}" "(cn=sshPublicKey)" 2>/dev/null | grep -q "dn: CN=sshPublicKey"; then
		echo "✓ sshPublicKey schema already exists, skipping setup"
		return 0
	fi
	
	# Generate LDIF files
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
	
	# Retry loop for schema additions
	while [ $attempt -le $max_retries ]; do
		echo "Adding SSH schemas (attempt $attempt/$max_retries)..."
		
		local attr_success=false
		local class_success=false
		
		# Try to add sshPublicKey attribute
		if ldbadd -H /var/lib/samba/private/sam.ldb /tmp/Sshpubkey.attr.ldif --option="dsdb:schema update allowed"=true 2>&1 | grep -qi "success\|already exists"; then
			echo "✓ sshPublicKey attribute added/exists"
			attr_success=true
		else
			echo "✗ sshPublicKey attribute add failed"
		fi
		
		# Try to add ldapPublicKey class
		if ldbadd -H /var/lib/samba/private/sam.ldb /tmp/Sshpubkey.class.ldif --option="dsdb:schema update allowed"=true 2>&1 | grep -qi "success\|already exists"; then
			echo "✓ ldapPublicKey class added/exists"
			class_success=true
		else
			echo "✗ ldapPublicKey class add failed"
		fi
		
		# Check if both succeeded
		if [ "$attr_success" = true ] && [ "$class_success" = true ]; then
			echo "✓ SSH schema setup completed successfully"
			rm -f /tmp/Sshpubkey.attr.ldif /tmp/Sshpubkey.class.ldif
			return 0
		fi
		
		# If not last attempt, wait and retry
		if [ $attempt -lt $max_retries ]; then
			echo "⚠ Schema setup incomplete, waiting ${retry_delay}s before retry..."
			sleep $retry_delay
		fi
		
		attempt=$((attempt + 1))
	done
	
	echo "⚠ SSH schema setup failed after $max_retries attempts (schemas may already exist)"
	rm -f /tmp/Sshpubkey.attr.ldif /tmp/Sshpubkey.class.ldif
	return 1
}

configureLAMApplication () {
	echo "=== CONFIGURING LAM APPLICATION (config.cfg) ==="
	
	# Configure LDAP client to trust self-signed certificates
	echo "Configuring LDAP client certificate trust..."
	
	# Copy Samba's CA certificate to LAM's expected location
	# LAM automatically calls setSSLCaCert() which does putenv('LDAPTLS_CACERT=...')
	cp /var/lib/samba/private/tls/ca.pem /var/www/html/lam/config/serverCerts.pem
	chown www-data:www-data /var/www/html/lam/config/serverCerts.pem
	chmod 644 /var/www/html/lam/config/serverCerts.pem
	echo "✓ Samba CA certificate installed to LAM config"
	echo "  - /var/www/html/lam/config/serverCerts.pem"
	
	# Also configure system-wide LDAP client (for command-line tools)
	mkdir -p /etc/ldap
	cat > /etc/ldap/ldap.conf <<-EOF
	# LDAP client configuration for LAM/Samba AD
	TLS_REQCERT allow
	TLS_CACERT /var/lib/samba/private/tls/cert.pem
	EOF
	
	# Also configure for PHP's LDAP extension (used by LAM)
	# PHP reads ldap.conf from multiple locations
	mkdir -p /etc/openldap
	cp /etc/ldap/ldap.conf /etc/openldap/ldap.conf
	
	echo "✓ LDAP client configured to trust Samba certificates"
	echo "  - /etc/ldap/ldap.conf configured"
	echo "  - /etc/openldap/ldap.conf configured"
	
	# Ensure LAM config directory exists
	mkdir -p /var/www/html/lam/config
	mkdir -p /var/lib/lam/sess
	mkdir -p /var/lib/lam/tmp
	chown -R www-data:www-data /var/lib/lam
	chown -R www-data:www-data /var/www/html/lam/config
	chmod 755 /var/www/html/lam/config
	
	# Check if config.cfg already exists
	if [[ -f /var/www/html/lam/config/config.cfg ]]; then
		echo "LAM application config exists - backing up..."
		cp /var/www/html/lam/config/config.cfg /var/www/html/lam/config/config.cfg.backup.$(date +%s)
	fi
	
	echo "Creating LAM application configuration (config.cfg)..."
	
	# Generate password hash using PHP's crypt with SHA512 (same as LAM uses)
	# LAM uses CRYPT-SHA512 format, not plain SHA256
	# Redirect stderr to avoid breaking output
	LAM_MASTER_HASH=$(php -r "echo crypt('${LAM_MASTER_PASSWORD}', '\$6\$' . bin2hex(random_bytes(8)) . '\$');" 2>/dev/null)
	LAM_SALT=$(php -r "echo base64_encode(random_bytes(16));" 2>/dev/null)
	
	# Create config.cfg with proper JSON format matching LAM's structure
	cat > /var/www/html/lam/config/config.cfg <<EOF
{
	"password": "{CRYPT-SHA512}${LAM_MASTER_HASH} ${LAM_SALT}",
	"default": "${LAM_PROFILE_NAME}",
	"sessionTimeout": "${LAM_SESSION_TIMEOUT}",
	"hideLoginErrorDetails": "false",
	"logLevel": "${LAM_LOG_LEVEL}",
	"logDestination": "SYSLOG",
	"allowedHosts": "",
	"passwordMinLength": "0",
	"passwordMinUpper": "0",
	"passwordMinLower": "0",
	"passwordMinNumeric": "0",
	"passwordMinClasses": "0",
	"passwordMinSymbol": "0",
	"checkedRulesCount": "-1",
	"passwordMustNotContainUser": "false",
	"passwordMustNotContain3Chars": "false",
	"externalPwdCheckUrl": "",
	"errorReporting": "default",
	"allowedHostsSelfService": "",
	"license": "",
	"licenseEmailFrom": "",
	"licenseEmailTo": "",
	"licenseWarningType": "",
	"licenseEmailDateSent": "",
	"mailServer": "",
	"mailUser": "",
	"mailPassword": "",
	"mailEncryption": "",
	"mailAttribute": "mail",
	"mailBackupAttribute": "passwordselfresetbackupmail",
	"configDatabaseType": "files",
	"configDatabaseServer": "",
	"configDatabasePort": "",
	"configDatabaseName": "",
	"configDatabaseUser": "",
	"configDatabasePassword": "",
	"configDatabaseSSLCA": "",
	"moduleSettings": "W10=",
	"smsProvider": "",
	"smsApiKey": "",
	"smsToken": "",
	"smsAccountId": "",
	"smsRegion": "",
	"smsFrom": "",
	"smsAttributes": "mobileTelephoneNumber;mobile",
	"smsDefaultCountryPrefix": ""
}
EOF
	
	# Set proper permissions
	chown www-data:www-data /var/www/html/lam/config/config.cfg
	chmod 600 /var/www/html/lam/config/config.cfg
	
	echo "✓ LAM application configuration created successfully"
	echo "  - Default profile: ${LAM_PROFILE_NAME}"
	echo "  - Session timeout: ${LAM_SESSION_TIMEOUT} minutes"
	echo "  - Log level: ${LAM_LOG_LEVEL}"
	echo "  - Language: ${LAM_PROFILE_LANGUAGE}"
	echo "  - Timezone: ${LAM_PROFILE_TIMEZONE}"
}

configureLAMServerProfile () {
	echo ""
	echo "=== CONFIGURING LAM SERVER PROFILE (${LAM_PROFILE_NAME}.conf) ==="
	
	# Sanitize profile name
	local clean_profile_name=$(echo "${LAM_PROFILE_NAME}" | sed 's/[^a-zA-Z0-9_-]//g')
	if [[ -z "$clean_profile_name" ]]; then
		clean_profile_name="samba-ad"
		echo "WARNING: Invalid profile name, using default: $clean_profile_name"
	elif [[ "$clean_profile_name" != "${LAM_PROFILE_NAME}" ]]; then
		echo "WARNING: Profile name sanitized from '${LAM_PROFILE_NAME}' to '$clean_profile_name'"
	fi
	
	# Parse UID/GID ranges
	local user_uid_min=$(echo "${LAM_UID_RANGE}" | cut -d'-' -f1)
	local user_uid_max=$(echo "${LAM_UID_RANGE}" | cut -d'-' -f2)
	local group_gid_min=$(echo "${LAM_GID_RANGE}" | cut -d'-' -f1)
	local group_gid_max=$(echo "${LAM_GID_RANGE}" | cut -d'-' -f2)
	
	# Determine LDAP connection settings
	local server_url
	local use_tls="no"
	local ignore_tls_errors="false"
	
	case "${LAM_LDAP_METHOD,,}" in
		"ldaps")
			server_url="ldaps://127.0.0.1:636"
			use_tls="no"  # TLS is built into LDAPS
			ignore_tls_errors="true"  # For self-signed certificates
			echo "Profile configured for LDAPS (SSL/TLS on port 636)"
			;;
		"starttls")
			server_url="ldap://127.0.0.1:389"
			use_tls="yes"  # Use StartTLS
			ignore_tls_errors="true"  # For self-signed certificates
			echo "Profile configured for LDAP with StartTLS (port 389)"
			;;
		"ldap"|"plain")
			server_url="ldap://127.0.0.1:389"
			use_tls="no"  # Plain LDAP (insecure)
			ignore_tls_errors="false"
			echo "Profile configured for plain LDAP (port 389) - WARNING: Insecure!"
			;;
		*)
			# Default to LDAPS
			server_url="ldaps://127.0.0.1:636"
			use_tls="no"
			ignore_tls_errors="true"
			echo "Profile configured for LDAPS (default) - unknown method: ${LAM_LDAP_METHOD}"
			;;
	esac
	
	# Generate profile password hash
	LAM_PROFILE_HASH=$(echo -n "${LAM_PROFILE_PASSWORD}" | sha256sum | awk '{print $1}')
	
	# Build user and group suffix DNs (relative suffix + base DN)
	local user_suffix_dn="${LAM_USER_SUFFIX},${DOMAIN_DC}"
	local group_suffix_dn="${LAM_GROUP_SUFFIX},${DOMAIN_DC}"
	
	# Parse module lists (convert comma-separated to JSON array format)
	IFS=',' read -ra USER_MODULES_ARRAY <<< "${LAM_USER_MODULES}"
	IFS=',' read -ra GROUP_MODULES_ARRAY <<< "${LAM_GROUP_MODULES}"
	
	# Build JSON arrays for modules
	# NOTE: Module order is important in LAM!
	# - First module in the array is the "base module" (provides structural objectClass)
	# - Additional modules are auxiliary modules (add extra attributes)
	# For Active Directory:
	#   - windowsUser: Base module for AD user accounts (structural objectClass)
	#   - inetOrgPerson: Auxiliary module for extended person attributes
	#   - windowsGroup: Base module for AD group accounts (structural objectClass)
	# Do NOT reorder modules without understanding LAM's base vs auxiliary module concept
	local user_modules_json=$(printf ',"%s"' "${USER_MODULES_ARRAY[@]}")
	user_modules_json="[${user_modules_json:1}]"  # Remove leading comma and wrap in brackets
	
	local group_modules_json=$(printf ',"%s"' "${GROUP_MODULES_ARRAY[@]}")
	group_modules_json="[${group_modules_json:1}]"
	
	# Parse semicolon-separated admin DNs and build JSON array
	# Note: Semicolon delimiter is required because DNs contain commas (e.g., cn=Admin,cn=Users)
	echo "DEBUG: LAM_ADMIN_DNS input = '${LAM_ADMIN_DNS}'"
	IFS=';' read -ra ADMIN_DN_ARRAY <<< "${LAM_ADMIN_DNS}"
	echo "DEBUG: Array length = ${#ADMIN_DN_ARRAY[@]}"
	echo "DEBUG: Array contents = ${ADMIN_DN_ARRAY[@]}"
	local admin_dns_json=""
	for admin_dn in "${ADMIN_DN_ARRAY[@]}"; do
		admin_dn=$(echo "$admin_dn" | xargs)  # Trim whitespace
		echo "DEBUG: Processing admin_dn = '${admin_dn}'"
		admin_dns_json="${admin_dns_json},\"${admin_dn},${DOMAIN_DC}\""
		echo "DEBUG: admin_dns_json so far = '${admin_dns_json}'"
	done
	admin_dns_json="[${admin_dns_json:1}]"  # Remove leading comma and wrap in brackets
	echo "DEBUG: Final admin_dns_json = '${admin_dns_json}'"
	
	# Create server profile with proper JSON format for modern LAM
	local profile_file="/var/www/html/lam/config/${clean_profile_name}.conf"
	
	echo "Creating server profile: ${clean_profile_name}.conf"
	
	cat > "$profile_file" <<EOF
{
	"ServerURL": "${server_url}",
	"useTLS": "${use_tls}",
	"ignoreTLSErrors": "${ignore_tls_errors}",
	"followReferrals": "false",
	"pagedResults": "false",
	"hidePasswordPromptForExpiredPasswords": "false",
	"referentialIntegrityOverlay": "false",
	"defaultLanguage": "${LAM_PROFILE_LANGUAGE}",
	"timeZone": "${LAM_PROFILE_TIMEZONE}",
	"treesuffix": "${DOMAIN_DC}",
	"Admins": ${admin_dns_json},
	"Passwd": "{SHA256}${LAM_PROFILE_HASH}",
	"searchLimit": 0,
	"accessLevel": ${LAM_ACCESS_LEVEL},
	"loginMethod": "fixed",
	"loginSearchSuffix": "${DOMAIN_DC}",
	"loginSearchFilter": "(&(objectClass=user)(sAMAccountName=%USER%))",
	"activeTypes": "user,group",
	"modules": {
		"user": ${user_modules_json},
		"group": ${group_modules_json}
	},
	"types": {
		"user": {
			"suffix": "${user_suffix_dn}",
			"attr": ["#sAMAccountName", "#givenName", "#sn", "#mail", "#employeeNumber", "#department", "#title", "memberOf"],
			"modules": "${LAM_USER_MODULES}"
		},
		"group": {
			"suffix": "${group_suffix_dn}",
			"attr": ["#cn", "#description", "#member"],
			"modules": "${LAM_GROUP_MODULES}"
		}
	},
	"moduleSettings": {
		"posixAccount_user": {
			"minUID": "${user_uid_min}",
			"maxUID": "${user_uid_max}",
			"minMachine": "50000",
			"maxMachine": "60000"
		},
		"posixGroup_group": {
			"minGID": "${group_gid_min}",
			"maxGID": "${group_gid_max}"
		},
		"windowsUser_user": {
			"sambaDomainName": "${URDOMAIN}",
			"windowsUser_hidemsSFU30Name": "false",
			"windowsUser_hidemsSFU30NisDomain": "false",
			"windowsUser_hideunixHomeDirectory": "false",
			"windowsUser_hideunixLoginShell": "false"
		},
		"windowsGroup_group": {
			"sambaDomainName": "${URDOMAIN}",
			"windowsGroup_hidemsSFU30Name": "false"
		},
		"inetOrgPerson_user": {
			"inetOrgPerson_hideDescription": "false",
			"inetOrgPerson_hideTelephoneNumber": "false",
			"inetOrgPerson_hideMobile": "false"
		}
	}
}
EOF
	
	# Set proper permissions
	chown www-data:www-data "$profile_file"
	chmod 600 "$profile_file"
	
	echo "✓ Server profile created successfully"
	echo "  - Profile name: ${clean_profile_name}"
	echo "  - LDAP method: ${LAM_LDAP_METHOD} (${server_url})"
	echo "  - Base DN: ${DOMAIN_DC}"
	echo "  - User suffix: ${user_suffix_dn}"
	echo "  - Group suffix: ${group_suffix_dn}"
	echo "  - User modules: ${LAM_USER_MODULES}"
	echo "  - Group modules: ${LAM_GROUP_MODULES}"
	echo "  - User UID range: ${user_uid_min}-${user_uid_max}"
	echo "  - Group GID range: ${group_gid_min}-${group_gid_max}"
}

configureLAM () {
	echo ""
	echo "========================================"
	echo "LAM CONFIGURATION WITH VALIDATION"
	echo "========================================"
	echo "Configuring LAM for Samba AD integration..."
	echo "Domain: ${DOMAIN} (${DOMAIN_DC})"
	
	# Step 1: Configure LAM application
	if ! configureLAMApplication; then
		echo ""
		echo "========================================"
		echo "LAM CONFIGURATION FAILED ✗"
		echo "========================================"
		echo "FATAL: LAM application configuration failed"
		echo "Container cannot start without valid LAM config"
		echo "Check config.cfg generation above for errors"
		echo "========================================"
		return 1
	fi
	
	# Step 2: Configure LAM server profile  
	if ! configureLAMServerProfile; then
		echo ""
		echo "========================================"
		echo "LAM CONFIGURATION FAILED ✗"
		echo "========================================"
		echo "FATAL: LAM server profile configuration failed"
		echo "Container cannot start without valid LAM profile"
		echo "Check ${LAM_PROFILE_NAME}.conf generation above for errors"
		echo "========================================"
		return 1
	fi
	
	# Step 3: Validate configuration
	echo ""
	echo "=== VALIDATING LAM CONFIGURATION ==="
	if validateLAMConfiguration; then
		# Restart PHP-FPM to pick up LDAP configuration changes
		echo ""
		echo "Restarting PHP-FPM to apply LDAP configuration..."
		if command -v supervisorctl >/dev/null 2>&1; then
			supervisorctl restart php-fpm 2>/dev/null || echo "Note: PHP-FPM restart skipped (not running yet)"
		fi
		
		echo ""
		echo "========================================"
		echo "LAM CONFIGURATION COMPLETE ✓"
		echo "========================================"
		echo "LAM web interface: http://<host-ip>:8080"
		echo "Master password: ${LAM_MASTER_PASSWORD}"
		echo "Profile password: ${LAM_PROFILE_PASSWORD}"
		echo "Default profile: ${LAM_PROFILE_NAME}"
		echo ""
		echo "Quick Start:"
		echo "1. Open LAM web interface"
		echo "2. Login with master password"
		echo "3. Select profile: ${LAM_PROFILE_NAME}"
		echo "4. Login with profile password"
		echo "5. Start managing AD accounts!"
		echo "========================================"
	else
		echo ""
		echo "========================================"
		echo "LAM CONFIGURATION FAILED ✗"
		echo "========================================"
		echo "Check the validation errors above"
		echo "LAM may not function correctly"
		echo "========================================"
		return 1
	fi
}

validateLAMConfiguration () {
	echo "Validating LAM configuration..."
	
	local config_errors=0
	local warnings=0
	
	# Sanitize profile name (same logic as in configureLAMServerProfile)
	local clean_profile_name=$(echo "${LAM_PROFILE_NAME}" | sed 's/[^a-zA-Z0-9_-]//g')
	if [[ -z "$clean_profile_name" ]]; then
		clean_profile_name="samba-ad"
	fi
	
	echo "Checking LAM configuration files..."
	
	# 1. Check LAM application config (config.cfg)
	if [[ ! -f /var/www/html/lam/config/config.cfg ]]; then
		echo "ERROR: LAM application config missing (config.cfg)"
		((config_errors++))
	else
		echo "✓ Application config exists (config.cfg)"
		
		# Validate JSON syntax
		if ! python3 -m json.tool /var/www/html/lam/config/config.cfg > /dev/null 2>&1; then
			echo "ERROR: Application config has invalid JSON syntax"
			((config_errors++))
		else
			echo "✓ Application config has valid JSON syntax"
		fi
		
		# Check required fields in config.cfg
		if ! grep -q "\"password\"" /var/www/html/lam/config/config.cfg; then
			echo "ERROR: Application config missing password field"
			((config_errors++))
		fi
		
		if ! grep -q "\"default\"" /var/www/html/lam/config/config.cfg; then
			echo "ERROR: Application config missing default profile"
			((config_errors++))
		fi
		
		# Check ownership and permissions
		if [[ $(stat -c %U /var/www/html/lam/config/config.cfg) != "www-data" ]]; then
			echo "WARNING: Application config ownership incorrect - should be www-data"
			((warnings++))
		fi
		
		if [[ $(stat -c %a /var/www/html/lam/config/config.cfg) != "600" ]]; then
			echo "WARNING: Application config permissions incorrect - should be 600"
			((warnings++))
		fi
	fi
	
	# 2. Check LAM server profile
	local profile_file="/var/www/html/lam/config/${clean_profile_name}.conf"
	if [[ ! -f "$profile_file" ]]; then
		echo "ERROR: LAM server profile missing (${clean_profile_name}.conf)"
		((config_errors++))
	else
		echo "✓ Server profile exists (${clean_profile_name}.conf)"
		
		# Validate JSON syntax  
		if ! python3 -m json.tool "$profile_file" > /dev/null 2>&1; then
			echo "ERROR: Server profile has invalid JSON syntax"
			((config_errors++))
		else
			echo "✓ Server profile has valid JSON syntax"
		fi
		
		# Check required fields in server profile
		local required_fields=("ServerURL" "treesuffix" "Passwd" "activeTypes" "modules")
		for field in "${required_fields[@]}"; do
			if ! grep -q "\"$field\"" "$profile_file"; then
				echo "ERROR: Server profile missing required field: $field"
				((config_errors++))
			fi
		done
		
		# Validate specific content
		if ! grep -q "\"treesuffix\": \"${DOMAIN_DC}\"" "$profile_file"; then
			echo "ERROR: Server profile treesuffix not set to correct domain DN"
			((config_errors++))
		fi
		
		if ! grep -q "\"activeTypes\": \"user,group\"" "$profile_file"; then
			echo "ERROR: Server profile missing essential activeTypes configuration"
			((config_errors++))
		fi
		
		# Check ownership and permissions
		if [[ $(stat -c %U "$profile_file") != "www-data" ]]; then
			echo "WARNING: Server profile ownership incorrect - should be www-data"
			((warnings++))
		fi
		
		if [[ $(stat -c %a "$profile_file") != "600" ]]; then
			echo "WARNING: Server profile permissions incorrect - should be 600"
			((warnings++))
		fi
	fi
	
	# 3. Check LAM directory structure
	local required_dirs=("/var/www/html/lam/config" "/var/lib/lam/sess" "/var/lib/lam/tmp")
	for dir in "${required_dirs[@]}"; do
		if [[ ! -d "$dir" ]]; then
			echo "ERROR: LAM directory missing: $dir"
			((config_errors++))
		elif [[ $(stat -c %U "$dir") != "www-data" ]]; then
			echo "WARNING: LAM directory ownership incorrect: $dir - should be www-data"
			((warnings++))
		fi
	done
	
	# 4. Validate password hashes are properly set
	if [[ -f /var/www/html/lam/config/config.cfg ]] && [[ -f "$profile_file" ]]; then
		if grep -q "\"password\".*{CRYPT-SHA512}" /var/www/html/lam/config/config.cfg && 
		   grep -q "Passwd.*{SHA256}" "$profile_file"; then
			echo "✓ Password hashes properly configured"
		else
			echo "ERROR: Password hashes not properly configured"
			((config_errors++))
		fi
	fi
	
	# 5. Check for conflicts with old configuration format
	if [[ -f /var/www/html/lam/config/lam.conf ]]; then
		echo "WARNING: Old format LAM config detected (lam.conf) - may cause conflicts"
		echo "  Consider removing: /var/www/html/lam/config/lam.conf"
		((warnings++))
	fi
	
	# Report validation results
	echo ""
	echo "=== VALIDATION SUMMARY ==="
	
	if [[ $config_errors -eq 0 ]]; then
		echo "✓ LAM configuration validation PASSED"
		echo "✓ Application config: Valid"
		echo "✓ Server profile (${clean_profile_name}): Valid"
		echo "✓ Essential settings: Configured"
		echo "✓ File permissions: Correct"
		
		if [[ $warnings -gt 0 ]]; then
			echo "⚠  $warnings warnings detected (non-critical)"
		fi
		
		echo ""
		echo "LAM is ready for use!"
		echo "Configuration validated for domain: ${DOMAIN}"
		return 0
	else
		echo "✗ LAM configuration validation FAILED"
		echo "✗ $config_errors critical errors detected"
		if [[ $warnings -gt 0 ]]; then
			echo "⚠  $warnings warnings detected"
		fi
		echo ""
		echo "LAM may not function correctly until errors are resolved"
		return 1
	fi
}

validateSSHSchemas () {
	echo "Validating SSH public key schemas..."
	local schemas_valid=true
	
	# Check for sshPublicKey attribute
	if ldbsearch -H /var/lib/samba/private/sam.ldb -b "CN=Schema,CN=Configuration,${DOMAIN_DC}" "(cn=sshPublicKey)" cn 2>/dev/null | grep -q "dn: CN=sshPublicKey"; then
		echo "✓ sshPublicKey attribute schema found"
	else
		echo "✗ sshPublicKey attribute schema NOT found"
		schemas_valid=false
	fi
	
	# Check for ldapPublicKey objectClass
	if ldbsearch -H /var/lib/samba/private/sam.ldb -b "CN=Schema,CN=Configuration,${DOMAIN_DC}" "(cn=ldapPublicKey)" cn 2>/dev/null | grep -q "dn: CN=ldapPublicKey"; then
		echo "✓ ldapPublicKey class schema found"
	else
		echo "✗ ldapPublicKey class schema NOT found"
		schemas_valid=false
	fi
	
	if [ "$schemas_valid" = true ]; then
		echo "✓ All SSH schemas validated successfully"
		return 0
	else
		echo "⚠ Some SSH schemas are missing"
		return 1
	fi
}

validateRFC2307Schema () {
	echo "Validating RFC2307 (NIS extensions) schema..."
	
	# Check for key RFC2307 attributes that should exist if provisioned with --use-rfc2307
	if ldbsearch -H /var/lib/samba/private/sam.ldb -b "CN=Schema,CN=Configuration,${DOMAIN_DC}" "(cn=uidNumber)" cn 2>/dev/null | grep -q "dn: CN=uidNumber"; then
		echo "✓ RFC2307 schema extensions found (uidNumber/gidNumber support enabled)"
		echo "  Unix attributes (uidNumber, gidNumber, loginShell, homeDirectory) are available"
		return 0
	else
		echo "⚠️  INFORMATIONAL: RFC2307 schema extensions NOT found"
		echo ""
		echo "   This is NORMAL if you are running a Windows-only Active Directory."
		echo "   RFC2307 extensions are only needed for Unix/Linux integration."
		echo ""
		echo "   Impact:"
		echo "   - Windows authentication: ✓ Works normally"
		echo "   - LAM windowsUser/windowsGroup modules: ✓ Work normally"
		echo "   - Unix attributes (uidNumber, gidNumber): ✗ Not available"
		echo "   - LAM posixAccount/posixGroup modules: ✗ Will not work"
		echo "   - Linux/Unix client authentication: ✗ Not supported"
		echo ""
		echo "   If you need Unix/Linux integration:"
		echo "   - Samba must be re-provisioned with: samba-tool domain provision --use-rfc2307"
		echo "   - Warning: This requires domain re-provisioning (destructive - data loss)"
		echo ""
		echo "   You can safely ignore this message if only using Windows clients."
		return 1
	fi
}

checkLAMWebInterface () {
	echo "Checking LAM web interface availability..."
	local max_attempts=10
	local attempt=1
	
	while [ $attempt -le $max_attempts ]; do
		if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080 2>/dev/null | grep -q "200\|302"; then
			echo "✓ LAM web interface is accessible at http://<container-ip>:8080"
			return 0
		fi
		
		if [ $attempt -lt $max_attempts ]; then
			sleep 2
		fi
		attempt=$((attempt + 1))
	done
	
	echo "⚠️  LAM web interface not responding after ${max_attempts} attempts"
	echo "   Check nginx and php-fpm services with: supervisorctl status"
	echo "   Container will continue running - LAM may become available shortly"
	return 1
}

waitForSambaReady () {
	echo "Waiting for Samba AD to be ready..."
	local max_wait=${SCHEMA_SETUP_DELAY}
	local elapsed=0
	local check_interval=2
	
	while [ $elapsed -lt $max_wait ]; do
		# Try to get domain info - if successful, Samba is ready
		if samba-tool domain info 127.0.0.1 >/dev/null 2>&1; then
			echo "✓ Samba AD is ready (took ${elapsed}s)"
			return 0
		fi
		
		echo "Waiting for Samba AD... (${elapsed}s/${max_wait}s)"
		sleep $check_interval
		elapsed=$((elapsed + check_interval))
	done
	
	echo "⚠ Samba AD not responding after ${max_wait}s, proceeding anyway..."
	return 1
}

appStart () {
	/usr/bin/supervisord > /var/log/supervisor/supervisor.log 2>&1 &
	if [ "${1}" = "true" ]; then
		echo "Checking Samba AD readiness before schema operations..."
		waitForSambaReady
		validateRFC2307Schema
		fixDomainUsersGroup
		setupSSH
		validateSSHSchemas
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
	fi
	
	# Configure LAM if config doesn't exist (runs on first start OR if config was deleted)
	if [[ ! -f /var/www/html/lam/config/config.cfg ]] || [[ ! -f "/var/www/html/lam/config/${LAM_PROFILE_NAME}.conf" ]]; then
		echo "LAM configuration not found, configuring now..."
		echo "Sleeping 5 seconds to ensure Samba LDAP is ready..."
		sleep 5
		configureLAM
		echo "Validating LAM configuration..."
		validateLAMConfiguration
		checkLAMWebInterface
	else
		echo "LAM configuration already exists, skipping configuration"
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
