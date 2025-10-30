# Agent Inbox - Persistent Storage Implementation Plan

## Executive Summary

**Goal**: Add server-side persistent configuration storage to Agent Inbox to solve browser localStorage limitations (configuration loss on clearing browser data, no multi-device sync, no multi-browser support).

**Current State**: 
- All configuration stored in browser localStorage only
- Configuration lost when clearing browser data
- No sync across devices/browsers
- Each browser session requires separate configuration

**Target State**:
- Optional server-side configuration storage
- Environment variable support for default configuration
- Backward compatible with browser-only localStorage
- Multi-device/browser support
- Configuration backup and restore capabilities

---

## Problem Statement

### Current Limitations

1. **Browser Data Clearing**: Clearing cache/cookies deletes all configuration
2. **Multi-Device**: No configuration sync across devices
3. **Multi-Browser**: Each browser requires separate configuration
4. **No Backup**: No automatic backup mechanism
5. **Manual Setup**: Must reconfigure LangSmith key and inboxes on each device

### User Pain Points

**Scenario 1: Accidental Data Loss**
- User clears browser data
- Loses LangSmith API key
- Loses all inbox configurations (URLs, assistant IDs, names)
- Must reconfigure everything from memory

**Scenario 2: Multi-Device Usage**
- User configures on desktop Chrome
- Opens laptop Firefox - no configuration
- Opens phone - no configuration
- Must manually reconfigure 3 times

**Scenario 3: Team Deployment**
- 5 team members need access
- Each must manually configure identical settings
- No way to share/distribute configuration
- High setup friction

---

## Proposed Solution Architecture

### Phase 1: Server-Side Storage Layer (Foundation)

**Goal**: Add optional server-side configuration storage without breaking existing browser-only mode.

#### Components to Add

1. **Configuration Storage Service** (`src/lib/config-storage.ts`)
   - Read/write configuration to server filesystem
   - JSON file-based storage (simple, no database needed)
   - Mounted volume for persistence
   - Fallback to browser localStorage if unavailable

2. **API Endpoints** (`src/app/api/config/`)
   ```
   GET  /api/config          - Retrieve configuration
   POST /api/config          - Save configuration
   PUT  /api/config          - Update configuration
   DELETE /api/config        - Clear configuration
   GET  /api/config/export   - Export configuration (backup)
   POST /api/config/import   - Import configuration (restore)
   ```

3. **Configuration Schema**
   ```typescript
   interface StoredConfiguration {
     version: string;
     lastUpdated: string;
     langsmithApiKey?: string;
     inboxes: AgentInbox[];
     preferences: {
       theme?: string;
       defaultInbox?: string;
       // Other UI preferences
     };
   }
   ```

4. **Storage Backend Options**
   - **Option A: File-based** (Recommended)
     - Simple JSON file: `/app/data/config.json`
     - No database dependency
     - Easy to backup/restore
     - Works with Docker volumes
   
   - **Option B: SQLite**
     - More robust for concurrent access
     - Query capabilities
     - Overkill for single config file
   
   - **Option C: Environment + File Hybrid**
     - Environment variables for defaults
     - File for user overrides
     - Best of both worlds

**Recommendation**: Start with **Option A (File-based)**, add Option C features.

#### Implementation Details

**1. Storage Service**
```typescript
// src/lib/config-storage.ts
import fs from 'fs/promises';
import path from 'path';

const CONFIG_FILE = process.env.CONFIG_FILE_PATH || '/app/data/config.json';
const USE_SERVER_STORAGE = process.env.USE_SERVER_STORAGE === 'true';

export async function saveConfig(config: StoredConfiguration) {
  if (!USE_SERVER_STORAGE) return null;
  await fs.writeFile(CONFIG_FILE, JSON.stringify(config, null, 2));
  return config;
}

export async function loadConfig(): Promise<StoredConfiguration | null> {
  if (!USE_SERVER_STORAGE) return null;
  try {
    const data = await fs.readFile(CONFIG_FILE, 'utf-8');
    return JSON.parse(data);
  } catch (error) {
    return null; // File doesn't exist yet
  }
}
```

**2. API Routes**
```typescript
// src/app/api/config/route.ts
import { NextResponse } from 'next/server';
import { loadConfig, saveConfig } from '@/lib/config-storage';

export async function GET() {
  const config = await loadConfig();
  return NextResponse.json(config || {});
}

export async function POST(request: Request) {
  const config = await request.json();
  await saveConfig(config);
  return NextResponse.json({ success: true });
}
```

**3. Client-Side Sync Hook**
```typescript
// src/hooks/use-persistent-config.tsx
export function usePersistentConfig() {
  const [serverEnabled, setServerEnabled] = useState(false);
  
  // Check if server storage is available
  useEffect(() => {
    fetch('/api/config')
      .then(res => res.ok)
      .then(setServerEnabled)
      .catch(() => setServerEnabled(false));
  }, []);
  
  // Sync localStorage to server periodically
  useEffect(() => {
    if (!serverEnabled) return;
    
    const syncToServer = async () => {
      const localConfig = getLocalStorageConfig();
      await fetch('/api/config', {
        method: 'POST',
        body: JSON.stringify(localConfig),
      });
    };
    
    // Sync every 30 seconds
    const interval = setInterval(syncToServer, 30000);
    return () => clearInterval(interval);
  }, [serverEnabled]);
  
  // Load from server on mount
  useEffect(() => {
    if (!serverEnabled) return;
    
    fetch('/api/config')
      .then(res => res.json())
      .then(serverConfig => {
        if (serverConfig.inboxes) {
          // Merge with local, server takes precedence
          mergeConfigIntoLocalStorage(serverConfig);
        }
      });
  }, [serverEnabled]);
}
```

#### Docker Volume Configuration

**Dockerfile Changes**
```dockerfile
# Create data directory for config storage
RUN mkdir -p /app/data && \
    chown -R nextjs:nodejs /app/data

VOLUME /app/data
```

**docker-compose.yml**
```yaml
services:
  agent-inbox:
    image: ghcr.io/ryan-haver/agent-inbox:latest
    volumes:
      - agent-inbox-config:/app/data
    environment:
      - USE_SERVER_STORAGE=true
      - CONFIG_FILE_PATH=/app/data/config.json

volumes:
  agent-inbox-config:
    driver: local
```

**Unraid Template Addition**
```xml
<Config Name="Config Storage" Target="/app/data" Default="/mnt/user/appdata/agent-inbox/config" Mode="rw" Description="Persistent configuration storage (optional - enables multi-device sync)" Type="Path" Display="advanced" Required="false" Mask="false">/mnt/user/appdata/agent-inbox/config</Config>

<Config Name="Enable Server Storage" Target="USE_SERVER_STORAGE" Default="true" Mode="" Description="Enable server-side configuration storage (true=persist across browsers/devices, false=browser localStorage only)" Type="Variable" Display="advanced" Required="false" Mask="false">true</Config>
```

---

### Phase 2: Environment Variable Defaults

**Goal**: Allow pre-configuration via environment variables for easy deployment.

#### Environment Variables to Add

```bash
# Core Configuration
LANGSMITH_API_KEY=lsv2_your_key_here
USE_SERVER_STORAGE=true

# Default Inbox Configuration
DEFAULT_INBOX_ENABLED=true
DEFAULT_INBOX_NAME="Executive AI Assistant"
DEFAULT_DEPLOYMENT_URL="http://192.168.1.100:2024"
DEFAULT_ASSISTANT_ID="email_assistant"

# Additional Inboxes (comma-separated)
ADDITIONAL_INBOXES='[
  {
    "name": "Development Agent",
    "deploymentUrl": "http://dev:2024",
    "assistantId": "dev_assistant"
  }
]'

# UI Preferences
DEFAULT_THEME="light"
DISABLE_BROWSER_OVERRIDE=false
```

#### Implementation

**1. Environment Loader**
```typescript
// src/lib/env-config.ts
export function getDefaultConfig(): Partial<StoredConfiguration> {
  const config: Partial<StoredConfiguration> = {};
  
  // LangSmith key from env
  if (process.env.LANGSMITH_API_KEY) {
    config.langsmithApiKey = process.env.LANGSMITH_API_KEY;
  }
  
  // Default inbox from env
  if (process.env.DEFAULT_INBOX_ENABLED === 'true') {
    config.inboxes = [{
      id: 'default',
      name: process.env.DEFAULT_INBOX_NAME || 'Default Inbox',
      deploymentUrl: process.env.DEFAULT_DEPLOYMENT_URL || '',
      assistantId: process.env.DEFAULT_ASSISTANT_ID || '',
    }];
  }
  
  // Additional inboxes from JSON
  if (process.env.ADDITIONAL_INBOXES) {
    try {
      const additional = JSON.parse(process.env.ADDITIONAL_INBOXES);
      config.inboxes = [...(config.inboxes || []), ...additional];
    } catch (e) {
      console.error('Invalid ADDITIONAL_INBOXES JSON', e);
    }
  }
  
  return config;
}
```

**2. Configuration Merging**
```typescript
// Priority order: Browser localStorage > Server storage > Environment defaults
export function mergeConfigurations(
  envDefaults: Partial<StoredConfiguration>,
  serverConfig: StoredConfiguration | null,
  localConfig: StoredConfiguration | null
): StoredConfiguration {
  return {
    ...envDefaults,
    ...(serverConfig || {}),
    ...(localConfig || {}),
    version: '1.0.0',
    lastUpdated: new Date().toISOString(),
  };
}
```

#### Unraid Template Updates

```xml
<!-- Environment Variable Defaults -->
<Config Name="LangSmith API Key (Default)" Target="LANGSMITH_API_KEY" Default="" Mode="" Description="Optional: Pre-configure LangSmith API key (users can still override in UI)" Type="Variable" Display="always" Required="false" Mask="true"/>

<Config Name="Enable Default Inbox" Target="DEFAULT_INBOX_ENABLED" Default="false" Mode="" Description="Pre-configure a default inbox for all users (true/false)" Type="Variable" Display="always" Required="false" Mask="false">false</Config>

<Config Name="Default Inbox Name" Target="DEFAULT_INBOX_NAME" Default="Executive AI Assistant" Mode="" Description="Name for the default inbox (if enabled)" Type="Variable" Display="always" Required="false" Mask="false">Executive AI Assistant</Config>

<Config Name="Default Deployment URL" Target="DEFAULT_DEPLOYMENT_URL" Default="http://192.168.1.100:2024" Mode="" Description="Default LangGraph deployment URL (use your Unraid IP)" Type="Variable" Display="always" Required="false" Mask="false">http://192.168.1.100:2024</Config>

<Config Name="Default Assistant ID" Target="DEFAULT_ASSISTANT_ID" Default="email_assistant" Mode="" Description="Default assistant/graph ID from langgraph.json" Type="Variable" Display="always" Required="false" Mask="false">email_assistant</Config>
```

---

### Phase 3: Enhanced Features

#### 3.1 Configuration Import/Export UI

**Add to Settings UI**
```typescript
// src/components/settings-dialog.tsx
<div className="space-y-4">
  <h3>Configuration Backup</h3>
  
  <Button onClick={handleExportConfig}>
    <Download className="mr-2 h-4 w-4" />
    Export Configuration
  </Button>
  
  <Button onClick={handleImportConfig}>
    <Upload className="mr-2 h-4 w-4" />
    Import Configuration
  </Button>
  
  {serverStorageEnabled && (
    <div className="text-sm text-muted-foreground">
      ✓ Server storage enabled - config persists across devices
    </div>
  )}
</div>
```

#### 3.2 Multi-User Support (Future)

**User Authentication Layer**
- Add simple auth (username/password or API key)
- Each user gets their own config file
- Shared vs personal inboxes
- Team collaboration features

**Structure**
```
/app/data/
  └── users/
      ├── user1_config.json
      ├── user2_config.json
      └── shared_config.json
```

#### 3.3 Configuration Versioning

**Track configuration changes**
```typescript
interface ConfigHistory {
  version: string;
  timestamp: string;
  config: StoredConfiguration;
}

// Store last 10 versions for rollback
/app/data/
  ├── config.json (current)
  └── history/
      ├── config_2025-10-30_12-00.json
      └── config_2025-10-29_15-30.json
```

---

## Implementation Timeline

### Phase 1: Foundation (Week 1-2)
**Priority: HIGH** - Solves core pain points

1. **Day 1-2**: Server-side storage service
   - Create `src/lib/config-storage.ts`
   - File-based JSON storage
   - Docker volume support

2. **Day 3-4**: API endpoints
   - GET/POST/PUT/DELETE `/api/config`
   - Export/import endpoints
   - Error handling

3. **Day 5-7**: Client-side integration
   - `use-persistent-config` hook
   - Modify existing `use-inboxes` hook
   - Sync localStorage ↔ server
   - Testing

4. **Day 8-10**: Docker & deployment
   - Update Dockerfile with volume
   - Update docker-compose.yml
   - Update DOCKER.md
   - Testing on Unraid

5. **Day 11-14**: Documentation & testing
   - Update Unraid template
   - Migration guide
   - Testing scenarios
   - Bug fixes

**Deliverables**:
- ✅ Optional server-side storage
- ✅ Volume support in Docker
- ✅ Backward compatible (browser-only still works)
- ✅ Configuration persistence across devices

### Phase 2: Environment Defaults (Week 3)
**Priority: MEDIUM** - Improves deployment experience

1. **Day 15-17**: Environment variable support
   - `src/lib/env-config.ts`
   - Default configuration loading
   - Configuration merging logic

2. **Day 18-19**: Unraid template updates
   - Add environment variable configs
   - Update documentation
   - Example configurations

3. **Day 20-21**: Testing & refinement
   - Test various env var combinations
   - Test override behavior
   - Documentation

**Deliverables**:
- ✅ Pre-configuration via env vars
- ✅ Easy team deployment
- ✅ Updated Unraid template

### Phase 3: Enhanced Features (Week 4+)
**Priority: LOW** - Nice-to-have improvements

1. **Import/Export UI**: 2-3 days
2. **Configuration versioning**: 2-3 days
3. **Multi-user support**: 5-7 days (if needed)

---

## Technical Specifications

### File Structure Changes

```
agent-inbox/
├── src/
│   ├── app/
│   │   └── api/
│   │       └── config/
│   │           ├── route.ts         (NEW - GET/POST config)
│   │           ├── export/
│   │           │   └── route.ts     (NEW - Export backup)
│   │           └── import/
│   │               └── route.ts     (NEW - Import restore)
│   ├── lib/
│   │   ├── config-storage.ts        (NEW - Storage service)
│   │   └── env-config.ts            (NEW - Env var loader)
│   ├── hooks/
│   │   └── use-persistent-config.tsx (NEW - Persistence hook)
│   └── components/
│       └── settings-dialog.tsx       (UPDATE - Add import/export)
├── Dockerfile                        (UPDATE - Add volume)
├── docker-compose.yml                (UPDATE - Add volume)
└── DOCKER.md                         (UPDATE - Document new features)
```

### Environment Variables Reference

```bash
# Storage Configuration
USE_SERVER_STORAGE=true                    # Enable server-side storage
CONFIG_FILE_PATH=/app/data/config.json    # Config file location

# LangSmith Configuration
LANGSMITH_API_KEY=lsv2_xxx                # Default API key

# Default Inbox
DEFAULT_INBOX_ENABLED=true                # Pre-configure default inbox
DEFAULT_INBOX_NAME="My Inbox"             # Inbox display name
DEFAULT_DEPLOYMENT_URL=http://host:2024   # LangGraph URL
DEFAULT_ASSISTANT_ID=email_assistant      # Graph ID

# Additional Inboxes (JSON array)
ADDITIONAL_INBOXES='[{"name":"Dev","deploymentUrl":"http://dev:2024","assistantId":"dev"}]'

# UI Preferences
DEFAULT_THEME=light                       # light/dark
DISABLE_BROWSER_OVERRIDE=false           # Force server config
```

### API Specifications

#### GET /api/config
```typescript
Response: StoredConfiguration
{
  "version": "1.0.0",
  "lastUpdated": "2025-10-30T12:00:00Z",
  "langsmithApiKey": "lsv2_xxx",
  "inboxes": [
    {
      "id": "uuid",
      "name": "Executive AI Assistant",
      "deploymentUrl": "http://192.168.1.100:2024",
      "assistantId": "email_assistant"
    }
  ],
  "preferences": {
    "theme": "light"
  }
}
```

#### POST /api/config
```typescript
Request: StoredConfiguration
Response: { success: true, config: StoredConfiguration }
```

#### GET /api/config/export
```typescript
Response: File download (application/json)
Filename: agent-inbox-config-YYYY-MM-DD.json
```

#### POST /api/config/import
```typescript
Request: multipart/form-data with config file
Response: { success: true, imported: StoredConfiguration }
```

---

## Migration Strategy

### Backward Compatibility

**Browser-Only Mode (Default)**
- If `USE_SERVER_STORAGE` is not set or `false`
- Works exactly as before
- No breaking changes
- Pure client-side localStorage

**Server Storage Mode (Opt-in)**
- Set `USE_SERVER_STORAGE=true`
- Add volume mount
- Configuration syncs to server
- Still falls back to browser if server unavailable

### User Migration Path

**Existing Users (Browser localStorage)**
1. Update to new image version
2. Container works as before (no changes)
3. Optionally enable server storage:
   - Add volume mount
   - Set `USE_SERVER_STORAGE=true`
   - Restart container
   - First load: syncs browser config to server
   - Future: server is source of truth

**New Users**
1. Install with server storage enabled (recommended)
2. Configure via UI or environment variables
3. Configuration persists automatically
4. Access from any device/browser

### Rollback Plan

If issues arise:
1. Set `USE_SERVER_STORAGE=false`
2. Restart container
3. Falls back to browser-only mode
4. No data loss (localStorage still has config)

---

## Testing Strategy

### Unit Tests

1. **Storage Service Tests**
   - File read/write operations
   - Error handling (permission errors, disk full)
   - Concurrent access handling

2. **API Endpoint Tests**
   - GET returns valid config
   - POST saves correctly
   - Export generates valid JSON
   - Import handles malformed data

3. **Configuration Merging Tests**
   - Env defaults < Server < Browser precedence
   - Partial configurations merge correctly
   - Invalid data is rejected

### Integration Tests

1. **Docker Volume Tests**
   - Config persists after container restart
   - Volume permissions correct
   - Backup/restore works

2. **Multi-Device Tests**
   - Device A saves config
   - Device B loads same config
   - Conflicts resolve correctly

3. **Upgrade Tests**
   - Old version → new version migration
   - No data loss during upgrade
   - Rollback scenarios

### User Acceptance Tests

1. **Scenario: Clear Browser Data**
   - Configure inbox
   - Clear browser cookies/cache
   - Reload page
   - ✅ Configuration restored from server

2. **Scenario: Multi-Device Setup**
   - Configure on Desktop Chrome
   - Open Laptop Firefox
   - ✅ Same configuration appears

3. **Scenario: Team Deployment**
   - Admin sets environment variables
   - 5 users access Agent Inbox
   - ✅ All see pre-configured inboxes

---

## Security Considerations

### Sensitive Data Handling

1. **LangSmith API Key**
   - Stored in server config file
   - File permissions: 600 (owner read/write only)
   - No logging of key value
   - Masked in UI after entry

2. **File Permissions**
   ```dockerfile
   RUN mkdir -p /app/data && \
       chown -R nextjs:nodejs /app/data && \
       chmod 700 /app/data
   ```

3. **Volume Security**
   - Unraid: Limited to appdata directory
   - Docker: No host access beyond volume
   - Recommend: Encrypted storage for production

### Access Control (Future)

1. **API Authentication**
   - Simple token-based auth
   - Environment variable: `API_SECRET_KEY`
   - Required for config API endpoints

2. **Rate Limiting**
   - Prevent brute force on API
   - 10 requests/minute per IP

3. **Audit Logging**
   - Log config changes
   - Include timestamp and source
   - Separate log file: `/app/data/audit.log`

---

## Documentation Updates Required

### 1. DOCKER.md
- Add server storage section
- Volume configuration examples
- Environment variable reference
- Migration guide

### 2. Unraid Template
- New volume mapping
- Environment variable configs
- Usage examples
- Troubleshooting

### 3. README.md
- Feature highlights
- Comparison: browser-only vs server storage
- Quick start guide
- FAQ

### 4. Migration Guide (NEW)
- Step-by-step upgrade process
- Backup instructions
- Rollback procedures
- Common issues

---

## Success Metrics

### Functional Requirements

✅ Configuration persists across browser sessions
✅ Configuration syncs across devices
✅ Configuration survives browser data clearing
✅ Zero-config deployment possible via env vars
✅ Backward compatible with existing deployments
✅ No breaking changes to existing users

### Performance Requirements

✅ Config load time < 100ms
✅ Sync delay < 1 second
✅ No UI blocking during save
✅ Handles 100+ inboxes without slowdown

### Usability Requirements

✅ No extra steps for browser-only users
✅ Clear opt-in for server storage
✅ Easy import/export for backup
✅ Helpful error messages
✅ Documentation covers all scenarios

---

## Risks & Mitigations

### Risk 1: File System Permissions
**Impact**: Config file not writable
**Mitigation**: 
- Dockerfile sets correct ownership
- Fallback to browser localStorage
- Clear error message in logs

### Risk 2: Configuration Conflicts
**Impact**: Different devices have different config
**Mitigation**:
- Server is always source of truth
- Last-write-wins strategy
- Conflict detection UI (Phase 3)

### Risk 3: Volume Mount Issues
**Impact**: Users forget to add volume
**Mitigation**:
- Template includes volume by default
- Auto-detect missing volume
- Show warning in UI
- Still functional without volume

### Risk 4: Breaking Changes
**Impact**: Existing users affected by update
**Mitigation**:
- Feature is opt-in
- Default behavior unchanged
- Extensive testing before release
- Rollback instructions

---

## Alternative Approaches Considered

### Alternative 1: IndexedDB Only
**Pros**: Client-side, larger storage
**Cons**: Still browser-specific, no multi-device sync
**Decision**: Rejected - doesn't solve core problem

### Alternative 2: External Database (PostgreSQL/MongoDB)
**Pros**: Robust, scalable
**Cons**: Over-engineered, complex deployment
**Decision**: Rejected - too complex for use case

### Alternative 3: Cloud Sync (S3, etc.)
**Pros**: True multi-device sync
**Cons**: Requires internet, cloud account, costs
**Decision**: Rejected - not self-hosted

### Alternative 4: Cookie-Based Storage
**Pros**: Simple, built-in
**Cons**: 4KB limit, sent with every request
**Decision**: Rejected - too limited

**Chosen Approach**: File-based server storage with volume
**Reasoning**: Simple, self-hosted, adequate for use case

---

## Future Enhancements

### Phase 4+ (Post-MVP)

1. **Cloud Sync Adapter**
   - Optional plugin for S3/Dropbox sync
   - For users wanting cloud backup
   - ~1 week effort

2. **Configuration Encryption**
   - Encrypt config file at rest
   - Password/key management
   - ~3 days effort

3. **Web-Based Admin Panel**
   - Manage users and configs via UI
   - Team/organization features
   - ~2 weeks effort

4. **Git Integration**
   - Store config in git repo
   - Version control built-in
   - ~1 week effort

5. **Configuration Templates**
   - Pre-built configurations
   - One-click import
   - Community sharing
   - ~1 week effort

---

## Conclusion

This plan provides a comprehensive, phased approach to solving the Agent Inbox configuration persistence problem:

**Phase 1 (Weeks 1-2)**: Core server storage - solves immediate pain points
**Phase 2 (Week 3)**: Environment defaults - improves deployment
**Phase 3+ (Week 4+)**: Enhanced features - nice-to-have improvements

The solution is:
- ✅ Backward compatible
- ✅ Opt-in (no breaking changes)
- ✅ Self-hosted (no cloud dependencies)
- ✅ Simple to deploy (file-based storage)
- ✅ Solves all identified problems

**Recommended Action**: Proceed with Phase 1 implementation, evaluate Phase 2 based on user feedback.
