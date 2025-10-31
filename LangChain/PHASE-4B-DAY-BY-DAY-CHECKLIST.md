# Phase 4B: Day-by-Day Implementation Checklist

## 📅 Week 1: Core Authentication Backend (Days 1-7)

### Day 1: Password Hashing Utility ✅
**Goal**: Create secure password hashing functions

- [ ] **Create directory**: `agent-inbox/lib/security/`
  ```bash
  mkdir -p agent-inbox/lib/security
  ```

- [ ] **Install bcrypt**:
  ```bash
  cd agent-inbox
  npm install bcryptjs
  npm install --save-dev @types/bcryptjs
  ```

- [ ] **Create `lib/security/password-hash.ts`**:
  ```typescript
  import bcrypt from 'bcryptjs';
  
  export async function hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 12);
  }
  
  export async function verifyPassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }
  
  export function generateToken(): string {
    return require('crypto').randomBytes(32).toString('hex');
  }
  ```

- [ ] **Test password hashing**:
  ```bash
  node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('TestPassword123!', 12));"
  # Save output for ADMIN_PASSWORD_HASH
  ```

- [ ] **Commit**:
  ```bash
  git add lib/security/password-hash.ts
  git commit -m "feat(auth): add password hashing utility with bcrypt"
  ```

**Testing**:
```bash
# In agent-inbox directory
node -e "
const { hashPassword, verifyPassword } = require('./lib/security/password-hash');
(async () => {
  const hash = await hashPassword('test123');
  console.log('Hash:', hash);
  console.log('Valid:', await verifyPassword('test123', hash));
  console.log('Invalid:', await verifyPassword('wrong', hash));
})();
"
```

---

### Day 2: Session Manager ✅
**Goal**: Create session CRUD operations (in-memory storage)

- [ ] **Create `lib/security/session-manager.ts`**:
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
      
      if (new Date() > new Date(session.expiresAt)) {
        this.sessions.delete(token);
        return null;
      }
      
      session.lastActivity = new Date().toISOString();
      return session;
    }
    
    destroySession(token: string): void {
      this.sessions.delete(token);
    }
    
    getAllSessions(): Session[] {
      return Array.from(this.sessions.values());
    }
    
    cleanup(): number {
      const now = new Date();
      let cleaned = 0;
      
      for (const [token, session] of this.sessions.entries()) {
        if (now > new Date(session.expiresAt)) {
          this.sessions.delete(token);
          cleaned++;
        }
      }
      
      return cleaned;
    }
  }
  
  export const sessionManager = new SessionManager();
  
  // Cleanup expired sessions every 5 minutes
  setInterval(() => {
    const cleaned = sessionManager.cleanup();
    if (cleaned > 0) {
      console.log(`Cleaned up ${cleaned} expired sessions`);
    }
  }, 5 * 60 * 1000);
  ```

- [ ] **Commit**:
  ```bash
  git add lib/security/session-manager.ts
  git commit -m "feat(auth): add session manager with automatic cleanup"
  ```

**Testing**:
```bash
node -e "
const { sessionManager } = require('./lib/security/session-manager');
const session = sessionManager.createSession('user123');
console.log('Created:', session);
console.log('Valid:', sessionManager.validateSession(session.token));
console.log('Invalid:', sessionManager.validateSession('fake-token'));
sessionManager.destroySession(session.token);
console.log('After destroy:', sessionManager.validateSession(session.token));
"
```

---

### Day 3: Auth Service ✅
**Goal**: Main authentication logic (user validation, session creation)

- [ ] **Update `lib/config-storage.ts`** to support auth field:
  ```typescript
  export interface User {
    id: string;
    username: string;
    passwordHash: string;
    role: 'admin' | 'user';
    createdAt: string;
    lastLogin?: string;
  }
  
  export interface AuthConfig {
    enabled: boolean;
    users: User[];
  }
  
  export interface StoredConfiguration {
    version: string;
    lastUpdated: string;
    auth?: AuthConfig;  // ← NEW
    langsmithApiKey?: string;
    inboxes: AgentInbox[];
    preferences: any;
  }
  ```

- [ ] **Create `lib/auth-service.ts`**:
  ```typescript
  import { loadConfig, saveConfig, User, AuthConfig } from './config-storage';
  import { hashPassword, verifyPassword, generateToken } from './security/password-hash';
  import { sessionManager, Session } from './security/session-manager';
  
  export function isAuthEnabled(): boolean {
    return process.env.AUTH_ENABLED === 'true';
  }
  
  export function getAdminCredentials(): { username: string; passwordHash: string } | null {
    const username = process.env.ADMIN_USERNAME;
    const passwordHash = process.env.ADMIN_PASSWORD_HASH;
    if (!username || !passwordHash) return null;
    return { username, passwordHash };
  }
  
  export async function ensureAdminUser(): Promise<void> {
    if (!isAuthEnabled()) return;
    
    const config = await loadConfig();
    if (!config) {
      console.error('Cannot ensure admin user: config not found');
      return;
    }
    
    if (!config.auth) {
      config.auth = { enabled: true, users: [] };
    }
    
    const adminUser = config.auth.users.find(u => u.role === 'admin');
    if (adminUser) return;
    
    const adminCreds = getAdminCredentials();
    if (!adminCreds) {
      console.error('AUTH_ENABLED=true but ADMIN_USERNAME/ADMIN_PASSWORD_HASH not set');
      return;
    }
    
    const admin: User = {
      id: generateToken(),
      username: adminCreds.username,
      passwordHash: adminCreds.passwordHash,
      role: 'admin',
      createdAt: new Date().toISOString()
    };
    
    config.auth.users.push(admin);
    await saveConfig(config);
    console.log(`Admin user created: ${admin.username}`);
  }
  
  export async function authenticateUser(username: string, password: string): Promise<Session | null> {
    if (!isAuthEnabled()) return null;
    
    const config = await loadConfig();
    if (!config?.auth) return null;
    
    const user = config.auth.users.find(u => u.username === username);
    if (!user) {
      console.log(`Login attempt failed: user not found (username: ${username})`);
      return null;
    }
    
    const valid = await verifyPassword(password, user.passwordHash);
    if (!valid) {
      console.log(`Login attempt failed: invalid password (username: ${username})`);
      return null;
    }
    
    // Update last login
    user.lastLogin = new Date().toISOString();
    await saveConfig(config);
    
    console.log(`Login successful: ${username}`);
    return sessionManager.createSession(user.id);
  }
  
  export function validateSession(token: string): Session | null {
    if (!isAuthEnabled()) return null;
    return sessionManager.validateSession(token);
  }
  
  export function logout(token: string): void {
    sessionManager.destroySession(token);
  }
  
  export { User, AuthConfig };
  ```

- [ ] **Commit**:
  ```bash
  git add lib/auth-service.ts lib/config-storage.ts
  git commit -m "feat(auth): add authentication service with user management"
  ```

**Testing**: See Day 4 (test via API routes)

---

### Day 4: Login API Route ✅
**Goal**: POST /api/auth/login endpoint

- [ ] **Create directory**: `src/app/api/auth/login/`
  ```bash
  mkdir -p src/app/api/auth/login
  ```

- [ ] **Create `src/app/api/auth/login/route.ts`**:
  ```typescript
  import { NextRequest, NextResponse } from 'next/server';
  import { authenticateUser, isAuthEnabled } from '@/lib/auth-service';
  import { cookies } from 'next/headers';
  
  export async function POST(request: NextRequest) {
    try {
      if (!isAuthEnabled()) {
        return NextResponse.json(
          { enabled: false, message: 'Authentication not enabled' },
          { status: 400 }
        );
      }
      
      const body = await request.json();
      const { username, password } = body;
      
      if (!username || !password) {
        return NextResponse.json(
          { error: 'Username and password required' },
          { status: 400 }
        );
      }
      
      const session = await authenticateUser(username, password);
      
      if (!session) {
        return NextResponse.json(
          { error: 'Invalid username or password' },
          { status: 401 }
        );
      }
      
      const cookieStore = cookies();
      cookieStore.set('session_token', session.token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 30 * 60,
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

- [ ] **Create `src/app/api/auth/logout/route.ts`**:
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

- [ ] **Create `src/app/api/auth/me/route.ts`**:
  ```typescript
  import { NextRequest, NextResponse } from 'next/server';
  import { validateSession, isAuthEnabled } from '@/lib/auth-service';
  import { cookies } from 'next/headers';
  
  export async function GET(request: NextRequest) {
    try {
      if (!isAuthEnabled()) {
        return NextResponse.json({
          enabled: false,
          authenticated: false
        });
      }
      
      const cookieStore = cookies();
      const token = cookieStore.get('session_token')?.value;
      
      if (!token) {
        return NextResponse.json({
          enabled: true,
          authenticated: false
        });
      }
      
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

- [ ] **Commit**:
  ```bash
  git add src/app/api/auth/
  git commit -m "feat(auth): add login, logout, and auth check API routes"
  ```

**Testing**:
```bash
# First, generate admin password hash
node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('TestPassword123!', 12));"

# Add to .env.local:
AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=<output from above>

# Restart dev server
npm run dev

# Test login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"TestPassword123!"}' \
  -c cookies.txt

# Test auth check
curl http://localhost:3000/api/auth/me -b cookies.txt

# Test logout
curl -X POST http://localhost:3000/api/auth/logout -b cookies.txt
```

---

### Day 5-6: Login UI Page ✅
**Goal**: Create beautiful login form

- [ ] **Create directory**: `src/app/login/`
  ```bash
  mkdir -p src/app/login
  ```

- [ ] **Create `src/app/login/page.tsx`**:
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
  
        router.push('/');
        router.refresh();
  
      } catch (err) {
        setError('Network error. Please try again.');
        setLoading(false);
      }
    };
  
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900 px-4">
        <div className="max-w-md w-full space-y-8 p-8 bg-white dark:bg-gray-800 rounded-lg shadow-lg">
          <div>
            <h2 className="text-center text-3xl font-extrabold text-gray-900 dark:text-white">
              Agent Inbox
            </h2>
            <p className="mt-2 text-center text-sm text-gray-600 dark:text-gray-400">
              Sign in to access your inbox
            </p>
          </div>
  
          <form className="mt-8 space-y-6" onSubmit={handleLogin}>
            {error && (
              <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-400 px-4 py-3 rounded relative">
                <span className="block sm:inline">{error}</span>
              </div>
            )}
  
            <div className="space-y-4">
              <div>
                <label htmlFor="username" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Username
                </label>
                <input
                  id="username"
                  name="username"
                  type="text"
                  required
                  autoComplete="username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="appearance-none relative block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 sm:text-sm"
                  placeholder="Enter your username"
                />
              </div>
  
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Password
                </label>
                <input
                  id="password"
                  name="password"
                  type="password"
                  required
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="appearance-none relative block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 sm:text-sm"
                  placeholder="Enter your password"
                />
              </div>
            </div>
  
            <div>
              <button
                type="submit"
                disabled={loading}
                className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
              >
                {loading ? (
                  <span className="flex items-center">
                    <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Signing in...
                  </span>
                ) : (
                  'Sign in'
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    );
  }
  ```

- [ ] **Commit**:
  ```bash
  git add src/app/login/
  git commit -m "feat(auth): add login page UI with dark mode support"
  ```

**Testing**:
```bash
# Start dev server
npm run dev

# Open browser
# Navigate to http://localhost:3000/login
# Try logging in with:
#   Username: admin
#   Password: TestPassword123!
```

---

### Day 7: Frontend Auth Hook ✅
**Goal**: React hook for auth state management

- [ ] **Create directory**: `src/hooks/`
  ```bash
  mkdir -p src/hooks
  ```

- [ ] **Create `src/hooks/use-auth.tsx`**:
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
  
        if (data.enabled && !data.authenticated && window.location.pathname !== '/login') {
          router.push('/login');
        }
  
      } catch (error) {
        console.error('Auth check failed:', error);
        setAuthState(prev => ({ ...prev, isLoading: false }));
      }
    }, [router]);
  
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
  
    const logout = useCallback(async () => {
      await fetch('/api/auth/logout', { method: 'POST' });
      setAuthState({
        enabled: true,
        authenticated: false,
        isLoading: false
      });
      router.push('/login');
    }, [router]);
  
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

- [ ] **Commit**:
  ```bash
  git add src/hooks/
  git commit -m "feat(auth): add useAuth hook for authentication state management"
  ```

**End of Week 1**: Core authentication backend complete! ✅

---

## 📅 Week 2: UI Integration & Route Protection (Days 8-14)

### Day 8: Middleware (Route Protection) ✅
**Goal**: Protect all routes except /login

- [ ] **Create `src/app/middleware.ts`**:
  ```typescript
  import { NextRequest, NextResponse } from 'next/server';
  
  export async function middleware(request: NextRequest) {
    // Check if auth is enabled
    const authEnabled = process.env.AUTH_ENABLED === 'true';
    
    if (!authEnabled) {
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
  
    // Validate session (import validateSession from auth-service)
    // Note: middleware.ts runs on edge, so might need adjustment
    // For now, just check token exists
    // TODO: Validate session properly
  
    return NextResponse.next();
  }
  
  export const config = {
    matcher: [
      '/((?!_next/static|_next/image|favicon.ico|public).*)',
    ],
  };
  ```

- [ ] **Commit**:
  ```bash
  git add src/app/middleware.ts
  git commit -m "feat(auth): add middleware for route protection"
  ```

**Testing**:
```bash
# Without login
curl http://localhost:3000/
# Should redirect to /login

# With login
curl http://localhost:3000/ -b cookies.txt
# Should work
```

---

### Day 9: Update Layout (Auth Provider) ✅
**Goal**: Add auth context to app

- [ ] **Create `src/contexts/auth-context.tsx`**:
  ```typescript
  'use client';
  
  import { createContext, useContext, ReactNode } from 'react';
  import { useAuth } from '@/hooks/use-auth';
  
  const AuthContext = createContext<ReturnType<typeof useAuth> | null>(null);
  
  export function AuthProvider({ children }: { children: ReactNode }) {
    const auth = useAuth();
    return <AuthContext.Provider value={auth}>{children}</AuthContext.Provider>;
  }
  
  export function useAuthContext() {
    const context = useContext(AuthContext);
    if (!context) {
      throw new Error('useAuthContext must be used within AuthProvider');
    }
    return context;
  }
  ```

- [ ] **Update `src/app/layout.tsx`** to wrap with AuthProvider:
  ```typescript
  import { AuthProvider } from '@/contexts/auth-context';
  
  export default function RootLayout({ children }: { children: ReactNode }) {
    return (
      <html lang="en">
        <body>
          <AuthProvider>
            {children}
          </AuthProvider>
        </body>
      </html>
    );
  }
  ```

- [ ] **Commit**:
  ```bash
  git add src/contexts/ src/app/layout.tsx
  git commit -m "feat(auth): add auth context provider"
  ```

---

### Day 10: Add Logout Button ✅
**Goal**: Add logout functionality to header

- [ ] **Create `src/components/logout-button.tsx`**:
  ```typescript
  'use client';
  
  import { useAuthContext } from '@/contexts/auth-context';
  
  export function LogoutButton() {
    const { enabled, authenticated, logout } = useAuthContext();
  
    if (!enabled || !authenticated) {
      return null;
    }
  
    return (
      <button
        onClick={logout}
        className="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md transition-colors"
      >
        Logout
      </button>
    );
  }
  ```

- [ ] **Update header component** to include LogoutButton

- [ ] **Commit**:
  ```bash
  git add src/components/logout-button.tsx
  git commit -m "feat(auth): add logout button component"
  ```

---

### Day 11-12: Session Timeout Warning ✅
**Goal**: Warn user 5 minutes before session expires

- [ ] **Create `src/components/session-expiry-warning.tsx`**:
  ```typescript
  'use client';
  
  import { useState, useEffect } from 'react';
  import { useAuthContext } from '@/contexts/auth-context';
  
  export function SessionExpiryWarning() {
    const { enabled, authenticated, expiresAt, checkAuth } = useAuthContext();
    const [showWarning, setShowWarning] = useState(false);
    const [minutesLeft, setMinutesLeft] = useState(0);
  
    useEffect(() => {
      if (!enabled || !authenticated || !expiresAt) return;
  
      const interval = setInterval(() => {
        const now = new Date();
        const expires = new Date(expiresAt);
        const diff = expires.getTime() - now.getTime();
        const minutes = Math.floor(diff / 60000);
  
        setMinutesLeft(minutes);
  
        if (minutes <= 5 && minutes > 0) {
          setShowWarning(true);
        } else if (minutes <= 0) {
          // Session expired
          window.location.href = '/login';
        } else {
          setShowWarning(false);
        }
      }, 10000); // Check every 10 seconds
  
      return () => clearInterval(interval);
    }, [enabled, authenticated, expiresAt]);
  
    if (!showWarning) return null;
  
    return (
      <div className="fixed bottom-4 right-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 text-yellow-800 dark:text-yellow-400 px-6 py-4 rounded-lg shadow-lg max-w-md">
        <div className="flex items-start">
          <div className="flex-shrink-0">
            <svg className="h-6 w-6 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <div className="ml-3 flex-1">
            <h3 className="text-sm font-medium">Session Expiring Soon</h3>
            <p className="mt-1 text-sm">
              Your session will expire in {minutesLeft} minute{minutesLeft !== 1 ? 's' : ''}.
            </p>
            <button
              onClick={checkAuth}
              className="mt-2 text-sm font-medium text-yellow-800 dark:text-yellow-400 hover:underline"
            >
              Extend Session
            </button>
          </div>
        </div>
      </div>
    );
  }
  ```

- [ ] **Add to layout**:
  ```typescript
  import { SessionExpiryWarning } from '@/components/session-expiry-warning';
  
  // In layout.tsx
  <AuthProvider>
    {children}
    <SessionExpiryWarning />
  </AuthProvider>
  ```

- [ ] **Commit**:
  ```bash
  git add src/components/session-expiry-warning.tsx
  git commit -m "feat(auth): add session expiry warning with extend option"
  ```

---

### Day 13: Environment Variables & Config ✅
**Goal**: Document all environment variables

- [ ] **Create `.env.example`**:
  ```bash
  # Authentication
  AUTH_ENABLED=true
  ADMIN_USERNAME=admin
  ADMIN_PASSWORD_HASH=  # Generate with: node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('your-password', 12));"
  SESSION_TIMEOUT=1800000  # 30 minutes in milliseconds
  
  # Server Storage
  USE_SERVER_STORAGE=true
  CONFIG_FILE_PATH=/app/data/config.json
  
  # LangSmith (optional)
  LANGSMITH_API_KEY=
  
  # Development
  NODE_ENV=development
  ```

- [ ] **Update `README.md`** with setup instructions

- [ ] **Commit**:
  ```bash
  git add .env.example README.md
  git commit -m "docs: add authentication setup instructions"
  ```

---

### Day 14: Testing & Bug Fixes ✅
**Goal**: Test all auth flows, fix bugs

- [ ] **Test Cases**:
  - [ ] Login with correct password works
  - [ ] Login with wrong password shows error
  - [ ] Login with wrong username shows error
  - [ ] Logout redirects to /login
  - [ ] Protected routes require login
  - [ ] Session persists across page reloads
  - [ ] Session expires after 30 minutes
  - [ ] Session expiry warning shows at 5 minutes
  - [ ] Extend session works
  - [ ] Auth can be disabled (AUTH_ENABLED=false)

- [ ] **Fix any bugs found**

- [ ] **Commit**:
  ```bash
  git add .
  git commit -m "fix(auth): resolve bugs from testing"
  ```

**End of Week 2**: UI integration complete! ✅

---

## 📅 Week 3: Testing, Documentation & Polish (Days 15-21)

### Day 15: Security Testing ✅
**Goal**: Test for common vulnerabilities

- [ ] **XSS Testing**:
  - Try injecting `<script>alert('XSS')</script>` in login form
  - Should be sanitized/escaped

- [ ] **CSRF Testing**:
  - Try login from different origin
  - Should fail (SameSite=strict)

- [ ] **Session Hijacking Testing**:
  - Copy session_token cookie to different browser
  - Should work (expected behavior - mitigate with IP tracking in future)

- [ ] **Password Enumeration Testing**:
  - Try login with valid username, wrong password
  - Try login with invalid username, any password
  - Error message should be same: "Invalid username or password"

- [ ] **Commit findings**:
  ```bash
  git add SECURITY-TEST-RESULTS.md
  git commit -m "test: document security testing results"
  ```

---

### Day 16: Multi-Browser Testing ✅
**Goal**: Ensure works in all major browsers

- [ ] **Chrome/Edge**: Test login, logout, session expiry
- [ ] **Firefox**: Test login, logout, session expiry
- [ ] **Safari**: Test login, logout, session expiry
- [ ] **Mobile Safari**: Test login, logout
- [ ] **Mobile Chrome**: Test login, logout

- [ ] **Document results**:
  ```bash
  git add BROWSER-COMPATIBILITY.md
  git commit -m "test: document browser compatibility testing"
  ```

---

### Day 17-18: Documentation ✅
**Goal**: Comprehensive user and admin docs

- [ ] **Create `docs/AUTHENTICATION-SETUP.md`**:
  - How to enable auth
  - How to generate password hash
  - How to set environment variables
  - How to restart container

- [ ] **Create `docs/AUTHENTICATION-USER-GUIDE.md`**:
  - How to login
  - How to logout
  - Session timeout behavior
  - What to do if you forget password

- [ ] **Create `docs/AUTHENTICATION-SECURITY.md`**:
  - Security best practices
  - Password recommendations
  - Session management
  - Rate limiting (future)

- [ ] **Update main README.md** with auth section

- [ ] **Commit**:
  ```bash
  git add docs/
  git commit -m "docs: add comprehensive authentication documentation"
  ```

---

### Day 19-20: Unraid Template Update ✅
**Goal**: Update Unraid template with auth variables

- [ ] **Update XML template** to include:
  ```xml
  <Config Name="AUTH_ENABLED" Target="AUTH_ENABLED" Default="false" Mode="" Description="Enable authentication" Type="Variable" Display="always" Required="false" Mask="false">false</Config>
  
  <Config Name="ADMIN_USERNAME" Target="ADMIN_USERNAME" Default="admin" Mode="" Description="Admin username" Type="Variable" Display="always" Required="false" Mask="false">admin</Config>
  
  <Config Name="ADMIN_PASSWORD_HASH" Target="ADMIN_PASSWORD_HASH" Default="" Mode="" Description="bcrypt hash of admin password (generate with: docker exec agent-inbox node -e 'const bcrypt = require(\"bcryptjs\"); console.log(bcrypt.hashSync(\"your-password\", 12));')" Type="Variable" Display="always" Required="false" Mask="true"></Config>
  ```

- [ ] **Update template description** with setup instructions

- [ ] **Test template installation** on clean Unraid system

- [ ] **Commit**:
  ```bash
  git add LAM.xml
  git commit -m "feat: add authentication variables to Unraid template"
  ```

---

### Day 21: Final Review & Deployment ✅
**Goal**: Final checks before marking Phase 4B complete

- [ ] **Code Review Checklist**:
  - [ ] All passwords hashed with bcrypt ≥12 rounds
  - [ ] All secrets in environment variables
  - [ ] No passwords/tokens logged
  - [ ] HTTP-only cookies used
  - [ ] SameSite=strict set
  - [ ] Secure flag in production
  - [ ] Generic error messages (no enumeration)
  - [ ] Session timeout working
  - [ ] All routes protected
  - [ ] Backward compatible (AUTH_ENABLED=false works)

- [ ] **Performance Testing**:
  - [ ] Login latency < 200ms
  - [ ] Auth check latency < 50ms
  - [ ] No memory leaks (session cleanup works)

- [ ] **Documentation Review**:
  - [ ] Setup guide complete
  - [ ] User guide complete
  - [ ] Security guide complete
  - [ ] API docs complete
  - [ ] README updated

- [ ] **Final Commit**:
  ```bash
  git add .
  git commit -m "feat(auth): Phase 4B complete - basic authentication ✅"
  git tag v1.4.0-auth
  git push origin main --tags
  ```

**Phase 4B Complete!** 🎉

---

## 📊 Progress Tracking

### Daily Standup Template
```markdown
## Day X: [Task Name]

**Today's Goal**: [What you're building]

**Completed**:
- [x] Task 1
- [x] Task 2

**In Progress**:
- [ ] Task 3

**Blocked**:
- [ ] None

**Tomorrow**:
- [ ] Task 4
- [ ] Task 5

**Notes**: [Any important observations or decisions]
```

---

## 🚨 Common Issues & Solutions

### Issue: bcrypt not found
```bash
npm install bcryptjs @types/bcryptjs
```

### Issue: Middleware not running
```bash
# Check middleware.ts is in src/app/ not src/
mv src/middleware.ts src/app/middleware.ts
```

### Issue: Session not persisting
```bash
# Check cookie settings
# Ensure secure: false in development
# Ensure sameSite: 'strict'
```

### Issue: Can't generate password hash
```bash
# Use Docker exec
docker exec agent-inbox node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('YourPassword123!', 12));"
```

---

## 🎯 Success Metrics (Track Daily)

| Metric | Target | Day 7 | Day 14 | Day 21 |
|--------|--------|-------|--------|--------|
| Login works | ✅ | [ ] | [ ] | [ ] |
| Wrong password rejected | ✅ | [ ] | [ ] | [ ] |
| Routes protected | ✅ | [ ] | [ ] | [ ] |
| Session persists | ✅ | [ ] | [ ] | [ ] |
| Session expires (30min) | ✅ | [ ] | [ ] | [ ] |
| No XSS vulnerabilities | ✅ | [ ] | [ ] | [ ] |
| No CSRF vulnerabilities | ✅ | [ ] | [ ] | [ ] |
| Works in all browsers | ✅ | [ ] | [ ] | [ ] |
| Documentation complete | ✅ | [ ] | [ ] | [ ] |

---

**Ready to start?** Begin with Day 1! 🚀

**Questions?** Refer to:
- Full plan: `PHASE-4B-AUTHENTICATION-IMPLEMENTATION-PLAN.md`
- Quick start: `PHASE-4B-QUICK-START.md`
- Architecture: `PHASE-4B-ARCHITECTURE-COMPARISON.md`
