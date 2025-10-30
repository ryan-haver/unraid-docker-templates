# LAM + Samba AD Documentation Index

**Last Updated**: October 30, 2025  
**Status**: ✅ PRODUCTION READY - Authentication Working

This index provides quick access to all documentation and reflects the **current working configuration**.

---

## 🚀 Quick Start (New Users Start Here)

1. **[QUICK-START.md](QUICK-START.md)** - Get up and running in 15 minutes
2. **[README.md](README.md)** - Complete feature overview and architecture
3. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Fix common issues

---

## 📋 Current Working Configuration (VERIFIED)

### Critical Settings That MUST Be Correct

| Setting | Working Value | Source | Notes |
|---------|---------------|--------|-------|
| `loginMethod` | `"list"` | init.sh:780 | ✅ MUST be "list" (NOT "fixed"!) |
| `attr_user` | `"#sAMAccountName;#givenName;#sn;#mail"` | init.sh:786 | ✅ Only safe attributes |
| `Admins` format | STRING (not array) | init.sh:776 | ✅ "CN=Admin,CN=Users,DC=..." |
| DN case | UPPERCASE | All DNs | ✅ CN=... DC=... (not cn/dc) |
| Config structure | `typeSettings` | init.sh:784 | ✅ NOT types/modules |

### What Each loginMethod Does

| Method | Status | Behavior | Use Case |
|--------|--------|----------|----------|
| `"list"` | ✅ **WORKING** | Shows dropdown of admin DNs from Admins field | **Current config** |
| `"search"` | ⚠️ Complex | Requires loginSearchDN/Password or anonymous bind | Not recommended for Samba AD |
| `"fixed"` | ❌ **DOES NOT EXIST** | N/A - not in LAM 9.3 source code | **Never use!** |

---

## 📚 Documentation by Purpose

### For Deployment

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[QUICK-START.md](QUICK-START.md)** | Fast deployment guide | First-time setup |
| **[README.md](README.md)** | Complete features & architecture | Understanding the system |
| **[GITHUB-NO-DOCKERHUB.md](GITHUB-NO-DOCKERHUB.md)** | GitHub Container Registry setup | Setting up automated builds |
| **[DEPLOYMENT-OPTIONS.md](DEPLOYMENT-OPTIONS.md)** | Deployment strategies | Choosing deployment method |

### For Troubleshooting

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Authentication & config issues | **READ THIS FIRST when issues occur** |
| **[VALIDATION-EXAMPLES.md](VALIDATION-EXAMPLES.md)** | Real examples of prevented issues | Understanding what validation catches |
| **[REMEDIATION-PLAN.md](REMEDIATION-PLAN.md)** | Historical fix documentation | Reference for past issues |

### For Validation & Prevention

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[VALIDATION-PLAN.md](VALIDATION-PLAN.md)** | Comprehensive validation strategy | Planning prevention measures |
| **[scripts/README.md](scripts/README.md)** | Validation script usage | Using validation tools |
| **[VALIDATION-EXAMPLES.md](VALIDATION-EXAMPLES.md)** | How validation prevents issues | Understanding validation value |

### For Development

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md)** | Technical implementation details | Understanding internals |
| **[FILES-SUMMARY.md](FILES-SUMMARY.md)** | File structure reference | Finding specific files |

### For GitHub Setup

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[GITHUB-NO-DOCKERHUB.md](GITHUB-NO-DOCKERHUB.md)** | GitHub-only deployment | **Recommended** - No Docker Hub needed |
| **[GITHUB-SETUP.md](GITHUB-SETUP.md)** | Original GitHub setup | Alternative approach |
| **[GITHUB-QUICK-SETUP.md](GITHUB-QUICK-SETUP.md)** | Quick GitHub config | Fast GitHub setup |

---

## 🔧 Configuration Files Reference

### Core Files (What Actually Runs)

| File | Purpose | Key Content | Validation |
|------|---------|-------------|------------|
| **init.sh** | Container initialization | LAM config generation, Samba setup | ✅ Validated working |
| **haver.conf** | LAM runtime config | Generated from init.sh at startup | ✅ Auto-generated |
| **samba-ad-lam-combined.xml** | Unraid template | UI variables for deployment | ✅ Up to date |

### Helper Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **domain.sh** | Samba AD management | `docker exec ... domain.sh <command>` |
| **lam-config.sh** | LAM configuration | `docker exec ... lam-config.sh <command>` |

### Validation Scripts (New!)

| Script | Purpose | Usage |
|--------|---------|-------|
| **extract_lam_schema.py** | Extract LAM valid config options | `python3 scripts/extract_lam_schema.py` |
| **extract_samba_schema.py** | Extract Samba attributes | `python3 scripts/extract_samba_schema.py` |
| **validate_lam_config.py** | Validate haver.conf | `python3 scripts/validate_lam_config.py <conf>` |
| **setup_validation.ps1** | One-time validation setup | `.\scripts\setup_validation.ps1` |

---

## 🎯 Common Tasks Quick Reference

### Initial Deployment

```bash
# 1. Pull image
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest

# 2. Deploy via Unraid template or docker run
# See QUICK-START.md for complete instructions

# 3. Access LAM
http://<container-ip>:8080
# Select "haver" profile
# Choose "Administrator" from dropdown
# Enter domain password (DOMAINPASS)
```

### Validation Before Changes

```bash
# 1. SSH to Unraid server
ssh root@<unraid-ip>

# 2. Navigate to templates repo
cd /boot/config/plugins/dockerMan/templates-repos/unraid-docker-templates

# 3. Run validation
python3 LAM_Samba-AD/scripts/validate_lam_config.py \
  /mnt/user/appdata/Samba-AD-LAM/lam/config/haver.conf

# 4. Fix any errors before deployment
```

### Rebuilding After Changes

```bash
# 1. Update to latest code
git pull origin main

# 2. Delete old config to force regeneration
rm /mnt/user/appdata/Samba-AD-LAM/lam/config/haver.conf

# 3. Update container
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest

# 4. Restart container
docker restart Samba-AD-LAM

# 5. Verify login works
# Navigate to http://<ip>:8080
```

### Checking Logs

```bash
# LAM error log (MOST IMPORTANT for debugging)
docker exec Samba-AD-LAM tail -100 /var/log/nginx/lam-error.log

# LAM access log
docker exec Samba-AD-LAM tail -100 /var/log/nginx/lam-access.log

# Container logs
docker logs Samba-AD-LAM --tail 100

# Samba logs
docker exec Samba-AD-LAM tail -100 /var/log/samba/log.samba
```

---

## 🐛 Troubleshooting Decision Tree

```
Are you getting authentication errors?
├─ YES → Read TROUBLESHOOTING.md
│   ├─ "Invalid credentials" → Check loginMethod is "list"
│   ├─ "Wrong password" → Verify DOMAINPASS is correct
│   └─ No dropdown shown → Config has loginMethod: "fixed" (WRONG!)
│
└─ NO → Is LAM loading but other errors?
    ├─ TypeError in logs → Check attr_user attributes exist in Samba
    ├─ Can't connect to LDAPS → Check certificate trust
    └─ Config not loading → Check Admins field format (string not array)
```

**Key Rule**: ALWAYS check `/var/log/nginx/lam-error.log` first!

---

## ✅ Validation Checklist (Before Every Deployment)

Use this checklist to prevent issues:

- [ ] `loginMethod` is `"list"` (NOT "fixed")
- [ ] `attr_user` uses only safe attributes (sAMAccountName, givenName, sn, mail)
- [ ] `Admins` is STRING (not array)
- [ ] All DNs use UPPERCASE CN/DC
- [ ] Config uses `typeSettings` (not types/modules)
- [ ] `moduleSettings` values are arrays
- [ ] Run validation script before deployment
- [ ] Delete old haver.conf before rebuild
- [ ] Test login after deployment
- [ ] Check LAM error logs for issues

---

## 📊 Issue Resolution History

### Issues Encountered & Fixed

| Issue | Root Cause | Fix | Prevention |
|-------|------------|-----|------------|
| Invalid credentials | `loginMethod: "fixed"` | Changed to `"list"` | Validation catches non-existent method |
| TypeError in user list | `attr_user` had missing attributes | Removed employeeNumber, department, title | Validation checks against Samba schema |
| LAM can't parse Admins | Admins was array not string | Changed to semicolon-separated string | Validation checks data type |
| DN case sensitivity | lowercase cn/dc | Changed to uppercase CN/DC | Documentation now emphasizes this |

All fixes are documented in:
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - How to fix
- **[VALIDATION-EXAMPLES.md](VALIDATION-EXAMPLES.md)** - What prevention looks like
- **[REMEDIATION-PLAN.md](REMEDIATION-PLAN.md)** - Historical record

---

## 🔄 Update Process

### When to Update

- New LAM version released
- New Samba version released
- Security updates required
- Bug fixes needed
- Feature additions

### Update Steps

1. **Before updating**:
   ```bash
   # Backup all volumes
   tar -czf samba-ad-lam-backup-$(date +%Y%m%d).tar.gz \
     /mnt/user/appdata/Samba-AD-LAM/
   ```

2. **Pull new image**:
   ```bash
   docker pull ghcr.io/ryan-haver/samba-ad-lam:latest
   ```

3. **Re-extract schemas** (if LAM version changed):
   ```bash
   python3 scripts/extract_lam_schema.py
   python3 scripts/extract_samba_schema.py
   ```

4. **Validate config** (critical!):
   ```bash
   python3 scripts/validate_lam_config.py \
     /mnt/user/appdata/Samba-AD-LAM/lam/config/haver.conf
   ```

5. **Update container**:
   ```bash
   docker stop Samba-AD-LAM
   docker rm Samba-AD-LAM
   # Recreate with same settings
   ```

6. **Verify functionality**:
   - Test login
   - Check user list displays
   - Review error logs
   - Test CRUD operations

---

## 📝 Contributing & Maintaining

### Before Making Changes

1. ✅ Read relevant documentation
2. ✅ Understand current working config
3. ✅ Run validation on current state
4. ✅ Make changes to init.sh
5. ✅ Run validation on new config
6. ✅ Test in container
7. ✅ Update documentation if needed
8. ✅ Commit with clear message

### Documentation Updates

When you change code, update these docs:

| Changed | Update These Docs |
|---------|-------------------|
| init.sh config | README.md, TROUBLESHOOTING.md |
| New validation | scripts/README.md, VALIDATION-PLAN.md |
| Fix applied | TROUBLESHOOTING.md, VALIDATION-EXAMPLES.md |
| New feature | README.md, QUICK-START.md |
| Breaking change | ALL docs + version bump |

### Commit Message Format

```
<type>: <subject>

<body explaining what and why>

Fixes: #<issue-number>
See: <relevant-doc>.md
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

---

## 🎓 Learning Path

### New to This Project?

1. Start: **[QUICK-START.md](QUICK-START.md)** (15 min)
2. Read: **[README.md](README.md)** (30 min)
3. Deploy: Follow QUICK-START steps (30 min)
4. Understand: **[IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md)** (1 hour)

### Want to Contribute?

1. Review: **[VALIDATION-PLAN.md](VALIDATION-PLAN.md)**
2. Understand: **[VALIDATION-EXAMPLES.md](VALIDATION-EXAMPLES.md)**
3. Set up: Run `setup_validation.ps1`
4. Validate: Test validation on current config

### Troubleshooting Issues?

1. Check: **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** FIRST
2. Review: **[VALIDATION-EXAMPLES.md](VALIDATION-EXAMPLES.md)**
3. Search: Issue history in git commits
4. Ask: Create GitHub issue with logs

---

## 📞 Support Resources

### Internal Documentation
- This index (start here)
- TROUBLESHOOTING.md (for issues)
- VALIDATION-PLAN.md (for prevention)

### External Resources
- LAM Documentation: https://www.ldap-account-manager.org/lamcms/documentation
- Samba Wiki: https://wiki.samba.org/
- nowsci/samba-domain: https://github.com/Fmstrat/samba-domain

### Getting Help
1. Check TROUBLESHOOTING.md
2. Review logs (LAM error log especially)
3. Run validation script
4. Search GitHub issues
5. Create new issue with logs

---

## 🎉 Success Indicators

Your deployment is working correctly when:

- ✅ LAM login shows dropdown with "Administrator"
- ✅ Authentication succeeds with DOMAINPASS
- ✅ User list displays without errors
- ✅ `/var/log/nginx/lam-error.log` is clean
- ✅ Can create/modify/delete users via LAM
- ✅ Validation script reports no errors
- ✅ All attributes display in user list

---

## 🔒 Security Reminders

**Always**:
- Use strong passwords (12+ characters)
- Use LDAPS (not LDAP) for remote connections
- Backup regularly
- Update regularly
- Review logs periodically
- Use validation before deployment

**Never**:
- Commit passwords to git
- Use "fixed" loginMethod (doesn't exist!)
- Skip validation before deployment
- Deploy untested configs to production
- Use this combined container in production (separate containers instead)

---

## 📅 Maintenance Schedule

### Daily
- Monitor container logs
- Check for authentication issues

### Weekly
- Review error logs
- Check disk space
- Verify backups working

### Monthly
- Update container images
- Re-run validation
- Review security settings
- Test disaster recovery

### Quarterly
- Full backup verification
- Security audit
- Documentation review
- Update external documentation links

---

## Version History

| Version | Date | Changes | Documentation Updated |
|---------|------|---------|----------------------|
| 1.0.0 | Oct 2025 | Initial release | All |
| 1.1.0 | Oct 2025 | Fixed loginMethod to "list" | README, TROUBLESHOOTING |
| 1.2.0 | Oct 2025 | Added validation system | Added scripts/README, VALIDATION-PLAN |
| 1.3.0 | Oct 2025 | Fixed attr_user attributes | TROUBLESHOOTING, VALIDATION-EXAMPLES |

**Current Version**: 1.3.0 (WORKING)

---

## Quick Command Reference

```bash
# Deployment
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest
docker restart Samba-AD-LAM

# Validation
python3 scripts/validate_lam_config.py /path/to/haver.conf

# Logs (MOST IMPORTANT)
docker exec Samba-AD-LAM tail -f /var/log/nginx/lam-error.log

# Testing
docker exec Samba-AD-LAM ldapsearch -H ldaps://127.0.0.1:636 -D "CN=Administrator,CN=Users,DC=haver,DC=internal" -w "<password>" -b "DC=haver,DC=internal" -s base

# Management
docker exec Samba-AD-LAM domain.sh info
docker exec Samba-AD-LAM lam-config.sh test-ldap
```

---

**Remember**: When in doubt, check TROUBLESHOOTING.md and run validation!

**Last Verified Working**: October 30, 2025
