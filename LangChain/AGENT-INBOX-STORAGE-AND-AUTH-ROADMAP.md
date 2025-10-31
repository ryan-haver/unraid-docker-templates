# Agent Inbox - Persistent Storage & Authentication Roadmap

## Executive Summary

**Date**: October 30, 2025  
**Status**: Persistent Storage Phase 1-3 COMPLETE, Authentication HIGH PRIORITY  
**Purpose**: Comprehensive review of UI-facing features requiring persistent storage and authentication implementation plan

---

## ✅ Persistent Storage - COMPLETED FEATURES

### Phase 1: Backend Infrastructure ✅
- File-based JSON storage at `/app/data/config.json`
- API endpoints: GET/POST/DELETE `/api/config`
- Docker volume support with `/app/data` mount
- Environment variable: `USE_SERVER_STORAGE` (opt-in)

### Phase 2: UI Integration ✅
- `usePersistentConfig` React hook for sync
- Settings UI shows storage mode (Cloud/HardDrive icons)
- 30-second periodic sync from server
- 1-second debounced saves to server
- Fallback to localStorage when server unavailable

### Phase 3: Zero-Touch Deployment ✅
- Pre-configuration via environment variables
- Welcome dialog suppression for pre-configured inboxes
- Automatic inbox creation from env vars
- Multi-device/multi-browser sync working

### Recent Bug Fixes ✅
- **Bug #1**: Welcome dialog race condition (wait for `isLoading`)
- **Bug #2**: Inbox visibility (integrate persistent config into `useInboxes`)
- **Bug #3**: Duplicate inbox creation (server creates config immediately, no merge)

---

## 📊 COMPREHENSIVE UI FEATURES REVIEW

### 1. ✅ CURRENTLY PERSISTED (Server Storage)

| Feature | Storage Location | Server Sync | Multi-Device | Status |
|---------|-----------------|-------------|--------------|--------|
| **Inboxes** | `config.inboxes[]` | ✅ Yes | ✅ Yes | ✅ Complete |
| - Inbox Name | `inbox.name` | ✅ | ✅ | ✅ |
| - Deployment URL | `inbox.deploymentUrl` | ✅ | ✅ | ✅ |
| - Assistant ID | `inbox.graphId` | ✅ | ✅ | ✅ |
| - Created Date | `inbox.createdAt` | ✅ | ✅ | ✅ |
| - Selected State | `inbox.selected` | ✅ | ✅ | ✅ |
| **LangSmith API Key** | `config.langsmithApiKey` | ✅ Yes | ✅ Yes | ✅ Complete |
| **User Preferences** | `config.preferences` | ✅ Yes | ✅ Yes | ✅ Complete |
| - Theme | `preferences.theme` | ✅ | ✅ | ✅ |

### 2. 🟡 BROWSER-ONLY (localStorage, Not Synced)

| Feature | Current Storage | Should Sync? | Priority | Reason |
|---------|----------------|--------------|----------|--------|
| **Backfill Status** | `inbox:id_backfill_completed` | ❌ No | Low | One-time migration flag |
| **Session Refresh Flags** | `inbox-refreshed-${sessionId}` | ❌ No | None | Temporary UI state |
| **Last Sync Timestamp** | `inbox:last_sync` | ❌ No | Low | Client-side tracking only |

### 3. ❌ NOT STORED (Fetched from API)

| Feature | Source | Should Store? | Reason |
|---------|--------|---------------|--------|
| **Thread Data** | LangSmith API | ❌ No | Real-time data, constantly changing |
| **Thread Status** | LangSmith API | ❌ No | Reflects live agent state |
| **Thread Messages** | LangSmith API | ❌ No | Managed by LangGraph/LangSmith |
| **Agent State** | LangSmith API | ❌ No | Live agent execution state |

### 4. 🔴 MISSING - NEEDS IMPLEMENTATION

| Feature | Description | Current State | Should Add? | Priority |
|---------|-------------|---------------|-------------|----------|
| **UI Column Layout** | Thread list column widths | ❌ Not stored | ⚠️ Maybe | Low |
| **Filter Preferences** | Last selected filter (All/Interrupted/etc) | ❌ Not stored | ✅ Yes | Medium |
| **Sidebar Collapsed State** | Sidebar expanded/collapsed | ❌ Not stored | ✅ Yes | Low |
| **Thread Sort Order** | Sort threads by date/status/etc | ❌ Not stored | ⚠️ Maybe | Low |
| **Pagination State** | Current page in thread list | ❌ Not stored | ❌ No | None |
| **Draft Responses** | Unsent human responses | ❌ Not stored | ✅ Yes | High |
| **Notification Settings** | Desktop notifications on/off | ❌ Not stored | ✅ Yes | Medium |
| **Auto-refresh Interval** | Thread polling frequency | ❌ Not stored | ✅ Yes | Medium |
| **Inbox Order** | Custom inbox sorting | ❌ Not stored | ✅ Yes | Medium |

---

## 🚨 HIGH PRIORITY: AUTHENTICATION & AUTHORIZATION

### Current Security State

**Agent Inbox (Current)**:
- ❌ No authentication - anyone with URL can access
- ❌ No user accounts - single-user application
- ❌ No password protection
- ✅ LangSmith API key stored securely (masked in UI)
- ⚠️ Relies on network security (private network/VPN)

**Executive AI Assistant (Current)**:
- ❌ No authentication - anyone with URL can access
- ❌ No protection for OAuth credentials
- ❌ No admin panel protection
- ⚠️ Gmail OAuth tokens accessible to anyone on network
- ⚠️ Email account fully controlled by anyone with access

### Security Risks

**🔴 CRITICAL RISKS**:
1. **Unauthorized Email Access**: Anyone on network can read/send emails as authenticated user
2. **API Key Exposure**: LangSmith API key visible to anyone accessing UI
3. **Configuration Tampering**: Anyone can add/delete inboxes, change settings
4. **OAuth Token Theft**: Gmail refresh tokens exposed via `/app/secrets` volume
5. **No Audit Trail**: No logging of who accessed what or when

**🟡 MEDIUM RISKS**:
6. **Shared Browser Sessions**: Multiple users share same config in browser
7. **No Access Control**: Can't limit features to specific users
8. **No Admin Panel**: Can't manage users or restrict access
9. **No Rate Limiting**: Vulnerable to brute force or DoS

### Authentication Requirements

#### 1. **Basic Authentication (Minimum Viable)**

**Features**:
- Single admin password set via environment variable
- HTTP Basic Auth or simple login form
- Session management with secure cookies
- Logout functionality

**Implementation**:
```typescript
// Environment Variables
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<bcrypt-hashed-password>
SESSION_SECRET=<random-secret>
AUTH_ENABLED=true  // Default: false for backward compatibility
```

**UI Changes**:
- Login page at `/login`
- Session cookie validation middleware
- Logout button in settings
- "Change Password" in settings

**Priority**: 🔴 **CRITICAL - Implement ASAP**

#### 2. **Multi-User Authentication (Enhanced)**

**Features**:
- Multiple user accounts
- User management UI
- Per-user inbox assignments
- Role-based access (Admin, User, Read-Only)

**Implementation**:
```typescript
// User Schema
interface User {
  id: string;
  username: string;
  passwordHash: string;
  role: 'admin' | 'user' | 'readonly';
  assignedInboxes: string[];  // inbox IDs
  createdAt: string;
  lastLogin: string;
}
```

**Storage**:
- Option A: SQLite database in `/app/data/users.db`
- Option B: File-based JSON (simple, consistent with config)
- Option C: External auth provider (OAuth, LDAP, etc.)

**Priority**: 🟡 **HIGH - Phase 2**

#### 3. **Advanced Security Features (Future)**

**Features**:
- OAuth 2.0 integration (Google, Microsoft, GitHub)
- Two-factor authentication (2FA)
- API key per-user generation
- Audit logging (who did what, when)
- Session management (active sessions, force logout)
- Password policies (complexity, expiration)
- Account lockout after failed attempts
- IP whitelisting

**Priority**: 🟢 **MEDIUM - Phase 3**

---

## 📋 RECOMMENDED IMPLEMENTATION ROADMAP

### 🔴 PHASE 4: BASIC AUTHENTICATION (CRITICAL - 2-3 weeks)

**Goal**: Protect **ALL UIs** (Agent Inbox AND Executive AI Assistant) with password authentication

**Scope**:
- ✅ Agent Inbox UI (port 3000)
- ✅ Executive AI Assistant API (port 2024) 
- ✅ Executive AI Assistant Setup UI (port 2025)
- ✅ All admin/management endpoints

#### Week 1: Core Authentication
- [ ] Design authentication schema
- [ ] Implement password hashing (bcrypt)
- [ ] Create session management middleware
- [ ] Add login page UI
- [ ] Add logout functionality
- [ ] Environment variable configuration

#### Week 2: UI Integration
- [ ] Add "Change Password" to settings
- [ ] Add session timeout (30 minutes idle)
- [ ] Add "Remember Me" checkbox
- [ ] Protected route middleware
- [ ] Redirect to login on auth failure
- [ ] Update Unraid templates with auth vars

#### Week 3: Testing & Documentation
- [ ] Security testing (session hijacking, CSRF)
- [ ] Multi-browser testing
- [ ] Update README with authentication guide
- [ ] Create migration guide for existing users
- [ ] Add troubleshooting section

**Deliverables**:
- ✅ Password-protected UI
- ✅ Secure session management
- ✅ Backward compatible (auth optional, off by default)
- ✅ Updated Unraid templates
- ✅ Documentation

### 🟡 PHASE 5: ENHANCED USER FEATURES (HIGH - 3-4 weeks)

**Goal**: Add missing UI preferences to persistent storage

#### Week 1: Filter & View Preferences
- [ ] Store last selected filter (All/Interrupted/Idle/etc)
- [ ] Store sidebar collapsed state
- [ ] Store thread list layout preferences
- [ ] Add to `config.preferences` schema

#### Week 2: Draft Management
- [ ] Store unsent draft responses per thread
- [ ] Auto-save drafts every 5 seconds
- [ ] Restore drafts on page reload
- [ ] Add "Discard Draft" button

#### Week 3: Notification & Refresh Settings
- [ ] Add notification toggle to UI
- [ ] Store notification preferences
- [ ] Add auto-refresh interval setting
- [ ] Store polling frequency preference

#### Week 4: Inbox Management
- [ ] Add inbox reordering (drag-and-drop)
- [ ] Store custom inbox order
- [ ] Add inbox categories/tags
- [ ] Store inbox metadata

**Deliverables**:
- ✅ Enhanced UX with persistent preferences
- ✅ Draft auto-save and restore
- ✅ Customizable notification settings
- ✅ Flexible inbox organization

### 🟢 PHASE 6: MULTI-USER & RBAC (MEDIUM - 4-5 weeks)

**Goal**: Support multiple users with role-based access control

#### Week 1-2: User Management Backend
- [ ] Design user schema
- [ ] Implement user CRUD operations
- [ ] Add user authentication API
- [ ] Add role-based middleware
- [ ] Create user database (SQLite or JSON)

#### Week 3: Admin UI
- [ ] Create user management page
- [ ] Add "Users" section to settings
- [ ] User creation/edit/delete forms
- [ ] Role assignment UI
- [ ] Inbox assignment per user

#### Week 4: Access Control
- [ ] Implement role-based permissions
- [ ] Restrict inbox access per user
- [ ] Add admin-only features toggle
- [ ] Per-user API keys

#### Week 5: Testing & Polish
- [ ] Multi-user session testing
- [ ] Permission boundary testing
- [ ] Performance testing (concurrent users)
- [ ] Documentation update

**Deliverables**:
- ✅ Multi-user support
- ✅ Role-based access control
- ✅ Admin management UI
- ✅ Per-user inbox assignments

### 🟢 PHASE 7: ADVANCED SECURITY (LOW - Future)

**Goal**: Enterprise-grade security features

- [ ] OAuth 2.0 integration (Google, Microsoft, GitHub)
- [ ] Two-factor authentication (TOTP)
- [ ] Audit logging
- [ ] Session management UI
- [ ] API key rotation
- [ ] IP whitelisting
- [ ] Advanced password policies

---

## 🔧 TECHNICAL ARCHITECTURE UPDATES

### Authentication Schema

```typescript
// config.json - Enhanced Schema
interface StoredConfiguration {
  version: string;
  lastUpdated: string;
  
  // Authentication (NEW)
  auth?: {
    enabled: boolean;
    users: User[];
    sessions: Session[];
  };
  
  // Existing
  langsmithApiKey?: string;
  inboxes: AgentInbox[];
  
  // Enhanced Preferences (NEW)
  preferences: {
    theme?: string;
    notifications?: {
      enabled: boolean;
      sound: boolean;
      desktop: boolean;
    };
    filters?: {
      lastSelected: string;
      customFilters: CustomFilter[];
    };
    ui?: {
      sidebarCollapsed: boolean;
      columnWidths: Record<string, number>;
      inboxOrder: string[];
    };
    polling?: {
      interval: number;  // milliseconds
      enabled: boolean;
    };
  };
  
  // Drafts (NEW)
  drafts?: {
    [threadId: string]: {
      content: string;
      lastSaved: string;
    };
  };
}

interface User {
  id: string;
  username: string;
  passwordHash: string;
  role: 'admin' | 'user' | 'readonly';
  assignedInboxes: string[];
  apiKey?: string;  // Per-user API key
  createdAt: string;
  lastLogin?: string;
  preferences: UserPreferences;
}

interface Session {
  id: string;
  userId: string;
  token: string;
  createdAt: string;
  expiresAt: string;
  lastActivity: string;
  ipAddress?: string;
  userAgent?: string;
}
```

### New API Endpoints

```typescript
// Authentication
POST   /api/auth/login          // Login with username/password
POST   /api/auth/logout         // Logout current session
GET    /api/auth/me             // Get current user info
POST   /api/auth/change-password  // Change password
GET    /api/auth/sessions       // List active sessions (admin)
DELETE /api/auth/sessions/:id   // Revoke session (admin)

// User Management (Admin only)
GET    /api/users               // List all users
POST   /api/users               // Create new user
GET    /api/users/:id           // Get user details
PUT    /api/users/:id           // Update user
DELETE /api/users/:id           // Delete user

// Preferences (Per-user)
GET    /api/preferences         // Get current user preferences
PUT    /api/preferences         // Update preferences
POST   /api/preferences/reset   // Reset to defaults

// Drafts (Per-user)
GET    /api/drafts              // Get all drafts
GET    /api/drafts/:threadId    // Get specific draft
PUT    /api/drafts/:threadId    // Save draft
DELETE /api/drafts/:threadId    // Discard draft
```

### Environment Variables (NEW)

```bash
# Authentication
AUTH_ENABLED=true                          # Enable authentication
AUTH_MODE=basic                            # basic, multi-user, oauth
ADMIN_USERNAME=admin                       # Initial admin username
ADMIN_PASSWORD_HASH=<bcrypt>              # Hashed password
SESSION_SECRET=<random-secret>            # Session encryption key
SESSION_TIMEOUT=1800                      # 30 minutes in seconds
REQUIRE_STRONG_PASSWORD=true              # Enforce password policy

# OAuth (Future)
OAUTH_PROVIDER=google                     # google, microsoft, github
OAUTH_CLIENT_ID=xxx
OAUTH_CLIENT_SECRET=xxx
OAUTH_CALLBACK_URL=http://localhost:3000/auth/callback

# Security
ENABLE_2FA=false                          # Two-factor authentication
ENABLE_IP_WHITELIST=false                 # IP restriction
ALLOWED_IPS=192.168.1.0/24               # CIDR notation
ENABLE_AUDIT_LOG=true                     # Log all actions
MAX_LOGIN_ATTEMPTS=5                      # Account lockout
LOCKOUT_DURATION=900                      # 15 minutes
```

---

## 🎯 PRIORITIES SUMMARY

### 🔴 CRITICAL (Start Immediately)
1. **Basic Authentication** - Protect both UIs with password
2. **Session Management** - Secure session handling
3. **Security Audit** - Review OAuth token storage

### 🟡 HIGH (Next Sprint)
4. **Filter Preferences** - Store last selected filter
5. **Draft Auto-Save** - Don't lose unsent responses
6. **Notification Settings** - Customizable alerts
7. **Inbox Ordering** - Custom inbox arrangement

### 🟢 MEDIUM (Future Phases)
8. **Multi-User Support** - Multiple accounts
9. **Role-Based Access** - Admin/User/ReadOnly
10. **Audit Logging** - Track user actions
11. **Advanced Security** - OAuth, 2FA, etc.

### ⚪ LOW (Nice to Have)
12. **UI Customization** - Column widths, themes
13. **Advanced Filters** - Custom filter builder
14. **Keyboard Shortcuts** - Power user features

---

## 🚧 BACKWARD COMPATIBILITY

**All new features will be backward compatible:**

1. **Authentication**:
   - Default: `AUTH_ENABLED=false` (current behavior)
   - Opt-in: Set `AUTH_ENABLED=true` + credentials
   - Migration: Existing users continue without auth

2. **Enhanced Preferences**:
   - Additive only - new fields in `preferences` object
   - Old configs still work (missing fields use defaults)
   - Auto-migration on first load

3. **Multi-User**:
   - Single-user mode still supported
   - Multi-user mode requires `AUTH_MODE=multi-user`
   - Can convert single → multi-user without data loss

---

## 📝 IMPLEMENTATION NOTES

### Security Best Practices

1. **Password Storage**:
   - Use bcrypt with salt rounds ≥ 12
   - Never log passwords (even hashed)
   - Store hashes in config.json with 0600 permissions

2. **Session Management**:
   - Secure, HttpOnly, SameSite cookies
   - Regenerate session ID on login
   - Clear session on logout
   - Timeout after inactivity

3. **API Security**:
   - CSRF token validation for state-changing operations
   - Rate limiting on auth endpoints
   - Fail2ban-style lockout on repeated failures
   - Audit log for security events

4. **Transport Security**:
   - Document HTTPS requirement for production
   - Add reverse proxy examples (Nginx, Traefik)
   - Warn about HTTP-only local network use

### Testing Checklist

- [ ] Session hijacking prevention
- [ ] CSRF attack prevention
- [ ] XSS prevention (input sanitization)
- [ ] SQL injection (if using SQL)
- [ ] Brute force protection
- [ ] Password reset flow
- [ ] Concurrent user sessions
- [ ] Mobile browser compatibility
- [ ] Multi-device sync
- [ ] Migration from browser-only mode

---

## 🎉 SUCCESS CRITERIA

**Phase 4 (Authentication) Complete When**:
- ✅ Both UIs protected with password
- ✅ Secure session management working
- ✅ No security vulnerabilities in audit
- ✅ Documentation complete
- ✅ Backward compatible (auth optional)
- ✅ Unraid templates updated

**Phase 5 (Enhanced Features) Complete When**:
- ✅ All UI preferences persist across devices
- ✅ Draft auto-save working reliably
- ✅ Notification settings customizable
- ✅ User experience improved measurably

**Phase 6 (Multi-User) Complete When**:
- ✅ Multiple users can log in independently
- ✅ Admin can manage users via UI
- ✅ Role-based permissions enforced
- ✅ Per-user inbox assignments working

---

## 📞 NEXT STEPS

1. **Review & Approve** this roadmap
2. **Prioritize** authentication implementation
3. **Create** detailed technical specs for Phase 4
4. **Assign** resources and timeline
5. **Start** development on authentication

---

**Document Version**: 1.0  
**Last Updated**: October 30, 2025  
**Status**: Awaiting approval to proceed with Phase 4
