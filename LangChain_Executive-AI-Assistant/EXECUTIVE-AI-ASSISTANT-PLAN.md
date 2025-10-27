# Executive AI Assistant - Unraid Template Deployment Plan

## Project Overview

**Source Repository**: https://github.com/langchain-ai/executive-ai-assistant  
**Purpose**: AI agent that functions as an Executive Assistant for email management, calendar scheduling, and automated responses  
**Technology Stack**: Python 3.11/3.12, LangChain, LangGraph, OpenAI/Anthropic APIs, Gmail API, Google Calendar  
**Deployment Model**: LangGraph Platform with persistent storage and cron-based email ingestion

---

## Architecture Analysis

### Core Components

1. **LangGraph Server** (Port 2024)
   - Main application server running `langgraph dev` or production mode
   - Multiple graph endpoints: main, cron, reflection graphs
   - Built-in store with OpenAI embeddings (text-embedding-3-small)

2. **Email Ingestion System**
   - Cron job that runs periodically to check Gmail
   - Script: `scripts/run_ingest.py`
   - Configurable timing (minutes-since parameter)

3. **OAuth Authentication**
   - Google OAuth for Gmail/Calendar API access
   - LangChain Auth provider for token management
   - Requires initial setup flow with browser authentication

4. **Configuration System**
   - User config in `eaia/main/config.yaml`
   - Secrets in `eaia/.secrets/secrets.json`
   - Environment variables for API keys

### Dependencies

**Required Python Packages** (from pyproject.toml):
- Python 3.11+ (3.12 preferred)
- langgraph ^0.4.5
- langgraph-checkpoint ^2.0.0
- langchain ^0.3.9
- langchain-openai ^0.2
- langchain-anthropic ^0.3
- langchain-community (for Ollama support)
- google-api-python-client ^2.128.0
- langchain-auth ^0.1.2
- langgraph-sdk ^0.2
- langsmith ^0.3.45
- pytz, pyyaml, python-dateutil, python-dotenv
- langgraph-cli[inmem] ^0.3.6
- langgraph-api ^0.2.134

---

## Deployment Challenges & Solutions

### Challenge 1: OAuth Initial Setup
**Problem**: Google OAuth requires browser-based authentication flow that can't be automated in Docker  
**Solutions**:
1. **Pre-Setup Approach**: Run `python scripts/setup_gmail.py` on host before container deployment
2. **Volume Mount Approach**: Mount pre-configured secrets directory into container
3. **Init Container Pattern**: Interactive setup container that runs once to configure OAuth
4. **Documentation**: Clear step-by-step guide for users to complete OAuth setup

### Challenge 2: Persistent State Management
**Problem**: Multiple state directories need persistence across container restarts  
**Required Volumes**:
- `/app/eaia/.secrets/` - OAuth tokens and credentials
- `/app/eaia/main/config.yaml` - User configuration
- `/root/.langchain/` - LangChain Auth storage
- `/app/data/` - LangGraph checkpoint/store data (if using file backend)

### Challenge 3: Cron Job Management
**Problem**: Need automated email checking without manual intervention  
**Solutions**:
1. Container runs two services: LangGraph server + cron daemon
2. Use supervisord or similar process manager
3. Configure cron to call `python scripts/run_ingest.py` every N minutes
4. Alternatively: Use external cron (Unraid User Scripts) to trigger via API

### Challenge 4: API Key Management
**Problem**: Multiple sensitive API keys needed  
**Required Environment Variables**:
- `OPENAI_API_KEY` - Optional (required if using OpenAI or hybrid mode)
- `ANTHROPIC_API_KEY` - Optional (required if using Anthropic)
- `LANGSMITH_API_KEY` - Required for LangGraph Platform features
- `GMAIL_SECRET` - OAuth client secret (can be file-based)
- `GMAIL_TOKEN` - OAuth access token (generated during setup)

### Challenge 5: LLM Provider Flexibility
**Problem**: Support multiple LLM providers (cloud and local)  
**Solution**: LLM abstraction layer with provider selection
- **Ollama**: Connect to existing Ollama instance (local or cloud-hosted)
- **OpenAI**: Cloud API (fast, reliable, costs per token)
- **Anthropic**: Cloud API (high quality, costs per token)
- **Hybrid Mode**: Use Ollama for routine tasks, cloud for complex/critical tasks
- Fallback mechanism when primary provider unavailable
- User can specify any model available in their Ollama instance

---

## Unraid Template Design

### Container Specifications

**Base Image Recommendation**: 
- Use `python:3.12-slim` or `python:3.12-alpine`
- Build custom image or use multi-stage Dockerfile

**Network Configuration**:
- **Option A**: Bridge mode with port 2024 exposed (connect to existing Ollama via IP:port)
- **Option B**: Host mode (access host's Ollama at localhost:11434)
- **Option C**: Custom bridge network (if Ollama on same custom network)
- **Option D**: Link to Ollama container via `--link ollama:ollama` (if both on same Docker network)

**Note**: This container does **NOT** include Ollama. It connects to your existing Ollama deployment.

**Resource Requirements**:

*For This Container Only (Executive AI Assistant):*
- RAM: 2GB minimum, 4GB recommended
- CPU: 2 cores minimum
- Storage: 5GB for application
- GPU: Not required (Ollama handles inference)

*Network Connectivity:*
- Access to existing Ollama instance (local or remote)
- Ollama endpoint must be reachable from container
- Default: http://[OLLAMA_HOST]:11434

### Required Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 2024 | TCP | LangGraph server web interface |
| 8000 | TCP | Alternative API port (if needed) |

### Environment Variables (Template Config)

#### Critical - Always Required
```xml
<Config Name="LangSmith API Key" Target="LANGSMITH_API_KEY" Required="true" Mask="true" 
  Description="Required for LangGraph Platform features and monitoring" />
```

#### LLM Provider Configuration
```xml
<Config Name="LLM Provider" Target="LLM_PROVIDER" Default="hybrid" Required="true"
  Description="Select LLM provider: ollama (local only), openai, anthropic, or hybrid (ollama with cloud fallback)">
  <Selection>
    <Option>hybrid</Option>
    <Option>ollama</Option>
    <Option>openai</Option>
    <Option>anthropic</Option>
  </Selection>
</Config>

<Config Name="Ollama Base URL" Target="OLLAMA_BASE_URL" Default="http://192.168.1.100:11434" Required="false"
  Description="URL to your existing Ollama instance. Examples: http://192.168.1.100:11434 (local), http://ollama:11434 (container name), https://ollama.example.com (cloud)" />

<Config Name="Ollama Model" Target="OLLAMA_MODEL" Default="llama3.1:8b" Required="false"
  Description="ANY model available in your Ollama instance. Check with 'ollama list' or visit http://[OLLAMA_URL]/api/tags. Common: llama3.1:8b, mistral:7b, qwen2.5:7b, deepseek-coder, etc." />

<Config Name="Ollama Model (Triage)" Target="OLLAMA_MODEL_TRIAGE" Default="" Required="false" Display="advanced"
  Description="Optional: Specific model for email triage. Defaults to OLLAMA_MODEL if empty. Use faster/smaller model for quick categorization." />

<Config Name="Ollama Model (Draft)" Target="OLLAMA_MODEL_DRAFT" Default="" Required="false" Display="advanced"
  Description="Optional: Specific model for drafting responses. Defaults to OLLAMA_MODEL if empty. Use larger/better model for quality writing." />

<Config Name="Ollama Model (Schedule)" Target="OLLAMA_MODEL_SCHEDULE" Default="" Required="false" Display="advanced"
  Description="Optional: Specific model for calendar scheduling. Defaults to OLLAMA_MODEL if empty. Use model good at structured tasks." />

<Config Name="Enable Cloud Fallback" Target="ENABLE_CLOUD_FALLBACK" Default="true" Required="false"
  Description="Auto-fallback to cloud LLMs when Ollama unavailable. Will try all configured cloud providers in order." />

<Config Name="Fallback Priority" Target="FALLBACK_PRIORITY" Default="openai,anthropic" Required="false" Display="advanced"
  Description="Cloud provider fallback order (comma-separated). Options: openai, anthropic. Example: 'anthropic,openai' to prefer Claude">
  openai,anthropic
</Config>

<Config Name="OpenAI API Key" Target="OPENAI_API_KEY" Required="false" Mask="true" 
  Description="Optional for Ollama-only. Will be used as fallback if configured (based on priority)" />

<Config Name="Anthropic API Key" Target="ANTHROPIC_API_KEY" Required="false" Mask="true"
  Description="Optional. Will be used as fallback if configured (based on priority)" />
```

#### User Configuration
```xml
<Config Name="User Email" Target="EAIA_EMAIL" Required="true" />
<Config Name="User Full Name" Target="EAIA_FULL_NAME" Required="true" />
<Config Name="User First Name" Target="EAIA_NAME" Required="true" />
<Config Name="Timezone" Target="TZ" Default="America/New_York" />
```

#### Email Ingestion Schedule
```xml
<Config Name="Ingest Interval (minutes)" Target="INGEST_INTERVAL" Default="15" />
<Config Name="Ingest Minutes Since" Target="INGEST_MINUTES_SINCE" Default="120" />
```

#### Advanced Settings
```xml
<Config Name="Log Level" Target="LOG_LEVEL" Default="INFO" Display="advanced" />
<Config Name="Deployment URL" Target="LANGGRAPH_DEPLOYMENT_URL" Display="advanced" />
```

### Volume Mappings (Template Config)

```xml
<!-- Critical Persistent Data -->
<Config Name="OAuth Secrets" Target="/app/eaia/.secrets" 
  Default="/mnt/user/appdata/executive-ai-assistant/secrets" Required="true" />

<Config Name="Configuration" Target="/app/eaia/main" 
  Default="/mnt/user/appdata/executive-ai-assistant/config" Required="true" />

<Config Name="LangChain Data" Target="/root/.langchain" 
  Default="/mnt/user/appdata/executive-ai-assistant/langchain" Required="true" />

<!-- Optional: Checkpoint/Store Data -->
<Config Name="Database" Target="/app/data" 
  Default="/mnt/user/appdata/executive-ai-assistant/data" Display="advanced" />

<!-- Optional: Logs -->
<Config Name="Logs" Target="/app/logs" 
  Default="/mnt/user/appdata/executive-ai-assistant/logs" Display="advanced" />
```

---

## Dockerfile Strategy

### Recommended Dockerfile Structure

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    cron \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone forked repository with Ollama support
# NOTE: Will use our fork with LLM abstraction layer
RUN git clone https://github.com/[YOUR-USERNAME]/executive-ai-assistant.git . \
    || COPY . /app/

# Install Python dependencies including Ollama support
RUN pip install --no-cache-dir -e . && \
    pip install --no-cache-dir langchain-community

# Create necessary directories
RUN mkdir -p /app/eaia/.secrets \
    /app/data \
    /app/logs \
    /root/.langchain

# Copy custom files
COPY llm_factory.py /app/eaia/llm_factory.py
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose ports
EXPOSE 2024

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:2024/ok || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
```

### Supervisord Configuration

```ini
[supervisord]
nodaemon=true
user=root

[program:langgraph]
command=langgraph dev --host 0.0.0.0 --port 2024
directory=/app
autostart=true
autorestart=true
stdout_logfile=/app/logs/langgraph.log
stderr_logfile=/app/logs/langgraph_error.log

[program:ingest-cron]
command=python /app/scripts/ingest_cron.py
directory=/app
autostart=true
autorestart=true
stdout_logfile=/app/logs/ingest.log
stderr_logfile=/app/logs/ingest_error.log
```

### Entrypoint Script

```bash
#!/bin/bash
set -e

# Initialize config if not exists
if [ ! -f /app/eaia/main/config.yaml ]; then
    echo "Generating default config.yaml..."
    cat > /app/eaia/main/config.yaml <<EOF
email: "${EAIA_EMAIL}"
full_name: "${EAIA_FULL_NAME}"
name: "${EAIA_NAME}"
timezone: "${TZ:-America/New_York}"
# ... etc
EOF
fi

# Check for OAuth credentials
if [ ! -f /app/eaia/.secrets/secrets.json ]; then
    echo "WARNING: OAuth secrets not found!"
    echo "Please complete OAuth setup before running."
    echo "See documentation: /app/docs/OAUTH_SETUP.md"
fi

# Validate LLM configuration
LLM_PROVIDER="${LLM_PROVIDER:-hybrid}"
echo "LLM Provider: ${LLM_PROVIDER}"

case "$LLM_PROVIDER" in
    ollama)
        echo "Using Ollama for inference"
        if [ -z "$OLLAMA_BASE_URL" ]; then
            echo "ERROR: OLLAMA_BASE_URL not set for ollama mode"
            exit 1
        fi
        # Test Ollama connection and list available models
        echo "Testing Ollama connection at ${OLLAMA_BASE_URL}..."
        if curl -f "${OLLAMA_BASE_URL}/api/tags" -o /tmp/ollama_models.json 2>/dev/null; then
            echo "✓ Successfully connected to Ollama"
            echo "Available models:"
            cat /tmp/ollama_models.json | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "  (unable to parse model list)"
            
            # Verify configured model exists
            CONFIGURED_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
            if grep -q "\"name\":\"$CONFIGURED_MODEL\"" /tmp/ollama_models.json; then
                echo "✓ Configured model '$CONFIGURED_MODEL' is available"
            else
                echo "⚠ WARNING: Configured model '$CONFIGURED_MODEL' not found in Ollama instance"
                echo "  Available models listed above. Update OLLAMA_MODEL to match."
            fi
        else
            echo "✗ ERROR: Cannot connect to Ollama at ${OLLAMA_BASE_URL}"
            echo "  Make sure Ollama is running and accessible from this container"
            echo "  Test with: curl ${OLLAMA_BASE_URL}/api/tags"
            exit 1
        fi
        ;;
    openai)
        echo "Using OpenAI cloud API"
        if [ -z "$OPENAI_API_KEY" ]; then
            echo "ERROR: OPENAI_API_KEY required for openai mode"
            exit 1
        fi
        ;;
    anthropic)
        echo "Using Anthropic cloud API"
        if [ -z "$ANTHROPIC_API_KEY" ]; then
            echo "ERROR: ANTHROPIC_API_KEY required for anthropic mode"
            exit 1
        fi
        ;;
    hybrid)
        echo "Using hybrid mode: Ollama with cloud fallback"
        if [ -z "$OLLAMA_BASE_URL" ]; then
            echo "WARNING: OLLAMA_BASE_URL not set, fallback mode only"
        fi
        if [ -z "$OPENAI_API_KEY" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
            echo "WARNING: No cloud API keys set, cannot fallback"
        fi
        ;;
    *)
        echo "ERROR: Invalid LLM_PROVIDER: ${LLM_PROVIDER}"
        exit 1
        ;;
esac

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
```

---

## OAuth Setup Process

### Step 1: Pre-Deployment Setup (Outside Container)

User must complete this BEFORE deploying container:

1. **Enable Gmail API**
   - Go to https://console.cloud.google.com/
   - Create new project or select existing
   - Enable Gmail API and Google Calendar API
   - Create OAuth 2.0 Client ID (Desktop application type)
   - Download `client_secret.json`

2. **Configure OAuth Consent Screen**
   - User Type: External (for personal Gmail) or Internal (for Workspace)
   - Add email as test user if External
   - Configure scopes: gmail.readonly, gmail.send, calendar

3. **Run Initial OAuth Flow**
   - Option A: Run locally with Python installed
   - Option B: Use temporary Docker container for setup

### Step 2: Container Setup

```bash
# Create appdata directory structure
mkdir -p /mnt/user/appdata/executive-ai-assistant/{secrets,config,langchain,data,logs}

# Copy OAuth client secret
cp client_secret.json /mnt/user/appdata/executive-ai-assistant/secrets/secrets.json

# Run OAuth setup container (interactive)
docker run -it --rm \
  -v /mnt/user/appdata/executive-ai-assistant/secrets:/app/eaia/.secrets \
  -v /mnt/user/appdata/executive-ai-assistant/langchain:/root/.langchain \
  executive-ai-assistant:latest \
  python scripts/setup_gmail.py
```

This will:
- Open browser for OAuth authentication
- Store tokens in mounted volumes
- Persist for production container

---

## Configuration Management

### config.yaml Template

Create default template that users customize:

```yaml
# User Identity
email: "user@example.com"
full_name: "John Doe"
name: "John"
background: "Professional working in [industry]"
timezone: "America/New_York"

# Scheduling Preferences
schedule_preferences: |
  - Default meeting length: 30 minutes
  - Prefer afternoon meetings (2-5 PM)
  - Avoid Mondays before 10 AM
  - Always include Zoom link

# Email Response Preferences
response_preferences: |
  - Include Calendly link when scheduling
  - CC assistant@company.com on meetings
  - Use professional but friendly tone

# Rewrite Preferences
rewrite_preferences: |
  - Keep concise (under 150 words)
  - Use bullet points for multiple items
  - Sign off with "Best,"

# Triage Rules
triage_no: |
  - Marketing emails
  - Automated notifications
  - Newsletters

triage_notify: |
  - Emails from CEO/direct manager
  - Urgent client requests
  - Calendar invites requiring decision

triage_email: |
  - Meeting scheduling requests
  - Information inquiries within my expertise
  - Follow-ups on previous conversations
```

### Environment Variable Substitution

Support dynamic config generation from environment variables:

```python
# In entrypoint script
import os
import yaml

config_template = {
    'email': os.getenv('EAIA_EMAIL'),
    'full_name': os.getenv('EAIA_FULL_NAME'),
    'name': os.getenv('EAIA_NAME'),
    'timezone': os.getenv('TZ', 'America/New_York'),
    # ... load rest from file or defaults
}
```

---

## Cron/Ingestion Strategy

### Option 1: Internal Cron (Recommended)

Run cron inside container:

```python
# scripts/ingest_cron.py
import time
import os
import subprocess

INTERVAL = int(os.getenv('INGEST_INTERVAL', '15'))  # minutes
MINUTES_SINCE = int(os.getenv('INGEST_MINUTES_SINCE', '120'))

while True:
    print(f"Running ingest at {time.ctime()}")
    subprocess.run([
        'python', 'scripts/run_ingest.py',
        '--minutes-since', str(MINUTES_SINCE),
        '--rerun', '0',
        '--early', '1',
        '--url', 'http://localhost:2024'
    ])
    time.sleep(INTERVAL * 60)
```

### Option 2: External Cron (Unraid User Scripts)

Create Unraid User Script to trigger ingestion via API:

```bash
#!/bin/bash
# Schedule: */15 * * * * (every 15 minutes)

CONTAINER_NAME="executive-ai-assistant"
docker exec $CONTAINER_NAME \
  python scripts/run_ingest.py \
  --minutes-since 120 \
  --rerun 0 \
  --early 1 \
  --url http://localhost:2024
```

---

## Integration with Agent Inbox

### Overview: Self-Hosted vs Hosted Options

**Agent Inbox** is LangChain's web interface for managing human-in-the-loop AI agent interactions. It's a Next.js application that can be:

1. **Self-Hosted** (recommended for privacy/control): Deploy as separate Docker container on Unraid
2. **Cloud-Hosted** (simpler setup): Use https://dev.agentinbox.ai/

**Repository:** https://github.com/langchain-ai/agent-inbox

### Option 1: Self-Hosted Agent Inbox (Recommended)

**Why Separate Container?**
- Agent Inbox is an independent Next.js web app that connects to ANY LangGraph deployment
- Reusable across multiple AI agents (not just Executive Assistant)
- Independent updates, scaling, and lifecycle management
- Clean separation between backend agent logic and frontend UI

**Deployment Steps:**
1. Deploy this Executive AI Assistant template (backend agent)
2. Deploy separate Agent Inbox template (frontend UI) - **requires second Unraid template**
3. Configure Agent Inbox to connect to this container

**Agent Inbox Template Requirements (Future Development):**
```xml
- Base Image: node:20-alpine
- Port: 3000 (web interface)
- Environment Variables:
  - NODE_ENV=production
  - NEXT_PUBLIC_API_URL (optional)
- Build: yarn install && yarn build && yarn start
- No persistent storage needed (configuration in browser localStorage)
```

### Option 2: Cloud-Hosted Agent Inbox (Simpler Setup)

If you prefer not to self-host the UI, use LangChain's hosted version:

**Setup Instructions After Container Deployment:**

1. **Access Cloud Agent Inbox**: https://dev.agentinbox.ai/
2. **Add Inbox Configuration**:
   - Click "Settings" → Enter LangSmith API key
   - Click "Add Inbox" → Configure:
     - **Assistant/Graph ID:** `main`
     - **Deployment URL:** `http://[UNRAID-IP]:2024`
     - **Name:** "Executive AI Assistant"
3. **Verify Connection**: Check inbox for processed emails

**Note:** Deployment URL must be accessible from your browser. For cloud-hosted Agent Inbox to reach local Unraid container, you may need:
- VPN connection to your local network, OR
- Reverse proxy with public URL, OR
- Self-host Agent Inbox instead (Option 1)

### API Endpoint Documentation

Key endpoints this container exposes for Agent Inbox:

- `GET /ok` - Health check
- `POST /runs/stream` - Stream agent runs
- `GET /threads` - List conversation threads
- `POST /threads` - Create new thread
- Various LangGraph API endpoints

---

## Security Considerations

### API Key Protection

1. **Use Unraid's built-in password masking** for template
2. **Never log API keys** in application logs
3. **Secure file permissions** on secrets directory: `chmod 600`

### OAuth Token Security

1. **Encrypt tokens at rest** (LangChain Auth handles this)
2. **Regular token rotation** (OAuth refresh tokens)
3. **Limit OAuth scopes** to minimum required

### Network Security

1. **Reverse proxy recommendation**: Use Nginx Proxy Manager or Traefik
2. **HTTPS enforcement** if exposing externally
3. **Firewall rules**: Only allow necessary ports
4. **Consider VPN access** instead of public exposure

---

## Monitoring & Logging

### Health Checks

```yaml
# Docker health check
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:2024/ok"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Log Management

1. **Separate log files**:
   - `/app/logs/langgraph.log` - Main application
   - `/app/logs/ingest.log` - Email ingestion
   - `/app/logs/oauth.log` - Authentication events

2. **Log rotation**: Configure logrotate in container

3. **Unraid integration**: Map logs to `/mnt/user/appdata/executive-ai-assistant/logs`

### Monitoring Recommendations

- **LangSmith dashboard**: Built-in monitoring and tracing
- **Container stats**: Use Unraid Docker dashboard
- **Custom alerts**: Monitor log files for errors

---

## Backup Strategy

### Critical Data to Backup

1. **OAuth secrets** (`/app/eaia/.secrets/`)
   - Frequency: After initial setup, then weekly
   - Method: Copy to secure location, encrypt

2. **Configuration** (`/app/eaia/main/config.yaml`)
   - Frequency: After each change
   - Method: Version control or Unraid appdata backup

3. **LangChain Auth data** (`/root/.langchain/`)
   - Frequency: Weekly
   - Method: Automated backup script

4. **Database/Store** (`/app/data/`)
   - Frequency: Daily
   - Method: Snapshot or rsync

### Backup Script Example

```bash
#!/bin/bash
# Unraid User Script - Daily backup

SOURCE="/mnt/user/appdata/executive-ai-assistant"
BACKUP="/mnt/user/backups/executive-ai-assistant/$(date +%Y%m%d)"

mkdir -p "$BACKUP"
rsync -av --exclude="logs/*" "$SOURCE/" "$BACKUP/"
find /mnt/user/backups/executive-ai-assistant -type d -mtime +30 -exec rm -rf {} +
```

---

## Troubleshooting Guide

### Common Issues

1. **OAuth Setup Fails**
   - Check Google Cloud Console configuration
   - Verify test user email if using External consent
   - Ensure redirect URI matches

2. **Container Won't Start**
   - Check API keys are set
   - Verify volume permissions
   - Review container logs: `docker logs executive-ai-assistant`

3. **No Emails Being Processed**
   - Check ingestion logs
   - Verify Gmail API quota not exceeded
   - Test OAuth tokens still valid

4. **High Memory Usage**
   - Reduce checkpoint retention
   - Limit concurrent processing
   - Consider smaller AI model

---

## Testing Plan

### Pre-Deployment Testing

1. **Build Docker image** with test configuration
2. **Verify OAuth flow** completes successfully
3. **Test email ingestion** with sample inbox
4. **Validate API endpoints** respond correctly
5. **Check resource usage** under load

### Post-Deployment Testing

1. **Send test email** to monitored address
2. **Verify triage** categorizes correctly
3. **Review draft responses** in Agent Inbox
4. **Test scheduling** with calendar integration
5. **Monitor logs** for errors

---

## Example Configurations

### Simple Setup (Single Model, Multi-Provider Fallback)
```yaml
LLM_PROVIDER: ollama
OLLAMA_BASE_URL: http://192.168.1.100:11434
OLLAMA_MODEL: llama3.1:8b
ENABLE_CLOUD_FALLBACK: true
FALLBACK_PRIORITY: openai,anthropic          # Try OpenAI first, then Anthropic
OPENAI_API_KEY: sk-...
ANTHROPIC_API_KEY: sk-ant-...
```
**Behavior**: Uses Ollama for everything. If Ollama down → tries OpenAI → tries Anthropic → fails

### Advanced Setup (Task-Specific Models)
```yaml
LLM_PROVIDER: hybrid
OLLAMA_BASE_URL: http://192.168.1.100:11434
OLLAMA_MODEL: qwen2.5:14b                    # Default
OLLAMA_MODEL_TRIAGE: mistral:7b              # Fast triage
OLLAMA_MODEL_DRAFT: llama3.1:70b             # Quality writing
ENABLE_CLOUD_FALLBACK: true
FALLBACK_PRIORITY: anthropic,openai          # Prefer Claude for fallback
ANTHROPIC_API_KEY: sk-ant-...
OPENAI_API_KEY: sk-...
```
**Behavior**: 
- Triage → mistral:7b (Ollama) → Claude → GPT
- Drafts → llama3.1:70b (Ollama) → Claude → GPT  
- Critical tasks → Claude directly (skip Ollama)

### Cloud-Only with Redundancy
```yaml
LLM_PROVIDER: openai
ENABLE_CLOUD_FALLBACK: true
FALLBACK_PRIORITY: openai,anthropic
OPENAI_API_KEY: sk-...
ANTHROPIC_API_KEY: sk-ant-...
```
**Behavior**: Uses OpenAI. If OpenAI has outage → switches to Anthropic automatically

---

## Template XML Structure

### Key Sections

1. **Metadata**:
   - Name: Executive-AI-Assistant
   - Repository: [your-dockerhub]/executive-ai-assistant
   - Category: Productivity:Business AI:Assistant
   - Icon: LangChain logo or custom

2. **Overview**: Detailed description with:
   - What it does
   - Prerequisites (API keys, OAuth setup)
   - Key features
   - Links to documentation

3. **Requires Section**: Pre-deployment checklist
   - Google Cloud Project setup
   - API key acquisition
   - OAuth configuration steps

4. **Network**: Bridge mode, port 2024

5. **Variables**: All environment variables with descriptions

6. **Paths**: All volume mounts with purposes

7. **Support/Project URLs**: Link to GitHub and docs

---

## Deployment Timeline

### Phase 1: Preparation (Week 1)
- Create Dockerfile
- Build and test Docker image
- Write comprehensive documentation
- Create OAuth setup guide

### Phase 2: Template Development (Week 2)
- Create XML template
- Configure all variables and volumes
- Add validation and requirements
- Test template installation

### Phase 3: Testing (Week 3)
- Deploy on test Unraid system
- Complete OAuth setup process
- Test email ingestion and processing
- Verify Agent Inbox integration
- Load testing and optimization

### Phase 4: Documentation (Week 4)
- Write user guide
- Create video walkthrough
- Document troubleshooting steps
- Prepare support materials

### Phase 5: Release
- Publish Docker image to Docker Hub
- Submit template to Unraid Community Apps
- Create GitHub repository for template
- Announce availability

---

## Success Metrics

### Technical Metrics
- Container starts successfully within 30 seconds
- OAuth setup completes in under 5 minutes
- Email ingestion runs every 15 minutes reliably
- Memory usage stays under 2GB during operation
- API response time under 2 seconds

### User Experience Metrics
- Setup completion rate > 80%
- Average time to first processed email < 30 minutes
- User satisfaction with documentation
- Support ticket volume < 5 per week

---

## Future Enhancements

### Phase 2 Features
1. **Multi-user support**: Handle multiple email accounts
2. **Custom AI models**: Support local LLMs via Ollama
3. **Advanced scheduling**: Integration with more calendar systems
4. **Slack integration**: Extend beyond email
5. **Dashboard UI**: Custom web interface for management

### Community Feedback
- Collect user feedback via GitHub Issues
- Regular updates based on LangChain releases
- Performance optimizations based on usage patterns

---

## Resource Links

### Documentation
- **GitHub Repo**: https://github.com/langchain-ai/executive-ai-assistant
- **LangGraph Docs**: https://docs.langchain.com/langgraph-platform
- **Gmail API**: https://developers.google.com/gmail/api
- **LangChain Auth**: https://github.com/langchain-ai/langchain-auth

### Support Channels
- GitHub Issues for bug reports
- Unraid Forums for deployment help
- LangChain Discord for AI/agent questions

---

## Implementation Checklist

### Core Development
- [ ] Fork executive-ai-assistant repository
- [ ] Create LLM abstraction layer (llm_factory.py)
- [ ] Modify all LLM calls to use factory pattern
- [ ] Add Ollama support via langchain-community
- [ ] Implement hybrid mode with fallback logic
- [ ] Add provider-specific error handling
- [ ] Test with all LLM providers

### Docker Infrastructure
- [ ] Set up Docker Hub repository
- [ ] Create Dockerfile with all dependencies
- [ ] Build supervisord configuration
- [ ] Write entrypoint script with LLM validation
- [ ] Implement health checks
- [ ] Configure logging system
- [ ] Test with Ollama container linking

### Documentation
- [ ] Create OAuth setup documentation
- [ ] Design config.yaml template
- [ ] Write LLM provider selection guide
- [ ] Document Ollama setup and model recommendations
- [ ] Create GPU passthrough guide for Unraid
- [ ] Document hybrid mode configuration
- [ ] Create backup scripts

### Template & Testing
- [ ] Write Unraid XML template with LLM options
- [ ] Test cloud-only mode (OpenAI/Anthropic)
- [ ] Test Ollama-only mode
- [ ] Test hybrid mode with fallback
- [ ] Test on fresh Unraid install
- [ ] Performance benchmarking (all modes)
- [ ] Resource usage monitoring

### Release
- [ ] Create user documentation
- [ ] Record setup video (including Ollama setup)
- [ ] Submit to Community Apps
- [ ] Monitor initial deployments
- [ ] Gather user feedback on LLM preferences

---

## LLM Provider Implementation Details

### LLM Factory Pattern

Create `eaia/llm_factory.py`:

```python
"""LLM Factory for multi-provider support."""
import os
from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain_community.llms import Ollama

class LLMFactory:
    """Factory for creating LLM instances based on configuration."""
    
    @staticmethod
    def create_llm(
        provider: Optional[str] = None,
        task_type: str = "general",
        temperature: float = 0.7
    ):
        """
        Create LLM instance based on provider and task type.
        
        Args:
            provider: 'ollama', 'openai', 'anthropic', 'hybrid', or None (use env)
            task_type: 'triage', 'draft', 'rewrite', 'schedule', 'general'
            temperature: Model temperature
        """
        provider = provider or os.getenv("LLM_PROVIDER", "hybrid")
        
        # Hybrid mode: Use Ollama for most tasks, cloud for critical
        if provider == "hybrid":
            critical_tasks = ["schedule", "important_draft"]
            if task_type in critical_tasks:
                return LLMFactory._create_cloud_llm_with_fallback(temperature, task_type)
            else:
                try:
                    return LLMFactory._create_ollama_llm(task_type, temperature)
                except Exception as e:
                    print(f"Ollama unavailable for {task_type}, falling back to cloud: {e}")
                    if os.getenv("ENABLE_CLOUD_FALLBACK", "true") == "true":
                        return LLMFactory._create_cloud_llm_with_fallback(temperature, task_type)
                    raise
        
        elif provider == "ollama":
            try:
                return LLMFactory._create_ollama_llm(task_type, temperature)
            except Exception as e:
                # Even in ollama-only mode, fallback if enabled
                if os.getenv("ENABLE_CLOUD_FALLBACK", "true") == "true":
                    print(f"Ollama failed, attempting cloud fallback: {e}")
                    return LLMFactory._create_cloud_llm_with_fallback(temperature, task_type)
                raise
        
        elif provider == "openai":
            return LLMFactory._create_openai_llm(temperature)
        
        elif provider == "anthropic":
            return LLMFactory._create_anthropic_llm(temperature)
        
        else:
            raise ValueError(f"Unknown provider: {provider}")
    
    @staticmethod
    def _create_ollama_llm(task_type: str, temperature: float):
        """
        Create Ollama LLM instance.
        Uses task-specific models if configured, falls back to default model.
        Connects to existing Ollama instance (local or remote).
        """
        base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
        
        # Task-specific model selection (user can configure different models per task)
        task_model_map = {
            "triage": os.getenv("OLLAMA_MODEL_TRIAGE"),
            "draft": os.getenv("OLLAMA_MODEL_DRAFT"),
            "rewrite": os.getenv("OLLAMA_MODEL_REWRITE"),
            "schedule": os.getenv("OLLAMA_MODEL_SCHEDULE"),
        }
        
        # Use task-specific model if configured, otherwise use default
        model = task_model_map.get(task_type) or os.getenv("OLLAMA_MODEL", "llama3.1:8b")
        
        print(f"Using Ollama model '{model}' for task '{task_type}' at {base_url}")
        
        return Ollama(
            base_url=base_url,
            model=model,
            temperature=temperature,
            timeout=300  # 5 minute timeout for slower models/hardware
        )
    
    @staticmethod
    def _create_openai_llm(temperature: float):
        """Create OpenAI LLM instance."""
        model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
        
        return ChatOpenAI(
            model=model,
            temperature=temperature
        )
    
    @staticmethod
    def _create_anthropic_llm(temperature: float):
        """Create Anthropic LLM instance."""
        model = os.getenv("ANTHROPIC_MODEL", "claude-3-haiku-20240307")
        
        return ChatAnthropic(
            model=model,
            temperature=temperature
        )
    
    @staticmethod
    def _create_cloud_llm_with_fallback(temperature: float, task_type: str = "general"):
        """
        Create cloud LLM with intelligent fallback.
        Tries providers in order based on FALLBACK_PRIORITY setting.
        """
        # Get fallback priority (default: openai, then anthropic)
        priority = os.getenv("FALLBACK_PRIORITY", "openai,anthropic")
        providers = [p.strip() for p in priority.split(",")]
        
        errors = []
        for provider in providers:
            try:
                if provider == "openai" and os.getenv("OPENAI_API_KEY"):
                    print(f"Using OpenAI for {task_type}")
                    return LLMFactory._create_openai_llm(temperature)
                elif provider == "anthropic" and os.getenv("ANTHROPIC_API_KEY"):
                    print(f"Using Anthropic for {task_type}")
                    return LLMFactory._create_anthropic_llm(temperature)
            except Exception as e:
                error_msg = f"{provider} failed: {e}"
                print(error_msg)
                errors.append(error_msg)
                continue
        
        # If we get here, all providers failed
        raise ValueError(
            f"All cloud providers failed for {task_type}. "
            f"Tried: {', '.join(providers)}. "
            f"Errors: {'; '.join(errors)}"
        )
```

### Modifying Existing Code

Example modification for `eaia/main/triage.py`:

```python
# OLD:
from langchain_openai import ChatOpenAI
llm = ChatOpenAI(model="gpt-4")

# NEW:
from eaia.llm_factory import LLMFactory
llm = LLMFactory.create_llm(task_type="triage", temperature=0.3)
```

### Model Recommendations by Task

**Note**: Use ANY model available in your Ollama instance. These are suggestions based on common models:

| Task | Suggested Models | Task Env Var | Notes |
|------|------------------|--------------|-------|
| **Email Triage** | llama3.1:8b, mistral:7b, qwen2.5:7b, gemma2:9b | `OLLAMA_MODEL_TRIAGE` | Fast categorization, smaller models work well |
| **Draft Writing** | llama3.1:70b, qwen2.5:32b, mistral-large, deepseek-coder:33b | `OLLAMA_MODEL_DRAFT` | Quality matters, use your best writing model |
| **Rewrite/Tone** | mistral:7b, llama3.1:8b, phi3:14b | `OLLAMA_MODEL_REWRITE` | Style adjustments |
| **Calendar Logic** | qwen2.5:7b, llama3.1:8b, phi3:14b | `OLLAMA_MODEL_SCHEDULE` | Structured output, reasoning |

**How to Choose Your Models:**

1. **Check what you have**: Run `ollama list` or visit `http://[your-ollama]:11434/api/tags`
2. **Start simple**: Use one model for everything (set `OLLAMA_MODEL` only)
3. **Optimize later**: Configure task-specific models based on performance/quality needs
4. **Any model works**: The app will use whatever you specify - experiment!

### Connecting to Existing Ollama

**This container does NOT install or run Ollama.** It connects to your existing Ollama deployment.

**Connection Examples:**

```yaml
# Local Ollama container (same Docker network)
OLLAMA_BASE_URL: http://ollama:11434

# Local Ollama container (bridge network, use Unraid IP)
OLLAMA_BASE_URL: http://192.168.1.100:11434

# Host mode access
OLLAMA_BASE_URL: http://host.docker.internal:11434

# Remote Ollama server
OLLAMA_BASE_URL: http://10.0.1.50:11434

# Cloud-hosted Ollama (with auth)
OLLAMA_BASE_URL: https://ollama.example.com
```

**Testing Connection:**

```bash
# From Unraid terminal
curl http://192.168.1.100:11434/api/tags

# From inside container
docker exec executive-ai-assistant curl http://192.168.1.100:11434/api/tags

# Should return JSON with list of available models
```

### Cost Comparison

**Monthly API Costs (500 emails/day processed):**

| Mode | Cost | Speed | Privacy | Setup Complexity |
|------|------|-------|---------|------------------|
| **OpenAI Only** | $40-60 | ⚡⚡⚡ Fast | ⚠️ Cloud | ⭐ Easy |
| **Anthropic Only** | $45-65 | ⚡⚡⚡ Fast | ⚠️ Cloud | ⭐ Easy |
| **Ollama Only** | $0 | 🐌-⚡ Variable | ✅ Private | ⭐⭐ Medium |
| **Hybrid (70% Ollama)** | $12-18 | ⚡⚡ Good | ✅ Mostly Private | ⭐⭐ Medium |

**Notes:**
- Ollama costs assume you already have Ollama running (zero additional cost)
- Speed depends on your Ollama hardware (GPU vs CPU, model size)
- Privacy: Ollama keeps all data local, cloud providers process externally
- You can switch providers anytime by changing environment variables

---

## Conclusion

This plan provides a comprehensive roadmap for deploying the Executive AI Assistant on Unraid with **multi-LLM provider support**. The key challenges are:

1. **OAuth Setup**: Requires careful pre-deployment configuration
2. **State Management**: Multiple volumes need proper persistence
3. **Cron Integration**: Automated ingestion must be reliable
4. **Security**: API keys and OAuth tokens must be protected
5. **LLM Abstraction**: Support multiple providers with intelligent fallback

The recommended approach is a **forked repository** with LLM abstraction layer, deployed as a custom Docker image with supervisord managing both the LangGraph server and the ingestion cron job. **Hybrid mode** (Ollama + cloud fallback) provides the best balance of cost, privacy, and reliability.

**Estimated Total Development Time**: 4-5 weeks (includes multi-LLM support)
**Complexity Level**: High (OAuth, LangGraph Platform, multi-LLM support)
**User Technical Level Required**: Intermediate to Advanced
**Prerequisites**: 
- OAuth setup (Google Cloud Console)
- API keys for chosen cloud providers (optional if using Ollama-only)
- Existing Ollama instance (if using Ollama mode) - user should already have this
