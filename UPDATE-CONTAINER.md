# Update Samba-AD-LAM Container with New PHP Version

## Step 1: Wait for Build to Complete
Check GitHub Actions: https://github.com/ryan-haver/unraid-docker-templates/actions
- Wait for green checkmark ✅
- Build typically takes 3-5 minutes

## Step 2: Update Container on Unraid

### Option A: Via Unraid Web UI (Easiest)
1. Go to Docker tab
2. Click **Stop** on "Samba-AD-LAM" container
3. Click **Remove** (your data is safe in `/mnt/user/appdata/samba-ad-lam/data`)
4. Click **Add Container**
5. Under "Template" dropdown, select **"Samba-AD-LAM"** (pulls your saved config)
6. Click **Apply** (Unraid will pull new image automatically)
7. Wait 2-3 minutes for domain provisioning
8. Access LAM at http://192.168.1.115:8080

### Option B: Via SSH/Terminal
```bash
# Connect to Unraid
ssh root@192.168.1.110

# Stop and remove container
docker stop Samba-AD-LAM
docker remove Samba-AD-LAM

# Pull new image
docker pull ghcr.io/ryan-haver/samba-ad-lam:latest

# Recreate from saved template
# (Go back to Web UI and use "Add Container" → select "Samba-AD-LAM" from dropdown)
```

## Step 3: Verify PHP Version
Once container is running:
```bash
docker exec Samba-AD-LAM php -v
```
Should show: **PHP 8.1.x** (where x >= 10)

## Step 4: Access LAM
Open browser to: http://192.168.1.115:8080
- Should no longer show PHP version error
- Login with LAM Master Password: `*2!67oZ*MWKX6hEZj9`

## Your Configuration (Preserved)
All these settings are saved in `/mnt/user/appdata/samba-ad-lam/data`:
- Domain: haver.internal
- Container IP: 192.168.1.115
- Domain Admin Password: MBF.bmg5trk1vmq_wzj
- DNS Forwarder: 192.168.1.1
- LAM Password: *2!67oZ*MWKX6hEZj9

## Troubleshooting
If LAM still shows errors:
```bash
# Check container logs
docker logs Samba-AD-LAM

# Check PHP version
docker exec Samba-AD-LAM php -v

# Check LAM installation
docker exec Samba-AD-LAM ls -la /var/www/html/lam
```
