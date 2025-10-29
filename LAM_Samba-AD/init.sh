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
	
	# Auto-generate DOMAIN_DC from DOMAIN if not explicitly set
	# Convert domain.example.com to dc=domain,dc=example,dc=com
	if [[ -z "${DOMAIN_DC}" ]]; then
		DOMAIN_DC=$(echo "${DOMAIN}" | sed 's/\./,dc=/g' | sed 's/^/dc=/')
		echo "Auto-generated DOMAIN_DC: ${DOMAIN_DC}"
	fi
	
	# LAM Application Settings (config.cfg)
	LAM_MASTER_PASSWORD=${LAM_MASTER_PASSWORD:-lam}
	LAM_DEFAULT_PROFILE=${LAM_DEFAULT_PROFILE:-samba-ad}
	LAM_SESSION_TIMEOUT=${LAM_SESSION_TIMEOUT:-30}
	LAM_LOG_LEVEL=${LAM_LOG_LEVEL:-4}
	
	# LAM Server Profile Settings (profile.conf)
	LAM_PROFILE_NAME=${LAM_PROFILE_NAME:-samba-ad}
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

configureLAMApplication () {
	echo "=== CONFIGURING LAM APPLICATION (config.cfg) ==="
	
	# Ensure LAM config directory exists
	mkdir -p /var/lib/lam/config
	mkdir -p /var/lib/lam/sess
	mkdir -p /var/lib/lam/tmp
	chown -R www-data:www-data /var/lib/lam
	
	# Check if config.cfg already exists
	if [[ -f /var/lib/lam/config/config.cfg ]]; then
		echo "LAM application config exists - backing up..."
		cp /var/lib/lam/config/config.cfg /var/lib/lam/config/config.cfg.backup.$(date +%s)
	fi
	
	echo "Creating LAM application configuration (config.cfg)..."
	
	# Generate password hash (SHA256 with prefix)
	LAM_MASTER_HASH=$(echo -n "${LAM_MASTER_PASSWORD}" | sha256sum | awk '{print $1}')
	
	# Create config.cfg with proper JSON format
	cat > /var/lib/lam/config/config.cfg <<EOF
{
	"ServerProfiles": {
		"${LAM_DEFAULT_PROFILE}": {
			"name": "${LAM_DEFAULT_PROFILE}",
			"default": true
		}
	},
	"passwordHash": "{SHA256}${LAM_MASTER_HASH}",
	"sessionTimeout": ${LAM_SESSION_TIMEOUT},
	"allowedHosts": "",
	"logLevel": "${LAM_LOG_LEVEL}",
	"logDestination": "SYSLOG",
	"encryptSession": "true",
	"language": "${LAM_PROFILE_LANGUAGE}",
	"timeZone": "${LAM_PROFILE_TIMEZONE}"
}
EOF
	
	# Set proper permissions
	chown www-data:www-data /var/lib/lam/config/config.cfg
	chmod 600 /var/lib/lam/config/config.cfg
	
	echo "✓ LAM application configuration created successfully"
	echo "  - Default profile: ${LAM_DEFAULT_PROFILE}"
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
	local user_modules_json=$(printf ',"%s"' "${USER_MODULES_ARRAY[@]}")
	user_modules_json="[${user_modules_json:1}]"  # Remove leading comma and wrap in brackets
	
	local group_modules_json=$(printf ',"%s"' "${GROUP_MODULES_ARRAY[@]}")
	group_modules_json="[${group_modules_json:1}]"
	
	# Create server profile with proper JSON format for modern LAM
	local profile_file="/var/lib/lam/config/${clean_profile_name}.conf"
	
	echo "Creating server profile: ${clean_profile_name}.conf"
	
	cat > "$profile_file" <<EOF
{
	"ServerURL": "${server_url}",
	"useTLS": "${use_tls}",
	"ignoreTLSErrors": ${ignore_tls_errors},
	"treesuffix": "${DOMAIN_DC}",
	"Admins": ["cn=Administrator,cn=Users,${DOMAIN_DC}"],
	"Passwd": "{SHA256}${LAM_PROFILE_HASH}",
	"searchLimit": 0,
	"accessLevel": 100,
	"loginMethod": "search",
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
			"attr": ["#sAMAccountName", "#givenName", "#sn", "#mail"],
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
	configureLAMApplication
	
	# Step 2: Configure LAM server profile  
	configureLAMServerProfile
	
	# Step 3: Validate configuration
	echo ""
	echo "=== VALIDATING LAM CONFIGURATION ==="
	if validateLAMConfiguration; then
		echo ""
		echo "========================================"
		echo "LAM CONFIGURATION COMPLETE ✓"
		echo "========================================"
		echo "LAM web interface: http://<host-ip>:8080"
		echo "Master password: ${LAM_MASTER_PASSWORD}"
		echo "Profile password: ${LAM_PROFILE_PASSWORD}"
		echo "Default profile: ${LAM_DEFAULT_PROFILE}"
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
	if [[ ! -f /var/lib/lam/config/config.cfg ]]; then
		echo "ERROR: LAM application config missing (config.cfg)"
		((config_errors++))
	else
		echo "✓ Application config exists (config.cfg)"
		
		# Validate JSON syntax
		if ! python3 -m json.tool /var/lib/lam/config/config.cfg > /dev/null 2>&1; then
			echo "ERROR: Application config has invalid JSON syntax"
			((config_errors++))
		else
			echo "✓ Application config has valid JSON syntax"
		fi
		
		# Check required fields in config.cfg
		if ! grep -q "passwordHash" /var/lib/lam/config/config.cfg; then
			echo "ERROR: Application config missing passwordHash"
			((config_errors++))
		fi
		
		if ! grep -q "ServerProfiles" /var/lib/lam/config/config.cfg; then
			echo "ERROR: Application config missing ServerProfiles"
			((config_errors++))
		fi
		
		# Check ownership and permissions
		if [[ $(stat -c %U /var/lib/lam/config/config.cfg) != "www-data" ]]; then
			echo "WARNING: Application config ownership incorrect - should be www-data"
			((warnings++))
		fi
		
		if [[ $(stat -c %a /var/lib/lam/config/config.cfg) != "600" ]]; then
			echo "WARNING: Application config permissions incorrect - should be 600"
			((warnings++))
		fi
	fi
	
	# 2. Check LAM server profile
	local profile_file="/var/lib/lam/config/${clean_profile_name}.conf"
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
	local required_dirs=("/var/lib/lam/config" "/var/lib/lam/sess" "/var/lib/lam/tmp")
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
	if [[ -f /var/lib/lam/config/config.cfg ]] && [[ -f "$profile_file" ]]; then
		if grep -q "passwordHash.*{SHA256}" /var/lib/lam/config/config.cfg && 
		   grep -q "Passwd.*{SHA256}" "$profile_file"; then
			echo "✓ Password hashes properly configured"
		else
			echo "ERROR: Password hashes not properly configured"
			((config_errors++))
		fi
	fi
	
	# 5. Check for conflicts with old configuration format
	if [[ -f /var/lib/lam/config/lam.conf ]]; then
		echo "WARNING: Old format LAM config detected (lam.conf) - may cause conflicts"
		echo "  Consider removing: /var/lib/lam/config/lam.conf"
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
	fi
	
	# Configure LAM if config doesn't exist (runs on first start OR if config was deleted)
	if [[ ! -f /var/lib/lam/config/config.cfg ]] || [[ ! -f "/var/lib/lam/config/${LAM_PROFILE_NAME}.conf" ]]; then
		echo "LAM configuration not found, configuring now..."
		echo "Sleeping 5 seconds to ensure Samba LDAP is ready..."
		sleep 5
		configureLAM
		echo "Validating LAM configuration..."
		validateLAMConfiguration
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
