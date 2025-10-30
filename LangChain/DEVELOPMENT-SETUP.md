# Development Environment Setup Guide

## Executive AI Assistant - Local Development Setup

**Last Updated**: October 30, 2025  
**Python Version**: 3.12  
**Status**: ✅ Verified Working

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Setup](#repository-setup)
3. [Python Environment](#python-environment)
4. [Dependency Installation](#dependency-installation)
5. [Dependency Issues & Resolutions](#dependency-issues--resolutions)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

---

## Prerequisites

### Required Software

- **Python 3.12** (Microsoft Store version recommended for Windows)
- **Git** for repository management
- **PowerShell** or equivalent terminal
- **GitHub Account** (for forking the repository)

### Optional but Recommended

- **VS Code** with Python extension
- **Ollama** (for local LLM testing)
- **Docker Desktop** (for container testing)

---

## Repository Setup

### 1. Fork the Repository

1. Navigate to: https://github.com/langchain-ai/executive-ai-assistant
2. Click "Fork" button (top right)
3. Select your GitHub account as the destination

### 2. Clone Your Fork

```powershell
# Navigate to your working directory
cd C:\scripts\unraid-templates\LangChain

# Clone your forked repository
git clone https://github.com/YOUR_USERNAME/executive-ai-assistant.git
cd executive-ai-assistant
```

### 3. Add Upstream Remote (Optional)

```powershell
# Add original repository as upstream for future updates
git remote add upstream https://github.com/langchain-ai/executive-ai-assistant.git

# Verify remotes
git remote -v
```

**Expected output:**
```
origin    https://github.com/YOUR_USERNAME/executive-ai-assistant.git (fetch)
origin    https://github.com/YOUR_USERNAME/executive-ai-assistant.git (push)
upstream  https://github.com/langchain-ai/executive-ai-assistant.git (fetch)
upstream  https://github.com/langchain-ai/executive-ai-assistant.git (push)
```

---

## Python Environment

### 1. Verify Python Installation

```powershell
python --version
```

**Expected output:** `Python 3.12.x`

> ⚠️ **Important**: If you see Python 3.11 or earlier, install Python 3.12 from the Microsoft Store or python.org

### 2. Create Virtual Environment

```powershell
# Create virtual environment
python -m venv venv

# Activate virtual environment (PowerShell)
.\venv\Scripts\Activate.ps1
```

**Expected output:** Your terminal prompt should now show `(venv)` prefix

> 💡 **Tip**: If you get an execution policy error, run:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

### 3. Upgrade pip

```powershell
python -m pip install --upgrade pip
```

---

## Dependency Installation

### Overview

The project uses several key dependency families:

- **LangChain Ecosystem**: Core framework, community integrations, text splitters
- **LangGraph**: Workflow orchestration and API server
- **LLM Providers**: OpenAI, Anthropic integrations
- **Google APIs**: Gmail, Calendar, Drive access
- **Infrastructure**: uvicorn, starlette, cryptography

### Initial Installation

```powershell
# Install the package in editable mode
pip install -e .
```

> ⚠️ **Note**: You WILL encounter dependency conflicts. See next section for resolution.

### Additional Required Packages

```powershell
# Install langchain-community for Ollama support
pip install langchain-community
```

---

## Dependency Issues & Resolutions

### Issue 1: Yanked Package Versions

**Problem:**
```
ERROR: No matching distribution found for langgraph-api<0.3.0,>=0.2.134
Ignored yanked versions: 0.2.134, 0.2.135, 0.2.137
```

**Root Cause:**  
The `pyproject.toml` specified `langgraph-api = "^0.2.134"`, but versions 0.2.134-0.2.137 were yanked (removed) from PyPI.

**Solution:**  
Update `pyproject.toml` to use a compatible non-yanked version:

```toml
# File: pyproject.toml
# Line: ~31 (in [tool.poetry.dependencies])

# BEFORE:
langgraph-api = "^0.2.134"

# AFTER:
langgraph-api = "^0.2.120"
```

**Why this works:**
- Version 0.2.120 is available on PyPI (not yanked)
- Falls within the constraint range required by `langgraph-cli[inmem]`
- Compatible with all other dependencies

### Issue 2: Version Incompatibility with langgraph-cli

**Problem:**
```
ERROR: Cannot install eaia==0.1.0, langgraph-cli[inmem]==0.3.8 because these package versions have conflicting dependencies.
The conflict is caused by:
    eaia 0.1.0 depends on langgraph-api<0.5.0 and >=0.4.7
    langgraph-cli[inmem] 0.3.8 depends on langgraph-api<0.4.0 and >=0.2.120
```

**Root Cause:**  
After fixing Issue 1 by upgrading to `^0.4.7`, we created a new conflict. The `langgraph-cli[inmem]` package has an upper bound of `<0.4.0`, but we specified `>=0.4.7`.

**Solution:**  
Use version `0.2.120` which satisfies both constraints:

```toml
# File: pyproject.toml
# Line: ~31 (in [tool.poetry.dependencies])

# INCORRECT (creates conflict):
langgraph-api = "^0.4.7"

# CORRECT:
langgraph-api = "^0.2.120"
```

**Constraint Analysis:**
- `eaia` allows: `>=0.2.120, <0.5.0` (after our fix)
- `langgraph-cli[inmem]` requires: `>=0.2.120, <0.4.0`
- **Compatible range**: `>=0.2.120, <0.4.0`
- **Solution**: Use `^0.2.120` (installs 0.2.125 in practice)

### Issue 3: langchain-community Version Conflicts

**Problem:**
```
ERROR: pip's dependency resolver does not currently take into account all the packages that are installed.
langchain 0.3.27 requires langchain-core<1.0.0,>=0.3.72, but you have langchain-core 1.0.2 which is incompatible.
```

**Root Cause:**  
Installing `langchain-community` pulled in `langchain-core 1.0.2` and `langchain-text-splitters 1.0.0`, which are too new for the existing `langchain 0.3.27` package.

**Solution:**  
Downgrade to compatible versions:

```powershell
pip install "langchain-core<1.0.0,>=0.3.78" "langchain-text-splitters<1.0.0,>=0.3.9"
```

**Constraint Analysis:**
- `langchain 0.3.27` requires: `langchain-core<1.0.0,>=0.3.72`
- `langchain-anthropic 0.3.22` requires: `langchain-core<1.0.0,>=0.3.78`
- `langchain-openai 0.2.14` requires: `langchain-core<0.4.0,>=0.3.27`
- **Compatible range**: `>=0.3.78, <1.0.0`
- **Solution**: Install `langchain-core>=0.3.78, <1.0.0`

---

## Final Working Configuration

### pyproject.toml Changes

Only **ONE** line needs to be changed from the original:

```toml
[tool.poetry.dependencies]
python = "^3.12"
langchain = "^0.3.27"
langchain-openai = "^0.2.14"
langchain-anthropic = "^0.3.22"
langgraph = "^0.4.10"
langgraph-api = "^0.2.120"  # ← CHANGED from "^0.2.134"
langgraph-cli = { version = "^0.3.8", extras = ["inmem"] }
google-api-python-client = "^2.185.0"
google-auth = "^2.42.1"
google-auth-oauthlib = "^1.2.1"
cryptography = "^44.0.3"
```

### Additional Packages Installed Separately

```bash
# Installed via pip after main installation
langchain-community==0.4.1
langchain-core==0.3.79  # Downgraded from 1.0.2
langchain-text-splitters==0.3.11  # Downgraded from 1.0.0
```

### Complete Installation Commands (Clean Install)

```powershell
# 1. Create and activate virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# 2. Upgrade pip
python -m pip install --upgrade pip

# 3. Edit pyproject.toml (change line 31)
# Change: langgraph-api = "^0.2.134"
# To:     langgraph-api = "^0.2.120"

# 4. Install main package
pip install -e .

# 5. Install additional packages
pip install langchain-community

# 6. Fix version conflicts
pip install "langchain-core<1.0.0,>=0.3.78" "langchain-text-splitters<1.0.0,>=0.3.9"
```

---

## Verification

### 1. Verify Installation

```powershell
pip list | Select-String "langchain|langgraph"
```

**Expected output should include:**
```
langchain                    0.3.27
langchain-anthropic          0.3.22
langchain-classic            1.0.0
langchain-community          0.4.1
langchain-core               0.3.79
langchain-openai             0.2.14
langchain-text-splitters     0.3.11
langgraph                    0.4.10
langgraph-api                0.2.125
langgraph-cli                0.3.8
langsmith                    0.3.45
```

### 2. Verify Python Environment

```powershell
python -c "import sys; print(f'Python {sys.version}')"
python -c "import langchain; print(f'LangChain {langchain.__version__}')"
python -c "import langgraph; print(f'LangGraph {langgraph.__version__}')"
```

**Expected output:**
```
Python 3.12.x
LangChain 0.3.27
LangGraph 0.4.10
```

### 3. Test Imports

```powershell
python -c "from langchain_openai import ChatOpenAI; from langchain_anthropic import ChatAnthropic; from langchain_community.llms import Ollama; print('✅ All imports successful')"
```

**Expected output:**
```
✅ All imports successful
```

---

## Troubleshooting

### Common Issues

#### Issue: "Execution policy" error when activating venv

**Error:**
```
.\venv\Scripts\Activate.ps1 : File cannot be loaded because running scripts is disabled on this system.
```

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue: Wrong Python version

**Problem:** `python --version` shows Python 3.11 or earlier

**Solution:**
1. Install Python 3.12 from Microsoft Store or python.org
2. Use `py -3.12` instead of `python` to create venv:
   ```powershell
   py -3.12 -m venv venv
   ```

#### Issue: pip not upgrading

**Solution:**
```powershell
python -m pip install --upgrade pip --force-reinstall
```

#### Issue: Module not found after installation

**Solution:**
1. Ensure virtual environment is activated (check for `(venv)` prefix)
2. Reinstall the package:
   ```powershell
   pip install -e . --force-reinstall
   ```

#### Issue: Dependency conflict messages

**Solution:**
Follow the exact order in "Complete Installation Commands" section above. The order matters because:
1. Main package must be installed first
2. `langchain-community` pulls in newer versions
3. Final downgrade fixes conflicts

---

## Package Inventory

### Core Dependencies (100+ packages total)

**LangChain Ecosystem:**
- `langchain` 0.3.27 - Core framework
- `langchain-core` 0.3.79 - Shared abstractions
- `langchain-community` 0.4.1 - Community integrations (Ollama, etc.)
- `langchain-classic` 1.0.0 - Classic LangChain components
- `langchain-text-splitters` 0.3.11 - Text chunking utilities
- `langsmith` 0.3.45 - Observability and debugging

**LangGraph Workflow:**
- `langgraph` 0.4.10 - State machine framework
- `langgraph-api` 0.2.125 - API server for graphs
- `langgraph-cli` 0.3.8 - CLI tools (with inmem extras)

**LLM Provider Integrations:**
- `langchain-openai` 0.2.14 - OpenAI integration
- `langchain-anthropic` 0.3.22 - Anthropic integration
- *(Ollama via langchain-community)*

**Google API Integration:**
- `google-api-python-client` 2.185.0 - Google APIs
- `google-auth` 2.42.1 - Authentication
- `google-auth-oauthlib` 1.2.1 - OAuth flow
- `google-auth-httplib2` 0.2.0 - HTTP transport

**Web Framework:**
- `uvicorn` 0.38.0 - ASGI server
- `starlette` 0.49.1 - Web framework
- `fastapi` (via dependencies) - API framework

**Data Handling:**
- `pydantic` 2.12.3 - Data validation
- `pydantic-settings` 2.11.0 - Settings management
- `SQLAlchemy` 2.0.44 - Database toolkit
- `orjson` 3.11.4 - Fast JSON parsing

**HTTP & Networking:**
- `httpx` 0.28.1 - Async HTTP client
- `httpx-sse` 0.4.3 - Server-Sent Events
- `aiohttp` 3.13.2 - Async HTTP framework
- `requests` 2.32.5 - Sync HTTP client
- `urllib3` 2.5.0 - HTTP library

**Utilities:**
- `cryptography` 44.0.3 - Cryptographic operations
- `python-dotenv` 1.2.1 - Environment variables
- `tenacity` 9.1.2 - Retrying logic
- `PyYAML` 6.0.3 - YAML parsing
- `jsonpatch` 1.33 - JSON patching
- `numpy` 2.3.4 - Numerical computing
- `zstandard` 0.23.0 - Compression

---

## Next Steps

Now that your development environment is set up, you can proceed with:

### 1. Create Feature Branch

```powershell
git checkout -b feature/multi-llm-support
git push -u origin feature/multi-llm-support
```

### 2. Implement LLM Factory

Create `eaia/llm_factory.py` with multi-provider support:
- Ollama for local models
- OpenAI for GPT models
- Anthropic for Claude models
- Hybrid mode with fallback logic

See **IMPLEMENTATION-ROADMAP.md** Phase 1, Day 1-2 for details.

### 3. Update Existing Code

Modify 5 files to use the new LLM factory:
- `eaia/main/triage.py`
- `eaia/main/draft_response.py`
- `eaia/main/rewrite.py`
- `eaia/main/find_meeting_time.py`
- `eaia/reflection_graphs.py`

### 4. Testing

Write unit tests for LLM factory:
- Test provider selection
- Test fallback logic
- Test task-specific routing
- Test error handling

---

## References

- **Original Repository**: https://github.com/langchain-ai/executive-ai-assistant
- **LangChain Docs**: https://python.langchain.com/docs/
- **LangGraph Docs**: https://langchain-ai.github.io/langgraph/
- **Project Roadmap**: `IMPLEMENTATION-ROADMAP.md`
- **Architecture Decision**: `DEPLOYMENT-ARCHITECTURE-DECISION.md`
- **Project Summary**: `EXECUTIVE-SUMMARY.md`

---

## Changelog

### 2025-10-30 - Initial Setup
- ✅ Forked and cloned repository
- ✅ Created Python 3.12 virtual environment
- ✅ Resolved `langgraph-api` yanked package issue (0.2.134 → 0.2.120)
- ✅ Resolved version conflict with `langgraph-cli[inmem]`
- ✅ Installed `langchain-community` for Ollama support
- ✅ Fixed `langchain-core` version conflict (1.0.2 → 0.3.79)
- ✅ All 100+ dependencies installed and verified
- ✅ Environment ready for development

**Status**: ✅ **READY FOR DEVELOPMENT**

---

**Maintained by**: Ryan Haver  
**Last Verified**: October 30, 2025  
**Python Version**: 3.12  
**Environment**: Windows 11 + PowerShell
