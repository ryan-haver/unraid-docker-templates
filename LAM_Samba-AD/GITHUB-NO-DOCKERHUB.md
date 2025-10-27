# GitHub-Only Setup - No Docker Hub Required!

## ✅ What You Get

- 🚀 Automated Docker image builds on every push
- 📦 Images hosted on **GitHub Container Registry (ghcr.io)** - FREE!
- 🏗️ Multi-architecture support (AMD64 + ARM64)
- 🔄 Users can simply `docker pull` - no Docker Hub account needed!
- 🔒 Built-in authentication via GitHub

---

## 📋 Super Simple Setup (3 Minutes!)

### 1️⃣ Create GitHub Repository (1 minute)

- [ ] Go to https://github.com/new
- [ ] Name: `samba-ad-lam`
- [ ] Visibility: **Public** (required for free ghcr.io hosting)
- [ ] **DO NOT** check "Initialize with README"
- [ ] Click "Create repository"

### 2️⃣ Push Code to GitHub (1 minute)

```bash
cd C:\scripts\unraid-templates\LAM_Samba-AD

# Initialize git
git init
git add .
git commit -m "Initial commit: Combined Samba AD + LAM container"

# Add your GitHub repo (REPLACE WITH YOUR USERNAME!)
git remote add origin https://github.com/yourusername/samba-ad-lam.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### 3️⃣ Verify Auto-Build (1 minute)

- [ ] Go to your repo → **Actions** tab
- [ ] See "Build and Push Docker Image" workflow running
- [ ] Wait for green checkmark ✅ (5-10 minutes first time)
- [ ] Go to your repo main page → **Packages** (right sidebar)
- [ ] Your image should appear! 🎉

**That's it! No secrets, no Docker Hub account, nothing else needed!**

---

## 🎉 How Users Deploy

### Pull from GitHub Container Registry

```bash
# Pull the image (free, no authentication needed for public repos!)
docker pull ghcr.io/yourusername/samba-ad-lam:latest
```

### In Unraid Template

The template is already configured:
```xml
<Repository>ghcr.io/yourusername/samba-ad-lam</Repository>
```

Users just:
1. Add Container → Select template
2. Configure settings
3. Click Apply
4. Unraid pulls from GitHub automatically!

---

## 🔄 Making Updates (Future)

```bash
# Make changes to files
git add .
git commit -m "feat: add new feature"
git push

# GitHub Actions automatically:
# ✅ Builds new image
# ✅ Pushes to ghcr.io
# ✅ Tags as 'latest'
# ✅ No Docker Hub, no secrets required!
```

---

## 🏷️ Version Releases

```bash
# Tag a version
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# GitHub Actions automatically creates:
# ✅ ghcr.io/yourusername/samba-ad-lam:1.0.0
# ✅ ghcr.io/yourusername/samba-ad-lam:1.0
# ✅ ghcr.io/yourusername/samba-ad-lam:1
# ✅ ghcr.io/yourusername/samba-ad-lam:latest
```

---

## 🆚 Why GitHub Container Registry vs Docker Hub?

| Feature | ghcr.io | Docker Hub |
|---------|---------|------------|
| **Cost** | FREE (unlimited for public) | Free tier limited |
| **Setup** | Zero config (built-in GitHub token) | Requires separate account + secrets |
| **Authentication** | Automatic via GitHub | Manual login required |
| **Integration** | Native GitHub integration | External service |
| **Bandwidth** | Unlimited | Limited on free tier |
| **Storage** | Unlimited for public images | Limited on free tier |
| **Secrets Needed** | ❌ None! | ✅ DOCKER_USERNAME + DOCKER_PASSWORD |

**Winner: ghcr.io for simplicity and cost!** 🏆

---

## 🔍 Viewing Your Images

### On GitHub
1. Go to your repository
2. Right sidebar → **Packages**
3. Click your image name
4. See all versions and pull commands

### Package URL Format
```
https://github.com/yourusername/samba-ad-lam/pkgs/container/samba-ad-lam
```

---

## 🔒 Making Images Public (Important!)

By default, package visibility inherits from repo. To ensure public access:

1. Go to your package: https://github.com/users/yourusername/packages/container/samba-ad-lam
2. Click **Package settings** (right sidebar)
3. Scroll to **Danger Zone**
4. Click **Change visibility** → **Public**
5. Confirm

Now anyone can pull without authentication!

---

## 📦 Pull Commands

Users can pull images with:

```bash
# Latest version
docker pull ghcr.io/yourusername/samba-ad-lam:latest

# Specific version
docker pull ghcr.io/yourusername/samba-ad-lam:1.0.0

# Specific branch (for testing)
docker pull ghcr.io/yourusername/samba-ad-lam:main
```

---

## 🆘 Troubleshooting

### Workflow Failed?
1. Check Actions tab for error details
2. Verify repository is public
3. Check Dockerfile syntax
4. Re-run failed jobs

### Can't Pull Image?
1. Verify package is public (see "Making Images Public" above)
2. Check package exists: go to repo → Packages
3. Verify image name matches: `ghcr.io/yourusername/samba-ad-lam`

### Image Not Showing Up?
1. Wait for Actions workflow to complete (green checkmark)
2. Refresh Packages sidebar on repo main page
3. Check workflow logs for push errors

---

## 🚀 Advanced: Private Images (Optional)

If you want private images (requires authentication):

```bash
# Authenticate to pull private images
echo $GITHUB_TOKEN | docker login ghcr.io -u yourusername --password-stdin

# Then pull
docker pull ghcr.io/yourusername/samba-ad-lam:latest
```

For Unraid with private images, add credentials in Docker settings.

---

## ✨ Benefits Summary

**What You DON'T Need:**
- ❌ Docker Hub account
- ❌ Docker Hub secrets
- ❌ Manual Docker login
- ❌ Separate container registry
- ❌ Credit card for registry hosting

**What You DO Get:**
- ✅ Automatic builds on push
- ✅ Free unlimited storage
- ✅ Free unlimited bandwidth
- ✅ Built-in version control
- ✅ Native GitHub integration
- ✅ Multi-architecture builds
- ✅ Zero configuration secrets

---

## 📚 Resources

- **GitHub Packages Docs**: https://docs.github.com/en/packages
- **Container Registry Guide**: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- **Your Packages**: https://github.com/yourusername?tab=packages

---

## 🎯 Quick Checklist

- [ ] GitHub repo created (public)
- [ ] Code pushed to GitHub
- [ ] GitHub Actions workflow completed
- [ ] Package visible in GitHub Packages
- [ ] Package set to public visibility
- [ ] Image pullable: `docker pull ghcr.io/yourusername/samba-ad-lam:latest`
- [ ] Unraid template updated with ghcr.io URL

---

**Total Setup Time**: ~3 minutes
**Secrets Required**: 0
**External Accounts**: 0
**Cost**: $0 forever

**Ready to go?** Just create the repo and `git push`! 🚀
