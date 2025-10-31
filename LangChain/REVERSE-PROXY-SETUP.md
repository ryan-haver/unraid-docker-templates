# 🌐 Reverse Proxy Setup Guide
## Executive AI Assistant & Agent Inbox

This guide covers deploying the Executive AI Assistant and Agent Inbox behind reverse proxies (Nginx, Traefik, Caddy, NPM). Both services support **flexible domain configurations** - use any domain structure that works for your setup!

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Deployment Options](#deployment-options)
- [Environment Variable Configuration](#environment-variable-configuration)
- [Nginx Configuration](#nginx-configuration)
- [Traefik Configuration](#traefik-configuration)
- [Caddy Configuration](#caddy-configuration)
- [Nginx Proxy Manager (NPM)](#nginx-proxy-manager-npm)
- [Testing & Troubleshooting](#testing--troubleshooting)
- [Security Considerations](#security-considerations)

---

## Overview

### Services

| Service | Port | Purpose | Proxy Needs |
|---------|------|---------|-------------|
| **Setup UI** | 2025 | OAuth configuration interface | **HIGH** - Generates OAuth callback URLs |
| **LangGraph API** | 2024 | Main AI agent REST API | **MEDIUM** - CORS for browser clients |
| **Agent Inbox** | 3000 | Web UI for agent interrupts | **MEDIUM** - May need basePath for subpaths |

### Key Features

✅ **Flexible Domain Structure** - Use any domain/path configuration  
✅ **Automatic Detection** - X-Forwarded-* headers detected automatically  
✅ **Manual Override** - Environment variables for complex setups  
✅ **CORS Support** - Configurable cross-origin requests  
✅ **Backwards Compatible** - Works with or without proxy  

---

## Architecture

### Typical Deployment

```
                    ┌─────────────────────────────────────┐
                    │    REVERSE PROXY (Nginx/Traefik)   │
                    │    https://example.com              │
                    └──────────────┬──────────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
            ▼                      ▼                      ▼
    ┌───────────────┐      ┌──────────────┐     ┌──────────────┐
    │   Setup UI    │      │  LangGraph   │     │ Agent Inbox  │
    │   Port 2025   │      │  API 2024    │     │  Port 3000   │
    └───────────────┘      └──────────────┘     └──────────────┘
            │                      │                      │
            │                      │                      │
            ▼                      ▼                      ▼
    OAuth Callbacks          AI Processing        Human Review
```

---

## Deployment Options

### Option A: Root Domain per Service (Recommended) ⭐

**Best for:** Simplicity, clean separation, easy SSL management

```
https://setup.example.com   → Setup UI (port 2025)
https://api.example.com     → LangGraph API (port 2024)
https://inbox.example.com   → Agent Inbox (port 3000)
```

**Pros:**
- ✅ Simple configuration
- ✅ No special Next.js setup needed
- ✅ Clean URL structure
- ✅ Easy SSL certificates (one per subdomain)

**Cons:**
- ❌ Requires 3 subdomains

---

### Option B: Subpath Routing (Advanced)

**Best for:** Single domain requirement, internal deployments

```
https://assistant.example.com/setup/  → Setup UI
https://assistant.example.com/api/    → LangGraph API
https://assistant.example.com/inbox/  → Agent Inbox
```

**Pros:**
- ✅ Single domain
- ✅ Single SSL certificate

**Cons:**
- ❌ Requires `basePath` configuration in Agent Inbox
- ❌ More complex proxy rules
- ❌ Agent Inbox requires rebuild to change basePath

---

### Option C: Mixed Approach (Pragmatic)

**Best for:** Balanced complexity and flexibility

```
https://assistant.example.com/        → LangGraph API (main)
https://assistant.example.com/setup/  → Setup UI
https://inbox.example.com/            → Agent Inbox (separate)
```

**Pros:**
- ✅ Logical grouping
- ✅ Agent Inbox separate (no basePath needed)
- ✅ Moderate complexity

**Cons:**
- ⚠️ 2 domains needed

---

## Environment Variable Configuration

### Executive AI Assistant Template

Configure these in Unraid's Docker template under "Advanced View":

```bash
# Setup UI (Port 2025) - OAuth Configuration Interface
#
# SETUP_UI_BASE_URL: Public URL for OAuth callbacks
#   - Leave empty for automatic detection (recommended)
#   - Set only if X-Forwarded headers don't work correctly
#   - Examples:
#     • https://setup.example.com
#     • https://assistant.example.com/setup
SETUP_UI_BASE_URL=

# CORS_ALLOWED_ORIGINS: Setup UI CORS origins
#   - Default: * (all origins - development only)
#   - Production: Comma-separated list of allowed domains
#   - Examples:
#     • * (allow all)
#     • https://setup.example.com
#     • https://setup.example.com,https://app.example.com
CORS_ALLOWED_ORIGINS=*

# LangGraph API (Port 2024) - Main AI Agent
#
# LANGGRAPH_CORS_ORIGINS: LangGraph API CORS origins
#   - Default: * (all origins - development only)
#   - Required if Agent Inbox accesses from different domain
#   - Examples:
#     • * (allow all)
#     • https://inbox.example.com
#     • https://inbox.example.com,https://admin.example.com
LANGGRAPH_CORS_ORIGINS=*
```

### Agent Inbox Template

Configure these in Unraid's Docker template under "Advanced View":

```bash
# NEXT_PUBLIC_LANGGRAPH_API_URL: Pre-configure API URL (optional)
#   - Prepopulates the LangGraph API URL in browser UI
#   - User can still override in browser
#   - Note: Build-time variable (requires rebuild to change)
#   - Examples:
#     • https://api.example.com
#     • http://executive-ai-assistant:2024
#     • Leave empty to configure manually (recommended)
NEXT_PUBLIC_LANGGRAPH_API_URL=

# NEXT_PUBLIC_BASE_PATH: Base path for subpath deployments
#   - Only needed if deploying to subpath (Option B)
#   - Leave empty for root domain (Option A/C - recommended)
#   - Note: Requires rebuild to change
#   - Examples:
#     • (empty) for https://inbox.example.com/
#     • /inbox for https://example.com/inbox/
NEXT_PUBLIC_BASE_PATH=
```

---

## Nginx Configuration

### Option A: Root Domain per Service

```nginx
# =============================================================================
# Setup UI - OAuth Configuration Interface
# Domain: https://setup.example.com
# =============================================================================
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name setup.example.com;

    # SSL Configuration
    ssl_certificate /path/to/setup.example.com/fullchain.pem;
    ssl_certificate_key /path/to/setup.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/setup.example.com-access.log;
    error_log /var/log/nginx/setup.example.com-error.log;

    location / {
        proxy_pass http://192.168.1.100:2025;
        
        # Essential proxy headers for OAuth
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# =============================================================================
# LangGraph API - Main AI Agent
# Domain: https://api.example.com
# =============================================================================
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.example.com;

    # SSL Configuration
    ssl_certificate /path/to/api.example.com/fullchain.pem;
    ssl_certificate_key /path/to/api.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/api.example.com-access.log;
    error_log /var/log/nginx/api.example.com-error.log;

    location / {
        proxy_pass http://192.168.1.100:2024;
        
        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers (if LangGraph config doesn't handle it)
        # Note: Only add if LANGGRAPH_CORS_ORIGINS doesn't work
        # add_header Access-Control-Allow-Origin "https://inbox.example.com" always;
        # add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        # add_header Access-Control-Allow-Headers "*" always;
        # add_header Access-Control-Allow-Credentials "true" always;
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            return 204;
        }
        
        # Timeouts for long-running requests
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}

# =============================================================================
# Agent Inbox - Web UI
# Domain: https://inbox.example.com
# =============================================================================
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name inbox.example.com;

    # SSL Configuration
    ssl_certificate /path/to/inbox.example.com/fullchain.pem;
    ssl_certificate_key /path/to/inbox.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/inbox.example.com-access.log;
    error_log /var/log/nginx/inbox.example.com-error.log;

    location / {
        proxy_pass http://192.168.1.100:3000;
        
        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Next.js specific
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# HTTP to HTTPS redirects
server {
    listen 80;
    listen [::]:80;
    server_name setup.example.com api.example.com inbox.example.com;
    return 301 https://$host$request_uri;
}
```

### Environment Variables for Option A

**Executive AI Assistant:**
```bash
# Leave these empty - X-Forwarded headers will be detected automatically
SETUP_UI_BASE_URL=
CORS_ALLOWED_ORIGINS=https://inbox.example.com,https://admin.example.com
LANGGRAPH_CORS_ORIGINS=https://inbox.example.com,https://admin.example.com
```

**Agent Inbox:**
```bash
# Leave both empty for root domain deployment
NEXT_PUBLIC_LANGGRAPH_API_URL=
NEXT_PUBLIC_BASE_PATH=
```

---

### Option B: Subpath Routing

```nginx
# =============================================================================
# Single Domain with Subpaths
# Domain: https://assistant.example.com
# =============================================================================
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name assistant.example.com;

    # SSL Configuration
    ssl_certificate /path/to/assistant.example.com/fullchain.pem;
    ssl_certificate_key /path/to/assistant.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/assistant.example.com-access.log;
    error_log /var/log/nginx/assistant.example.com-error.log;

    # Setup UI - /setup/
    location /setup/ {
        proxy_pass http://192.168.1.100:2025/;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Prefix /setup;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # LangGraph API - /api/
    location /api/ {
        proxy_pass http://192.168.1.100:2024/;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Prefix /api;
        
        # CORS
        if ($request_method = 'OPTIONS') {
            return 204;
        }
        
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Agent Inbox - /inbox/
    location /inbox/ {
        proxy_pass http://192.168.1.100:3000/;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Prefix /inbox;
        
        # Next.js specific
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Default location
    location / {
        return 301 /inbox/;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name assistant.example.com;
    return 301 https://$host$request_uri;
}
```

### Environment Variables for Option B

**Executive AI Assistant:**
```bash
# Manual override needed for subpath OAuth callbacks
SETUP_UI_BASE_URL=https://assistant.example.com/setup
CORS_ALLOWED_ORIGINS=https://assistant.example.com
LANGGRAPH_CORS_ORIGINS=https://assistant.example.com
```

**Agent Inbox:**
```bash
# Subpath configuration - REQUIRES REBUILD!
NEXT_PUBLIC_LANGGRAPH_API_URL=https://assistant.example.com/api
NEXT_PUBLIC_BASE_PATH=/inbox
```

**⚠️ Important:** Agent Inbox must be rebuilt after changing `NEXT_PUBLIC_BASE_PATH`!

---

## Traefik Configuration

### Option A: Root Domain per Service

```yaml
# docker-compose.yml or Traefik dynamic configuration
version: '3.8'

services:
  # Executive AI Assistant
  executive-ai-assistant:
    image: ghcr.io/ryan-haver/executive-ai-assistant:latest
    labels:
      # Setup UI - port 2025
      - "traefik.enable=true"
      
      # Setup UI Router
      - "traefik.http.routers.setup-ui.rule=Host(`setup.example.com`)"
      - "traefik.http.routers.setup-ui.entrypoints=websecure"
      - "traefik.http.routers.setup-ui.tls.certresolver=letsencrypt"
      - "traefik.http.routers.setup-ui.service=setup-ui"
      - "traefik.http.services.setup-ui.loadbalancer.server.port=2025"
      
      # LangGraph API Router
      - "traefik.http.routers.langgraph-api.rule=Host(`api.example.com`)"
      - "traefik.http.routers.langgraph-api.entrypoints=websecure"
      - "traefik.http.routers.langgraph-api.tls.certresolver=letsencrypt"
      - "traefik.http.routers.langgraph-api.service=langgraph-api"
      - "traefik.http.services.langgraph-api.loadbalancer.server.port=2024"
      
      # Middleware for headers
      - "traefik.http.middlewares.assistant-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
    environment:
      - SETUP_UI_BASE_URL=
      - CORS_ALLOWED_ORIGINS=https://inbox.example.com
      - LANGGRAPH_CORS_ORIGINS=https://inbox.example.com
    networks:
      - traefik

  # Agent Inbox
  agent-inbox:
    image: ghcr.io/ryan-haver/agent-inbox:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.agent-inbox.rule=Host(`inbox.example.com`)"
      - "traefik.http.routers.agent-inbox.entrypoints=websecure"
      - "traefik.http.routers.agent-inbox.tls.certresolver=letsencrypt"
      - "traefik.http.services.agent-inbox.loadbalancer.server.port=3000"
    environment:
      - NEXT_PUBLIC_LANGGRAPH_API_URL=
      - NEXT_PUBLIC_BASE_PATH=
    networks:
      - traefik

networks:
  traefik:
    external: true
```

---

## Caddy Configuration

### Option A: Root Domain per Service

```caddyfile
# Caddyfile

# Setup UI
setup.example.com {
    reverse_proxy 192.168.1.100:2025
    
    # Caddy automatically handles:
    # - SSL certificates (Let's Encrypt)
    # - X-Forwarded-* headers
    # - HTTP/2
}

# LangGraph API
api.example.com {
    reverse_proxy 192.168.1.100:2024
    
    # CORS headers (if needed)
    @options method OPTIONS
    handle @options {
        header Access-Control-Allow-Origin "https://inbox.example.com"
        header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        header Access-Control-Allow-Headers "*"
        header Access-Control-Allow-Credentials "true"
        respond 204
    }
    
    # Longer timeouts for AI processing
    reverse_proxy 192.168.1.100:2024 {
        transport http {
            dial_timeout 300s
            response_header_timeout 300s
        }
    }
}

# Agent Inbox
inbox.example.com {
    reverse_proxy 192.168.1.100:3000
}
```

### Option B: Subpath Routing

```caddyfile
assistant.example.com {
    # Setup UI
    handle_path /setup/* {
        reverse_proxy 192.168.1.100:2025
    }
    
    # LangGraph API
    handle_path /api/* {
        reverse_proxy 192.168.1.100:2024 {
            transport http {
                dial_timeout 300s
                response_header_timeout 300s
            }
        }
    }
    
    # Agent Inbox
    handle_path /inbox/* {
        reverse_proxy 192.168.1.100:3000
    }
    
    # Default redirect
    handle {
        redir /inbox/ permanent
    }
}
```

---

## Nginx Proxy Manager (NPM)

### Setup Instructions

#### 1. Add Proxy Hosts

**For Each Service:**

**Setup UI (setup.example.com):**
- Domain Names: `setup.example.com`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.100` (your Unraid IP)
- Forward Port: `2025`
- ✅ Cache Assets
- ✅ Block Common Exploits
- ✅ Websockets Support
- ✅ Force SSL
- ✅ HTTP/2 Support
- SSL Certificate: Request new Let's Encrypt (or use existing)

**Custom Nginx Configuration:**
```nginx
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
```

**LangGraph API (api.example.com):**
- Domain Names: `api.example.com`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.100`
- Forward Port: `2024`
- ✅ Cache Assets
- ✅ Block Common Exploits
- ✅ Websockets Support
- ✅ Force SSL
- ✅ HTTP/2 Support

**Custom Nginx Configuration:**
```nginx
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
```

**Agent Inbox (inbox.example.com):**
- Domain Names: `inbox.example.com`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.100`
- Forward Port: `3000`
- ✅ Cache Assets
- ✅ Block Common Exploits
- ✅ Websockets Support
- ✅ Force SSL
- ✅ HTTP/2 Support

**Custom Nginx Configuration:**
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

#### 2. Configure DNS

Point all subdomains to your public IP or use Cloudflare:
```
setup.example.com  →  A  →  YOUR_PUBLIC_IP
api.example.com    →  A  →  YOUR_PUBLIC_IP
inbox.example.com  →  A  →  YOUR_PUBLIC_IP
```

#### 3. Port Forwarding

Forward port 443 (HTTPS) and 80 (HTTP) to NPM:
```
Router Port 443 → NPM Server:443
Router Port 80  → NPM Server:80
```

---

## Testing & Troubleshooting

### Testing Checklist

#### Setup UI (OAuth) Testing
```bash
# 1. Test HTTPS accessibility
curl -I https://setup.example.com

# 2. Test OAuth flow
# - Visit https://setup.example.com/setup in browser
# - Upload client_secret.json
# - Click "Connect to Gmail"
# - Should redirect to Google OAuth
# - After authorization, should redirect back to https://setup.example.com/setup/callback
# - Verify success page displays

# 3. Check logs
docker logs executive-ai-assistant | grep "OAuth"
```

#### LangGraph API Testing
```bash
# 1. Test API endpoint
curl https://api.example.com/health

# 2. Test CORS (from browser console on inbox.example.com)
fetch('https://api.example.com/health')
  .then(r => r.json())
  .then(console.log)
  .catch(console.error);

# 3. Check response headers
curl -I https://api.example.com/health
# Should see: Access-Control-Allow-Origin header

# 4. Check logs
docker logs executive-ai-assistant | grep "CORS"
```

#### Agent Inbox Testing
```bash
# 1. Test page load
curl -I https://inbox.example.com

# 2. Test in browser
# - Visit https://inbox.example.com
# - Should load without console errors
# - Check browser DevTools Network tab for 404s
# - Verify assets load correctly

# 3. Test API connection
# - In Agent Inbox UI, add LangGraph API URL: https://api.example.com
# - Should connect successfully
# - Check browser console for CORS errors

# 4. Check logs
docker logs agent-inbox
```

### Common Issues

#### OAuth Callback Fails
**Symptom:** Google OAuth redirects to wrong URL or shows "redirect_uri_mismatch"

**Solution:**
```bash
# 1. Check what URL Setup UI is using
docker logs executive-ai-assistant | grep "base URL"

# 2. Manually override if needed
# In Unraid template:
SETUP_UI_BASE_URL=https://setup.example.com

# 3. Verify X-Forwarded headers are being sent
# Add to nginx:
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
```

#### CORS Errors
**Symptom:** Browser console shows "blocked by CORS policy"

**Solution:**
```bash
# 1. Set CORS origins in Executive AI Assistant
LANGGRAPH_CORS_ORIGINS=https://inbox.example.com

# 2. Restart container
docker restart executive-ai-assistant

# 3. Verify CORS headers in response
curl -H "Origin: https://inbox.example.com" \
     -I https://api.example.com/health

# Should see: Access-Control-Allow-Origin: https://inbox.example.com
```

#### Agent Inbox 404 Errors
**Symptom:** Assets fail to load, showing 404 in browser

**Solution:**
```bash
# If using subpath deployment, ensure NEXT_PUBLIC_BASE_PATH is set
NEXT_PUBLIC_BASE_PATH=/inbox

# Rebuild container (required for Next.js build-time variables)
docker stop agent-inbox
docker rm agent-inbox
# Recreate via Unraid UI with new variable
```

#### Long Response Times
**Symptom:** API requests timeout or take very long

**Solution:**
```nginx
# Increase proxy timeouts in nginx
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
```

---

## Security Considerations

### Production Checklist

#### ✅ CORS Configuration
```bash
# ❌ DON'T use in production:
CORS_ALLOWED_ORIGINS=*
LANGGRAPH_CORS_ORIGINS=*

# ✅ DO use specific domains:
CORS_ALLOWED_ORIGINS=https://setup.example.com,https://admin.example.com
LANGGRAPH_CORS_ORIGINS=https://inbox.example.com,https://admin.example.com
```

#### ✅ SSL/TLS
- Use valid SSL certificates (Let's Encrypt recommended)
- Enable HSTS headers
- Disable TLS 1.0 and 1.1
- Use strong cipher suites

#### ✅ Rate Limiting
```nginx
# In nginx, add rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

server {
    location / {
        limit_req zone=api_limit burst=20 nodelay;
        # ...
    }
}
```

#### ✅ Headers
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```

#### ✅ Firewall Rules
- Only expose ports 80 and 443 to internet
- Block direct access to ports 2024, 2025, 3000 from WAN
- Use VPN for administrative access

#### ✅ Authentication
- Setup UI OAuth is secure by default (Google OAuth)
- Consider adding HTTP Basic Auth at proxy level for additional security
- Use strong LangSmith API keys
- Rotate API keys regularly

---

## Summary

### Quick Start (Option A - Root Domains)

1. **Add DNS records:**
   ```
   setup.example.com → YOUR_IP
   api.example.com   → YOUR_IP
   inbox.example.com → YOUR_IP
   ```

2. **Configure environment variables in Unraid:**
   ```bash
   # Executive AI Assistant
   CORS_ALLOWED_ORIGINS=https://inbox.example.com
   LANGGRAPH_CORS_ORIGINS=https://inbox.example.com
   
   # Agent Inbox
   # (leave empty)
   ```

3. **Set up reverse proxy** (choose one):
   - Nginx: Use Option A configuration above
   - Traefik: Use labels from Option A
   - Caddy: Use Caddyfile from Option A
   - NPM: Follow NPM instructions

4. **Test:**
   - Visit https://setup.example.com/setup
   - Complete OAuth setup
   - Visit https://inbox.example.com
   - Configure to use https://api.example.com

### Support

- **Nginx Issues:** Check `/var/log/nginx/error.log`
- **Container Issues:** `docker logs <container-name>`
- **OAuth Issues:** Check X-Forwarded headers are being sent
- **CORS Issues:** Verify `LANGGRAPH_CORS_ORIGINS` matches inbox domain

For more help, see:
- [Executive AI Assistant README](executive-ai-assistant/README.md)
- [Agent Inbox Documentation](https://github.com/langchain-ai/agent-inbox)
