# LAM Deployment Guide for Unraid

This guide provides step-by-step instructions for deploying LDAP Account Manager (LAM) on Unraid using the provided Docker template.

## Prerequisites

### System Requirements
- Unraid 6.8.0 or higher
- Minimum 1GB RAM available for container
- 1GB free space for AppData
- Network access to LDAP server

### LDAP Server Requirements
- Working LDAP server (OpenLDAP, Active Directory, etc.)
- LDAP administrator credentials
- Network connectivity between Unraid and LDAP server
- Firewall rules allowing LDAP traffic (389/636)

## Pre-Deployment Checklist

### 1. LDAP Server Information
Gather the following information before deployment:

```
LDAP Server: _________________________
Port: _____________ (389 for LDAP, 636 for LDAPS)
Domain: ___________________________
Base DN: __________________________
Admin User DN: ____________________
Admin Password: ___________________
```

### 2. Security Planning
- [ ] Choose a strong LAM master password
- [ ] Plan network access restrictions
- [ ] Verify LDAP server security configuration
- [ ] Consider using LDAPS for encrypted connections

### 3. Unraid Preparation
- [ ] Ensure Docker service is enabled
- [ ] Check available ports (default: 8080)
- [ ] Plan AppData location
- [ ] Verify network configuration

## Deployment Steps

### Step 1: Add the Template

#### Method A: Manual Template Addition
1. Navigate to Docker tab in Unraid WebGUI
2. Click "Add Container"
3. Set "Template repositories" to include:
   ```
   https://raw.githubusercontent.com/your-repo/unraid-templates/main/
   ```
4. Click "Save"

#### Method B: Direct Template Import
1. Navigate to Docker tab
2. Click "Add Container"
3. Click "Template" dropdown
4. Select "LAM" from the list

### Step 2: Configure Basic Settings

1. **Container Name**: `LAM` (or customize as needed)
2. **Repository**: `ghcr.io/ldapaccountmanager/lam:stable`
3. **Network Type**: `bridge`

### Step 3: Configure Port Mapping

1. **Container Port**: `80`
2. **Host Port**: `8080` (or choose available port)
3. **Protocol**: `TCP`

### Step 4: Configure Storage

1. **Container Path**: `/var/lib/ldap-account-manager`
2. **Host Path**: `/mnt/user/appdata/lam`
3. **Access Mode**: `Read/Write`

### Step 5: Configure Environment Variables

#### Required Variables

1. **LAM_PASSWORD**
   ```
   Value: [YOUR_SECURE_PASSWORD]
   Description: Master password for LAM configuration
   Security: CHANGE FROM DEFAULT!
   ```

2. **LDAP_SERVER**
   ```
   Examples:
   - ldap://openldap.example.com:389
   - ldaps://ad.company.com:636
   - ldap://192.168.1.100:389
   ```

3. **LDAP_DOMAIN**
   ```
   Example: company.com
   Note: Used to generate Base DN if not specified
   ```

#### Optional Variables (Customize as needed)

4. **LDAP_BASE_DN**
   ```
   Default: dc=example,dc=com
   Custom: dc=company,dc=com
   ```

5. **LDAP_USERS_DN**
   ```
   Default: ou=people,dc=example,dc=com
   Custom: ou=users,dc=company,dc=com
   ```

6. **LDAP_GROUPS_DN**
   ```
   Default: ou=groups,dc=example,dc=com
   Custom: ou=groups,dc=company,dc=com
   ```

7. **LDAP_USER**
   ```
   Default: cn=admin,dc=example,dc=com
   Custom: cn=administrator,dc=company,dc=com
   ```

#### Advanced Variables

8. **LAM_LANG**
   ```
   Options: en_US, de_DE, fr_FR, es_ES, etc.
   Default: en_US
   ```

9. **LAM_SKIP_PRECONFIGURE**
   ```
   Default: false
   Set to true if using external configuration files
   ```

10. **LAM_DISABLE_TLS_CHECK**
    ```
    Default: false
    WARNING: Only set to true for development!
    ```

### Step 6: Deploy Container

1. Review all settings
2. Click "Apply"
3. Wait for container download and startup
4. Monitor logs for any errors

## Post-Deployment Configuration

### Step 1: Initial Access

1. Open web browser
2. Navigate to: `http://UNRAID-IP:8080`
3. You should see LAM login page

### Step 2: First Login

1. **Username**: `admin`
2. **Password**: [Your LAM_PASSWORD value]
3. Click "Login"

### Step 3: Configuration Wizard

If LAM starts the configuration wizard:

1. **Language**: Select preferred language
2. **Profile**: Create or select server profile
3. **LDAP Connection**: Verify settings
4. **Account Types**: Select required modules
5. **Save Configuration**

### Step 4: Test LDAP Connection

1. Go to "Configuration" → "Edit Server Profiles"
2. Click "Test connection"
3. Enter LDAP admin credentials
4. Verify successful connection

### Step 5: Configure Account Types

Enable required account modules:
- Unix accounts
- Samba accounts
- Group accounts
- Others as needed

## Verification Steps

### 1. Container Health
```bash
# Check container status
docker ps | grep lam

# View container logs
docker logs lam
```

### 2. WebUI Access
- [ ] Can access LAM interface
- [ ] Login works with configured password
- [ ] No JavaScript errors in browser console

### 3. LDAP Connection
- [ ] Connection test passes
- [ ] Can browse LDAP tree
- [ ] Can view existing accounts

### 4. Persistent Storage
- [ ] Configuration saves after container restart
- [ ] Files exist in `/mnt/user/appdata/lam`
- [ ] Proper file permissions

## Troubleshooting Common Issues

### Container Won't Start
```bash
# Check logs
docker logs lam

# Common causes:
# - Port conflict
# - Permission issues
# - Invalid environment variables
```

### Cannot Access WebUI
- Verify port mapping
- Check Unraid firewall settings
- Confirm container is running
- Test with different browser

### LDAP Connection Failed
- Verify LDAP server accessibility
- Check credentials
- Validate DN formats
- Test network connectivity

### Configuration Not Persistent
- Check AppData path mapping
- Verify file permissions
- Ensure sufficient disk space

## Security Hardening

### 1. Password Security
```bash
# Use strong passwords
LAM_PASSWORD: Complex password with special characters
LDAP Admin: Strong domain admin password
```

### 2. Network Security
```bash
# Restrict access by IP
# Configure in Unraid network settings or external firewall
# Allow only necessary IP ranges
```

### 3. LDAP Security
```bash
# Use LDAPS when possible
LDAP_SERVER: ldaps://server:636

# Disable TLS check only for development
LAM_DISABLE_TLS_CHECK: false
```

### 4. Regular Maintenance
- Update LAM container regularly
- Monitor access logs
- Review LDAP permissions
- Backup configuration files

## Backup and Recovery

### Configuration Backup
```bash
# Backup AppData directory
tar -czf lam-backup-$(date +%Y%m%d).tar.gz /mnt/user/appdata/lam
```

### Recovery Process
1. Stop LAM container
2. Restore AppData from backup
3. Start LAM container
4. Verify configuration

## Advanced Configuration

### External Configuration Files
1. Set `LAM_SKIP_PRECONFIGURE=true`
2. Place configuration files in AppData directory
3. Restart container

### Database Backend
1. Configure through LAM web interface
2. Set database connection parameters
3. Migrate from file-based configuration

### SSL/TLS Certificates
1. Mount certificate files into container
2. Configure through LAM interface
3. Update Apache configuration if needed

## Performance Optimization

### Container Resources
```yaml
# Optional: Set resource limits
memory: 512m
cpu_shares: 1024
```

### LDAP Optimization
- Use connection pooling
- Optimize search filters
- Configure appropriate timeouts
- Use LDAP indexes

## Monitoring and Logs

### Container Monitoring
```bash
# Resource usage
docker stats lam

# Live logs
docker logs -f lam
```

### LAM Application Logs
- Location: `/mnt/user/appdata/lam/logs/`
- Types: Error logs, access logs, debug logs
- Rotation: Configure through LAM interface

## Support and Resources

### Getting Help
1. Check container logs first
2. Review LAM documentation
3. Search Unraid community forums
4. Report issues with detailed logs

### Useful Commands
```bash
# Container status
docker ps | grep lam

# Enter container
docker exec -it lam sh

# View configuration
cat /mnt/user/appdata/lam/config/lam.conf
```

This deployment guide provides comprehensive instructions for successfully deploying LAM on Unraid. Follow the steps carefully and refer to the troubleshooting section if you encounter issues.