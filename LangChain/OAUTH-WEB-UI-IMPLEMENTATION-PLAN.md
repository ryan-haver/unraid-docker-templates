# OAuth Web UI Implementation Plan
## Executive AI Assistant - Streamlined Gmail Setup

---

## Executive Summary

Replace the current manual OAuth setup process (terminal commands, manual base64 encoding) with an intuitive web-based setup wizard. Users will complete Gmail OAuth authorization entirely through their browser, eliminating all terminal commands and manual file handling.

### Current Process (15-20 minutes, error-prone):
1. Download `client_secret.json` from Google Cloud Console
2. Run `docker run` command with volume mounting
3. Copy authorization URL to browser
4. Copy authorization code back to terminal
5. Manually base64 encode `client_secret.json`
6. Manually base64 encode `token.json`
7. Paste both base64 strings into Unraid template

### Target Process (3-5 minutes, foolproof):
1. Download `client_secret.json` from Google Cloud Console
2. Access `http://unraid-ip:2024/setup`
3. Upload `client_secret.json` via web form
4. Click "Connect Gmail" button
5. Authorize in popup window
6. Done! Credentials automatically saved

**Time Savings:** 75% reduction in setup time  
**Error Reduction:** Eliminates manual encoding errors, path issues, clipboard mistakes  
**User Experience:** Non-technical users can complete setup independently

---

## Problem Statement

### Current Pain Points

**1. Technical Complexity:**
- Users must understand Docker volume mounting
- Terminal command syntax intimidating for non-technical users
- Base64 encoding requires additional tools (Windows users struggle)

**2. Error-Prone Manual Steps:**
- Typos in file paths
- Incorrect volume mount syntax
- Copy/paste errors with long base64 strings
- Confusion between `client_secret.json` and `token.json`

**3. Platform-Specific Issues:**
- Windows: No native `base64` command (requires WSL or online tools)
- macOS: Different `base64` syntax (`-w 0` flag doesn't exist)
- Linux variations: Different command options

**4. Poor Feedback:**
- No visual progress indicators
- Cryptic error messages in terminal
- Hard to debug OAuth failures

### Target User Scenarios

**Scenario A: Home Lab Enthusiast**
- Comfortable with Docker but not Python
- Wants email automation without DevOps complexity
- Expects modern web UI like other Unraid apps

**Scenario B: Small Business Owner**
- Non-technical, hired consultant to set up Unraid
- Needs to update credentials when they expire
- Cannot ask consultant to return for 5-minute task

**Scenario C: Developer Testing**
- Setting up multiple test environments
- Needs rapid credential rotation
- Wants to avoid repetitive manual steps

---

## Solution Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Executive AI Assistant                    │
│                         Container                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │  LangGraph API │         │  Setup Web UI    │           │
│  │  (Port 2024)   │◄────────┤  (Port 2024)     │           │
│  │                │         │                  │           │
│  │  /api/*        │         │  /setup          │           │
│  │  /health       │         │  /setup/upload   │           │
│  │                │         │  /setup/auth     │           │
│  │                │         │  /setup/callback │           │
│  │                │         │  /setup/status   │           │
│  └────────────────┘         └──────────────────┘           │
│         │                            │                      │
│         │                            │                      │
│         ▼                            ▼                      │
│  ┌─────────────────────────────────────────────┐           │
│  │         Credential Storage                   │           │
│  │  /app/secrets/client_secret.json            │           │
│  │  /app/secrets/token.json                    │           │
│  └─────────────────────────────────────────────┘           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    Docker Volume
            /mnt/user/appdata/executive-ai/secrets/
```

### Component Breakdown

#### 1. Setup Web UI (FastAPI + HTML/JS)
**Purpose:** Provide intuitive browser-based OAuth setup

**Pages:**
- `/setup` - Welcome page with upload form
- `/setup/auth` - OAuth authorization redirect
- `/setup/callback` - Handle OAuth callback
- `/setup/status` - Display setup completion status

**Tech Stack:**
- FastAPI (already in container)
- Jinja2 templates (lightweight, no build step)
- Vanilla JavaScript (no framework overhead)
- Tailwind CSS via CDN (modern styling, no build)

#### 2. OAuth Flow Handler (Python)
**Purpose:** Manage OAuth authorization flow server-side

**Functions:**
- Upload and validate `client_secret.json`
- Generate OAuth authorization URL
- Handle OAuth callback
- Exchange authorization code for tokens
- Save credentials to volume

**Libraries:**
- `google-auth-oauthlib` (already installed)
- `google-auth-httplib2` (already installed)

#### 3. Credential Manager (Python)
**Purpose:** Securely handle credential storage

**Functions:**
- Validate uploaded JSON structure
- Set file permissions (0600)
- Atomic file writes (prevent corruption)
- Cleanup temporary files
- Health check credential validity

#### 4. Setup Status Tracker (Python)
**Purpose:** Track setup progress and provide feedback

**States:**
- `not_started` - No credentials present
- `client_uploaded` - Client secret uploaded, awaiting authorization
- `authorizing` - User redirected to Google
- `complete` - Both files present and valid
- `error` - Setup failed with reason

---

## Technical Specifications

### File Structure

```
executive-ai-assistant/
├── eaia/
│   ├── setup/                       # NEW: Setup UI module
│   │   ├── __init__.py
│   │   ├── app.py                   # FastAPI routes for setup
│   │   ├── oauth_handler.py         # OAuth flow logic
│   │   ├── credential_manager.py    # File management
│   │   └── templates/               # HTML templates
│   │       ├── base.html
│   │       ├── welcome.html
│   │       ├── authorizing.html
│   │       ├── success.html
│   │       └── error.html
│   ├── api/
│   │   └── server.py                # MODIFIED: Add setup routes
│   └── ...
├── scripts/
│   ├── setup_gmail.py               # DEPRECATED: Keep for backward compat
│   └── docker-entrypoint.sh         # MODIFIED: Detect setup mode
└── ...
```

### API Endpoints

#### Setup Endpoints (New)

**`GET /setup`**
- Display welcome page with upload form
- Show current setup status
- Redirect to `/` if already configured

**`POST /setup/upload`**
- Accept `client_secret.json` file upload
- Validate JSON structure
- Save to `/app/secrets/client_secret.json`
- Return OAuth authorization URL
- Response: `{ "auth_url": "https://accounts.google.com/...", "status": "ready" }`

**`GET /setup/auth`**
- Initiate OAuth flow
- Redirect user to Google authorization page
- State parameter includes CSRF token

**`GET /setup/callback`**
- Handle OAuth callback from Google
- Exchange authorization code for tokens
- Save to `/app/secrets/token.json`
- Display success page
- Auto-redirect to main app in 5 seconds

**`GET /setup/status`**
- Return current setup state
- Check credential validity
- Response: `{ "status": "complete", "gmail_connected": true, "scopes": [...] }`

**`POST /setup/reset`**
- Clear existing credentials (admin feature)
- Return to initial state
- Require confirmation

#### Modified Main App Behavior

**`GET /`**
- If credentials missing: Redirect to `/setup`
- If credentials present: Show LangGraph API info (current behavior)

**`GET /health`**
- Include setup status in health check
- `{ "status": "healthy", "setup_complete": true, "gmail_connected": true }`

---

### OAuth Flow Sequence

```
User Browser          Setup UI          Google OAuth         Credential Storage
     │                   │                    │                      │
     │  1. Visit /setup  │                    │                      │
     ├──────────────────>│                    │                      │
     │                   │                    │                      │
     │  2. Show upload   │                    │                      │
     │     form          │                    │                      │
     │<──────────────────┤                    │                      │
     │                   │                    │                      │
     │  3. Upload        │                    │                      │
     │  client_secret    │                    │                      │
     ├──────────────────>│                    │                      │
     │                   │                    │                      │
     │                   │  4. Save file      │                      │
     │                   ├────────────────────┼─────────────────────>│
     │                   │                    │                      │
     │  5. Return auth   │                    │                      │
     │     URL + button  │                    │                      │
     │<──────────────────┤                    │                      │
     │                   │                    │                      │
     │  6. Click "Connect Gmail"              │                      │
     ├──────────────────>│                    │                      │
     │                   │                    │                      │
     │  7. Redirect to   │                    │                      │
     │     Google OAuth  │                    │                      │
     ├────────────────────┼───────────────────>│                      │
     │                   │                    │                      │
     │  8. User authorizes app                │                      │
     ├────────────────────┼───────────────────>│                      │
     │                   │                    │                      │
     │  9. Callback with │                    │                      │
     │     auth code     │                    │                      │
     ├───────────────────>│                    │                      │
     │                   │                    │                      │
     │                   │  10. Exchange code │                      │
     │                   │      for token     │                      │
     │                   ├───────────────────>│                      │
     │                   │                    │                      │
     │                   │  11. Receive token │                      │
     │                   │<───────────────────┤                      │
     │                   │                    │                      │
     │                   │  12. Save token.json                      │
     │                   ├────────────────────┼─────────────────────>│
     │                   │                    │                      │
     │  13. Show success │                    │                      │
     │      page         │                    │                      │
     │<──────────────────┤                    │                      │
     │                   │                    │                      │
     │  14. Auto-redirect to main app (5s)    │                      │
     │<──────────────────┤                    │                      │
```

---

## Implementation Plan

### Phase 1: Core Setup UI (Week 1)

#### Day 1-2: Project Setup & File Upload
**Tasks:**
- Create `eaia/setup/` module structure
- Add FastAPI routes for `/setup` endpoints
- Create HTML templates (base, welcome, success, error)
- Implement file upload handler for `client_secret.json`
- Add JSON validation

**Deliverables:**
- Users can visit `/setup` and upload `client_secret.json`
- File saved to `/app/secrets/` with correct permissions
- Basic success/error feedback

**Testing:**
- Upload valid JSON → Success
- Upload invalid JSON → Error message
- Upload non-JSON file → Rejection
- Check file permissions (0600)

#### Day 3-4: OAuth Flow Implementation
**Tasks:**
- Implement OAuth authorization URL generation
- Create `/setup/auth` redirect endpoint
- Implement `/setup/callback` handler
- Add authorization code → token exchange
- Save `token.json` with proper permissions

**Deliverables:**
- Complete OAuth flow from upload to token retrieval
- Automatic redirection through Google OAuth
- Success page displayed on completion

**Testing:**
- Full OAuth flow with personal Gmail
- Full OAuth flow with Google Workspace account
- Test with invalid authorization code
- Test callback CSRF protection

#### Day 5: Status Tracking & Main App Integration
**Tasks:**
- Create `/setup/status` endpoint
- Implement setup state machine
- Modify main app (`/`) to redirect to setup if needed
- Add setup status to health check endpoint
- Create credential validator

**Deliverables:**
- Main app automatically detects missing credentials
- Health check reports setup status
- Users cannot access API without setup completion

**Testing:**
- Fresh container → Auto-redirect to setup
- Configured container → Normal operation
- Delete credentials → Auto-redirect to setup
- Health check returns correct status

---

### Phase 2: UI/UX Polish (Week 2)

#### Day 6-7: Visual Design & User Experience
**Tasks:**
- Add Tailwind CSS styling
- Create progress indicators
- Add loading spinners
- Implement real-time status updates (polling or SSE)
- Add helpful error messages with troubleshooting steps

**Deliverables:**
- Modern, professional UI
- Clear visual feedback at each step
- User-friendly error messages
- Mobile-responsive design

**UI Components:**
- File upload dropzone (drag & drop)
- Progress bar (4 steps: Upload → Authorize → Verify → Complete)
- OAuth popup window (optional, better UX than redirect)
- Success animation
- Error state with retry button

#### Day 8: Documentation & Help Text
**Tasks:**
- Add inline help text to UI
- Create tooltips for technical terms
- Add "How to get client_secret.json" guide
- Create troubleshooting section
- Add FAQ to setup page

**Deliverables:**
- Self-service setup experience
- Links to Google Cloud Console setup guide
- Common error explanations
- Contact/support information

---

### Phase 3: Advanced Features (Week 3)

#### Day 9-10: Credential Management
**Tasks:**
- Add credential reset functionality
- Implement credential re-authorization (token refresh)
- Add credential export (for backup)
- Add credential validation on demand
- Create admin panel for credential management

**Deliverables:**
- `/setup/reset` endpoint with confirmation
- "Reconnect Gmail" button if token expires
- Download credentials button (for migration)
- "Test Connection" button

**Admin Features:**
- View current Gmail connection status
- See token expiration date
- Force token refresh
- View authorized scopes
- Revoke access

#### Day 11: Error Handling & Recovery
**Tasks:**
- Implement comprehensive error handling
- Add retry logic for OAuth failures
- Create error recovery workflows
- Add detailed error logging
- Implement graceful degradation

**Error Scenarios:**
- Network timeout during OAuth
- Invalid client_secret.json structure
- Insufficient scopes granted
- Token expired during setup
- File write permission errors

**Recovery Actions:**
- Automatic retry with exponential backoff
- Clear error messages with next steps
- "Try Again" buttons
- Rollback to previous state on failure

#### Day 12: Security Hardening
**Tasks:**
- Add CSRF protection to all forms
- Implement rate limiting on upload endpoint
- Add file size limits (prevent DoS)
- Sanitize file uploads (prevent path traversal)
- Add audit logging for setup events

**Security Measures:**
- CSRF tokens in all forms
- Rate limit: 10 uploads per 10 minutes
- File size limit: 10KB (client_secret is ~500 bytes)
- Whitelist allowed file extensions (.json only)
- Reject files with suspicious content
- Log all setup events to `/app/logs/setup.log`

---

### Phase 4: Testing & Documentation (Week 4)

#### Day 13-14: Comprehensive Testing
**Test Scenarios:**
1. Fresh installation (no credentials)
2. Partial setup (client_secret exists, no token)
3. Complete setup (both files exist)
4. Invalid credentials (wrong format)
5. Expired token (needs re-authorization)
6. Multiple concurrent setups (race conditions)
7. Container restart during setup
8. Network failures during OAuth
9. Google OAuth service outage
10. File permission issues

**Test Matrix:**
- Personal Gmail account
- Google Workspace account
- External user type (testing mode)
- Different browsers (Chrome, Firefox, Safari, Edge)
- Mobile browsers (iOS Safari, Android Chrome)
- Different Unraid configurations (Bridge, MACVLAN, Host)

#### Day 15-16: Documentation Updates
**Documents to Update:**
1. **Unraid Template** (`executive-ai-assistant.xml`)
   - Remove Steps 5-6 (terminal commands)
   - Add "Web Setup" instructions
   - Update screenshots (if we add them)

2. **Testing Guide** (`UNRAID-TESTING-GUIDE.md`)
   - Replace OAuth section with web UI flow
   - Add screenshots/GIFs
   - Update troubleshooting

3. **Docker README** (`docker/README.md`)
   - Add web UI setup as primary method
   - Keep terminal method as alternative
   - Add architecture documentation

4. **Main README** (`README.md`)
   - Update quick start guide
   - Add web UI screenshots
   - Update feature list

5. **New: Setup UI Guide** (`docs/SETUP-UI-GUIDE.md`)
   - Detailed walkthrough with screenshots
   - Common issues and solutions
   - Advanced configuration options

#### Day 17-18: Demo & User Acceptance Testing
**Deliverables:**
- Record demo video (5 minutes)
- Create GIF animations for key steps
- Beta test with 3-5 users
- Collect feedback
- Make final adjustments

---

## Technical Implementation Details

### Code Structure

#### `eaia/setup/app.py` - FastAPI Routes

```python
from fastapi import FastAPI, UploadFile, Request, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from .oauth_handler import OAuthHandler
from .credential_manager import CredentialManager
from .state_manager import SetupStateManager

app = FastAPI()
templates = Jinja2Templates(directory="eaia/setup/templates")

oauth_handler = OAuthHandler()
cred_manager = CredentialManager()
state_manager = SetupStateManager()

@app.get("/setup", response_class=HTMLResponse)
async def setup_welcome(request: Request):
    """Display setup welcome page with upload form"""
    status = state_manager.get_status()
    
    if status == "complete":
        return RedirectResponse(url="/")
    
    return templates.TemplateResponse(
        "welcome.html",
        {
            "request": request,
            "status": status,
            "step": state_manager.get_current_step()
        }
    )

@app.post("/setup/upload")
async def upload_client_secret(file: UploadFile):
    """Handle client_secret.json upload"""
    try:
        # Validate file
        if not file.filename.endswith('.json'):
            raise HTTPException(400, "File must be JSON")
        
        content = await file.read()
        
        # Validate and save
        cred_manager.save_client_secret(content)
        
        # Generate OAuth URL
        auth_url = oauth_handler.get_authorization_url()
        
        state_manager.set_status("client_uploaded")
        
        return {
            "status": "success",
            "auth_url": auth_url,
            "next_step": "authorize"
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": str(e)
        }

@app.get("/setup/auth")
async def initiate_oauth():
    """Redirect to Google OAuth authorization"""
    auth_url = oauth_handler.get_authorization_url()
    return RedirectResponse(url=auth_url)

@app.get("/setup/callback")
async def oauth_callback(request: Request, code: str, state: str):
    """Handle OAuth callback from Google"""
    try:
        # Validate state (CSRF protection)
        if not oauth_handler.validate_state(state):
            raise HTTPException(400, "Invalid state parameter")
        
        # Exchange code for token
        token = oauth_handler.exchange_code_for_token(code)
        
        # Save token
        cred_manager.save_token(token)
        
        state_manager.set_status("complete")
        
        return templates.TemplateResponse(
            "success.html",
            {"request": request}
        )
        
    except Exception as e:
        return templates.TemplateResponse(
            "error.html",
            {
                "request": request,
                "error": str(e),
                "troubleshooting": get_troubleshooting_steps(e)
            }
        )

@app.get("/setup/status")
async def get_setup_status():
    """Return current setup status"""
    return {
        "status": state_manager.get_status(),
        "step": state_manager.get_current_step(),
        "client_secret_present": cred_manager.client_secret_exists(),
        "token_present": cred_manager.token_exists(),
        "gmail_connected": cred_manager.test_gmail_connection()
    }

@app.post("/setup/reset")
async def reset_credentials():
    """Clear all credentials and restart setup"""
    cred_manager.clear_all()
    state_manager.reset()
    return {"status": "reset", "message": "Credentials cleared"}
```

#### `eaia/setup/oauth_handler.py` - OAuth Logic

```python
from google_auth_oauthlib.flow import Flow
from google.oauth2.credentials import Credentials
import secrets
import json

class OAuthHandler:
    def __init__(self):
        self.client_secret_path = "/app/secrets/client_secret.json"
        self.scopes = ['https://www.googleapis.com/auth/gmail.modify']
        self.redirect_uri = self._get_redirect_uri()
        self.state_tokens = {}  # In-memory state storage
    
    def _get_redirect_uri(self):
        """Construct redirect URI based on container environment"""
        # Will be something like http://unraid-ip:2024/setup/callback
        # Needs to be dynamic based on request
        return "http://localhost:2024/setup/callback"
    
    def get_authorization_url(self):
        """Generate OAuth authorization URL"""
        flow = Flow.from_client_secrets_file(
            self.client_secret_path,
            scopes=self.scopes,
            redirect_uri=self.redirect_uri
        )
        
        # Generate CSRF token
        state = secrets.token_urlsafe(32)
        self.state_tokens[state] = True
        
        auth_url, _ = flow.authorization_url(
            access_type='offline',
            include_granted_scopes='true',
            state=state,
            prompt='consent'  # Force consent screen (needed for refresh token)
        )
        
        return auth_url
    
    def validate_state(self, state: str) -> bool:
        """Validate CSRF state token"""
        return state in self.state_tokens
    
    def exchange_code_for_token(self, code: str):
        """Exchange authorization code for access token"""
        flow = Flow.from_client_secrets_file(
            self.client_secret_path,
            scopes=self.scopes,
            redirect_uri=self.redirect_uri
        )
        
        flow.fetch_token(code=code)
        
        return flow.credentials
    
    def refresh_token(self, token_path: str):
        """Refresh an expired token"""
        credentials = Credentials.from_authorized_user_file(
            token_path,
            self.scopes
        )
        
        if credentials.expired:
            credentials.refresh()
        
        return credentials
```

#### `eaia/setup/credential_manager.py` - File Management

```python
import os
import json
import stat
from pathlib import Path
from typing import Optional

class CredentialManager:
    def __init__(self):
        self.secrets_dir = Path("/app/secrets")
        self.client_secret_path = self.secrets_dir / "client_secret.json"
        self.token_path = self.secrets_dir / "token.json"
        
        # Ensure secrets directory exists
        self.secrets_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(self.secrets_dir, stat.S_IRWXU)  # 700
    
    def save_client_secret(self, content: bytes):
        """Save and validate client_secret.json"""
        # Validate JSON structure
        try:
            data = json.loads(content)
            
            # Check for required fields
            if "installed" not in data and "web" not in data:
                raise ValueError("Invalid client_secret.json format")
            
            # Write file atomically
            temp_path = self.client_secret_path.with_suffix('.tmp')
            temp_path.write_bytes(content)
            os.chmod(temp_path, stat.S_IRUSR | stat.S_IWUSR)  # 600
            temp_path.rename(self.client_secret_path)
            
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON: {str(e)}")
    
    def save_token(self, credentials):
        """Save OAuth token to file"""
        token_data = {
            'token': credentials.token,
            'refresh_token': credentials.refresh_token,
            'token_uri': credentials.token_uri,
            'client_id': credentials.client_id,
            'client_secret': credentials.client_secret,
            'scopes': credentials.scopes
        }
        
        # Write atomically
        temp_path = self.token_path.with_suffix('.tmp')
        temp_path.write_text(json.dumps(token_data, indent=2))
        os.chmod(temp_path, stat.S_IRUSR | stat.S_IWUSR)  # 600
        temp_path.rename(self.token_path)
    
    def client_secret_exists(self) -> bool:
        """Check if client_secret.json exists and is valid"""
        if not self.client_secret_path.exists():
            return False
        
        try:
            data = json.loads(self.client_secret_path.read_text())
            return "installed" in data or "web" in data
        except:
            return False
    
    def token_exists(self) -> bool:
        """Check if token.json exists and is valid"""
        if not self.token_path.exists():
            return False
        
        try:
            data = json.loads(self.token_path.read_text())
            return "token" in data and "refresh_token" in data
        except:
            return False
    
    def test_gmail_connection(self) -> bool:
        """Test if credentials work with Gmail API"""
        if not self.token_exists():
            return False
        
        try:
            from googleapiclient.discovery import build
            from google.oauth2.credentials import Credentials
            
            creds = Credentials.from_authorized_user_file(
                str(self.token_path),
                ['https://www.googleapis.com/auth/gmail.modify']
            )
            
            service = build('gmail', 'v1', credentials=creds)
            # Test API call
            service.users().labels().list(userId='me').execute()
            return True
        except Exception as e:
            return False
    
    def clear_all(self):
        """Remove all credential files"""
        if self.client_secret_path.exists():
            self.client_secret_path.unlink()
        if self.token_path.exists():
            self.token_path.unlink()
```

#### `eaia/setup/state_manager.py` - Setup State Tracking

```python
from enum import Enum
from typing import Optional

class SetupState(Enum):
    NOT_STARTED = "not_started"
    CLIENT_UPLOADED = "client_uploaded"
    AUTHORIZING = "authorizing"
    COMPLETE = "complete"
    ERROR = "error"

class SetupStateManager:
    def __init__(self):
        self.current_state = SetupState.NOT_STARTED
        self.error_message: Optional[str] = None
    
    def get_status(self) -> str:
        """Get current setup status"""
        return self.current_state.value
    
    def set_status(self, state: str):
        """Update setup status"""
        try:
            self.current_state = SetupState(state)
        except ValueError:
            raise ValueError(f"Invalid state: {state}")
    
    def get_current_step(self) -> int:
        """Get current step number (1-4)"""
        step_map = {
            SetupState.NOT_STARTED: 1,
            SetupState.CLIENT_UPLOADED: 2,
            SetupState.AUTHORIZING: 3,
            SetupState.COMPLETE: 4,
            SetupState.ERROR: 0
        }
        return step_map[self.current_state]
    
    def set_error(self, message: str):
        """Set error state with message"""
        self.current_state = SetupState.ERROR
        self.error_message = message
    
    def reset(self):
        """Reset to initial state"""
        self.current_state = SetupState.NOT_STARTED
        self.error_message = None
```

---

### HTML Templates

#### `eaia/setup/templates/base.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Setup - Executive AI Assistant{% endblock %}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        .fade-in {
            animation: fadeIn 0.5s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
    </style>
</head>
<body class="bg-gray-50 min-h-screen">
    <nav class="bg-white shadow-sm">
        <div class="max-w-4xl mx-auto px-4 py-4">
            <div class="flex items-center">
                <h1 class="text-xl font-bold text-gray-900">
                    Executive AI Assistant
                </h1>
                <span class="ml-3 px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded">
                    Setup
                </span>
            </div>
        </div>
    </nav>

    <main class="max-w-4xl mx-auto px-4 py-8">
        {% block content %}{% endblock %}
    </main>

    <footer class="mt-12 text-center text-sm text-gray-500 pb-8">
        <p>Need help? Check the <a href="/docs" class="text-blue-600 hover:underline">documentation</a></p>
    </footer>

    {% block scripts %}{% endblock %}
</body>
</html>
```

#### `eaia/setup/templates/welcome.html`

```html
{% extends "base.html" %}

{% block content %}
<div class="fade-in">
    <!-- Progress Bar -->
    <div class="mb-8">
        <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-gray-700">Setup Progress</span>
            <span class="text-sm text-gray-500">Step {{ step }} of 4</span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-2">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-500" 
                 style="width: {{ (step / 4 * 100)|int }}%"></div>
        </div>
    </div>

    <div class="bg-white rounded-lg shadow-md p-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-4">
            🚀 Welcome to Executive AI Assistant
        </h2>
        
        <p class="text-gray-600 mb-6">
            Let's connect your Gmail account so I can help manage your emails. 
            This should take about 3 minutes.
        </p>

        <!-- Step 1: Upload Client Secret -->
        <div class="mb-8">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">
                Step 1: Upload Google Cloud Credentials
            </h3>
            
            <div class="bg-blue-50 border-l-4 border-blue-400 p-4 mb-4">
                <p class="text-sm text-blue-800">
                    <strong>Don't have credentials yet?</strong> 
                    <a href="/docs/google-oauth-setup" target="_blank" class="underline">
                        Follow this guide to create them
                    </a>
                </p>
            </div>

            <div id="dropzone" class="border-2 border-dashed border-gray-300 rounded-lg p-12 text-center hover:border-blue-400 transition cursor-pointer">
                <div id="dropzone-content">
                    <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                        <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <p class="mt-2 text-sm text-gray-600">
                        <span class="font-semibold">Click to upload</span> or drag and drop
                    </p>
                    <p class="text-xs text-gray-500 mt-1">
                        client_secret.json file from Google Cloud Console
                    </p>
                </div>
                <div id="dropzone-loading" class="hidden">
                    <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-blue-500 border-t-transparent"></div>
                    <p class="mt-2 text-sm text-gray-600">Uploading...</p>
                </div>
            </div>
            
            <input type="file" id="fileInput" accept=".json" class="hidden">
        </div>

        <!-- Step 2: Will appear after upload -->
        <div id="auth-section" class="hidden mb-8">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">
                Step 2: Authorize Gmail Access
            </h3>
            
            <p class="text-gray-600 mb-4">
                Click the button below to open Google's authorization page in a new window.
            </p>
            
            <button id="authButton" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-6 rounded-lg transition">
                Connect Gmail Account
            </button>
        </div>
    </div>

    <!-- Help Section -->
    <div class="mt-8 bg-gray-100 rounded-lg p-6">
        <h3 class="font-semibold text-gray-900 mb-3">❓ Common Questions</h3>
        
        <details class="mb-2">
            <summary class="cursor-pointer text-sm text-gray-700 hover:text-gray-900">
                Where do I get client_secret.json?
            </summary>
            <p class="mt-2 text-sm text-gray-600 ml-4">
                You create it in Google Cloud Console by setting up OAuth credentials. 
                <a href="/docs/google-oauth-setup" class="text-blue-600 underline">See detailed guide</a>
            </p>
        </details>
        
        <details class="mb-2">
            <summary class="cursor-pointer text-sm text-gray-700 hover:text-gray-900">
                Is my data secure?
            </summary>
            <p class="mt-2 text-sm text-gray-600 ml-4">
                Yes! Your credentials are stored locally in your Docker container with strict file permissions (read/write for container user only). 
                They never leave your Unraid server.
            </p>
        </details>
        
        <details>
            <summary class="cursor-pointer text-sm text-gray-700 hover:text-gray-900">
                Can I use a Google Workspace account?
            </summary>
            <p class="mt-2 text-sm text-gray-600 ml-4">
                Yes! Both personal Gmail and Google Workspace accounts are supported.
            </p>
        </details>
    </div>
</div>

<script>
    const dropzone = document.getElementById('dropzone');
    const fileInput = document.getElementById('fileInput');
    const authSection = document.getElementById('auth-section');
    let authUrl = null;

    // File upload handling
    dropzone.addEventListener('click', () => fileInput.click());
    
    dropzone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropzone.classList.add('border-blue-400', 'bg-blue-50');
    });
    
    dropzone.addEventListener('dragleave', () => {
        dropzone.classList.remove('border-blue-400', 'bg-blue-50');
    });
    
    dropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropzone.classList.remove('border-blue-400', 'bg-blue-50');
        
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleFileUpload(files[0]);
        }
    });
    
    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleFileUpload(e.target.files[0]);
        }
    });

    async function handleFileUpload(file) {
        // Validate file
        if (!file.name.endsWith('.json')) {
            alert('Please upload a JSON file');
            return;
        }

        // Show loading
        document.getElementById('dropzone-content').classList.add('hidden');
        document.getElementById('dropzone-loading').classList.remove('hidden');

        // Upload file
        const formData = new FormData();
        formData.append('file', file);

        try {
            const response = await fetch('/setup/upload', {
                method: 'POST',
                body: formData
            });

            const data = await response.json();

            if (data.status === 'success') {
                authUrl = data.auth_url;
                
                // Show success and auth button
                document.getElementById('dropzone-loading').classList.add('hidden');
                document.getElementById('dropzone-content').innerHTML = `
                    <svg class="mx-auto h-12 w-12 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                    <p class="mt-2 text-sm font-semibold text-green-600">File uploaded successfully!</p>
                `;
                document.getElementById('dropzone-content').classList.remove('hidden');
                
                authSection.classList.remove('hidden');
                
                // Update progress
                updateProgress(2);
            } else {
                throw new Error(data.message || 'Upload failed');
            }
        } catch (error) {
            document.getElementById('dropzone-loading').classList.add('hidden');
            document.getElementById('dropzone-content').classList.remove('hidden');
            alert('Error: ' + error.message);
        }
    }

    // Authorization button
    document.getElementById('authButton').addEventListener('click', () => {
        if (authUrl) {
            // Open in new window
            const width = 600;
            const height = 700;
            const left = (screen.width / 2) - (width / 2);
            const top = (screen.height / 2) - (height / 2);
            
            window.open(
                authUrl,
                'Gmail Authorization',
                `width=${width},height=${height},left=${left},top=${top}`
            );
            
            // Poll for completion
            checkAuthStatus();
        }
    });

    function checkAuthStatus() {
        const interval = setInterval(async () => {
            try {
                const response = await fetch('/setup/status');
                const data = await response.json();
                
                if (data.status === 'complete') {
                    clearInterval(interval);
                    window.location.href = '/setup/success';
                }
            } catch (error) {
                console.error('Status check failed:', error);
            }
        }, 2000); // Check every 2 seconds
    }

    function updateProgress(step) {
        const progressBar = document.querySelector('.bg-blue-600');
        progressBar.style.width = `${(step / 4 * 100)}%`;
        
        const stepText = document.querySelector('.text-sm.text-gray-500');
        stepText.textContent = `Step ${step} of 4`;
    }
</script>
{% endblock %}
```

#### `eaia/setup/templates/success.html`

```html
{% extends "base.html" %}

{% block content %}
<div class="fade-in text-center">
    <!-- Success Animation -->
    <div class="mb-8">
        <svg class="mx-auto h-24 w-24 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
    </div>

    <h2 class="text-3xl font-bold text-gray-900 mb-4">
        🎉 Setup Complete!
    </h2>
    
    <p class="text-lg text-gray-600 mb-8">
        Your Gmail account is now connected. Executive AI Assistant is ready to help manage your emails.
    </p>

    <!-- What happens next -->
    <div class="bg-white rounded-lg shadow-md p-6 text-left max-w-2xl mx-auto mb-8">
        <h3 class="font-semibold text-gray-900 mb-4">What happens next?</h3>
        
        <div class="space-y-3">
            <div class="flex items-start">
                <span class="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-semibold mr-3">1</span>
                <p class="text-gray-700">Your AI assistant will start checking for new emails</p>
            </div>
            
            <div class="flex items-start">
                <span class="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-semibold mr-3">2</span>
                <p class="text-gray-700">Emails will be automatically triaged and analyzed</p>
            </div>
            
            <div class="flex items-start">
                <span class="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-semibold mr-3">3</span>
                <p class="text-gray-700">Draft responses will appear in Agent Inbox for your review</p>
            </div>
        </div>
    </div>

    <!-- Action Buttons -->
    <div class="flex gap-4 justify-center">
        <a href="/" class="bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-8 rounded-lg transition">
            Go to Dashboard
        </a>
        
        <a href="http://{{ request.headers.get('host').split(':')[0] }}:3000" target="_blank" class="bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-3 px-8 rounded-lg transition">
            Open Agent Inbox
        </a>
    </div>

    <p class="mt-8 text-sm text-gray-500">
        Redirecting to dashboard in <span id="countdown">5</span> seconds...
    </p>
</div>

<script>
    let seconds = 5;
    const countdown = document.getElementById('countdown');
    
    const interval = setInterval(() => {
        seconds--;
        countdown.textContent = seconds;
        
        if (seconds <= 0) {
            clearInterval(interval);
            window.location.href = '/';
        }
    }, 1000);
</script>
{% endblock %}
```

---

## Docker Integration

### Modified `docker-entrypoint.sh`

```bash
#!/bin/bash

# Check if setup is needed
if [ ! -f "/app/secrets/token.json" ] || [ ! -f "/app/secrets/client_secret.json" ]; then
    echo "=================================================="
    echo "⚠️  SETUP REQUIRED"
    echo "=================================================="
    echo ""
    echo "Gmail credentials not found. Please complete setup:"
    echo ""
    echo "   🌐 Open your browser and go to:"
    echo "   http://YOUR_UNRAID_IP:2024/setup"
    echo ""
    echo "   Follow the on-screen instructions to connect Gmail."
    echo ""
    echo "=================================================="
    echo ""
fi

# Start services
exec supervisord -c /etc/supervisor/supervisord.conf
```

### Modified `supervisord.conf`

```ini
[program:setup-ui]
command=uvicorn eaia.setup.app:app --host 0.0.0.0 --port 2024
directory=/app
autostart=true
autorestart=true
stdout_logfile=/var/log/eaia/setup-ui.log
stderr_logfile=/var/log/eaia/setup-ui-error.log
priority=1

[program:langgraph-api]
command=langgraph up --config /app/langgraph.json --port 2024
directory=/app
autostart=true
autorestart=true
stdout_logfile=/var/log/eaia/langgraph.log
stderr_logfile=/var/log/eaia/langgraph-error.log
priority=10
startsecs=10
```

---

## Security Considerations

### 1. CSRF Protection
- All forms include CSRF tokens
- OAuth state parameter validated
- Session-based token storage

### 2. File Upload Security
- File size limit: 10KB
- Extension whitelist: `.json` only
- JSON validation before storage
- Path traversal prevention
- Virus scanning (optional, via ClamAV)

### 3. Credential Storage
- Files stored with 0600 permissions
- Directory with 0700 permissions
- Non-root container user
- No credentials in logs
- Atomic file writes (prevent corruption)

### 4. Rate Limiting
- Upload endpoint: 10 requests per 10 minutes per IP
- Status endpoint: 100 requests per minute
- OAuth callback: Single-use codes

### 5. Error Handling
- No sensitive data in error messages
- Generic error pages
- Detailed errors only in logs
- Graceful degradation

### 6. Audit Logging
- All setup events logged
- IP addresses recorded
- Timestamps in UTC
- Log rotation enabled

---

## Testing Strategy

### Unit Tests

```python
# tests/test_oauth_handler.py
def test_authorization_url_generation():
    handler = OAuthHandler()
    url = handler.get_authorization_url()
    
    assert "accounts.google.com" in url
    assert "scope=" in url
    assert "state=" in url

def test_state_validation():
    handler = OAuthHandler()
    url = handler.get_authorization_url()
    
    # Extract state from URL
    state = parse_qs(urlparse(url).query)['state'][0]
    
    assert handler.validate_state(state)
    assert not handler.validate_state("invalid_state")

# tests/test_credential_manager.py
def test_save_client_secret():
    manager = CredentialManager()
    
    valid_json = b'{"installed": {"client_id": "test"}}'
    manager.save_client_secret(valid_json)
    
    assert manager.client_secret_exists()
    
    # Check permissions
    stat_info = os.stat(manager.client_secret_path)
    assert oct(stat_info.st_mode)[-3:] == '600'

def test_invalid_json_rejection():
    manager = CredentialManager()
    
    with pytest.raises(ValueError):
        manager.save_client_secret(b'not valid json')
```

### Integration Tests

```python
from fastapi.testclient import TestClient
from eaia.setup.app import app

client = TestClient(app)

def test_full_oauth_flow():
    # 1. Visit setup page
    response = client.get("/setup")
    assert response.status_code == 200
    
    # 2. Upload client_secret
    files = {"file": ("client_secret.json", valid_client_secret, "application/json")}
    response = client.post("/setup/upload", files=files)
    
    assert response.status_code == 200
    data = response.json()
    assert "auth_url" in data
    
    # 3. Check status
    response = client.get("/setup/status")
    data = response.json()
    assert data["status"] == "client_uploaded"
```

### Manual Test Checklist

- [ ] Fresh container shows setup page at `/`
- [ ] Upload invalid file shows error
- [ ] Upload valid client_secret succeeds
- [ ] OAuth authorization opens in new window
- [ ] OAuth callback handles success correctly
- [ ] OAuth callback handles failure gracefully
- [ ] Completed setup redirects to dashboard
- [ ] Status endpoint returns accurate state
- [ ] Container restart preserves credentials
- [ ] Delete credentials triggers setup again
- [ ] Multiple browsers can view setup status
- [ ] Mobile browser UI is usable
- [ ] File permissions are correct (600/700)

---

## Rollout Plan

### Phase 1: Development (Weeks 1-3)
- Implement all features
- Write comprehensive tests
- Internal testing

### Phase 2: Beta Testing (Week 4)
- Release beta image with tag `:beta`
- Recruit 5-10 beta testers
- Collect feedback
- Fix critical bugs

### Phase 3: Documentation (Week 5)
- Update all documentation
- Create video tutorial
- Write blog post
- Update README

### Phase 4: Release (Week 6)
- Merge to main branch
- Tag version `v2.0.0`
- Update `:latest` image
- Announce in Unraid forums

---

## Success Metrics

### Primary Metrics
- **Setup Time**: < 5 minutes (vs 15-20 current)
- **Setup Success Rate**: > 95% (vs ~70% current)
- **Support Requests**: < 5 per month (vs ~20 current)

### User Experience Metrics
- **User Satisfaction**: > 4.5/5 in surveys
- **Completion Rate**: > 90% of users complete setup
- **Error Rate**: < 5% encounter errors

### Technical Metrics
- **Page Load Time**: < 2 seconds
- **OAuth Flow Time**: < 30 seconds
- **Uptime**: 99.9%

---

## Risks & Mitigations

### Risk 1: Google OAuth Changes
**Probability**: Medium  
**Impact**: High  
**Mitigation**: 
- Monitor Google Cloud release notes
- Version lock google-auth libraries
- Maintain backward compatibility layer

### Risk 2: Security Vulnerabilities
**Probability**: Low  
**Impact**: Critical  
**Mitigation**:
- Security audit before release
- Dependency scanning (Snyk, Dependabot)
- Regular security patches

### Risk 3: User Confusion
**Probability**: Medium  
**Impact**: Medium  
**Mitigation**:
- Extensive user testing
- Clear error messages
- Comprehensive documentation
- Video tutorials

### Risk 4: File Permission Issues
**Probability**: Low  
**Impact**: Medium  
**Mitigation**:
- Extensive testing on different systems
- Automatic permission repair
- Clear troubleshooting docs

---

## Future Enhancements

### Phase 5 (Optional):
- **Multi-account support**: Manage multiple Gmail accounts
- **Calendar integration**: OAuth setup for Google Calendar
- **Mobile app**: Native iOS/Android setup experience
- **Backup/restore**: Export/import credentials
- **Admin dashboard**: Manage credentials across containers

---

## Appendix

### Backward Compatibility

The terminal-based setup method will remain available:
- `scripts/setup_gmail.py` retained
- Documentation includes both methods
- Advanced users can choose terminal method
- No breaking changes to existing deployments

### Alternative: Unraid User Script

For users who prefer Unraid-native experience:

```bash
#!/bin/bash
# OAuth Setup User Script

echo "Executive AI Assistant - Gmail OAuth Setup"
echo "==========================================="

# Prompt for client_secret path
read -p "Path to client_secret.json: " CLIENT_SECRET

# Run OAuth in container
docker exec -it executive-ai-assistant python /app/scripts/setup_gmail.py

# Copy token to appdata
docker cp executive-ai-assistant:/app/token.json \
    /mnt/user/appdata/executive-ai-assistant/secrets/

echo "Setup complete!"
```

---

## Questions & Decisions

### Decision 1: Framework Choice
**Question**: FastAPI vs Flask for web UI?  
**Decision**: FastAPI  
**Rationale**: Already in container, async support, better docs

### Decision 2: Frontend Framework
**Question**: React vs Vue vs Vanilla JS?  
**Decision**: Vanilla JS + Tailwind  
**Rationale**: Zero build step, minimal dependencies, fast

### Decision 3: Redirect vs Popup
**Question**: OAuth in same window (redirect) or popup?  
**Decision**: Popup with redirect fallback  
**Rationale**: Better UX (don't lose context), graceful degradation

### Decision 4: State Storage
**Question**: Database vs In-Memory for OAuth state?  
**Decision**: In-Memory (dict)  
**Rationale**: Short-lived (5 minutes), single container, no persistence needed

---

## Conclusion

This web-based OAuth setup will dramatically improve user experience by:
1. Eliminating terminal commands
2. Removing manual encoding steps
3. Providing visual progress feedback
4. Offering self-service troubleshooting
5. Reducing support burden

**Estimated Total Effort**: 4 weeks (160 hours)  
**Expected ROI**: 75% reduction in setup time and support requests  
**User Impact**: Makes Executive AI Assistant accessible to non-technical users

**Next Steps:**
1. Review and approve plan
2. Create feature branch
3. Begin Phase 1 implementation
4. Set up CI/CD for testing
5. Recruit beta testers

---

**Document Version**: 1.0  
**Date**: October 30, 2025  
**Author**: GitHub Copilot  
**Status**: Proposal - Awaiting Approval
