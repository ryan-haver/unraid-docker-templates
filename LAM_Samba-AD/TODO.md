# LAM + Samba AD Project TODO List

**Last Updated**: October 30, 2025  
**Project Status**: ✅ PRODUCTION READY - Core functionality working

---

## 🎯 Current Sprint (High Priority)

### Documentation Enhancement
- [ ] **Download LAM Official Documentation**
  - Source: https://www.ldap-account-manager.org/lamcms/documentation
  - Download: Installation guide, configuration guide, module documentation, API reference
  - Save to: `docs/lam/official/`
  - Purpose: Offline reference for cross-checking against source code
  - Estimated time: 1 hour

- [ ] **Download Samba AD Documentation**
  - Source: https://wiki.samba.org
  - Download: AD DC setup, LDAP schema reference, attribute definitions, authentication methods
  - Save to: `docs/samba/wiki/`
  - Purpose: Validate attributes and configuration against official docs
  - Estimated time: 1 hour

- [ ] **Document Known LAM Version Differences**
  - Create: `LAM-VERSION-DIFFERENCES.md`
  - Content: LAM 8.x vs 9.x differences, deprecated options, breaking changes
  - Include: Why "fixed" loginMethod doesn't exist in 9.3
  - Reference: Current working config (loginMethod="list")
  - Estimated time: 2 hours

---

## 🔧 Development & Testing

### Validation System Enhancement
- [ ] **Build Comprehensive Test Suite**
  - Framework: Python with pytest + requests
  - Tests needed:
    - Config generation validation
    - LAM initialization check
    - Authentication flow (dropdown → login → success)
    - User list rendering (no TypeError)
    - CRUD operations (create/read/update/delete users)
  - Integration: Pre-commit hook to run automatically
  - Reference: VALIDATION-PLAN.md Phase 4
  - Estimated time: 1 week

- [ ] **Create Bash Version of setup_validation.ps1**
  - File: `scripts/setup_validation.sh`
  - Purpose: Run validation on Unraid server (Linux-based)
  - Include: Docker commands, schema extraction, validation
  - Test on: Unraid server environment
  - Estimated time: 2 hours

- [ ] **Add Pre-commit Hook**
  - File: `.git/hooks/pre-commit`
  - Function: Run validation before allowing commits
  - Checks: Config syntax, validation script, basic tests
  - Prevents: Committing broken configurations
  - Estimated time: 1 hour

---

## 📚 Documentation (Ongoing)

### Reference Documentation
- [ ] **Create LAM Configuration Reference Matrix**
  - Format: Markdown table
  - Columns: Config option, LAM source location, LAM docs link, Samba docs link, Validated status
  - Include: All haver.conf options with authoritative sources
  - Example template in: VALIDATION-PLAN.md
  - Estimated time: 3 hours

- [ ] **Create Samba AD Attribute Reference**
  - Format: Markdown table
  - Content: All Samba AD attributes with descriptions, types, multi-value status
  - Mark: Safe vs problematic attributes for LAM
  - Source: Extract from running Samba AD + official docs
  - Estimated time: 2 hours

- [ ] **Add Migration Guide**
  - Title: "Migrating from LAM 8.x to 9.x"
  - Cover: Breaking changes, config structure differences, loginMethod changes
  - Include: Step-by-step migration procedure
  - Target: Users upgrading from older versions
  - Estimated time: 2 hours

---

## 🔍 Investigation & Research

### LAM Deep Dive
- [ ] **Analyze LAM Source for All loginMethod Usages**
  - File: `/var/www/html/lam/templates/login.php`
  - Document: How LIST and SEARCH methods work internally
  - Create: Flow diagrams for each method
  - Purpose: Complete understanding of authentication flow
  - Estimated time: 3 hours

- [ ] **Research LAM Module System**
  - Understand: How modules_user and modules_group work
  - Document: Available modules and their purposes
  - Test: Which modules are compatible with Samba AD
  - Output: Module compatibility matrix
  - Estimated time: 4 hours

- [ ] **Investigate LAM Password Policies**
  - Research: How LAM enforces password complexity
  - Test: Integration with Samba AD password policies
  - Document: Best practices for password management
  - Estimated time: 2 hours

---

## 🚀 Features & Enhancements

### Container Improvements
- [ ] **Add Health Check to Dockerfile**
  - Check: Samba AD running, LAM accessible, LDAPS connection working
  - Frequency: Every 30 seconds
  - Action: Container marked unhealthy if checks fail
  - Estimated time: 1 hour

- [ ] **Implement Graceful Shutdown**
  - Handle: SIGTERM properly in init.sh
  - Stop: Services in correct order (LAM → Samba → cleanup)
  - Prevent: Data corruption on container stop
  - Estimated time: 2 hours

- [ ] **Add Backup Script**
  - File: `scripts/backup.sh`
  - Backup: Samba database, LAM config, certificates
  - Format: Timestamped tar.gz
  - Schedule: Instructions for cron setup
  - Estimated time: 2 hours

- [ ] **Add Restore Script**
  - File: `scripts/restore.sh`
  - Restore: From backup created by backup.sh
  - Verify: Data integrity after restore
  - Test: Complete disaster recovery procedure
  - Estimated time: 2 hours

### LAM Features
- [ ] **Add LAM Self-Service Module**
  - Enable: Users to change their own passwords
  - Configure: Self-service URL and permissions
  - Document: Setup procedure
  - Test: User experience
  - Estimated time: 3 hours

- [ ] **Configure LAM Account Profiles**
  - Create: Default templates for user creation
  - Include: Common attributes, group memberships
  - Purpose: Streamline user provisioning
  - Estimated time: 2 hours

- [ ] **Add LAM Job Queue**
  - Enable: Scheduled tasks (password expiry notifications, etc.)
  - Configure: Job schedule and permissions
  - Test: Job execution
  - Estimated time: 3 hours

---

## 🔒 Security Enhancements

### Certificate Management
- [ ] **Document Certificate Replacement Procedure**
  - Topic: Replacing self-signed with CA-signed certificate
  - Steps: Generate CSR, import cert, update LAM config
  - Test: LDAPS connection after replacement
  - Estimated time: 2 hours

- [ ] **Add Certificate Expiry Monitoring**
  - Check: Certificate expiration dates
  - Alert: Warning before expiry (30 days)
  - Automate: Certificate renewal reminder
  - Estimated time: 2 hours

### Access Control
- [ ] **Document LAM Access Levels**
  - Research: All LAM access level options (0, 100, 200)
  - Test: Each level's permissions
  - Document: Use cases for each level
  - Estimated time: 2 hours

- [ ] **Add Multiple Admin DNs Support**
  - Test: Semicolon-separated Admins field with multiple DNs
  - Verify: All admins can login via dropdown
  - Document: How to add/remove admins
  - Estimated time: 1 hour

---

## 📊 Monitoring & Logging

### Log Management
- [ ] **Add Log Rotation**
  - Configure: logrotate for LAM logs
  - Retention: 7 days of logs, compress old logs
  - Size: Rotate at 100MB
  - Estimated time: 1 hour

- [ ] **Create Log Analysis Script**
  - File: `scripts/analyze_logs.sh`
  - Parse: Common errors from LAM error log
  - Report: Summary of issues found
  - Suggest: Fixes for common problems
  - Estimated time: 3 hours

- [ ] **Add Prometheus Metrics**
  - Expose: Container metrics (optional advanced feature)
  - Metrics: Authentication attempts, user operations, LDAP queries
  - Integration: Prometheus/Grafana dashboard
  - Estimated time: 1 week

---

## 🧪 Testing & Validation

### Test Coverage
- [ ] **Create Unit Tests for init.sh**
  - Test: Config generation logic
  - Mock: Environment variables
  - Verify: Generated haver.conf correctness
  - Framework: bash_unit or bats
  - Estimated time: 1 week

- [ ] **Create Integration Tests**
  - Test: Full container lifecycle (start → provision → login → operations → stop)
  - Automate: GitHub Actions or local CI
  - Coverage: All major features
  - Estimated time: 2 weeks

- [ ] **Add Performance Tests**
  - Measure: Authentication latency, user list load time
  - Benchmark: LDAP query performance
  - Document: Expected performance metrics
  - Estimated time: 3 days

### Load Testing
- [ ] **Test with Large User Base**
  - Create: 1000+ test users
  - Measure: LAM performance with large directory
  - Optimize: If performance issues found
  - Document: Scaling recommendations
  - Estimated time: 1 week

---

## 📦 Deployment & Distribution

### GitHub Container Registry
- [ ] **Set Up Automated Multi-Arch Builds**
  - Platforms: amd64, arm64
  - Trigger: On push to main, on tag
  - Test: Both architectures
  - Estimated time: 4 hours

- [ ] **Create Release Process**
  - Document: Version numbering scheme (semver)
  - Automate: Changelog generation from commits
  - Tag: Releases in git
  - Publish: Release notes on GitHub
  - Estimated time: 3 hours

- [ ] **Add Container Vulnerability Scanning**
  - Tool: Trivy or Snyk
  - Scan: On every build
  - Report: Security vulnerabilities
  - Block: High severity issues
  - Estimated time: 2 hours

### Documentation for Users
- [ ] **Create Video Tutorial**
  - Content: Quick start deployment walkthrough
  - Length: 5-10 minutes
  - Cover: MACVLAN setup, container deployment, LAM login
  - Platform: YouTube or similar
  - Estimated time: 1 day

- [ ] **Add FAQ Document**
  - File: `FAQ.md`
  - Content: Common questions from users
  - Update: As new questions arise
  - Estimated time: 2 hours

---

## 🛠️ Maintenance

### Regular Tasks
- [ ] **Monthly Documentation Review**
  - Check: All docs still accurate
  - Update: Any outdated information
  - Test: All examples still work
  - Schedule: First of each month
  - Time: 1 hour/month

- [ ] **Quarterly Security Audit**
  - Review: Container security posture
  - Update: Base image and dependencies
  - Scan: For vulnerabilities
  - Apply: Security patches
  - Time: 4 hours/quarter

- [ ] **Semi-Annual Major Update**
  - Check: New LAM version available
  - Check: New Samba version available
  - Test: Upgrade procedure
  - Update: Documentation for new versions
  - Time: 1 week/semi-annual

---

## 🎓 Knowledge Base

### Training Materials
- [ ] **Create Administrator Guide**
  - File: `ADMIN-GUIDE.md`
  - Content: Day-to-day operations, common tasks, troubleshooting
  - Audience: System administrators using the container
  - Estimated time: 1 week

- [ ] **Create Developer Guide**
  - File: `DEVELOPER-GUIDE.md`
  - Content: Architecture, code structure, how to contribute
  - Audience: Developers modifying the container
  - Estimated time: 1 week

- [ ] **Document All Environment Variables**
  - File: `ENVIRONMENT-VARIABLES.md`
  - Content: Complete reference of all variables with examples
  - Include: Required vs optional, defaults, validation rules
  - Estimated time: 3 hours

---

## 🐛 Known Issues (Future Fixes)

### Minor Issues
- [ ] **LAM Session Timeout Configuration**
  - Issue: Session timeout not configurable via environment variable
  - Solution: Add LAM_SESSION_TIMEOUT variable
  - Priority: Low
  - Estimated time: 1 hour

- [ ] **Improve Error Messages**
  - Issue: Some errors not user-friendly
  - Solution: Add better error handling and messages in init.sh
  - Priority: Medium
  - Estimated time: 2 hours

### Enhancement Requests
- [ ] **Add Support for Multiple Domains**
  - Feature: Manage multiple AD domains from one LAM instance
  - Complexity: High
  - Research needed: LAM multi-server configuration
  - Estimated time: 2 weeks

- [ ] **Add LDAP Browser Feature**
  - Feature: Web-based LDAP tree browser in LAM
  - Research: LAM tree view capabilities
  - Estimated time: 1 week

---

## 📅 Roadmap

### Version 1.4.0 (Next Release) - Target: December 2025
- [ ] Complete test suite
- [ ] Bash validation script
- [ ] LAM version differences doc
- [ ] Official documentation downloaded

### Version 1.5.0 - Target: Q1 2026
- [ ] Health checks implemented
- [ ] Backup/restore scripts
- [ ] Certificate management documented
- [ ] Multi-arch builds

### Version 2.0.0 - Target: Q2 2026
- [ ] LAM self-service module
- [ ] Account profiles
- [ ] Performance optimizations
- [ ] Complete monitoring solution

---

## ✅ Completed (Recent)

### October 2025
- [x] Fixed loginMethod from "fixed" to "list" (Oct 30)
- [x] Fixed attr_user to safe attributes only (Oct 29)
- [x] Created comprehensive validation system (Oct 29-30)
- [x] Updated all documentation to current state (Oct 30)
- [x] Created master documentation index (Oct 30)
- [x] Added troubleshooting guide (Oct 30)
- [x] Created documentation compliance checklist (Oct 30)
- [x] Fixed validation script for non-Docker environments (Oct 30)

### Earlier
- [x] Fixed DN case sensitivity (uppercase CN/DC)
- [x] Fixed Admins field format (string not array)
- [x] Fixed config structure (typeSettings not types/modules)
- [x] Created GitHub Container Registry setup
- [x] Implemented auto-configuration of LAM
- [x] Created Unraid template

---

## 📊 Progress Tracking

### Overall Project Status
- **Core Functionality**: ✅ 100% Complete
- **Documentation**: ✅ 95% Complete (official docs download pending)
- **Validation System**: ✅ 80% Complete (test suite pending)
- **Testing**: ⚠️ 40% Complete (automated tests needed)
- **Monitoring**: ⚠️ 30% Complete (basic logging only)
- **Security**: ✅ 70% Complete (basic hardening done)

### By Category
- **Critical (Must Have)**: ✅ 100% Done
- **Important (Should Have)**: 🔄 60% Done
- **Nice to Have**: ⏳ 20% Done
- **Future**: ⏳ 0% Done

---

## 🎯 Next Actions (Prioritized)

1. **This Week**:
   - [ ] Download LAM official documentation
   - [ ] Download Samba AD documentation
   - [ ] Create LAM version differences doc

2. **This Month**:
   - [ ] Start building test suite
   - [ ] Create bash validation script
   - [ ] Add pre-commit hook

3. **This Quarter**:
   - [ ] Complete test suite
   - [ ] Add health checks
   - [ ] Create backup/restore scripts

---

## 📝 Notes

### Working Configuration (Reference)
```bash
loginMethod: "list"
attr_user: "#sAMAccountName;#givenName;#sn;#mail"
Admins: "CN=Administrator,CN=Users,DC=haver,DC=internal"
DN case: UPPERCASE CN/DC
Config structure: typeSettings
```

### Key Learnings
1. Always validate against source code, not just documentation
2. LAM 9.3 only has "list" and "search" loginMethods (no "fixed")
3. attr_user must only use attributes that exist in Samba AD schema
4. Admins field must be string (semicolon-separated), not array
5. DN case matters - use UPPERCASE CN/DC for consistency

### Resources
- LAM Docs: https://www.ldap-account-manager.org/lamcms/documentation
- Samba Wiki: https://wiki.samba.org
- Project Docs: DOCUMENTATION-INDEX.md
- Validation: scripts/README.md
- Troubleshooting: TROUBLESHOOTING.md

---

**Last Review**: October 30, 2025  
**Next Review**: November 30, 2025 or on next major change

**Status**: ✅ Core functionality complete and working. Enhancement and testing items remain.
