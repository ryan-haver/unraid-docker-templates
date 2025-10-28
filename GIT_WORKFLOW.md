# Git Workflow & Commit Process

**Last Updated:** October 27, 2025

---

## 🔐 SSH Authentication Setup

This project uses **1Password SSH Agent** for Git authentication.

### Configuration

Git is configured to use Windows OpenSSH with the 1Password SSH agent:

```powershell
git config --global core.sshCommand 'C:/Windows/System32/OpenSSH/ssh.exe'
```

### How It Works

1. **1Password SSH Agent** runs in the background on `\\.\pipe\openssh-ssh-agent`
2. Windows OpenSSH automatically uses this agent (no environment variables needed)
3. When you push/pull, 1Password prompts for authorization (Touch ID, Windows Hello, or password)
4. SSH key never leaves 1Password

### Troubleshooting SSH

If you get "Permission denied (publickey)" errors:

```powershell
# Test SSH connection
ssh -T git@github.com

# Should see: "Hi ryan-haver! You've successfully authenticated..."
```

If SSH test works but Git doesn't:
- Verify Git config: `git config --global core.sshCommand`
- Should be: `C:/Windows/System32/OpenSSH/ssh.exe`

### Reference

- [1Password SSH Documentation](https://developer.1password.com/docs/ssh/)
- [Git Commit Signing with SSH](https://developer.1password.com/docs/ssh/git-commit-signing/)

---

## 📝 Standard Commit Workflow

### 1. Make Your Changes

Edit files, add features, fix bugs as normal.

### 2. Stage Changes

```powershell
# Stage all changes
git add .

# Or stage specific files
git add path/to/file.ps1
```

### 3. Commit (Pre-Commit Validation Runs Automatically)

```powershell
git commit -m "feat: your commit message"
```

**The pre-commit hook automatically runs:**

1. ✅ **Structure Validation** - Ensures workspace organization is correct
2. ✅ **Regression Tests** - Runs 4 test suites (54 assertions total)
3. ✅ **Syntax Check** - Validates PowerShell script syntax

**If validation passes:**
- Commit succeeds ✅
- You can push to GitHub

**If validation fails:**
- Commit is blocked ❌
- Fix the reported issues
- Try committing again

### 4. Push to GitHub

```powershell
git push origin main
```

1Password will prompt you to authorize the SSH key usage.

---

## 🚫 Bypassing Pre-Commit Hook

**Use sparingly!** Only when you need to commit incomplete/broken code temporarily.

```powershell
git commit --no-verify -m "WIP: temporary commit"
```

⚠️ **Warning:** You'll still need passing tests before pushing to shared branches.

---

## 🧪 Pre-Commit Validation Details

### What Gets Tested

#### 1. Structure Validation (`scripts/validate-structure.ps1`)
- ✅ All required folders exist
- ✅ No unwanted files in root directory
- ✅ .gitignore configured correctly
- ✅ Main script exists
- ✅ Documentation structure intact

#### 2. Regression Tests (`tests/run-all-tests.ps1 -Category Regression`)
- **Configuration Persistence** (15 assertions)
  - Config loading/saving
  - Path resolution
  - Settings structure
  
- **Export Formats** (15 assertions)
  - Excel/CSV/JSON/HTML export functions
  - Format-specific requirements
  
- **Menu Navigation** (10 assertions)
  - All menu functions exist
  - Navigation flow intact
  
- **Path Resolution** (14 assertions)
  - Output/log/profile paths correct
  - No old hardcoded paths
  - All folders exist

#### 3. Syntax Validation
- PowerShell parser checks `export_kickstarter_backings.ps1`
- Catches syntax errors before commit

### Example Output

```
╔══════════════════════════════════════════════════════════════════╗
║  Pre-Commit Validation                                          ║
╚══════════════════════════════════════════════════════════════════╝

1. Validating folder structure...
   ✓ Structure valid
2. Running regression tests...
   ✓ Regression tests passed
3. Validating script syntax...
   ✓ Script syntax valid

╔══════════════════════════════════════════════════════════════════╗
║  ✅ PRE-COMMIT VALIDATION PASSED                                 ║
╚══════════════════════════════════════════════════════════════════╝

Proceeding with commit...
```

---

## 🔄 Common Workflows

### Adding New Features

```powershell
# 1. Create feature branch (optional but recommended)
git checkout -b feature/new-feature

# 2. Make changes
# ... edit files ...

# 3. Stage and commit (tests run automatically)
git add .
git commit -m "feat: add new feature"

# 4. Push to GitHub
git push origin feature/new-feature

# 5. Create pull request on GitHub
```

### Fixing Bugs

```powershell
# 1. Make fixes
# ... edit files ...

# 2. Run tests manually (optional - they run on commit anyway)
.\tests\run-all-tests.ps1 -Category Regression

# 3. Commit (tests run again automatically)
git add .
git commit -m "fix: resolve issue with X"

# 4. Push
git push origin main
```

### Updating Documentation

```powershell
# 1. Edit documentation files
# ... edit .md files ...

# 2. Commit (tests still run, but won't fail on doc changes)
git add docs/
git commit -m "docs: update installation guide"

# 3. Push
git push origin main
```

### Emergency Commit (Broken Code)

```powershell
# 1. Stage changes
git add .

# 2. Bypass validation (use sparingly!)
git commit --no-verify -m "WIP: work in progress"

# 3. Don't push to main yet - fix tests first
# ... fix issues ...

# 4. Amend commit with fixes
git add .
git commit --amend --no-edit

# 5. Now push
git push origin main
```

---

## 📊 Running Tests Manually

### All Regression Tests
```powershell
.\tests\run-all-tests.ps1 -Category Regression
```

### Fast Tests Only
```powershell
.\tests\run-all-tests.ps1 -Fast
```

### Specific Test
```powershell
.\tests\regression\test-path-resolution.ps1
```

### With VS Code Task
- Press `Ctrl+Shift+P`
- Type "Tasks: Run Task"
- Select "Run Regression Tests"

---

## 🛠️ Git Configuration

### View Current Config
```powershell
# View SSH command
git config --global core.sshCommand

# View all Git config
git config --global --list
```

### SSH-Related Settings
```powershell
# SSH command for 1Password
core.sshCommand=C:/Windows/System32/OpenSSH/ssh.exe

# Commit signing (optional)
gpg.format=ssh
gpg.ssh.program=C:\Users\ryanh\AppData\Local\1Password\app\8\op-ssh-sign.exe
commit.gpgsign=true
user.signingkey=ssh-ed25519 AAAA... (your key)
```

---

## 🆘 Troubleshooting

### Pre-Commit Hook Not Running?

Check if hook is installed:
```powershell
Test-Path .git\hooks\pre-commit
```

Reinstall if needed:
```powershell
.\scripts\install-hooks.ps1
```

### Tests Failing Unexpectedly?

Run tests manually to see detailed output:
```powershell
.\tests\run-all-tests.ps1 -Category Regression
```

Check test results:
```powershell
cat .\tests\test-results\latest\summary.json | ConvertFrom-Json | Format-List
```

### SSH Authentication Issues?

1. Verify 1Password SSH agent is running
2. Test SSH connection: `ssh -T git@github.com`
3. Check Git SSH config: `git config --global core.sshCommand`
4. Ensure SSH key is in 1Password and added to GitHub

### Structure Validation Fails?

Run validator manually:
```powershell
.\scripts\validate-structure.ps1
```

Check for:
- Files in root that should be in subdirectories
- Missing required folders
- Incorrect .gitignore configuration

---

## 📋 Commit Message Conventions

Use conventional commit format:

```
<type>: <description>

[optional body]

[optional footer]
```

### Types:
- **feat:** New feature
- **fix:** Bug fix
- **docs:** Documentation changes
- **test:** Adding or updating tests
- **refactor:** Code refactoring
- **style:** Formatting, missing semicolons, etc.
- **chore:** Maintenance tasks

### Examples:
```powershell
git commit -m "feat: add JSON export format"
git commit -m "fix: resolve Cloudflare timeout issue"
git commit -m "docs: update quick start guide"
git commit -m "test: add menu navigation tests"
git commit -m "refactor: simplify session management"
```

---

## 📁 Files Not Committed

These files are in the repository but **not tracked by Git**:

- `TODO.md` - Local task tracking (in `.gitignore`)
- `GIT_WORKFLOW.md` - This file (in `.gitignore`)
- `config.json` - Contains credentials (in `.gitignore`)
- `runtime/` - Browser profiles, logs, sessions (in `.gitignore`)
- `output/` - Export files (in `.gitignore`)
- `drivers/` - ChromeDriver binaries (in `.gitignore`)
- `tests/test-results/` - Test output files (in `.gitignore`)

---

## 🔍 Quick Reference

| Command | Description |
|---------|-------------|
| `git status` | Show current state |
| `git add .` | Stage all changes |
| `git commit -m "message"` | Commit with pre-validation |
| `git commit --no-verify` | Bypass pre-commit hook |
| `git push origin main` | Push to GitHub |
| `ssh -T git@github.com` | Test SSH connection |
| `.\tests\run-all-tests.ps1` | Run all tests manually |
| `.\scripts\validate-structure.ps1` | Check folder structure |

---

**For detailed SSH setup, see:** [1Password SSH Documentation](https://developer.1password.com/docs/ssh/get-started/)

**For testing guide, see:** [docs/reference/TESTING_GUIDE_v4.0.0.md](docs/reference/TESTING_GUIDE_v4.0.0.md)
