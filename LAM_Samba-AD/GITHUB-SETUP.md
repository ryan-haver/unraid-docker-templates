# GitHub Repository Setup Guide

This guide walks you through setting up the Samba AD + LAM container repository on GitHub with automated Docker image building.

## Quick Setup (5 Minutes)

### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `samba-ad-lam`
3. Description: `Combined Samba Active Directory + LAM container for testing environments`
4. Visibility: Public (or Private if preferred)
5. Initialize: **DO NOT** check "Add README" (we have one)
6. Click **Create repository**

### Step 2: Configure Docker Hub Secrets

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click **New repository secret**
3. Add two secrets:

   **Secret 1:**
   - Name: `DOCKER_USERNAME`
   - Value: Your Docker Hub username
   
   **Secret 2:**
   - Name: `DOCKER_PASSWORD`
   - Value: Your Docker Hub password or access token

### Step 3: Push Code to GitHub

```bash
cd C:\scripts\unraid-templates\LAM_Samba-AD

# Initialize git (if not already)
git init

# Add all files
git add .

# First commit
git commit -m "Initial commit: Combined Samba AD + LAM container"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/yourusername/samba-ad-lam.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 4: Verify GitHub Actions

1. Go to your repository → Actions tab
2. You should see "Build and Push Docker Image" workflow running
3. Wait for it to complete (5-10 minutes first time)
4. Check Docker Hub - your image should be there!

## Automated Workflow Features

### What Happens Automatically?

- **On every push to `main`**: Builds and pushes `latest` tag
- **On git tags (v1.0.0)**: Builds and pushes version tags
- **On pull requests**: Builds but doesn't push (testing only)
- **Multi-architecture**: Builds for AMD64 and ARM64
- **Caching**: Uses GitHub Actions cache for faster builds

### Supported Tags

The workflow automatically creates these tags:

```
yourusername/samba-ad-lam:latest       (main branch)
yourusername/samba-ad-lam:main         (main branch)
yourusername/samba-ad-lam:1.0.0        (git tag v1.0.0)
yourusername/samba-ad-lam:1.0          (major.minor)
yourusername/samba-ad-lam:1            (major only)
```

## User Deployment (Simple!)

### For End Users - No Building Required!

Once you have the GitHub repo set up, users can deploy in 3 ways:

#### Method 1: Pull Pre-Built Image (Easiest)
```bash
# Just pull the image from Docker Hub
docker pull yourusername/samba-ad-lam:latest

# Then use the Unraid template as normal
```

#### Method 2: Build from GitHub URL
```bash
# Build directly from GitHub (no git clone needed)
docker build -t samba-ad-lam https://github.com/yourusername/samba-ad-lam.git
```

#### Method 3: Clone and Build Locally
```bash
# Clone repo
git clone https://github.com/yourusername/samba-ad-lam.git
cd samba-ad-lam

# Build
docker build -t samba-ad-lam .
```

## Update Unraid Template for GitHub

Update your `samba-ad-lam-combined.xml` to point to Docker Hub:

```xml
<Repository>yourusername/samba-ad-lam</Repository>
<Registry>https://hub.docker.com/r/yourusername/samba-ad-lam</Registry>
```

Users will automatically get updates when you push to GitHub!

## Versioning Strategy

### Semantic Versioning

Use semantic versioning for releases:

```bash
# Create a version tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# GitHub Actions will automatically build and push:
# - yourusername/samba-ad-lam:1.0.0
# - yourusername/samba-ad-lam:1.0
# - yourusername/samba-ad-lam:1
```

### Branch Strategy

- **main**: Stable releases (auto-builds to `latest`)
- **develop**: Development branch (auto-builds to `develop`)
- **feature/***: Feature branches (no auto-build)

## Repository Structure

Your GitHub repo will look like:

```
samba-ad-lam/
├── .github/
│   └── workflows/
│       └── docker-build.yml          # GitHub Actions workflow
├── .gitignore                         # Git ignore rules
├── .dockerignore                      # Docker build ignore rules
├── Dockerfile                         # Container build instructions
├── init.sh                           # Initialization script
├── domain.sh                         # Domain management
├── lam-config.sh                     # LAM configuration
├── nginx-lam.conf                    # Nginx config
├── samba-ad-lam-combined.xml         # Unraid template
├── README.md                         # Main documentation
├── QUICK-START.md                    # Quick deployment guide
├── GITHUB-SETUP.md                   # This file
└── IMPLEMENTATION-PLAN.md            # Technical details
```

## Badges for README

Add these to your README.md:

```markdown
[![Docker Build](https://github.com/yourusername/samba-ad-lam/actions/workflows/docker-build.yml/badge.svg)](https://github.com/yourusername/samba-ad-lam/actions/workflows/docker-build.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/yourusername/samba-ad-lam)](https://hub.docker.com/r/yourusername/samba-ad-lam)
[![Docker Image Size](https://img.shields.io/docker/image-size/yourusername/samba-ad-lam/latest)](https://hub.docker.com/r/yourusername/samba-ad-lam)
[![License](https://img.shields.io/github/license/yourusername/samba-ad-lam)](LICENSE)
```

## Docker Hub Setup (Optional)

### Link GitHub to Docker Hub

For even more automation:

1. Go to https://hub.docker.com/
2. Create repository: `yourusername/samba-ad-lam`
3. Go to "Builds" tab
4. Connect to GitHub
5. Select your repository
6. Configure build rules:
   - Source: `main` → Tag: `latest`
   - Source: `/^v[0-9.]+$/` → Tag: `{sourceref}`

Now Docker Hub will also auto-build on push!

## Maintenance Workflow

### Making Updates

```bash
# Make changes to files
git add .
git commit -m "feat: add new feature"
git push

# GitHub Actions automatically builds and pushes to Docker Hub
# Users can pull the updated image
```

### Creating Releases

```bash
# When ready for a release
git tag -a v1.1.0 -m "Release v1.1.0: Added XYZ feature"
git push origin v1.1.0

# GitHub Actions builds and tags as 1.1.0, 1.1, and 1
```

### Hotfixes

```bash
# Create hotfix branch
git checkout -b hotfix/fix-critical-bug
# Make fixes
git commit -m "fix: critical bug"
git push origin hotfix/fix-critical-bug

# Create PR to main
# After merge, tag new version
git checkout main
git pull
git tag -a v1.0.1 -m "Hotfix v1.0.1"
git push origin v1.0.1
```

## Benefits of This Approach

### For You (Maintainer)
- ✅ Version control and history
- ✅ Automated builds on push
- ✅ No manual Docker Hub pushes
- ✅ Multi-architecture builds
- ✅ Build caching (faster)
- ✅ CI/CD pipeline

### For Users
- ✅ Always get latest version
- ✅ No need to build locally
- ✅ Fast deployment (pre-built images)
- ✅ Version pinning available
- ✅ Transparent development

### For Collaboration
- ✅ Pull requests for contributions
- ✅ Issue tracking
- ✅ Documentation in repo
- ✅ Community can fork/improve

## Alternative: GitHub Container Registry

Instead of Docker Hub, use GitHub Container Registry (ghcr.io):

```yaml
# In .github/workflows/docker-build.yml, change:
env:
  DOCKER_IMAGE: ghcr.io/yourusername/samba-ad-lam

# And login step:
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

**Advantages of ghcr.io:**
- Free for public repos
- Integrated with GitHub
- No separate Docker Hub account needed
- Automatic cleanup of old images

## Simplified User Instructions

Update your README with:

```markdown
## Quick Install

### Pull from Docker Hub (Recommended)
```bash
docker pull yourusername/samba-ad-lam:latest
```

### Or Build from GitHub
```bash
docker build -t samba-ad-lam https://github.com/yourusername/samba-ad-lam.git
```

Then deploy using the Unraid template!
```

## Next Steps

1. ✅ Create GitHub repository
2. ✅ Add Docker Hub secrets
3. ✅ Push code to GitHub
4. ✅ Verify GitHub Actions build
5. ✅ Test pulling image from Docker Hub
6. ✅ Update README with Docker Hub link
7. ✅ Share repository URL with users

---

**Estimated Setup Time**: 5-10 minutes
**Future Updates**: Automatic on every push!
**User Experience**: Pull and run - no building needed!
