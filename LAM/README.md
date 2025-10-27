# LDAP Account Manager (LAM) - Unraid Docker Template

This repository contains an Unraid Docker template for deploying LDAP Account Manager (LAM), a web-based LDAP management interface that simplifies administration of users, groups, and other LDAP entries.

## Overview

LDAP Account Manager (LAM) is a powerful web frontend for managing entries stored in an LDAP directory. It abstracts the technical complexities of LDAP and provides an intuitive interface for managing LDAP accounts without requiring deep LDAP knowledge.

### Key Features

- **User & Group Management**: Create, modify, and delete users and groups
- **Multiple Account Types**: Support for Unix, Samba, Kolab, and other account types
- **PDF Export**: Generate PDF reports of account information
- **Multi-language Support**: Available in multiple languages
- **Template System**: Use templates for consistent account creation
- **LDAP Browser**: Direct LDAP attribute editing for advanced users
- **Self-Service Portal**: Allow users to manage their own accounts
- **Bulk Operations**: Import/export accounts via CSV

## Installation

### Prerequisites

- Unraid 6.8.0 or higher
- Access to an LDAP server (OpenLDAP, Active Directory, etc.)
- LDAP administrator credentials

### Quick Installation

1. **Add Template Repository** (if using a custom repository):
   - Go to Docker tab in Unraid
   - Click "Add Container"
   - Set "Template repositories" to include this repository URL

2. **Deploy Container**:
   - Search for "LAM" or "LDAP Account Manager"
   - Click the template
   - Configure required settings (see Configuration section)
   - Click "Apply"

3. **Access WebUI**:
   - Navigate to `http://YOUR-UNRAID-IP:8080`
   - Default login: `admin` / `lam`
   - **IMPORTANT**: Change default password immediately!

## Configuration

### Required Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `LAM_PASSWORD` | `lam` | Master password for LAM configuration (**CHANGE THIS!**) |
| `LDAP_SERVER` | `ldap://your-ldap-server:389` | LDAP server URL (ldap:// or ldaps://) |
| `LDAP_DOMAIN` | `example.com` | Your organization's domain for DN generation |

### Optional Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `LDAP_BASE_DN` | `dc=example,dc=com` | Base Distinguished Name for LDAP operations |
| `LDAP_USERS_DN` | `ou=people,dc=example,dc=com` | DN where user accounts are stored |
| `LDAP_GROUPS_DN` | `ou=groups,dc=example,dc=com` | DN where group accounts are stored |
| `LDAP_USER` | `cn=admin,dc=example,dc=com` | LDAP administrator account DN |
| `LAM_LANG` | `en_US` | Default interface language |
| `LAM_SKIP_PRECONFIGURE` | `false` | Skip automatic configuration |
| `LAM_DISABLE_TLS_CHECK` | `false` | Disable TLS verification (dev only) |

### Storage Configuration

- **AppData Path**: `/mnt/user/appdata/lam`
  - Contains LAM configuration files and session data
  - Ensure proper backup of this directory

### Port Configuration

- **WebUI Port**: `8080` (maps to container port 80)
  - Change if port conflicts with other services
  - Access via `http://UNRAID-IP:PORT`

## Security Considerations

### Essential Security Steps

1. **Change Default Password**:
   ```
   - Set LAM_PASSWORD to a strong, unique password
   - Never use the default "lam" password in production
   ```

2. **Use Secure LDAP Connections**:
   ```
   - Prefer ldaps:// over ldap:// for production
   - Configure proper TLS certificates
   - Only set LAM_DISABLE_TLS_CHECK=true for development
   ```

3. **Network Security**:
   ```
   - Restrict access using firewall rules
   - Consider VPN access for remote administration
   - Use strong authentication on your LDAP server
   ```

4. **Regular Updates**:
   ```
   - Keep the LAM container updated
   - Monitor for security advisories
   - Update LDAP server software regularly
   ```

### Access Control

- LAM inherits LDAP permissions from the configured admin user
- Ensure LDAP admin account has appropriate permissions
- Use least-privilege principle for LDAP service accounts

## Initial Setup Guide

### Step 1: Configure Environment Variables

1. Set `LAM_PASSWORD` to a secure password
2. Configure `LDAP_SERVER` with your LDAP server details:
   - OpenLDAP: `ldap://openldap.yourdomain.com:389`
   - Active Directory: `ldap://ad.yourdomain.com:389`
   - Secure LDAP: `ldaps://ldap.yourdomain.com:636`
3. Set `LDAP_DOMAIN` to your organization's domain

### Step 2: Start Container

1. Deploy the container with your configuration
2. Wait for container to fully start (check logs)
3. Access WebUI at configured port

### Step 3: Initial Login

1. Navigate to `http://YOUR-UNRAID-IP:8080`
2. Login with:
   - Username: `admin`
   - Password: Your `LAM_PASSWORD` value
3. Complete configuration wizard if prompted

### Step 4: Configure LDAP Connection

1. Go to Configuration → Edit Server Profiles
2. Verify LDAP server settings
3. Test LDAP connection
4. Configure account types as needed

## Troubleshooting

### Common Issues

**Cannot Access WebUI**
- Check container status and logs
- Verify port mapping configuration
- Ensure no firewall blocking access
- Check Unraid IP address and port

**LDAP Connection Failed**
- Verify LDAP server URL and port
- Check LDAP server status
- Validate LDAP admin credentials
- Review network connectivity

**Permission Denied**
- Check LDAP admin user permissions
- Verify DN configurations
- Ensure proper LDAP ACLs

**Configuration Lost After Restart**
- Verify AppData path is correctly mapped
- Check file permissions in `/mnt/user/appdata/lam`
- Ensure persistent storage is working

### Log Analysis

View container logs:
```bash
docker logs lam
```

Check LAM application logs in AppData directory:
```
/mnt/user/appdata/lam/logs/
```

### Reset Configuration

To reset LAM configuration:
1. Stop the container
2. Delete contents of `/mnt/user/appdata/lam`
3. Restart container
4. Reconfigure from scratch

## Advanced Configuration

### Using External Configuration

Set `LAM_SKIP_PRECONFIGURE=true` and provide your own configuration files in the AppData directory.

### Custom SSL Certificates

Mount certificates into the container and configure LAM to use them through the web interface.

### Database Backend

LAM can use MySQL/MariaDB instead of file-based configuration:
- Configure database settings through LAM web interface
- Ensure database server is accessible from container

## Environment Variables Reference

### File-based Secrets

For enhanced security, use file-based secrets:
- `LAM_PASSWORD_FILE`: Path to file containing LAM password
- `LDAP_USER_FILE`: Path to file containing LDAP admin DN
- `LAM_CONFIGURATION_PASSWORD_FILE`: Path to file containing database password

### Database Configuration

For MySQL/MariaDB configuration database:
- `LAM_CONFIGURATION_DATABASE=mysql`
- `LAM_CONFIGURATION_HOST`: Database server hostname
- `LAM_CONFIGURATION_PORT`: Database server port
- `LAM_CONFIGURATION_DATABASE_NAME`: Database name
- `LAM_CONFIGURATION_USER`: Database username
- `LAM_CONFIGURATION_PASSWORD`: Database password

## Support and Documentation

### Official Resources

- **Project Website**: https://www.ldap-account-manager.org/
- **Documentation**: https://www.ldap-account-manager.org/lamcms/documentation
- **GitHub Repository**: https://github.com/LDAPAccountManager/lam
- **Docker Image**: https://github.com/LDAPAccountManager/docker

### Community Support

- **Unraid Forums**: https://forums.unraid.net/
- **LAM Forums**: https://www.ldap-account-manager.org/lamcms/support

## License

This template is provided under the MIT License. LDAP Account Manager is licensed under GPL v3.

## Contributing

Contributions to improve this template are welcome:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Changelog

### v1.0.0
- Initial release
- Support for LAM 9.3
- Complete environment variable configuration
- Security-focused defaults
- Comprehensive documentation

---

**Note**: Always test in a development environment before deploying to production. Ensure you have proper backups of your LDAP directory and LAM configuration.