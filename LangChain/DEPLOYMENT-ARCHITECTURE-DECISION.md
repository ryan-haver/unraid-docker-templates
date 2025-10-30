# Deployment Architecture Decision: Separate vs Combined Containers

**Date:** October 30, 2025  
**Decision Status:** ✅ **SEPARATE CONTAINERS RECOMMENDED**  
**Confidence Level:** High

---

## Executive Summary

After extensive evaluation, **deploying Executive AI Assistant and Agent Inbox as separate containers** is the strongly recommended approach. This provides maximum flexibility, maintainability, and aligns with Unraid best practices while requiring minimal additional effort.

**Key Finding:** We can easily support BOTH deployment scenarios with the same Docker images through proper template design, giving users choice without additional development burden.

---

## Option 1: Separate Containers (RECOMMENDED ✅)

### Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Unraid Server (192.168.1.100)                          │
│                                                         │
│  ┌────────────────────────────────────────────────┐    │
│  │ Container 1: Executive AI Assistant            │    │
│  │                                                │    │
│  │ - Python 3.12 + LangGraph                     │    │
│  │ - Port: 2024 (API/backend)                    │    │
│  │ - Supervisord: LangGraph + Cron              │    │
│  │ - Volumes: OAuth, config, data               │    │
│  │ - RAM: 2-4GB                                  │    │
│  │ - Function: Email processing, AI logic       │    │
│  └────────────────────────────────────────────────┘    │
│                         ▲                              │
│                         │ API calls (port 2024)        │
│                         │                              │
│  ┌────────────────────────────────────────────────┐    │
│  │ Container 2: Agent Inbox                       │    │
│  │                                                │    │
│  │ - Node.js 20 + Next.js 14                    │    │
│  │ - Port: 3000 (web UI)                        │    │
│  │ - No volumes (stateless)                     │    │
│  │ - RAM: 512MB-1GB                             │    │
│  │ - Function: Web interface only               │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
└──────────────────────────────────────────────────────────┘
         │                                    │
         │ User Browser                       │
         │ (from any device)                  │
         ▼                                    ▼
   http://IP:3000                      Direct API calls
   (Web UI)                            to http://IP:2024
```

### Advantages

#### 1. **Independent Lifecycle Management** ⭐⭐⭐⭐⭐
- **Update Executive AI** without touching web UI
- **Update Agent Inbox** without touching backend
- **Different update frequencies:**
  - Executive AI: Monthly (LangChain/AI updates)
  - Agent Inbox: Quarterly (UI polish only)
- **Rollback independently** if issues arise

#### 2. **Resource Optimization** ⭐⭐⭐⭐
- **Scale independently:**
  - Agent Inbox: 1 instance (web UI)
  - Executive AI: Multiple instances if needed (load balancing)
- **Stop Agent Inbox** when not needed (saves 500MB RAM)
- **Backend keeps running** even if UI container down

#### 3. **Unraid Best Practices Alignment** ⭐⭐⭐⭐⭐
- **Matches Unraid philosophy:** One function per container
- **Community Apps standard:** Separate containers for backend/frontend
- **Examples:**
  - Plex (backend) + Tautulli (web UI) = separate
  - Sonarr (backend) has built-in UI (combined)
  - Elasticsearch + Kibana = separate
- **User expectations:** Unraid users expect granular control

#### 4. **Reusability** ⭐⭐⭐⭐⭐
- **Agent Inbox connects to ANY LangGraph deployment:**
  - Executive AI Assistant ✅
  - Customer Support Agent ✅
  - Research Agent ✅
  - Any future AI agent ✅
- **One UI for many agents** (multi-inbox feature)
- **Not tied to Executive AI specifically**

#### 5. **Maintenance Simplicity** ⭐⭐⭐⭐
- **Troubleshoot independently:**
  - Backend issue? Check Executive AI logs
  - UI issue? Check Agent Inbox logs
- **Clear separation of concerns**
- **Easier community support** (focused help)

#### 6. **Development Workflow** ⭐⭐⭐⭐
- **Different tech stacks:**
  - Executive AI: Python (complex AI logic)
  - Agent Inbox: TypeScript (simple web app)
- **Different dependencies:**
  - Executive AI: Heavy (LangChain, APIs, cron)
  - Agent Inbox: Light (Next.js only)
- **Rebuild times:**
  - Executive AI: ~10 minutes (large dependencies)
  - Agent Inbox: ~5 minutes (smaller)

#### 7. **Deployment Flexibility** ⭐⭐⭐⭐⭐
- **Deploy Executive AI standalone** for headless/API-only use
- **Add Agent Inbox later** if user wants UI
- **Replace Agent Inbox** with custom UI if desired
- **Use cloud Agent Inbox** (dev.agentinbox.ai) instead of self-hosting

### Disadvantages

#### 1. **Slightly More Setup Steps** ⭐⭐
- **2 templates to install** vs 1
- **2 containers to manage** vs 1
- **Mitigation:** Clear documentation, video guide
- **Reality:** Only 5 extra minutes of setup time

#### 2. **Network Configuration** ⭐
- **Agent Inbox needs Executive AI URL**
- **User must enter:** `http://192.168.1.100:2024`
- **Mitigation:** Auto-detect possible, pre-fill in template
- **Reality:** One-time configuration, well-documented

#### 3. **Two Updates Instead of One** ⭐
- **Check for updates on 2 containers** instead of 1
- **Mitigation:** Unraid auto-checks both, one-click updates
- **Reality:** Actually a benefit (update only what changed)

### Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| User confusion (2 templates) | Low | Low | Clear docs, naming convention |
| Network misconfiguration | Low | Medium | Auto-detect, validation script |
| Both containers down | Medium | Very Low | Independent, different failure modes |
| Update coordination | Low | Low | No coordination needed |

**Overall Risk:** Low ✅

---

## Option 2: Combined Container

### Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Unraid Server (192.168.1.100)                          │
│                                                         │
│  ┌────────────────────────────────────────────────┐    │
│  │ Container: Executive AI + Agent Inbox          │    │
│  │                                                │    │
│  │ - Python 3.12 + Node.js 20                   │    │
│  │ - Port: 2024 (API), 3000 (Web UI)           │    │
│  │ - Supervisord: LangGraph + Cron + Next.js   │    │
│  │ - Volumes: OAuth, config, data               │    │
│  │ - RAM: 3-5GB                                 │    │
│  │ - Function: Everything                       │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
└──────────────────────────────────────────────────────────┘
```

### Advantages

#### 1. **Single Installation** ⭐⭐⭐⭐
- **One template to install**
- **One container to manage**
- **Simpler for beginners**

#### 2. **No Network Configuration** ⭐⭐⭐⭐
- **Backend and frontend in same container**
- **Use localhost communication**
- **No IP addresses to configure**

#### 3. **Atomic Updates** ⭐⭐⭐
- **One update for everything**
- **Guaranteed compatibility** between versions

### Disadvantages

#### 1. **Update Coupling** ⭐⭐⭐⭐⭐
- **UI change requires backend update** (and vice versa)
- **Small bug in UI** = entire container rebuild
- **Cannot update selectively**
- **Longer testing cycle** (test both components every time)

#### 2. **Resource Inefficiency** ⭐⭐⭐
- **Both running always** (cannot stop UI separately)
- **Larger base image** (Python + Node.js both required)
- **More RAM usage** even if UI unused

#### 3. **Complexity** ⭐⭐⭐⭐⭐
- **3 services in one supervisord:**
  - LangGraph server
  - Email ingestion cron
  - Next.js server
- **Complex startup coordination** (which starts first?)
- **Complex failure handling** (if one fails, restart all?)

#### 4. **Reduced Reusability** ⭐⭐⭐⭐
- **Agent Inbox tied to Executive AI**
- **Cannot use for other agents** easily
- **Duplicate deployments** if user wants multiple agents

#### 5. **Against Unraid Philosophy** ⭐⭐⭐⭐
- **Unraid users expect modularity**
- **Violates single-responsibility principle**
- **Harder to share/recommend** (all-or-nothing)

#### 6. **Development Overhead** ⭐⭐⭐⭐
- **Multi-language Dockerfile** (Python + Node.js)
- **Larger image size** (~1GB vs 250MB + 300MB separate)
- **Longer build times** (both stacks every time)
- **More complex CI/CD**

#### 7. **Troubleshooting Difficulty** ⭐⭐⭐
- **Logs mixed together** (3 services in one)
- **Harder to isolate issues** (is it backend? frontend? both?)
- **Restart all or nothing** (cannot restart UI separately)

### Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| One component breaks entire container | High | Medium | Thorough testing |
| Cannot scale components independently | Medium | Low | Not typically needed |
| User wants only backend | Medium | Medium | Provide config flag |
| Update breaks both components | High | Low | Extensive testing |
| Community contribution harder | Medium | Medium | Good documentation |

**Overall Risk:** Medium-High ⚠️

---

## Option 3: Flexible Deployment (BEST OF BOTH WORLDS) 🎯

### Strategy: Support Both with Minimal Extra Work

#### Base Docker Images (Build These)

1. **`executive-ai-assistant:latest`**
   - Backend only
   - Port 2024
   - All AI logic

2. **`agent-inbox:latest`**
   - Frontend only  
   - Port 3000
   - Web UI

3. **`executive-ai-assistant:all-in-one`** (optional)
   - Combined image
   - Ports 2024 + 3000
   - For users who prefer single container

#### Unraid Templates (Offer These)

1. **Executive AI Assistant** (recommended)
   - Uses `executive-ai-assistant:latest`
   - Backend container
   - Most control

2. **Agent Inbox**
   - Uses `agent-inbox:latest`
   - Frontend container
   - Reusable

3. **Executive AI Assistant - All-in-One** (optional)
   - Uses `executive-ai-assistant:all-in-one`
   - Single container
   - For beginners

#### Implementation Effort

```
Separate Containers:         16 hours (Executive AI) + 10 hours (Agent Inbox) = 26 hours
Combined Container:          26 hours (base) + 8 hours (combination) = 34 hours
Flexible (Support Both):     26 hours (base) + 4 hours (template variation) = 30 hours
                             ↑ Only 4 hours extra to support both!
```

**Cost:** 15% more work for 100% more flexibility ✅

---

## Decision Matrix

| Criteria | Separate | Combined | Flexible | Weight |
|----------|----------|----------|----------|--------|
| **Maintenance** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | 25% |
| **User Experience (Beginner)** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 15% |
| **User Experience (Advanced)** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | 15% |
| **Resource Efficiency** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 10% |
| **Flexibility** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | 15% |
| **Development Effort** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | 10% |
| **Community Alignment** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 10% |
| **Troubleshooting** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | 10% |

### Weighted Scores

- **Separate:** 4.6/5 ⭐⭐⭐⭐⭐
- **Combined:** 2.7/5 ⭐⭐⭐
- **Flexible:** 4.8/5 ⭐⭐⭐⭐⭐

---

## Final Recommendation

### PRIMARY APPROACH: **Separate Containers (Option 1)**

**Rationale:**
1. ✅ Best maintainability and flexibility
2. ✅ Aligns with Unraid philosophy
3. ✅ Minimal additional setup complexity
4. ✅ Industry best practice (microservices)
5. ✅ Future-proof (reusable Agent Inbox)

### OPTIONAL ENHANCEMENT: **Add All-in-One Template (Option 3)**

**Only if:**
- Community requests it
- After successful separate deployment
- As convenience option, not primary

**Priority:** Low (phase 2)

---

## Implementation Plan

### Phase 1: Core Deployment (Separate Containers)

**Week 1-2: Executive AI Assistant**
- [ ] Fork repository
- [ ] Implement multi-LLM support
- [ ] Create Dockerfile
- [ ] Build Unraid template
- [ ] Test thoroughly

**Week 3: Agent Inbox**
- [ ] Create Dockerfile
- [ ] Build Unraid template
- [ ] Test integration with Executive AI
- [ ] Verify reusability with other agents

**Week 4: Integration & Documentation**
- [ ] End-to-end testing
- [ ] Write comprehensive docs
- [ ] Create video tutorial
- [ ] Submit to Community Apps

### Phase 2 (Optional): All-in-One Variant

**Week 5 (if requested):**
- [ ] Create combined Dockerfile
- [ ] Configure supervisord for 3 services
- [ ] Build all-in-one template
- [ ] Test and document

---

## Technical Implementation Details

### Separate Containers: Dockerfile Architecture

**Executive AI Assistant Dockerfile:**
```dockerfile
FROM python:3.12-slim

# Install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Install supervisord for LangGraph + Cron
RUN apt-get update && apt-get install -y supervisor

# Copy application
COPY eaia/ /app/eaia/
COPY scripts/ /app/scripts/

# Supervisord config: LangGraph server + cron
COPY supervisord-backend.conf /etc/supervisor/conf.d/

EXPOSE 2024
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord-backend.conf"]
```

**Agent Inbox Dockerfile:**
```dockerfile
FROM node:20-alpine

# Install dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application
COPY . /app/

# Build Next.js
RUN yarn build

EXPOSE 3000
CMD ["yarn", "start"]
```

**Total Image Sizes:**
- Executive AI: ~800MB (Python + LangChain)
- Agent Inbox: ~250MB (Node.js + Next.js)
- **Combined:** 1.05GB separate vs ~1.2GB all-in-one

**Savings:** Minimal size difference, but separate = independent updates

### Communication Pattern

**Browser → Agent Inbox (Port 3000):**
```javascript
// User visits http://192.168.1.100:3000
// Loads React app into browser
// All state in browser localStorage
```

**Browser → Executive AI (Port 2024) - Direct API:**
```javascript
// JavaScript in browser makes API calls directly:
fetch('http://192.168.1.100:2024/threads')
  .then(res => res.json())
  .then(threads => displayInUI(threads))
```

**Key Point:** Agent Inbox container serves HTML/JS/CSS only. All API calls happen client-side (browser → Executive AI directly). No Agent Inbox → Executive AI communication needed.

### Network Configuration

**Unraid Bridge Network (Default):**
```yaml
Executive AI Assistant:
  Network: bridge
  Ports: 2024:2024

Agent Inbox:
  Network: bridge  
  Ports: 3000:3000
```

**User Configuration (in Agent Inbox UI):**
```
Deployment URL: http://192.168.1.100:2024
↑ This is entered by user in browser, not container
```

**No Inter-Container Communication Required** ✅
- Containers don't talk to each other
- Browser talks to both independently
- Simpler than most assume!

---

## User Experience Comparison

### Separate Containers Setup Flow

**Time: ~20 minutes**

1. **Install Executive AI Assistant** (10 min)
   - Community Apps → Search "Executive AI Assistant"
   - Configure: LLM provider, API keys, OAuth
   - Start container
   - Complete OAuth setup (one-time)

2. **Install Agent Inbox** (5 min)
   - Community Apps → Search "Agent Inbox"
   - Start container (no config needed)
   - Click WebUI button

3. **Connect Them** (5 min)
   - In Agent Inbox: Settings → Add LangSmith key
   - Add Inbox → Enter `http://[UNRAID-IP]:2024`
   - Done!

### Combined Container Setup Flow

**Time: ~15 minutes**

1. **Install Executive AI + Agent Inbox** (15 min)
   - Community Apps → Search "Executive AI Assistant All-in-One"
   - Configure: LLM provider, API keys, OAuth
   - Start container
   - Complete OAuth setup
   - Access built-in UI

**Time Savings:** 5 minutes (not significant)

**Flexibility Loss:** Cannot use Agent Inbox for other agents

---

## Community Apps Precedent Analysis

### Separate Container Examples (Industry Standard)

| Application Stack | Backend Container | Frontend Container | Separated? |
|-------------------|-------------------|-------------------|------------|
| **Elasticsearch + Kibana** | elasticsearch | kibana | ✅ Yes |
| **Grafana + Prometheus** | prometheus | grafana | ✅ Yes |
| **Nextcloud + Collabora** | nextcloud | collabora | ✅ Yes |
| **Home Assistant + ESPHome** | homeassistant | esphome-dashboard | ✅ Yes |
| **Jellyfin + Jellyseerr** | jellyfin | jellyseerr | ✅ Yes |

### Combined Container Examples (Less Common)

| Application | Reason for Combining |
|-------------|---------------------|
| **Plex** | Proprietary, single vendor |
| **Emby** | Proprietary, single vendor |
| **Sonarr/Radarr** | Simple app, minimal separation benefit |

**Pattern:** Complex stacks with distinct components = separate containers

---

## Cost-Benefit Analysis

### Development Cost

| Aspect | Separate | Combined | Delta |
|--------|----------|----------|-------|
| **Initial Development** | 26 hours | 34 hours | -8 hours |
| **Testing** | 12 hours | 18 hours | -6 hours |
| **Documentation** | 8 hours | 6 hours | +2 hours |
| **Maintenance (1st year)** | 10 hours | 25 hours | -15 hours |
| **TOTAL (1st year)** | **56 hours** | **83 hours** | **-27 hours** |

**Separate containers = 33% less effort over 1 year** ✅

### User Cost

| Aspect | Separate | Combined |
|--------|----------|----------|
| **Setup Time** | 20 min | 15 min |
| **Update Time (per year)** | 10 min | 10 min |
| **Troubleshooting (avg)** | 15 min | 30 min |
| **Resource Cost (RAM)** | 3-5GB | 3-5GB |
| **Flexibility Benefit** | High | Low |

**Separate = slightly longer setup, much easier troubleshooting** ✅

---

## Risk Analysis

### Separate Containers Risks

| Risk | Impact | Probability | Mitigation | Severity |
|------|--------|-------------|------------|----------|
| User confusion (2 templates) | Low | 20% | Clear naming, docs | Low |
| Network misconfiguration | Medium | 15% | Auto-detect, validation | Low |
| Version incompatibility | Low | 5% | Semantic versioning | Very Low |
| Community rejection | Low | 5% | Follows standards | Very Low |

**Overall Risk Score:** 1.2/10 (Very Low) ✅

### Combined Container Risks

| Risk | Impact | Probability | Mitigation | Severity |
|------|--------|-------------|------------|----------|
| Update breaks both | High | 25% | Extensive testing | High |
| Complex troubleshooting | Medium | 40% | Better logging | Medium |
| Reduced adoption (inflexible) | Medium | 30% | Offer both options | Medium |
| Maintenance burden | High | 60% | More resources | High |
| Cannot scale independently | Low | 20% | Document limitations | Low |

**Overall Risk Score:** 6.8/10 (Medium-High) ⚠️

---

## Conclusion: Clear Winner

### ✅ DECISION: Deploy as Separate Containers

**Primary Reasons:**
1. **33% less maintenance effort** over lifetime
2. **Aligns with Unraid community standards**
3. **Maximum flexibility** for users
4. **Agent Inbox reusable** for future agents
5. **Independent update cycles**
6. **Simpler troubleshooting**
7. **Industry best practice**

**Trade-off Accepted:**
- 5 extra minutes of setup time
- Negligible compared to lifetime benefits

### Implementation Strategy

**Phase 1 (Required):**
- ✅ Build Executive AI Assistant container
- ✅ Build Agent Inbox container
- ✅ Create separate Unraid templates
- ✅ Document connection process

**Phase 2 (Optional, Community-Driven):**
- ❓ If users request all-in-one option
- ❓ Create combined variant
- ❓ Offer as alternative template

**Recommendation:** Start with Phase 1, evaluate Phase 2 based on feedback.

---

## Next Actions

1. ✅ **Proceed with separate container architecture**
2. ✅ **Update implementation plan** to reflect decision
3. ✅ **Begin Executive AI Assistant development**
4. ✅ **Design clear template naming convention**
5. ✅ **Create connection documentation**
6. ✅ **Develop auto-detection features** where possible

**Decision is final, documented, and ready for implementation.** 🚀
