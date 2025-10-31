# Phase 4B: Authentication Implementation Plan

## 📋 Executive Summary

**Duration**: 2-3 weeks  
**Priority**: CRITICAL (Security vulnerability)  
**Dependencies**: Phase 1-3 (Persistent Storage) ✅ Complete  

### Current State
- ❌ NO authentication on Agent Inbox (ports 2024, 2025, 3000)
- ❌ NO authentication on Executive AI Assistant Setup UI (port 2025)
- ✅ Persistent storage infrastructure complete (Phases 1-3)
- ✅ Server-side storage patterns established

### Security Risks (Current)
1. **Unauthorized email access** - Anyone can read private emails
2. **API key exposure** - LangSmith API keys visible to anyone
3. **OAuth token theft** - Gmail OAuth credentials accessible
4. **Configuration manipulation** - Anyone can modify settings
5. **Multi-device exposure** - If you port forward, entire internet has access

### Goal
Implement **basic authentication** for both Agent Inbox and Setup UI using a **single shared password** for the admin user. This provides immediate security while maintaining simplicity.

---

## 🎯 Implementation Strategy

### Pattern Reuse from Persistent Storage
We'll follow the same successful patterns used in persistent storage (Phases 1-3):

| Storage Component | Auth Equivalent | Purpose |
|------------------|----------------|---------|
| `USE_SERVER_STORAGE` env var | `AUTH_ENABLED` env var | Feature flag to enable/disable |
| `/api/config` route | `/api/auth/*` routes | API endpoints |
| `usePersistentConfig` hook | `useAuth` hook | Frontend state management |
| `config-storage.ts` service | `auth-service.ts` service | Backend business logic |
| `config.json` file | Enhanced `config.json` + sessions | Data persistence |

### Key Differences
1. **Password hashing** - Use bcrypt (≥12 rounds) for secure password storage
2. **Session management** - HTTP-only cookies with CSRF protection
3. **Protected routes** - Next.js middleware to guard all pages
4. **Token validation** - Verify session tokens on every request
5. **Security focus** - Rate limiting, session expiry, secure headers

---

## 📁 File Structure

### New Files to Create

```
agent-inbox/
├── lib/
│   ├── auth-service.ts              # Backend auth logic (sessions, users)
│   ├── middleware/
│   │   └── auth-middleware.ts       # Session validation middleware
│   └── security/
│       ├── password-hash.ts         # bcrypt wrapper
│       ├── session-manager.ts       # Session CRUD operations
│       └── csrf.ts                  # CSRF token generation/validation
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   └── auth/
│   │   │       ├── login/route.ts   # POST /api/auth/login
│   │   │       ├── logout/route.ts  # POST /api/auth/logout
│   │   │       ├── me/route.ts      # GET /api/auth/me (current user)
│   │   │       └── session/route.ts # GET /api/auth/session (validate)
│   │   ├── login/
│   │   │   └── page.tsx             # Login page UI
│   │   └── middleware.ts            # Next.js route protection
│   └── hooks/
│       └── use-auth.tsx             # React hook for auth state
└── .env.local                        # AUTH_ENABLED=true
```

### Files to Modify

```
agent-inbox/
├── lib/
│   └── config-storage.ts            # Add auth field to config schema
├── src/
│   └── app/
│       ├── layout.tsx               # Add auth provider wrapper
│       └── page.tsx                 # Add login redirect if not authenticated
```

---

## 🔧 Implementation Sequence

### Week 1: Core Authentication (Days 1-7)

#### Day 1-2: Backend Foundation
**Files**: `auth-service.ts`, `password-hash.ts`, `session-manager.ts`

1. **Create `lib/security/password-hash.ts`**
   ```typescript
   import bcrypt from 'bcryptjs';
   
   export async function hashPassword(password: string): Promise<string> {
     return bcrypt.hash(password, 12); // 12 rounds for security
   }
   
   export async function verifyPassword(password: string, hash: string): Promise<boolean> {
     return bcrypt.compare(password, hash);
   }
   
   export function generateToken(): string {
     return crypto.randomBytes(32).toString('hex');
   }
   ```

2. **Create `lib/security/session-manager.ts`**
   ```typescript
   import { randomBytes } from 'crypto';
   
   export interface Session {
     id: string;
     userId: string;
     token: string;
     createdAt: string;
     expiresAt: string;
     lastActivity: string;
   }
   
   export class SessionManager {
     private sessions: Map<string, Session> = new Map();
     private readonly SESSION_TIMEOUT = 30 * 60 * 1000; // 30 minutes
     
     createSession(userId: string): Session {
       const token = randomBytes(32).toString('hex');
       const now = new Date();
       const expiresAt = new Date(now.getTime() + this.SESSION_TIMEOUT);
       
       const session: Session = {
         id: randomBytes(16).toString('hex'),
         userId,
         token,
         createdAt: now.toISOString(),
         expiresAt: expiresAt.toISOString(),
         lastActivity: now.toISOString()
       };
       
       this.sessions.set(token, session);
       return session;
     }
     
     validateSession(token: string): Session | null {
       const session = this.sessions.get(token);
       if (!session) return null;
       
       // Check expiry
       if (new Date() > new Date(session.expiresAt)) {
         this.sessions.delete(token);
         return null;
       }
       
       // Update last activity
       session.lastActivity = new Date().toISOString();
       return session;
     }
     
     destroySession(token: string): void {
       this.sessions.delete(token);
     }
   }
   
   export const sessionManager = new SessionManager();
   ```

3. **Create `lib/auth-service.ts`**
   ```typescript
   import { loadConfig, saveConfig, isServerStorageEnabled } from './config-storage';
   import { hashPassword, verifyPassword, generateToken } from './security/password-hash';
   import { sessionManager, Session } from './security/session-manager';
   
   export interface User {
     id: string;
     username: string;
     passwordHash: string;
     role: 'admin' | 'user';
     createdAt: string;
   }
   
   export interface AuthConfig {
     enabled: boolean;
     users: User[];
   }
   
   // Check if auth is enabled via env var
   export function isAuthEnabled(): boolean {
     return process.env.AUTH_ENABLED === 'true';
   }
   
   // Get admin credentials from env
   export function getAdminCredentials(): { username: string; passwordHash: string } | null {
     const username = process.env.ADMIN_USERNAME;
     const passwordHash = process.env.ADMIN_PASSWORD_HASH;
     
     if (!username || !passwordHash) return null;
     return { username, passwordHash };
   }
   
   // Initialize admin user if it doesn't exist
   export async function ensureAdminUser(): Promise<void> {
     if (!isAuthEnabled()) return;
     
     const config = await loadConfig();
     if (!config) return;
     
     // Check if auth section exists
     if (!config.auth) {
       config.auth = { enabled: true, users: [] };
     }
     
     // Check if admin user exists
     const adminUser = config.auth.users.find(u => u.role === 'admin');
     if (adminUser) return; // Already exists
     
     // Get admin credentials from env
     const adminCreds = getAdminCredentials();
     if (!adminCreds) {
       console.error('AUTH_ENABLED=true but ADMIN_USERNAME/ADMIN_PASSWORD_HASH not set');
       return;
     }
     
     // Create admin user
     const admin: User = {
       id: generateToken(),
       username: adminCreds.username,
       passwordHash: adminCreds.passwordHash,
       role: 'admin',
       createdAt: new Date().toISOString()
     };
     
     config.auth.users.push(admin);
     await saveConfig(config);
   }
   
   // Authenticate user
   export async function authenticateUser(username: string, password: string): Promise<Session | null> {
     if (!isAuthEnabled()) return null;
     
     const config = await loadConfig();
     if (!config?.auth) return null;
     
     // Find user
     const user = config.auth.users.find(u => u.username === username);
     if (!user) return null;
     
     // Verify password
     const valid = await verifyPassword(password, user.passwordHash);
     if (!valid) return null;
     
     // Create session
     return sessionManager.createSession(user.id);
   }
   
   // Validate session token
   export function validateSession(token: string): Session | null {
     if (!isAuthEnabled()) return null;
     return sessionManager.validateSession(token);
   }
   
   // Logout (destroy session)
   export function logout(token: string): void {
     sessionManager.destroySession(token);
   }
   ```

#### Day 3-4: API Routes
**Files**: `/api/auth/login/route.ts`, `/api/auth/logout/route.ts`, `/api/auth/me/route.ts`

1. **Create `/api/auth/login/route.ts`**
   ```typescript
   import { NextRequest, NextResponse } from 'next/server';
   import { authenticateUser, isAuthEnabled } from '@/lib/auth-service';
   import { cookies } from 'next/headers';
   
   export async function POST(request: NextRequest) {
     try {
       // Check if auth enabled
       if (!isAuthEnabled()) {
         return NextResponse.json(
           { enabled: false, message: 'Authentication not enabled' },
           { status: 400 }
         );
       }
       
       // Parse request body
       const body = await request.json();
       const { username, password } = body;
       
       // Validate input
       if (!username || !password) {
         return NextResponse.json(
           { error: 'Username and password required' },
           { status: 400 }
         );
       }
       
       // Authenticate
       const session = await authenticateUser(username, password);
       
       if (!session) {
         return NextResponse.json(
           { error: 'Invalid username or password' },
           { status: 401 }
         );
       }
       
       // Set HTTP-only cookie
       const cookieStore = cookies();
       cookieStore.set('session_token', session.token, {
         httpOnly: true,
         secure: process.env.NODE_ENV === 'production',
         sameSite: 'strict',
         maxAge: 30 * 60, // 30 minutes
         path: '/'
       });
       
       return NextResponse.json({
         success: true,
         message: 'Login successful',
         expiresAt: session.expiresAt
       });
       
     } catch (error) {
       console.error('Login error:', error);
       return NextResponse.json(
         { error: 'Internal server error' },
         { status: 500 }
       );
     }
   }
   ```

2. **Create `/api/auth/logout/route.ts`**
   ```typescript
   import { NextRequest, NextResponse } from 'next/server';
   import { logout } from '@/lib/auth-service';
   import { cookies } from 'next/headers';
   
   export async function POST(request: NextRequest) {
     try {
       const cookieStore = cookies();
       const token = cookieStore.get('session_token')?.value;
       
       if (token) {
         logout(token);
         cookieStore.delete('session_token');
       }
       
       return NextResponse.json({
         success: true,
         message: 'Logout successful'
       });
       
     } catch (error) {
       console.error('Logout error:', error);
       return NextResponse.json(
         { error: 'Internal server error' },
         { status: 500 }
       );
     }
   }
   ```

3. **Create `/api/auth/me/route.ts`**
   ```typescript
   import { NextRequest, NextResponse } from 'next/server';
   import { validateSession, isAuthEnabled } from '@/lib/auth-service';
   import { cookies } from 'next/headers';
   
   export async function GET(request: NextRequest) {
     try {
       // Check if auth enabled
       if (!isAuthEnabled()) {
         return NextResponse.json({
           enabled: false,
           authenticated: false
         });
       }
       
       // Get session token from cookie
       const cookieStore = cookies();
       const token = cookieStore.get('session_token')?.value;
       
       if (!token) {
         return NextResponse.json({
           enabled: true,
           authenticated: false
         });
       }
       
       // Validate session
       const session = validateSession(token);
       
       if (!session) {
         return NextResponse.json({
           enabled: true,
           authenticated: false
         });
       }
       
       return NextResponse.json({
         enabled: true,
         authenticated: true,
         userId: session.userId,
         expiresAt: session.expiresAt
       });
       
     } catch (error) {
       console.error('Auth check error:', error);
       return NextResponse.json(
         { error: 'Internal server error' },
         { status: 500 }
       );
     }
   }
   ```

#### Day 5-6: Login UI
**Files**: `/app/login/page.tsx`

```typescript
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.error || 'Login failed');
        setLoading(false);
        return;
      }

      // Redirect to home page
      router.push('/');
      router.refresh();

    } catch (err) {
      setError('Network error. Please try again.');
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
      <div className="max-w-md w-full space-y-8 p-8 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
        <div>
          <h2 className="text-center text-3xl font-extrabold text-gray-900 dark:text-white">
            Agent Inbox Login
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600 dark:text-gray-400">
            Enter your credentials to access your inbox
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleLogin}>
          {error && (
            <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-400 px-4 py-3 rounded">
              {error}
            </div>
          )}

          <div className="space-y-4">
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Username
              </label>
              <input
                id="username"
                name="username"
                type="text"
                required
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                placeholder="Enter username"
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                placeholder="Enter password"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
          >
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  );
}
```

#### Day 7: Frontend Auth Hook
**Files**: `hooks/use-auth.tsx`

```typescript
'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';

interface AuthState {
  enabled: boolean;
  authenticated: boolean;
  userId?: string;
  expiresAt?: string;
  isLoading: boolean;
}

export function useAuth() {
  const [authState, setAuthState] = useState<AuthState>({
    enabled: false,
    authenticated: false,
    isLoading: true
  });
  const router = useRouter();

  // Check authentication status
  const checkAuth = useCallback(async () => {
    try {
      const response = await fetch('/api/auth/me');
      const data = await response.json();

      setAuthState({
        enabled: data.enabled,
        authenticated: data.authenticated,
        userId: data.userId,
        expiresAt: data.expiresAt,
        isLoading: false
      });

      // Redirect to login if auth enabled but not authenticated
      if (data.enabled && !data.authenticated) {
        router.push('/login');
      }

    } catch (error) {
      console.error('Auth check failed:', error);
      setAuthState(prev => ({ ...prev, isLoading: false }));
    }
  }, [router]);

  // Login
  const login = useCallback(async (username: string, password: string) => {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });

    if (!response.ok) {
      const data = await response.json();
      throw new Error(data.error || 'Login failed');
    }

    await checkAuth();
    return true;
  }, [checkAuth]);

  // Logout
  const logout = useCallback(async () => {
    await fetch('/api/auth/logout', { method: 'POST' });
    setAuthState({
      enabled: true,
      authenticated: false,
      isLoading: false
    });
    router.push('/login');
  }, [router]);

  // Check auth on mount
  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  return {
    ...authState,
    login,
    logout,
    checkAuth
  };
}
```

---

### Week 2: UI Integration (Days 8-14)

#### Day 8-9: Protected Routes (Middleware)
**File**: `src/app/middleware.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { validateSession, isAuthEnabled } from '@/lib/auth-service';

export async function middleware(request: NextRequest) {
  // Check if auth is enabled
  if (!isAuthEnabled()) {
    return NextResponse.next();
  }

  // Allow login page
  if (request.nextUrl.pathname === '/login') {
    return NextResponse.next();
  }

  // Allow public API routes
  if (request.nextUrl.pathname.startsWith('/api/auth/')) {
    return NextResponse.next();
  }

  // Get session token from cookie
  const token = request.cookies.get('session_token')?.value;

  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Validate session
  const session = validateSession(token);

  if (!session) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Valid session - allow request
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|public).*)',
  ],
};
```

#### Day 10-11: Update Existing Pages
**Files**: Update `layout.tsx`, `page.tsx`

1. **Add auth provider to `layout.tsx`**
2. **Add logout button to header**
3. **Show session expiry warning**

#### Day 12-13: Session Management
- Implement session timeout warning (5 minutes before expiry)
- Add "Extend Session" button
- Auto-logout on expiry
- Session persistence across page reloads

#### Day 14: Environment Variables & Documentation
**File**: `.env.local`

```bash
# Authentication
AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=$2a$12$... # Use bcryptjs to generate
SESSION_SECRET=your-secret-key-here
SESSION_TIMEOUT=1800000  # 30 minutes in milliseconds

# Existing
USE_SERVER_STORAGE=true
```

**Update README.md** with:
- How to enable authentication
- How to generate password hash
- Security best practices

---

### Week 3: Testing & Polish (Days 15-21)

#### Day 15-16: Security Testing
- [ ] Test session hijacking prevention
- [ ] Test CSRF protection
- [ ] Test password brute force (rate limiting)
- [ ] Test XSS vulnerabilities
- [ ] Test SQL injection (N/A for JSON storage)

#### Day 17-18: Multi-Browser Testing
- [ ] Chrome/Edge
- [ ] Firefox
- [ ] Safari
- [ ] Mobile browsers

#### Day 19-20: Documentation
- [ ] User guide (how to login)
- [ ] Admin guide (how to setup)
- [ ] Security guide (best practices)
- [ ] Migration guide (for existing users)

#### Day 21: Final Review
- [ ] Code review
- [ ] Security audit
- [ ] Performance testing
- [ ] Documentation review

---

## 🔒 Security Best Practices

### Password Security
- ✅ Use bcrypt with ≥12 rounds
- ✅ Never log passwords
- ✅ Hash passwords on server-side only
- ✅ Use environment variables for admin credentials

### Session Security
- ✅ HTTP-only cookies (prevent XSS)
- ✅ Secure flag in production (HTTPS only)
- ✅ SameSite=strict (prevent CSRF)
- ✅ 30-minute session timeout
- ✅ Regenerate session on login

### API Security
- ✅ Validate all inputs
- ✅ Return generic error messages
- ✅ Rate limit login attempts (future)
- ✅ Log failed login attempts

### Storage Security
- ✅ Store sessions in memory initially (simple)
- ✅ Never store plaintext passwords
- ✅ Use file permissions (0600) for config.json

---

## 📊 Success Criteria

### Functional Requirements
- ✅ User can login with username/password
- ✅ User can logout
- ✅ Session persists across page reloads
- ✅ Session expires after 30 minutes
- ✅ All pages protected (except /login)
- ✅ Backward compatible (auth can be disabled)

### Security Requirements
- ✅ Passwords hashed with bcrypt ≥12 rounds
- ✅ Sessions use HTTP-only cookies
- ✅ CSRF protection via SameSite cookies
- ✅ No XSS vulnerabilities
- ✅ No session hijacking vulnerabilities

### UX Requirements
- ✅ Clean, intuitive login page
- ✅ Clear error messages
- ✅ Loading states during authentication
- ✅ Automatic redirect after login
- ✅ Session expiry warning

---

## 🚀 Deployment Checklist

### Environment Setup
```bash
# 1. Generate password hash
node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('your-password', 12));"

# 2. Set environment variables
AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=$2a$12$...
SESSION_SECRET=$(openssl rand -hex 32)

# 3. Restart container
docker restart agent-inbox
```

### Docker Template Updates
- Add environment variables to Unraid template
- Add documentation for password setup
- Add warning about security importance

### Testing Steps
1. Stop container
2. Update environment variables
3. Start container
4. Try to access without login → Should redirect to /login
5. Login with correct credentials → Should work
6. Login with wrong credentials → Should show error
7. Logout → Should redirect to /login
8. Wait 30 minutes → Session should expire

---

## 🔄 Future Enhancements (Post-Phase 4B)

### Phase 4C: Enhanced Security (Optional)
- Two-factor authentication (TOTP)
- Remember me (30-day sessions)
- Change password UI
- Password reset via email
- Session management UI (see all active sessions)

### Phase 6: Multi-User (Later)
- Multiple user accounts
- Role-based access control (admin, user, readonly)
- Per-user inbox assignments
- User management UI

---

## 📝 Notes from Pattern Analysis

### What We're Reusing
1. **Feature Flag Pattern** - Same as `USE_SERVER_STORAGE`
2. **API Route Structure** - Same GET/POST pattern
3. **Frontend Hook** - Same React hook pattern
4. **Backend Service** - Same service layer pattern
5. **Error Handling** - Same graceful fallback
6. **Backward Compatibility** - Auth disabled by default

### What's New
1. **Password Hashing** - bcrypt (not in config storage)
2. **Session Management** - Cookies & tokens (new)
3. **Route Protection** - Next.js middleware (new)
4. **Login UI** - Dedicated login page (new)
5. **Security Focus** - CSRF, XSS, rate limiting (new)

### Key Differences from Storage Implementation
| Aspect | Config Storage | Authentication |
|--------|---------------|---------------|
| **Data Sensitivity** | Medium (API keys) | HIGH (passwords, sessions) |
| **Validation** | Input validation | Security validation |
| **Storage** | Simple JSON file | JSON + in-memory sessions |
| **Error Messages** | Detailed | Generic (security) |
| **Testing** | Functional | Security-focused |

---

## ❓ Open Questions

1. **Session Storage**: Memory vs File?
   - **Recommendation**: Start with memory (simpler), migrate to file in Phase 4C if needed
   
2. **Rate Limiting**: Now or later?
   - **Recommendation**: Later (Phase 4C) - adds complexity
   
3. **CSRF Tokens**: Custom or SameSite?
   - **Recommendation**: SameSite cookies (simpler, sufficient for Phase 4B)
   
4. **Multi-User**: Now or later?
   - **Recommendation**: Later (Phase 6) - Phase 4B is single admin only

---

## 🎯 Next Steps

1. **Review this plan** with team/user
2. **Generate bcrypt password hash** for admin
3. **Start Day 1** implementation
4. **Daily commits** with clear messages
5. **Weekly testing** to catch issues early

---

## 📚 References

- [Next.js Middleware](https://nextjs.org/docs/app/building-your-application/routing/middleware)
- [bcrypt.js](https://github.com/dcodeIO/bcrypt.js)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [HTTP-only Cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies)

---

**Created**: 2025-01-XX  
**Last Updated**: 2025-01-XX  
**Status**: Ready for Review ✅
