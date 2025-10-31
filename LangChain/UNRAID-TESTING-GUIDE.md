# Unraid Testing Guide - Executive AI Assistant & Agent Inbox

## Pre-Testing Checklist

### ✅ Prerequisites
- [ ] Unraid server accessible
- [ ] Docker service running on Unraid
- [ ] Community Applications plugin installed (optional, for easy template import)
- [ ] Network access from Unraid to internet (for GHCR image pulls)
- [ ] Available ports: 2024 (LangGraph API), 2025 (Setup UI), 3000 (Agent Inbox)
- [ ] Gmail account for testing
- [ ] LangSmith account (get API key from https://smith.langchain.com/settings)
- [ ] Optional: Ollama container for local LLM testing

### 📦 What We're Testing
1. **Executive AI Assistant** (`ghcr.io/ryan-haver/executive-ai-assistant:latest`)
   - Docker image: 693MB
   - Ports: 2024 (LangGraph API), 2025 (Setup UI)
   - Volumes: 4 (data, config, secrets, logs)
   - Key features: **Web-based OAuth Setup (NEW!)**, Multi-LLM support, Cron scheduling
   - Setup time: **3-5 minutes** with web UI (vs 15-20 minutes manual)

2. **Agent Inbox** (`ghcr.io/ryan-haver/agent-inbox:latest`)
   - Docker image: 266MB
   - Port: 3000
   - Volumes: None (stateless)
   - Key features: Browser-based config, LangGraph connection

---

## Phase 1: Import Templates to Unraid

### Method A: Manual Template Import (Recommended for Testing)

**Step 1: Copy Templates to Unraid**

Option 1 - Via SSH/SCP:
```bash
# From your Windows machine
scp C:\scripts\unraid-templates\LangChain\executive-ai-assistant.xml root@YOUR_UNRAID_IP:/boot/config/plugins/dockerMan/templates-user/

scp C:\scripts\unraid-templates\LangChain\agent-inbox.xml root@YOUR_UNRAID_IP:/boot/config/plugins/dockerMan/templates-user/
```

Option 2 - Via Unraid SMB Share:
```powershell
# Map Unraid flash share as network drive
net use Z: \\YOUR_UNRAID_IP\flash

# Copy templates
Copy-Item "C:\scripts\unraid-templates\LangChain\executive-ai-assistant.xml" "Z:\config\plugins\dockerMan\templates-user\"
Copy-Item "C:\scripts\unraid-templates\LangChain\agent-inbox.xml" "Z:\config\plugins\dockerMan\templates-user\"

# Cleanup
net use Z: /delete
```

Option 3 - Via Unraid WebUI (Manual):
1. Open Unraid WebUI
2. Go to **Main** → Click on **Flash** device
3. Browse to `/config/plugins/dockerMan/templates-user/`
4. Upload both XML files

**Step 2: Verify Templates Visible**
1. In Unraid WebUI, go to **Docker** tab
2. Click **Add Container** dropdown
3. Look for:
   - `Executive-AI-Assistant`
   - `Agent-Inbox`

### Method B: Direct URL Import (Alternative)

In Unraid Docker page:
1. Click **Add Container**
2. **Template repositories**: Add this URL
   ```
   https://github.com/ryan-haver/unraid-docker-templates
   ```
3. Templates should appear in dropdown

---

## Phase 2: Deploy Executive AI Assistant

---

## Phase 2: Setup Gmail OAuth Credentials

**🎉 NEW! Web-Based Setup UI (Recommended)**

The Executive AI Assistant now includes a built-in web interface for OAuth setup! This is **much easier** than the manual process.

### Option 1: Web-Based Setup (3-5 Minutes) ⭐ RECOMMENDED

**Step 1: Start the Container First**

1. In Unraid Docker tab, click **Add Container** → Select `Executive-AI-Assistant`
2. **Minimal Required Configuration:**
   - Name: `executive-ai-assistant`
   - Repository: `ghcr.io/ryan-haver/executive-ai-assistant:latest`
   - Port 2024: `2024` (LangGraph API)
   - Port 2025: `2025` (Setup UI)
   - LLM Provider: `auto`
   - OpenAI API Key: `your_key` (or Anthropic, Ollama)
3. **Skip** Gmail Secret and Token fields (leave empty)
4. Click **Apply** to start the container

**Step 2: Access Setup UI**

Open your browser to:
```
http://YOUR-UNRAID-IP:2025/setup
```

**Step 3: Create Google OAuth Credentials**

Follow the on-screen instructions or see [SETUP-UI.md](executive-ai-assistant/SETUP-UI.md) for detailed steps:

1. Create Google Cloud Project
2. Enable Gmail API  
3. Configure OAuth consent screen
4. Create OAuth client ID (Desktop app type)
5. Download `client_secret.json`

**Step 4: Upload and Authorize**

1. In the Setup UI, drag-and-drop `client_secret.json`
2. Click "Connect to Gmail"
3. Complete OAuth authorization in your browser
4. Done! Container automatically starts processing emails

**Advantages of Web UI:**
- ✅ No Docker commands or terminal needed
- ✅ Automatic validation and error checking
- ✅ CSRF protection and secure token storage
- ✅ Visual feedback throughout process
- ✅ Health monitoring built-in

---

### Option 2: Manual Setup (15-20 Minutes) - Advanced

**Use this if you prefer manual configuration or need to troubleshoot.**

### Step 1: Gmail OAuth Setup (Do This FIRST!)

**This must be done BEFORE starting the container!**

#### 1.1 Create Google Cloud Project
1. Go to https://console.cloud.google.com/
2. Click the **project selector dropdown in the upper left** (shows your current project name or "Select a project")
3. In the popup dialog, click **NEW PROJECT** button
4. Project details:
   - Name: "Executive AI Assistant Testing"
   - (Optional) Edit the project ID if desired
5. Click **Create**
6. Wait for notification (30-60 seconds) - you'll see a bell icon notification in top-right
7. **Important**: Click the project selector again and choose your new project to activate it

#### 1.2 Enable Gmail API
1. In the Google Cloud Console, go to **APIs & Services** → **Enabled APIs & services**
2. Click **+ ENABLE APIS AND SERVICES** (blue button at the top)
3. In the API Library, search: "Gmail API"
4. Click on **Gmail API** in the search results
5. Click **ENABLE** button
6. Wait for activation (30-60 seconds)

#### 1.3 Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. Choose **User type**:
   - Select **External** (for personal Gmail accounts - most common)
   - Select **Internal** only if using Google Workspace organization
3. Click **CREATE**
4. Fill in the **App information** page:
   - App name: `Executive AI Assistant Test`
   - User support email: YOUR_EMAIL
   - (Optional) App logo, homepage, privacy policy, terms of service
5. Developer contact information: YOUR_EMAIL
6. Click **SAVE AND CONTINUE**
7. **Add Scopes** page:
   - Click **ADD OR REMOVE SCOPES**
   - In the filter/search box, type: `gmail`
   - Find and check the box for: **`.../auth/gmail.modify`**
   - Click **UPDATE** at the bottom
   - Click **SAVE AND CONTINUE**
8. **Test users** page (required for External apps):
   - Click **+ ADD USERS**
   - Enter YOUR_EMAIL (the Gmail account you'll use)
   - Click **ADD**
   - Click **SAVE AND CONTINUE**
9. **Summary** page:
   - Review your settings
   - Click **BACK TO DASHBOARD**

#### 1.4 Create OAuth Client ID Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** (button at top)
3. Select **OAuth client ID**
4. Application type: **Desktop app**
5. Name: `Executive AI Test Client`
6. Click **CREATE**
7. In the "OAuth client created" popup:
   - Click **DOWNLOAD JSON** button
   - Save the file as `client_secret.json` (note the download location!)
8. Click **OK** to close the popup

#### 1.5 Generate OAuth Token

**Run this on your Windows machine with Docker Desktop:**

```powershell
# Navigate to download location
cd C:\Users\YOUR_USERNAME\Downloads

# Run OAuth setup (interactive)
docker run --rm -it `
  -v ${PWD}/client_secret.json:/app/client_secret.json `
  ghcr.io/ryan-haver/executive-ai-assistant:feature-multi-llm-support `
  python /app/scripts/setup_gmail.py
```

**Follow the prompts:**
1. URL will be displayed → Copy and paste into browser
2. Sign in to Google → Authorize the app
3. Copy the authorization code from browser
4. Paste back into terminal
5. Script creates `token.json` in current directory

#### 1.6 Encode Credentials for Unraid

**Still in PowerShell:**

```powershell
# Encode client_secret.json
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("client_secret.json")) | Set-Clipboard
# Paste this into Unraid template "Gmail Client Secret" field

# Encode token.json
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("token.json")) | Set-Clipboard
# Paste this into Unraid template "Gmail OAuth Token" field
```

**⚠️ IMPORTANT**: Save these base64 strings somewhere secure! You'll need them for Unraid.

---

### Step 2: Configure Executive AI Container in Unraid (Manual Method)

**Note**: If you used the Web UI (Option 1), skip this step! Your container is already configured.

1. **Go to Docker tab** → **Add Container** → Select `Executive-AI-Assistant`

2. **Fill in Required Fields:**

   **Basic Settings:**
   - Name: `executive-ai-assistant` (or your preference)
   - Repository: `ghcr.io/ryan-haver/executive-ai-assistant:latest`
   - Port 2024: `2024` → `2024` (LangGraph API)
   - Port 2025: `2025` → `2025` (Setup UI)

   **Gmail OAuth (OPTIONAL if using Web UI):**
   - Gmail Client Secret: `<PASTE BASE64 FROM STEP 1.6>` (if manual setup)
   - Gmail OAuth Token: `<PASTE BASE64 FROM STEP 1.6>` (if manual setup)

   **LLM Provider (Choose ONE):**
   
   **Option A: Ollama (Free, Local)**
   - LLM Provider: `ollama`
   - Ollama Host: `http://YOUR_UNRAID_IP:11434` (adjust if different)
   - OpenAI API Key: (leave empty)
   - Anthropic API Key: (leave empty)

   **Option B: OpenAI (Cloud, Paid)**
   - LLM Provider: `openai`
   - Ollama Host: (leave default)
   - OpenAI API Key: `sk-proj-...` (from https://platform.openai.com/api-keys)
   - Anthropic API Key: (leave empty)

   **Option C: Anthropic (Cloud, Paid)**
   - LLM Provider: `anthropic`
   - Ollama Host: (leave default)
   - OpenAI API Key: (leave empty)
   - Anthropic API Key: `sk-ant-...` (from https://console.anthropic.com/)

   **Option D: Hybrid (Recommended for Testing)**
   - LLM Provider: `hybrid`
   - Ollama Host: `http://YOUR_UNRAID_IP:11434`
   - OpenAI API Key: `sk-proj-...` (fallback)
   - Anthropic API Key: (optional)

   **Cron Schedule (Optional):**
   - Cron Schedule: `*/5 * * * *` (every 5 minutes)
   - Minutes Since Last Check: `10`

   **Volumes (Auto-configured):**
   - Data: `/mnt/user/appdata/executive-ai-assistant/data`
   - Config: `/mnt/user/appdata/executive-ai-assistant/config`
   - Secrets: `/mnt/user/appdata/executive-ai-assistant/secrets`
   - Logs: `/mnt/user/appdata/executive-ai-assistant/logs`

3. **Click Apply**

4. **Wait for Container Start** (30-60 seconds)

---

### Step 3: Verify Executive AI Assistant

#### 3.1 Check Container Status
```bash
# SSH into Unraid
docker ps | grep executive-ai-assistant
# Should show: Up X seconds (healthy)
```

#### 3.2 Check Logs
```bash
docker logs executive-ai-assistant
# Look for:
# - "Gmail OAuth validation successful"
# - "LLM provider: <your choice>"
# - "LangGraph API started on port 2024"
# - "Cron service started"
```

#### 3.3 Test Web Interface
1. Open browser: `http://YOUR_UNRAID_IP:2024`
2. Should see: LangGraph API response or JSON output
3. If working, you'll see API info

#### 3.4 Check Health
```bash
docker inspect executive-ai-assistant | grep -A 10 Health
# Should show: "Status": "healthy"
```

#### 3.5 Manual Email Check (Optional)
```bash
# Trigger immediate email check
docker exec executive-ai-assistant python /app/scripts/cron_ingest.py
# Check logs for processing
docker logs executive-ai-assistant --tail 50
```

---

## Phase 3: Deploy Agent Inbox

### Step 1: Configure Agent Inbox Container

1. **Go to Docker tab** → **Add Container** → Select `Agent-Inbox`

2. **Fill in Required Fields:**

   **Basic Settings:**
   - Name: `agent-inbox` (or your preference)
   - Repository: `ghcr.io/ryan-haver/agent-inbox:latest`
   - Port: `3000` → `3000` (or choose different host port)

   **Optional Environment Variables:**
   - Node Environment: `production` (recommended)
   - Disable Telemetry: `1` (privacy)

   **Volumes:** None needed (stateless design)

3. **Click Apply**

4. **Wait for Container Start** (10-20 seconds, fast!)

---

### Step 2: Configure Agent Inbox in Browser

#### 2.1 Access Web UI
1. Open browser: `http://YOUR_UNRAID_IP:3000`
2. You should see the Agent Inbox interface

#### 2.2 Configure LangSmith
1. Click **Settings** icon (gear, bottom of sidebar)
2. Enter your **LangSmith API Key**
   - Get from: https://smith.langchain.com/settings
   - Format: `lsv2_pt_...`
3. Click **Save**

#### 2.3 Add Your First Inbox
1. In Settings, click **Add Inbox**
2. Fill in three fields:

   **Assistant/Graph ID:**
   - Enter: `email_assistant` (the graph name from langgraph.json)

   **Deployment URL:**
   - Enter: `http://YOUR_UNRAID_IP:2024`
   - (Use the IP/port of Executive AI Assistant container)

   **Name (Optional):**
   - Enter: `My Email Assistant` (or any friendly name)

3. Click **Create**

#### 2.4 Verify Connection
- The inbox should appear in the left sidebar
- Click on it
- If connected, you'll see: "No interrupts" or any pending interrupts
- If error, check:
  - Executive AI container is running
  - Deployment URL is correct
  - LangSmith key is valid

---

## Phase 4: Integration Testing

### Test Scenario 1: Basic Connectivity

**Goal**: Verify both containers are running and accessible

✅ **Checklist:**
- [ ] Executive AI container: Status = "healthy"
- [ ] Executive AI web UI accessible at port 2024
- [ ] Agent Inbox container: Status = "running"
- [ ] Agent Inbox web UI accessible at port 3000
- [ ] Agent Inbox connected to Executive AI (no connection errors)

**Commands:**
```bash
# Check both containers
docker ps | grep -E 'executive-ai|agent-inbox'

# Check Executive AI health
docker inspect executive-ai-assistant --format='{{.State.Health.Status}}'

# Check both logs for errors
docker logs executive-ai-assistant --tail 20
docker logs agent-inbox --tail 20
```

---

### Test Scenario 2: LLM Provider Testing

**Goal**: Verify LLM provider is working

**For Ollama:**
```bash
# Test Ollama connectivity
curl http://YOUR_UNRAID_IP:11434/api/tags

# Check Executive AI can reach Ollama
docker exec executive-ai-assistant curl -s http://YOUR_UNRAID_IP:11434/api/tags
```

**For OpenAI/Anthropic:**
```bash
# Check logs for API connection
docker logs executive-ai-assistant | grep -i "openai\|anthropic"
```

✅ **Checklist:**
- [ ] LLM provider responds to connectivity test
- [ ] No authentication errors in logs
- [ ] Executive AI successfully initialized provider

---

### Test Scenario 3: Gmail Integration

**Goal**: Verify Gmail OAuth and email access

**Send Test Email:**
1. From another email account, send email to your Gmail
2. Subject: "Test for AI Assistant"
3. Body: "This is a test email to verify the Executive AI Assistant is working."

**Trigger Immediate Check:**
```bash
# Manually trigger email ingestion
docker exec executive-ai-assistant python /app/scripts/cron_ingest.py

# Watch logs
docker logs -f executive-ai-assistant
```

**What to Look For:**
- Log message: "Found X new emails"
- Log message: "Processing email: Test for AI Assistant"
- Log message: "Email triaged as: ..." (category)
- Log message: "Draft response generated"

✅ **Checklist:**
- [ ] Gmail API authenticated successfully
- [ ] Test email detected and processed
- [ ] Email triaged correctly
- [ ] Draft response generated
- [ ] No OAuth errors

**Troubleshooting:**
- If "No new emails found": Check CRON_MINUTES_SINCE (default 10)
- If OAuth error: Regenerate token with setup_gmail.py
- If API quota error: Check Google Cloud Console quotas

---

### Test Scenario 4: Human-in-the-Loop (Interrupts)

**Goal**: Test interrupt handling in Agent Inbox

**Trigger an Interrupt:**
1. Send email that requires human approval
2. Wait for processing (check logs)
3. Look in Agent Inbox UI for interrupt

**Expected Flow:**
1. Email received and processed
2. Draft response created
3. Interrupt created in LangGraph
4. Interrupt appears in Agent Inbox
5. You can review/approve/edit

**In Agent Inbox:**
- Click on the inbox in sidebar
- Should see interrupt card with:
  - Original email content
  - AI-drafted response
  - Action buttons (Approve/Edit/Reject)

✅ **Checklist:**
- [ ] Interrupt appears in Agent Inbox
- [ ] Original email displayed correctly
- [ ] Draft response visible
- [ ] Can edit draft
- [ ] Can approve action
- [ ] Response sent after approval

---

### Test Scenario 5: End-to-End Workflow

**Goal**: Complete email workflow from receipt to sent response

**Steps:**
1. Send test email to your Gmail
2. Wait for cron to process (5 minutes, or trigger manually)
3. Check Executive AI logs for processing
4. Open Agent Inbox and find interrupt
5. Review draft response
6. (Optional) Edit the draft
7. Approve and send
8. Verify response sent from your Gmail

**Timeline:**
- Email sent: T+0
- Cron processes: T+5 min (or immediate if triggered)
- Interrupt appears: T+5-6 min
- You review/approve: T+6+ min
- Response sent: T+6+ min

✅ **Checklist:**
- [ ] Test email sent
- [ ] Email detected by Executive AI
- [ ] Email triaged correctly
- [ ] Draft generated
- [ ] Interrupt created
- [ ] Interrupt visible in Agent Inbox
- [ ] Draft approved
- [ ] Response sent from Gmail
- [ ] Response received by original sender
- [ ] No errors in any logs

---

## Phase 5: Advanced Testing

### Test 1: Multiple Emails
- Send 5 different emails
- Verify all processed
- Check for rate limiting or errors

### Test 2: Different Email Types
- Simple question
- Meeting request
- Complex multi-paragraph
- Email requiring clarification

### Test 3: LLM Provider Failover (Hybrid Mode)
- Disconnect Ollama
- Send email
- Verify fallback to OpenAI/Anthropic
- Check logs for failover messages

### Test 4: Container Restarts
- Restart Executive AI: `docker restart executive-ai-assistant`
- Verify health check passes
- Verify cron resumes
- Restart Agent Inbox: `docker restart agent-inbox`
- Verify reconnection to Executive AI

### Test 5: Performance & Resources
```bash
# Check CPU/Memory usage
docker stats executive-ai-assistant agent-inbox

# Check disk usage
du -sh /mnt/user/appdata/executive-ai-assistant/
```

---

## Troubleshooting Guide

### Executive AI Assistant Issues

**Problem: Container won't start**
```bash
# Check logs for error
docker logs executive-ai-assistant

# Common causes:
# 1. Invalid Gmail credentials (re-encode base64)
# 2. Missing LLM provider config
# 3. Port 2024 already in use
```

**Problem: Gmail OAuth failing**
```bash
# Regenerate token
docker run --rm -it \
  -v /mnt/user/appdata/executive-ai-assistant/secrets:/secrets \
  ghcr.io/ryan-haver/executive-ai-assistant:feature-multi-llm-support \
  python /app/scripts/setup_gmail.py
```

**Problem: LLM not working**
```bash
# Test Ollama
curl http://YOUR_UNRAID_IP:11434/api/tags

# Check API keys are set correctly
docker exec executive-ai-assistant env | grep -E "OPENAI|ANTHROPIC"
```

**Problem: No emails being processed**
```bash
# Check cron is running
docker exec executive-ai-assistant pgrep cron

# Check cron logs
docker exec executive-ai-assistant cat /var/log/eaia/cron.log

# Trigger manual check
docker exec executive-ai-assistant python /app/scripts/cron_ingest.py
```

---

### Agent Inbox Issues

**Problem: Can't connect to Executive AI**
- Verify Executive AI container is running
- Check Deployment URL is correct (use Unraid IP, not localhost)
- Verify port 2024 is accessible
- Check LangSmith API key is valid

**Problem: Configuration lost after clearing browser data**
- This is expected behavior (browser localStorage)
- Re-enter LangSmith key and inbox settings
- Consider implementing persistent storage (see AGENT-INBOX-PERSISTENT-STORAGE-PLAN.md)

**Problem: No interrupts appearing**
- Verify Executive AI is processing emails (check logs)
- Verify Assistant ID matches langgraph.json (`email_assistant`)
- Refresh the page
- Check browser console for errors (F12)

---

## Data Collection

### Logs to Save

**After each test, collect:**

```bash
# Executive AI logs
docker logs executive-ai-assistant > executive-ai-logs.txt

# Agent Inbox logs
docker logs agent-inbox > agent-inbox-logs.txt

# Cron logs
docker exec executive-ai-assistant cat /var/log/eaia/cron.log > cron-logs.txt

# Container stats
docker stats --no-stream executive-ai-assistant agent-inbox > container-stats.txt
```

### Screenshots to Capture

1. Unraid Docker page showing both containers running
2. Executive AI web UI (port 2024)
3. Agent Inbox web UI (port 3000)
4. Agent Inbox with interrupt visible
5. Draft email being reviewed
6. Approved response sent confirmation
7. Any error messages

---

## Success Criteria

✅ **Must Have:**
- [ ] Both containers start successfully
- [ ] Executive AI authenticates with Gmail
- [ ] Executive AI connects to LLM provider
- [ ] Emails detected and processed
- [ ] Draft responses generated
- [ ] Interrupts visible in Agent Inbox
- [ ] Can approve and send responses
- [ ] End-to-end workflow completes

✅ **Should Have:**
- [ ] Container health checks passing
- [ ] No critical errors in logs
- [ ] Performance acceptable (CPU/RAM)
- [ ] Multiple emails handled correctly
- [ ] Container restarts work properly

✅ **Nice to Have:**
- [ ] Multiple LLM providers tested
- [ ] Hybrid failover working
- [ ] Different email types handled well
- [ ] Response quality good

---

## Next Steps After Testing

1. **Document Results**
   - Create test report with findings
   - Include screenshots and logs
   - Note any issues or improvements

2. **Prepare for Production**
   - Merge feature branch to main
   - Create version tags (v1.0.0)
   - Update templates with :latest tag
   - Create release notes

3. **Optional Enhancements**
   - Implement persistent storage for Agent Inbox
   - Add monitoring/alerting
   - Create user documentation
   - Submit to Unraid Community Apps

4. **Share Results**
   - Post to Unraid forums
   - Update GitHub README with success story
   - Consider blog post or video demo

---

## Quick Reference

**Container URLs:**
- Executive AI: `http://YOUR_UNRAID_IP:2024`
- Agent Inbox: `http://YOUR_UNRAID_IP:3000`

**Key Commands:**
```bash
# View logs
docker logs executive-ai-assistant
docker logs agent-inbox

# Restart containers
docker restart executive-ai-assistant
docker restart agent-inbox

# Trigger manual email check
docker exec executive-ai-assistant python /app/scripts/cron_ingest.py

# Check health
docker inspect executive-ai-assistant --format='{{.State.Health.Status}}'
```

**Important Files:**
- Templates: `/boot/config/plugins/dockerMan/templates-user/*.xml`
- Executive AI data: `/mnt/user/appdata/executive-ai-assistant/`
- Logs: `/mnt/user/appdata/executive-ai-assistant/logs/`

**Support Links:**
- Executive AI: https://github.com/ryan-haver/executive-ai-assistant
- Agent Inbox: https://github.com/ryan-haver/agent-inbox
- Templates: https://github.com/ryan-haver/unraid-docker-templates

---

**Good luck with testing! 🚀**
