# LAM to Samba AD DC Networking Issue - TODO

## Current Situation
- **Samba AD DC Container**: Running on macvlan network (br0) at IP 192.168.1.115
- **LAM Container**: Running on bridge network with port mapping (8083:80)
- **Problem**: LAM cannot connect to Samba because bridge network containers cannot directly communicate with macvlan containers
- **Error**: Connection timeout when LAM tries to reach ldap://192.168.1.115:389

## Root Cause
Macvlan network isolation - the Unraid host and bridge network containers are unable to communicate directly with macvlan containers. This is a known Docker macvlan limitation, not a configuration error.

## Available Solutions

### Option 1: Move LAM to Macvlan Network (br0) - RECOMMENDED ✅
**Description:** Reconfigure LAM container to use br0 network with its own dedicated IP address (e.g., 192.168.1.116)

**Pros:**
- ✅ Cleanest solution - both containers on same network
- ✅ LAM and Samba can communicate freely
- ✅ No port conflicts - LAM gets all ports on its own IP
- ✅ LAM accessible from any device on network at http://192.168.1.116/
- ✅ No special routing or boot scripts needed
- ✅ Consistent with why Samba is on macvlan (avoiding port conflicts)

**Cons:**
- ❌ Uses an additional IP address from your network range
- ❌ Requires updating DNS/bookmarks to new IP
- ❌ Slightly more complex initial setup

**Implementation Steps:**
1. Stop and remove current LAM container
2. Recreate with network mode: br0
3. Assign static IP: 192.168.1.116
4. Update LDAP_SERVER to use ldap://192.168.1.115:389
5. Access LAM at http://192.168.1.116/

**Docker Command:**
```bash
docker run -d --name LAM \
  --network br0 --ip 192.168.1.116 \
  --restart=unless-stopped \
  --tmpfs /run/lock --tmpfs /tmp \
  -v /mnt/user/appdata/lam:/var/lib/ldap-account-manager/config \
  -e PUID=99 -e PGID=100 \
  -e LAM_PASSWORD=lam \
  -e LDAP_SERVER=ldap://192.168.1.115:389 \
  -e LDAP_DOMAIN=example.local \
  -e LDAP_BASE_DN=dc=example,dc=local \
  -e LDAP_USERS_DN='cn=Users,dc=example,dc=local' \
  -e LDAP_GROUPS_DN='cn=Users,dc=example,dc=local' \
  -e LDAP_USER='cn=administrator,dc=example,dc=local' \
  -e LAM_LANG=en_US \
  -e LAM_SKIP_PRECONFIGURE=false \
  ghcr.io/ldapaccountmanager/lam:stable
```

---

### Option 2: Add Macvlan Route on Unraid Host
**Description:** Configure Unraid host to route traffic to macvlan containers

**Pros:**
- ✅ LAM stays on bridge network (simple port mapping)
- ✅ Doesn't use additional IP address
- ✅ Bridge containers can reach macvlan containers

**Cons:**
- ❌ Requires persistent route configuration
- ❌ Must add commands to Unraid /boot/config/go file
- ❌ Route must be recreated on every reboot
- ❌ More complex troubleshooting if network issues occur
- ❌ Still can't access LAM directly from Unraid host terminal

**Implementation Steps:**
1. Create macvlan shim interface
2. Add route to Samba container
3. Add commands to /boot/config/go for persistence

**Commands to Add to /boot/config/go:**
```bash
# Macvlan route to allow bridge containers to reach macvlan containers
ip link add macvlan-shim link eth0 type macvlan mode bridge
ip addr add 192.168.1.199/32 dev macvlan-shim
ip link set macvlan-shim up
ip route add 192.168.1.115/32 dev macvlan-shim
```

---

### Option 3: Move Samba to Bridge Network
**Description:** Reconfigure Samba AD DC to use bridge network with port mapping

**Pros:**
- ✅ Both containers on same network
- ✅ Simpler networking setup

**Cons:**
- ❌ **BLOCKED BY PORT CONFLICTS** - This is why Samba is on macvlan
- ❌ Samba AD DC requires many standard ports (53, 88, 135, 139, 389, 445, 464, 636, 3268, 3269)
- ❌ These ports conflict with other services on Unraid
- ❌ Not a viable option

**Status:** ❌ NOT RECOMMENDED - Samba must stay on macvlan

---

### Option 4: Reverse Proxy
**Description:** Use a reverse proxy to forward traffic from LAM to Samba

**Pros:**
- None - this doesn't solve the problem

**Cons:**
- ❌ Reverse proxy would have the same macvlan isolation issue
- ❌ Doesn't solve the underlying network connectivity problem
- ❌ Adds unnecessary complexity

**Status:** ❌ NOT VIABLE - Doesn't address root cause

---

### Option 5: Host Network Mode for LAM
**Description:** Run LAM with --network host

**Pros:**
- ✅ LAM can access macvlan containers
- ✅ No IP assignment needed

**Cons:**
- ❌ LAM uses Unraid host's IP directly
- ❌ Port 80 conflict with Unraid WebUI or other services
- ❌ Less isolation/security
- ❌ May interfere with Unraid services

**Status:** ⚠️ POSSIBLE BUT NOT RECOMMENDED - Port conflicts likely

---

### Option 6: Run LAM Inside Samba Container
**Description:** Install LAM inside the Samba container

**Pros:**
- ✅ Same IP address, no networking issues
- ✅ Single container to manage

**Cons:**
- ❌ Requires custom Docker image
- ❌ More complex maintenance
- ❌ Loses separation of concerns
- ❌ Updates become complicated

**Status:** ❌ NOT RECOMMENDED - Overcomplicated

---

## Decision Matrix

| Option | Difficulty | Safety | Maintainability | Recommended |
|--------|-----------|--------|-----------------|-------------|
| 1. LAM to Macvlan | Medium | High | High | ✅ YES |
| 2. Add Route | Medium | Medium | Medium | ⚠️ Acceptable |
| 3. Samba to Bridge | Easy | High | High | ❌ Blocked by port conflicts |
| 4. Reverse Proxy | Medium | N/A | Low | ❌ Doesn't work |
| 5. Host Network | Easy | Low | Medium | ⚠️ Port conflicts likely |
| 6. Combined Container | Hard | Medium | Low | ❌ Too complex |

---

## Recommended Action Plan

**CHOOSE OPTION 1: Move LAM to Macvlan Network (br0)**

### Next Steps:
1. [ ] Verify available IP address on network (suggested: 192.168.1.116)
2. [ ] Stop current LAM container
3. [ ] Remove current LAM container
4. [ ] Recreate LAM on br0 with IP 192.168.1.116
5. [ ] Test connection: LAM → Samba LDAP
6. [ ] Update LAM template to reflect new network configuration
7. [ ] Update bookmarks/DNS to new LAM IP (192.168.1.116)
8. [ ] Document new WebUI URL in container notes

### Verification Commands:
```bash
# Test LAM can reach Samba LDAP
docker exec LAM ping -c 3 192.168.1.115

# Test LDAP port connectivity
curl -v telnet://192.168.1.115:389 --connect-timeout 3

# Verify LAM is accessible
curl -I http://192.168.1.116/
```

---

## Current Configuration Reference

### Samba AD DC
- **Network:** br0 (macvlan)
- **IP Address:** 192.168.1.115
- **Domain:** example.local
- **LDAP Port:** 389 (standard)
- **LDAPS Port:** 636 (secure)

### LAM (Current)
- **Network:** bridge
- **Port Mapping:** 8083:80
- **Access URL:** http://192.168.1.110:8083/
- **Config Path:** /mnt/user/appdata/lam

### LAM (After Change)
- **Network:** br0 (macvlan)
- **IP Address:** 192.168.1.116 (to be assigned)
- **Access URL:** http://192.168.1.116/
- **Config Path:** /mnt/user/appdata/lam (unchanged)

---

## Additional Notes
- Both containers use the stable tag: `ghcr.io/ldapaccountmanager/lam:stable`
- Config files are bind-mounted from host for easy access
- LAM is configured with Samba AD DC specific DNs (cn=Users structure)
- PUID/PGID set to 99:100 (nobody:users) for Unraid compatibility
