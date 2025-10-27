# GitHub Repository Setup - 5 Minute Checklist

## ✅ What You'll Get

- 🚀 Automated Docker image builds on every push
- 📦 Images published to Docker Hub automatically
- 🏗️ Multi-architecture support (AMD64 + ARM64)
- 🔄 Users can simply `docker pull` - no building needed!
- 🏷️ Automatic version tagging

---

## 📋 Setup Steps

### 1️⃣ Create GitHub Repository (1 minute)

- [ ] Go to https://github.com/new
- [ ] Name: `samba-ad-lam`
- [ ] Visibility: Public
- [ ] **DO NOT** check "Initialize with README" (we have files)
- [ ] Click "Create repository"

### 2️⃣ Add Docker Hub Credentials (1 minute)

- [ ] Go to your repo → **Settings** → **Secrets and variables** → **Actions**
- [ ] Click "New repository secret"
- [ ] Add secret: `DOCKER_USERNAME` = your Docker Hub username
- [ ] Add secret: `DOCKER_PASSWORD` = your Docker Hub password/token

> 💡 Get Docker Hub token at: https://hub.docker.com/settings/security

### 3️⃣ Push Code to GitHub (2 minutes)

```bash
cd C:\scripts\unraid-templates\LAM_Samba-AD

# Initialize git
git init
git add .
git commit -m "Initial commit: Combined Samba AD + LAM container"

# Add your GitHub repo (replace with your URL)
git remote add origin https://github.com/yourusername/samba-ad-lam.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### 4️⃣ Verify Auto-Build (1 minute)

- [ ] Go to your repo → **Actions** tab
- [ ] See "Build and Push Docker Image" workflow running
- [ ] Wait for green checkmark ✅ (5-10 minutes)
- [ ] Check Docker Hub - image should appear!

---

## 🎉 Done! Now What?

### Update Unraid Template

Edit `samba-ad-lam-combined.xml`:

```xml
<Repository>yourusername/samba-ad-lam</Repository>
<Registry>https://hub.docker.com/r/yourusername/samba-ad-lam</Registry>
```

### Users Can Now Deploy Easily!

**Option 1: Unraid WebUI (Easiest)**
1. Add Container → Select your template
2. Configure settings
3. Click Apply
4. Unraid automatically pulls from Docker Hub!

**Option 2: Command Line**
```bash
# Just pull and run - no building!
docker pull yourusername/samba-ad-lam:latest
```

---

## 🔄 Making Updates (Future)

```bash
# Make changes to files
git add .
git commit -m "feat: add new feature"
git push

# GitHub Actions automatically:
# ✅ Builds new image
# ✅ Pushes to Docker Hub
# ✅ Tags as 'latest'

# Users can update with:
docker pull yourusername/samba-ad-lam:latest
```

---

## 🏷️ Creating Releases

```bash
# Tag a version
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# GitHub Actions automatically creates:
# ✅ yourusername/samba-ad-lam:1.0.0
# ✅ yourusername/samba-ad-lam:1.0
# ✅ yourusername/samba-ad-lam:1
# ✅ yourusername/samba-ad-lam:latest
```

Users can pin to specific versions:
```bash
docker pull yourusername/samba-ad-lam:1.0.0  # Specific version
docker pull yourusername/samba-ad-lam:latest  # Latest release
```

---

## 🆘 Troubleshooting

### GitHub Actions Failed?

1. Check Actions tab for error details
2. Verify Docker Hub credentials in Secrets
3. Check Dockerfile syntax
4. Re-run failed jobs

### Image Not on Docker Hub?

1. Verify workflow completed successfully (green checkmark)
2. Check Docker Hub repository exists: `https://hub.docker.com/r/yourusername/samba-ad-lam`
3. Verify you're logged into Docker Hub
4. Check workflow logs for push errors

### Build Takes Too Long?

First build: 10-15 minutes (normal)
Subsequent builds: 3-5 minutes (cached)

GitHub Actions uses layer caching to speed up builds!

---

## 📚 More Information

- **Full GitHub Setup Guide**: See `GITHUB-SETUP.md`
- **User Deployment**: See `QUICK-START.md`
- **Complete Documentation**: See `README.md`

---

## ✨ Benefits Summary

| Before (Manual) | After (GitHub + Actions) |
|-----------------|--------------------------|
| Build locally | Auto-builds on push |
| Manual push to Docker Hub | Auto-pushes to Docker Hub |
| Users build from source | Users just `docker pull` |
| Version control: none | Full git history |
| Updates: manual rebuild | Updates: `git push` |
| Multi-arch: complex | Multi-arch: automatic |

**Estimated Time Saved**: Hours per release! 🎉

---

**Ready to go?** Start with Step 1 above! ⬆️
