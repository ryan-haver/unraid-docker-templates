# Quick Start Guide - Samba AD + LAM Combined Container

**Status**: ✅ **VERIFIED WORKING** (October 30, 2025)

## 🚀 15-Minute Deployment

### Prerequisites Check
- [ ] Unraid server running Docker
- [ ] MACVLAN network created (`macvlan-bridge`)
- [ ] Available IP address (e.g., `192.168.1.200`)
- [ ] Know your router IP (e.g., `192.168.1.1`)

> 📚 **Full Documentation**: See [DOCUMENTATION-INDEX.md](DOCUMENTATION-INDEX.md)

### Step 1: Pull Image (1 minute)
```bash
# Pull from GitHub Container Registry (recommended - no account needed!)
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest
```

### Step 2: Deploy Template to Unraid (1 minute)
```powershell
# Windows PowerShell
Copy-Item "samba-ad-lam-combined.xml" "\\192.168.1.110\flash\config\plugins\dockerMan\templates-user\" -Force
```

### Step 3: Create Container in Unraid (2 minutes)
1. Open Unraid WebUI → Docker tab
2. Click "Add Container"
3. Select template: **Samba-AD-LAM**
4. Fill in these 6 required fields:
   ```
   Container IP:        192.168.1.200
   Domain Name:         example.com
   Domain Password:     YourStr0ngP@ss!  (save this - needed for LAM login!)
   Host IP:             192.168.1.200
   DNS Forwarder:       192.168.1.1
   LAM Password:        your-lam-secret   (for LAM master config)
   ```
5. Click **Apply**

### Step 4: Wait for Provisioning (2-3 minutes)
```bash
# Watch the logs
docker logs -f Samba-AD-LAM

# Wait for: "LAM configuration complete"
```

### Step 5: Access LAM (30 seconds)
1. Open browser: `http://192.168.1.200:8080`
2. Select **"haver"** profile (auto-named from domain)
3. **Login** (IMPORTANT):
   - You'll see a **DROPDOWN** (not text field)
   - Select **"Administrator"** from dropdown
   - Enter **Domain Password** (DOMAINPASS from Step 3)
   - Click Login
4. ✅ You should now see the LAM dashboard with user management!

> ⚠️ **Common Mistake**: Don't use LAM Password here - use Domain Password (DOMAINPASS)!

---

## 📋 Essential Commands

### Verify Deployment
```bash
# Check domain info
docker exec samba-ad-lam domain info

# Test LDAP connection
docker exec samba-ad-lam lam-config.sh test-ldap

# View all logs
docker logs samba-ad-lam
```

### Pull from GitHub Container Registry
```bash
# Pull the image (free, no authentication needed for public repos!)
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest

# Or use LAM web interface at http://192.168.1.200:8080
```

### Check Service Status
```bash
docker exec samba-ad-lam supervisorctl status
```

---

## 🔧 Common Issues

### Container Won't Start
```bash
# Check logs for errors
docker logs samba-ad-lam

# Verify MACVLAN network exists
docker network ls | grep macvlan-bridge
```

### Can't Access LAM Web Interface
```bash
# Check if nginx is running
docker exec samba-ad-lam supervisorctl status nginx

# Verify port 8080 is accessible
curl -I http://192.168.1.200:8080
```

### LDAP Connection Failed
```bash
# Test LDAPS
docker exec samba-ad-lam lam-config.sh test-ldap

# Check Samba is running
docker exec samba-ad-lam supervisorctl status samba
```

---

## 📁 Important File Locations

### On Host (Unraid)
```
/mnt/user/appdata/samba-ad-lam/
├── data/           (Samba AD database - BACKUP THIS!)
├── config/         (Samba configuration)
└── lam-config/     (LAM configuration)
```

### In Container
```
/var/lib/samba/                  (Samba data)
/etc/samba/external/             (Samba config)
/var/lib/lam/config/             (LAM config)
/var/www/html/lam/               (LAM web files)
```

---

## 🔐 Security Quick Wins

1. **Change default passwords immediately**
   ```bash
   docker exec -it samba-ad-lam lam-config.sh reset-password
   docker exec -it samba-ad-lam domain change-password Administrator
   ```

2. **Enable password complexity** (if not set)
   - Set `NOCOMPLEXITY=false` in template

3. **Backup volumes daily**
   ```bash
   tar -czf samba-backup-$(date +%Y%m%d).tar.gz /mnt/user/appdata/samba-ad-lam/
   ```

---

## 📊 Resource Usage

### Typical Consumption
- **CPU**: 5-10% idle, 20-40% under load
- **RAM**: 500MB idle, 1-2GB under load
- **Disk**: 500MB system + domain data (100-500MB)
- **Network**: Low bandwidth (< 1Mbps typical)

### Recommended Minimums
- **CPU**: 2 cores
- **RAM**: 2GB (4GB for 500+ objects)
- **Disk**: SSD recommended for `/var/lib/samba`

---

## 🎯 Next Actions

### Testing Environment
- [x] Deploy container
- [ ] Create test users
- [ ] Create test groups
- [ ] Join Windows PC to domain
- [ ] Test file sharing
- [ ] Test LAM user management
- [ ] Document any issues

### Production Planning
- [ ] Review security requirements
- [ ] Plan backup strategy
- [ ] Consider separate containers
- [ ] Design high availability
- [ ] Document disaster recovery
- [ ] Schedule regular maintenance

---

## 📞 Getting Help

### Check Documentation
1. **README.md** - Complete user guide
2. **IMPLEMENTATION-PLAN.md** - Technical details
3. **FILES-SUMMARY.md** - File inventory

### View Logs
```bash
# All logs
docker logs samba-ad-lam

# Supervisord logs
docker exec samba-ad-lam cat /var/log/supervisor/supervisord.log

# Nginx logs
docker exec samba-ad-lam cat /var/log/nginx/lam-access.log
```

### Community Support
- **Unraid Forums**: https://forums.unraid.net/
- **Samba Project**: https://wiki.samba.org/
- **LAM Project**: https://www.ldap-account-manager.org/

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] MACVLAN network created
- [ ] Available IP address identified
- [ ] Strong passwords prepared
- [ ] Backup plan in place

### Deployment
- [ ] Docker image built
- [ ] Template copied to Unraid
- [ ] Container created with correct variables
- [ ] Container started successfully
- [ ] Logs show successful provisioning

### Post-Deployment
- [ ] Domain info displays correctly
- [ ] LAM web interface accessible
- [ ] LDAPS connection working
- [ ] Test user created
- [ ] Test group created
- [ ] All services running (supervisorctl status)

### Production Readiness (if applicable)
- [ ] Default passwords changed
- [ ] Firewall rules configured
- [ ] Backup automation set up
- [ ] Monitoring configured
- [ ] Documentation updated with site-specific details
- [ ] Disaster recovery plan tested

---

## 🎓 Learning Resources

### Samba AD DC
- Official Wiki: https://wiki.samba.org/
- nowsci Documentation: https://nowsci.com/samba-domain/

### LDAP Account Manager
- Official Docs: https://www.ldap-account-manager.org/lamcms/documentation
- User Manual: https://www.ldap-account-manager.org/static/doc/manual/

### Docker & Unraid
- Unraid Documentation: https://docs.unraid.net/
- Docker Networking: https://docs.docker.com/network/

---

**Document Version**: 1.0.0
**Last Updated**: Initial Release
**Status**: ✅ Ready for deployment
**Estimated Time to Deploy**: 10-15 minutes (including image build)
