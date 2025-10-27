# Samba Active Directory + LAM Combined Container

A unified Docker container combining Samba Active Directory Domain Controller with LDAP Account Manager (LAM) for simplified LDAP management in testing and lab environments.

## ⚠️ Important Notice

**This combined container is designed for TESTING and LAB environments only.**

For production deployments, use separate containers for better:
- Update management
- Security isolation
- Resource allocation
- Service independence

## Features

- **Samba AD DC**: Full-featured Active Directory Domain Controller (Ubuntu 22.04 based)
- **LAM Web Interface**: Web-based LDAP management on port 8080
- **Auto-Configuration**: LAM automatically configured to connect to local Samba AD
- **MACVLAN Networking**: Dedicated IP address with no port conflicts
- **Process Management**: Supervisord managing all services (Samba, NTP, Nginx, PHP-FPM)
- **Secure by Default**: LDAPS connection between LAM and Samba AD (localhost)

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Samba AD + LAM Container (192.168.1.200)       │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────┐      ┌──────────────┐        │
│  │  Samba AD DC │◄────►│  LAM (Nginx  │        │
│  │              │      │  + PHP-FPM)  │        │
│  │  Port 53     │      │  Port 8080   │        │
│  │  Port 88     │      └──────────────┘        │
│  │  Port 389    │             │                 │
│  │  Port 636    │      ldaps://127.0.0.1:636   │
│  │  Port 445    │             │                 │
│  │  Port 3268   │             ▼                 │
│  │  Port 3269   │      ┌──────────────┐        │
│  └──────────────┘      │  NTP Service │        │
│                        └──────────────┘        │
│                                                  │
│  Managed by: Supervisord                        │
└─────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

1. **MACVLAN Network** - Create in Unraid:
   - Go to: Settings → Docker → Custom Networks → Add Network
   - Network Name: `macvlan-bridge`
   - Network Type: `macvlan`
   - Parent Interface: `eth0` (or your network interface)
   - Subnet: `192.168.1.0/24` (match your network)
   - Gateway: `192.168.1.1` (your router)
   - IP Range: `192.168.1.200/28` (16 IPs for containers)

2. **Available IP Address** - Choose unused IP in your network (e.g., 192.168.1.200)

### Getting the Image

**Option 1: Pull from GitHub Container Registry (Recommended)**

```bash
# Pull from GitHub (no Docker Hub account needed!)
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest
```

**Option 2: Build from GitHub**

```bash
# Build directly from GitHub (no git clone needed!)
docker build -t samba-ad-lam https://github.com/ryan-haver/unraid-docker-templates.git#main:LAM_Samba-AD
```

**Option 3: Build Locally**

```bash
# Clone repository
git clone https://github.com/ryan-haver/unraid-docker-templates.git
cd samba-ad-lam

# Build image
docker build -t samba-ad-lam .
```

> 💡 **For Maintainers**: Set up automated builds with GitHub Actions - see [GITHUB-NO-DOCKERHUB.md](GITHUB-NO-DOCKERHUB.md) (no Docker Hub account needed!)

### Deploying to Unraid

#### Option 1: Using Template (Recommended)

1. Copy `samba-ad-lam-combined.xml` to Unraid:
   ```powershell
   # On Windows
   Copy-Item "samba-ad-lam-combined.xml" "\\192.168.1.110\flash\config\plugins\dockerMan\templates-user\" -Force
   ```

2. In Unraid WebUI:
   - Docker tab → Add Container
   - Select template: `Samba-AD-LAM`
   - Configure required variables (see below)
   - Click Apply

#### Option 2: Manual Docker Command

```bash
docker run -d \
  --name=samba-ad-lam \
  --network=macvlan-bridge \
  --ip=192.168.1.200 \
  --privileged \
  --restart=unless-stopped \
  -e DOMAIN="example.com" \
  -e DOMAINPASS="YourStrongPassword123!" \
  -e HOSTIP="192.168.1.200" \
  -e DNSFORWARDER="192.168.1.1" \
  -e LAM_PASSWORD="your-lam-password" \
  -v /mnt/user/appdata/samba-ad-lam/data:/var/lib/samba \
  -v /mnt/user/appdata/samba-ad-lam/config:/etc/samba/external \
  -v /mnt/user/appdata/samba-ad-lam/lam-config:/var/lib/lam/config \
  ryan-haver/samba-ad-lam:latest
```

### Required Configuration Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `CONTAINER_IP` | `192.168.1.200` | Dedicated IP for container (MACVLAN) |
| `DOMAIN` | `example.com` | Domain FQDN |
| `DOMAINPASS` | `Str0ngP@ss!` | Administrator password (12+ chars) |
| `HOSTIP` | `192.168.1.200` | Must match CONTAINER_IP |
| `DNSFORWARDER` | `192.168.1.1` | DNS server for external queries |
| `LAM_PASSWORD` | `lam-secret` | LAM master configuration password |

### Optional Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN_DC` | (auto) | Domain DN (e.g., dc=example,dc=com) |
| `DOMAIN_EMAIL` | (empty) | Email domain for users |
| `INSECURELDAP` | `false` | Allow unencrypted LDAP (not recommended) |
| `NOCOMPLEXITY` | `false` | Disable password complexity |
| `JOIN` | `false` | Join existing domain (true) or create new (false) |
| `JOINSITE` | (empty) | AD Site name when joining |
| `MULTISITE` | `false` | Enable OpenVPN for multi-site |
| `TZ` | `America/Denver` | Container timezone |

## Usage

### Accessing LAM Web Interface

1. Open browser: `http://192.168.1.200:8080` (use your container IP)
2. Login with LAM master password (set via `LAM_PASSWORD` variable)
3. LAM is auto-configured to connect to Samba AD via `ldaps://127.0.0.1:636`

### Managing Samba AD DC

```bash
# Get domain info
docker exec samba-ad-lam domain info

# List users
docker exec samba-ad-lam domain users

# List groups
docker exec samba-ad-lam domain groups

# Create user (interactive)
docker exec -it samba-ad-lam domain create-user john.doe

# Change password
docker exec -it samba-ad-lam domain change-password john.doe

# Add user to group
docker exec samba-ad-lam domain add-user-to-group john.doe "Domain Admins"
```

### Managing LAM Configuration

```bash
# Show current LAM configuration
docker exec samba-ad-lam lam-config.sh show-config

# Test LDAPS connection
docker exec samba-ad-lam lam-config.sh test-ldap

# Reset LAM master password (interactive)
docker exec -it samba-ad-lam lam-config.sh reset-password

# Show LAM web interface URL
docker exec samba-ad-lam lam-config.sh show-url
```

### Viewing Logs

```bash
# Follow all logs
docker logs -f samba-ad-lam

# View supervisord logs
docker exec samba-ad-lam cat /var/log/supervisor/supervisord.log

# View Samba logs
docker exec samba-ad-lam cat /var/log/supervisor/samba-stdout---supervisor-*.log

# View Nginx logs
docker exec samba-ad-lam cat /var/log/nginx/lam-access.log
```

## File Structure

```
LAM_Samba-AD/
├── Dockerfile                      # Container build instructions
├── init.sh                         # Initialization script (Samba + LAM setup)
├── domain.sh                       # Domain management helper script
├── lam-config.sh                   # LAM configuration helper script
├── nginx-lam.conf                  # Nginx configuration for LAM
├── samba-ad-lam-combined.xml       # Unraid template
├── build.sh                        # Build automation script
├── deploy.sh                       # Deployment automation script
├── README.md                       # This file
└── IMPLEMENTATION-PLAN.md          # Comprehensive implementation documentation
```

## Volume Mappings

| Container Path | Host Path | Description | Size |
|---------------|-----------|-------------|------|
| `/var/lib/samba` | `/mnt/user/appdata/samba-ad-lam/data` | Samba database | ~100-500MB |
| `/etc/samba/external` | `/mnt/user/appdata/samba-ad-lam/config` | Samba config | ~1-5MB |
| `/var/lib/lam/config` | `/mnt/user/appdata/samba-ad-lam/lam-config` | LAM config | ~1-2MB |

**⚠️ BACKUP THESE VOLUMES REGULARLY** - They contain your entire domain database and configuration!

## Port Reference

All ports available on container IP (MACVLAN):

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 53 | TCP/UDP | DNS | Domain Name Service |
| 88 | TCP/UDP | Kerberos | Authentication |
| 135 | TCP | RPC | Remote Procedure Call |
| 137-139 | TCP/UDP | NetBIOS | Legacy network naming |
| 389 | TCP | LDAP | Lightweight Directory Access (STARTTLS) |
| 445 | TCP | SMB | File sharing |
| 464 | TCP/UDP | Kerberos | Password changes |
| 636 | TCP | LDAPS | Secure LDAP (SSL/TLS) |
| 3268 | TCP | Global Catalog | AD search |
| 3269 | TCP | Global Catalog SSL | Secure AD search |
| 8080 | TCP | HTTP | LAM web interface |

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
docker logs samba-ad-lam

# Check supervisord status
docker exec samba-ad-lam supervisorctl status

# Verify MACVLAN network
docker network inspect macvlan-bridge
```

### Cannot Access LAM Web Interface

```bash
# Check Nginx status
docker exec samba-ad-lam supervisorctl status nginx

# Check PHP-FPM status
docker exec samba-ad-lam supervisorctl status php-fpm

# Test from container
docker exec samba-ad-lam curl -I http://127.0.0.1:8080
```

### LDAP Connection Issues

```bash
# Test LDAPS connection
docker exec samba-ad-lam lam-config.sh test-ldap

# Check Samba status
docker exec samba-ad-lam supervisorctl status samba

# Verify LDAP is listening
docker exec samba-ad-lam netstat -tlnp | grep 636
```

### Domain Provisioning Failed

```bash
# Check if domain already exists
docker exec samba-ad-lam samba-tool domain info

# View initialization logs
docker logs samba-ad-lam 2>&1 | grep -A 20 "provision"

# Check permissions on data volumes
ls -la /mnt/user/appdata/samba-ad-lam/
```

## Performance Tuning

### Resource Allocation

Recommended minimum resources:
- **CPU**: 2 cores
- **RAM**: 2GB (4GB recommended for larger domains)
- **Storage**: 10GB for system + domain data

### Optimization Tips

1. **SSD Storage**: Use SSD for `/var/lib/samba` volume for better database performance
2. **Memory**: Increase if domain has 500+ objects
3. **Network**: MACVLAN provides best performance (zero NAT overhead)

## Security Considerations

### Production Recommendations

For production use, deploy **separate containers**:
1. One container for Samba AD DC
2. One container for LAM
3. Use separate networks and firewall rules
4. Implement backup and disaster recovery

### Security Hardening

1. **Change default passwords** immediately
2. **Enable password complexity** (`NOCOMPLEXITY=false`)
3. **Require encrypted LDAP** (`INSECURELDAP=false`)
4. **Regular backups** of all volumes
5. **Firewall rules** restricting access to necessary ports only
6. **Monitor logs** for suspicious activity

## Updating

### Update Container

```bash
# Pull new image
docker pull ryan-haver/samba-ad-lam:latest

# Stop and remove old container
docker stop samba-ad-lam
docker rm samba-ad-lam

# Recreate with same configuration (volumes persist)
# Use same docker run command as initial deployment
```

**⚠️ IMPORTANT**: Always backup volumes before updating!

## Support

- **Samba AD DC Issues**: https://github.com/Fmstrat/samba-domain
- **LAM Issues**: https://www.ldap-account-manager.org/lamcms/support
- **Container Issues**: [Your repository URL]

## License

This combined container is provided under GPLv3 license (inherited from Samba and nowsci/samba-domain).

- Samba: GPLv3
- LAM: GPLv3
- This container: GPLv3

## Credits

- **Samba Project**: https://www.samba.org/
- **LAM Project**: https://www.ldap-account-manager.org/
- **nowsci/samba-domain**: https://github.com/Fmstrat/samba-domain (base for Samba AD DC component)

## Changelog

### Version 1.0.0 (Initial Release)
- Combined Samba AD DC 4.x with LAM 8.9
- Ubuntu 22.04 base
- PHP 8.1 + Nginx stack
- Auto-configuration of LAM for Samba AD
- Supervisord process management
- MACVLAN networking support
