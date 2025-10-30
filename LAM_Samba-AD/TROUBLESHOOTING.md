# LAM Authentication Troubleshooting

## Current Error: Invalid Credentials (data 52e)

**Error Message**:
```
Wrong password/user name combination. Please try again.
LDAP error, server says: Invalid credentials - 80090308: LdapErr: DSID-0C0903A9, 
comment: AcceptSecurityContext error, data 52e, v1db1
```

**Error Code Meaning**:
- `data 52e` = **Invalid credentials** (wrong username OR password)

## Root Cause

init.sh had `loginMethod: "fixed"` which **doesn't exist in LAM 9.3**. 

Valid methods are:
- ✅ `"list"` - Show dropdown of admin DNs
- ✅ `"search"` - Search LDAP for users
- ❌ `"fixed"` - **Does not exist!**

## Fix Applied

Changed line 780 in init.sh:
```diff
- "loginMethod": "fixed",
+ "loginMethod": "list",
```

## Deployment Steps

### 1. Update Container Image

```bash
# On Unraid, update to latest image
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest
```

### 2. Clear Old Config

```bash
# Delete old haver.conf to force regeneration
rm /mnt/user/appdata/Samba-AD-LAM/lam/config/haver.conf

# Or delete entire LAM config directory
rm -rf /mnt/user/appdata/Samba-AD-LAM/lam/config/*
```

### 3. Restart Container

```bash
docker restart Samba-AD-LAM
```

### 4. Verify Config Generated

```bash
# Check haver.conf has loginMethod: list
cat /mnt/user/appdata/Samba-AD-LAM/lam/config/haver.conf | grep loginMethod
# Should show: "loginMethod": "list",
```

## Login Process with "list" Method

### What You Should See

1. **Profile Selection**: Choose "haver" profile
2. **Login Form**:
   - **Dropdown** (not text field) with "Administrator" option
   - **Password** field

### Credentials to Use

**Username**: Select "Administrator" from dropdown
**Password**: Your DOMAINPASS value (the domain admin password you set)

### What "list" Method Does

1. LAM reads the `Admins` field from haver.conf:
   ```json
   "Admins": "CN=Administrator,CN=Users,DC=haver,DC=internal"
   ```

2. Splits DN by comma: `["CN=Administrator", "CN=Users", "DC=haver", "DC=internal"]`

3. Takes first component: `"CN=Administrator"`

4. Extracts value: `"Administrator"`

5. Creates dropdown with **"Administrator"** as display text and full DN as value

6. When you select it and enter password, LAM binds to LDAP as:
   ```
   DN: CN=Administrator,CN=Users,DC=haver,DC=internal
   Password: <your DOMAINPASS>
   ```

## Verification Checklist

After rebuilding container:

- [ ] Container started successfully
- [ ] Navigate to http://<container-ip>:8080
- [ ] Select "haver" profile
- [ ] See **dropdown** (not text field) for username
- [ ] Dropdown contains "Administrator" option
- [ ] Select "Administrator" from dropdown
- [ ] Enter domain admin password (DOMAINPASS)
- [ ] Click Login

### Expected Result

✅ **Login successful** → Redirected to user list page  
✅ **User list displays** → Shows users with sAMAccountName, givenName, sn, mail columns  
✅ **No errors in logs** → Check `/var/log/nginx/lam-error.log` for no TypeError

## If Still Getting Invalid Credentials

### 1. Verify Password is Correct

Test LDAP bind directly:
```bash
docker exec Samba-AD-LAM ldapsearch -LLL \
  -H ldaps://127.0.0.1:636 \
  -D "CN=Administrator,CN=Users,DC=haver,DC=internal" \
  -w "YOUR_DOMAINPASS" \
  -b "DC=haver,DC=internal" \
  -s base "(objectClass=*)"
```

**Expected**: Success with output showing base DN info  
**If fails**: Password is wrong or DN format is wrong

### 2. Check haver.conf Was Regenerated

```bash
docker exec Samba-AD-LAM cat /var/www/html/lam/config/haver.conf | jq .loginMethod
```

**Should show**: `"list"`  
**If shows**: `"fixed"` → Config wasn't regenerated, delete and restart

### 3. Verify Admins Field Format

```bash
docker exec Samba-AD-LAM cat /var/www/html/lam/config/haver.conf | jq .Admins
```

**Should show**: `"CN=Administrator,CN=Users,DC=haver,DC=internal"`  
**Check**: 
- Must be STRING (not array)
- Must use uppercase CN and DC
- Must not have semicolon (unless multiple admins)

### 4. Check LAM Error Logs

```bash
docker exec Samba-AD-LAM tail -50 /var/log/nginx/lam-error.log
```

Look for:
- PHP errors
- LDAP connection errors
- Certificate errors
- Authentication errors

### 5. Check LAM Can Connect to Samba

```bash
docker exec Samba-AD-LAM php -r "
\$conn = ldap_connect('ldaps://127.0.0.1:636');
if (\$conn) {
    echo 'LDAP connection successful\n';
    ldap_set_option(\$conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    ldap_set_option(\$conn, LDAP_OPT_REFERRALS, 0);
    \$bind = @ldap_bind(\$conn, 'CN=Administrator,CN=Users,DC=haver,DC=internal', 'YOUR_DOMAINPASS');
    if (\$bind) {
        echo 'LDAP bind successful!\n';
    } else {
        echo 'LDAP bind failed: ' . ldap_error(\$conn) . '\n';
    }
}
"
```

## Common Issues

### Issue 1: "fixed" loginMethod
**Symptom**: Invalid credentials error  
**Cause**: LAM 9.3 doesn't have "fixed" method  
**Fix**: Use "list" or "search"

### Issue 2: Wrong Password
**Symptom**: data 52e error  
**Cause**: DOMAINPASS doesn't match what's in Samba  
**Fix**: Verify password with direct ldapsearch

### Issue 3: Wrong DN Format
**Symptom**: Invalid credentials or object not found  
**Cause**: Lowercase cn/dc or wrong structure  
**Fix**: Use uppercase: `CN=Administrator,CN=Users,DC=haver,DC=internal`

### Issue 4: Certificate Trust Issues
**Symptom**: Can't connect to LDAPS  
**Cause**: Self-signed cert not trusted  
**Fix**: Check serverCerts.pem contains Samba cert

### Issue 5: Admins as Array
**Symptom**: LAM can't parse config  
**Cause**: Admins field is JSON array not string  
**Fix**: Must be semicolon-separated string

## Password Reset (If Needed)

If you've forgotten the domain admin password:

```bash
# SSH to Unraid
docker exec -it Samba-AD bash

# Reset Administrator password
samba-tool user setpassword Administrator --newpassword="YourNewPassword123!"

# Test it works
ldapsearch -H ldaps://127.0.0.1:636 \
  -D "CN=Administrator,CN=Users,DC=haver,DC=internal" \
  -w "YourNewPassword123!" \
  -b "DC=haver,DC=internal" -s base
```

## Validation Before Testing

Before trying to login, run validation:

```bash
cd /mnt/user/appdata/unraid-templates
python3 LAM_Samba-AD/scripts/validate_lam_config.py \
  /mnt/user/appdata/Samba-AD-LAM/lam/config/haver.conf
```

Should show:
```
✅ Configuration validated successfully!
   All checks passed
```

## Success Indicators

When everything is working:

1. ✅ haver.conf has `"loginMethod": "list"`
2. ✅ LAM shows dropdown (not text field)
3. ✅ Can select "Administrator" from dropdown
4. ✅ Login succeeds with domain password
5. ✅ User list page displays without errors
6. ✅ No errors in `/var/log/nginx/lam-error.log`
7. ✅ attr_user attributes all display correctly

## Still Need Help?

Check these logs in order:

1. **LAM Error Log**:
   ```bash
   docker exec Samba-AD-LAM tail -100 /var/log/nginx/lam-error.log
   ```

2. **LAM Access Log**:
   ```bash
   docker exec Samba-AD-LAM tail -100 /var/log/nginx/lam-access.log
   ```

3. **Samba Log**:
   ```bash
   docker exec Samba-AD tail -100 /var/log/samba/log.samba
   ```

4. **Container Logs**:
   ```bash
   docker logs Samba-AD-LAM --tail 100
   ```

Share these logs if issue persists.
