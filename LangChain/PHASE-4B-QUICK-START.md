# Phase 4B: Authentication Quick Start Guide

## 🎯 TL;DR

**Goal**: Add basic password authentication to Agent Inbox (single admin user)  
**Duration**: 2-3 weeks  
**Pattern**: Reuse persistent storage patterns from Phases 1-3  

---

## 📋 What You're Building

### The 5 Core Components

```
1. Backend Service (lib/auth-service.ts)
   └─ Validates passwords, manages sessions
   
2. API Routes (/api/auth/*)
   └─ login, logout, me endpoints
   
3. Frontend Hook (hooks/use-auth.tsx)
   └─ React state management (like usePersistentConfig)
   
4. Login UI (app/login/page.tsx)
   └─ Username/password form
   
5. Route Protection (middleware.ts)
   └─ Guards all pages except /login
```

---

## 🔄 Pattern Mapping (Storage → Auth)

| Storage Implementation | Auth Equivalent |
|----------------------|----------------|
| `USE_SERVER_STORAGE` env | `AUTH_ENABLED` env |
| `/api/config` route | `/api/auth/*` routes |
| `usePersistentConfig` hook | `useAuth` hook |
| `config-storage.ts` service | `auth-service.ts` service |
| Simple JSON validation | bcrypt + session validation |

**Key Insight**: You already know the patterns! Just add security on top.

---

## 🚀 Implementation Order

### Week 1: Backend (7 days)
```
Day 1-2: password-hash.ts + session-manager.ts
         └─ bcrypt hashing + session CRUD

Day 3-4: API routes (login, logout, me)
         └─ Same pattern as /api/config

Day 5-6: Login UI page
         └─ Simple form (username + password)

Day 7:   useAuth hook
         └─ Like usePersistentConfig but for auth
```

### Week 2: Integration (7 days)
```
Day 8-9:   middleware.ts (protect routes)
           └─ Redirect to /login if no session

Day 10-11: Update layout.tsx (logout button)
           └─ Add auth provider wrapper

Day 12-13: Session management (timeout warnings)
           └─ Auto-logout after 30 minutes

Day 14:    Environment variables + docs
           └─ AUTH_ENABLED, ADMIN_USERNAME, etc.
```

### Week 3: Testing (7 days)
```
Day 15-16: Security testing (XSS, CSRF, session hijacking)
Day 17-18: Multi-browser testing
Day 19-20: Documentation (user guide, setup guide)
Day 21:    Final review + audit
```

---

## 🔒 Security Checklist

### Must-Have (Week 1)
- ✅ bcrypt with ≥12 rounds
- ✅ HTTP-only cookies
- ✅ Never log passwords
- ✅ Hash on server-side only

### Must-Have (Week 2)
- ✅ Protected routes (middleware)
- ✅ SameSite=strict cookies (CSRF protection)
- ✅ 30-minute session timeout
- ✅ Secure flag in production (HTTPS)

### Nice-to-Have (Phase 4C)
- ⏭️ Rate limiting (login attempts)
- ⏭️ Two-factor authentication
- ⏭️ Session management UI
- ⏭️ Change password feature

---

## 📁 Files You'll Create (9 files)

```
agent-inbox/
├── lib/
│   ├── auth-service.ts              ← Main auth logic
│   └── security/
│       ├── password-hash.ts         ← bcrypt wrapper
│       ├── session-manager.ts       ← Session CRUD
│       └── csrf.ts                  ← CSRF tokens (Week 2)
├── src/
│   ├── app/
│   │   ├── api/auth/
│   │   │   ├── login/route.ts       ← POST /api/auth/login
│   │   │   ├── logout/route.ts      ← POST /api/auth/logout
│   │   │   └── me/route.ts          ← GET /api/auth/me
│   │   ├── login/page.tsx           ← Login UI
│   │   └── middleware.ts            ← Route protection
│   └── hooks/
│       └── use-auth.tsx             ← Auth state hook
```

---

## 🔧 Environment Setup

### Step 1: Generate Password Hash
```bash
# In agent-inbox directory
npm install bcryptjs
node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('YourPassword123!', 12));"
```

### Step 2: Update .env.local
```bash
AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=$2a$12$... # Output from Step 1
SESSION_SECRET=$(openssl rand -hex 32)
SESSION_TIMEOUT=1800000  # 30 minutes

# Existing vars
USE_SERVER_STORAGE=true
```

### Step 3: Restart Container
```bash
docker restart agent-inbox
```

---

## 🎯 Success = Can Answer These

After Week 1:
- ✅ Can you login with correct password?
- ✅ Does wrong password return error?
- ✅ Is session created on login?

After Week 2:
- ✅ Are all pages protected except /login?
- ✅ Does logout work?
- ✅ Does session expire after 30 minutes?

After Week 3:
- ✅ Passed security testing (XSS, CSRF)?
- ✅ Works in all browsers?
- ✅ Documentation complete?

---

## 🚨 Key Differences from Storage

| What's Same | What's New |
|------------|-----------|
| Feature flag pattern | Password hashing (bcrypt) |
| API route structure | Session management (cookies) |
| React hook pattern | Route protection (middleware) |
| Backend service layer | Security validation (not just input) |
| Backward compatible | Login UI page |

**Important**: Storage validation checks "is this valid JSON?"  
Auth validation checks "is this secure? Can I trust this?"

---

## 💡 Implementation Tips

### 1. Start Simple
- Week 1: Just make login work (no fancy features)
- Week 2: Add protection & logout
- Week 3: Polish & test

### 2. Test As You Go
```bash
# After each day, test:
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"YourPassword123!"}'
```

### 3. Commit Often
```bash
git commit -m "feat(auth): add password hashing utility"
git commit -m "feat(auth): add session manager"
git commit -m "feat(auth): add login API endpoint"
```

### 4. Use Existing Code
Look at:
- `use-persistent-config.tsx` → Copy pattern for `use-auth.tsx`
- `/api/config/route.ts` → Copy structure for `/api/auth/login/route.ts`
- `config-storage.ts` → Copy pattern for `auth-service.ts`

---

## 🔄 Comparison with Setup UI Auth

### Agent Inbox (Your Implementation)
- **Architecture**: Next.js API routes + React hooks
- **Storage**: Enhanced config.json + in-memory sessions
- **Pattern**: Feature flag (AUTH_ENABLED)
- **Scope**: Protect entire app
- **Users**: Single admin (Phase 4B), multi-user later (Phase 6)

### Executive AI Assistant Setup UI (Reference)
- **Architecture**: FastAPI + Jinja templates
- **Storage**: OAuth tokens in /app/secrets
- **Pattern**: Always-on authentication (OAuth)
- **Scope**: Setup flow only (one-time)
- **Users**: Single user (OAuth account owner)

**Key Difference**: Agent Inbox is session-based (username/password),  
Setup UI is OAuth-based (Google authorization). Different use cases!

---

## ❓ Quick FAQ

**Q: Why not OAuth like Setup UI?**  
A: Setup UI needs Gmail access (OAuth required). Agent Inbox just needs protection (password sufficient).

**Q: Why single user first?**  
A: Simpler! Multi-user (Phase 6) adds complexity (user management UI, RBAC, etc.)

**Q: Why 30-minute timeout?**  
A: Balance between security and UX. Can be configured via `SESSION_TIMEOUT` env var.

**Q: What if I forget password?**  
A: Phase 4B: Regenerate hash and restart container  
    Phase 4C: Password reset feature (later)

**Q: Can I disable auth?**  
A: Yes! Set `AUTH_ENABLED=false` (backward compatible)

---

## 📚 Next Actions

1. ✅ Read full plan: `PHASE-4B-AUTHENTICATION-IMPLEMENTATION-PLAN.md`
2. ⏭️ Generate password hash (see Environment Setup)
3. ⏭️ Start Day 1: Create `password-hash.ts`
4. ⏭️ Commit after each file/feature
5. ⏭️ Test daily to catch issues early

---

## 🎓 Learning Outcomes

After Phase 4B, you'll understand:
- ✅ How to implement authentication in Next.js
- ✅ bcrypt password hashing best practices
- ✅ Session management with HTTP-only cookies
- ✅ CSRF protection via SameSite cookies
- ✅ Route protection with Next.js middleware
- ✅ Security testing for web apps

**This knowledge applies to ANY Next.js app!**

---

**Ready?** Open the full plan and let's start Day 1! 🚀
