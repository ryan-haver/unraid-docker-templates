# Dependency Management

## Executive AI Assistant - Package Dependencies

**Last Updated**: October 30, 2025  
**Python Version**: 3.12  
**Environment**: Development (Editable Install)

---

## Critical Dependency Constraints

### Version Compatibility Matrix

| Package | Version | Constraint | Reason |
|---------|---------|------------|--------|
| `langgraph-api` | 0.2.120 | `>=0.2.120, <0.4.0` | Must satisfy langgraph-cli[inmem] upper bound |
| `langchain-core` | 0.3.79 | `>=0.3.78, <1.0.0` | Must be compatible with langchain 0.3.27 |
| `langchain-text-splitters` | 0.3.11 | `>=0.3.9, <1.0.0` | Must be compatible with langchain 0.3.27 |
| `langchain` | 0.3.27 | Fixed | Core framework version |
| `langgraph` | 0.4.10 | `^0.4.10` | Workflow orchestration |

### Known Conflicts

#### 1. langgraph-api Yanked Versions
**Versions to AVOID**: 0.2.134, 0.2.135, 0.2.137

**Reason**: These versions were yanked from PyPI (removed due to issues)

**Solution**: Use 0.2.120 or compatible version within range

#### 2. langgraph-cli[inmem] Upper Bound
**Conflict**: langgraph-cli[inmem] requires `langgraph-api<0.4.0`

**Impact**: Cannot use langgraph-api 0.4.x or higher

**Solution**: Use version in range `>=0.2.120, <0.4.0`

#### 3. langchain-core 1.0+ Breaking Changes
**Conflict**: langchain 0.3.27 not compatible with langchain-core 1.0+

**Impact**: langchain-community pulls in langchain-core 1.0.2 by default

**Solution**: Explicitly downgrade to `<1.0.0` after installing langchain-community

---

## Core Dependencies

### LangChain Ecosystem

```toml
[tool.poetry.dependencies]
langchain = "^0.3.27"              # Core framework
langchain-openai = "^0.2.14"       # OpenAI integration
langchain-anthropic = "^0.3.22"    # Anthropic integration
```

**Additional (installed separately):**
- `langchain-community` 0.4.1 - Community integrations (Ollama)
- `langchain-core` 0.3.79 - Shared abstractions
- `langchain-classic` 1.0.0 - Classic components
- `langchain-text-splitters` 0.3.11 - Text chunking
- `langsmith` 0.3.45 - Observability

### LangGraph Workflow

```toml
[tool.poetry.dependencies]
langgraph = "^0.4.10"              # State machine framework
langgraph-api = "^0.2.120"         # API server (MODIFIED from 0.2.134)
langgraph-cli = { version = "^0.3.8", extras = ["inmem"] }  # CLI tools
```

### Google API Integration

```toml
[tool.poetry.dependencies]
google-api-python-client = "^2.185.0"  # Google APIs
google-auth = "^2.42.1"                # Authentication
google-auth-oauthlib = "^1.2.1"        # OAuth flow
cryptography = "^44.0.3"               # Cryptographic operations
```

**Additional (via dependencies):**
- `google-auth-httplib2` 0.2.0 - HTTP transport
- `google-api-core` - Core Google API functionality

---

## Complete Package List

### Tier 1: Core Frameworks (9 packages)

```
langchain                    0.3.27        ✅ LangChain core framework
langchain-anthropic          0.3.22        ✅ Anthropic Claude integration
langchain-classic            1.0.0         ✅ Classic LangChain components
langchain-community          0.4.1         ✅ Community integrations (Ollama)
langchain-core               0.3.79        ✅ Shared abstractions
langchain-openai             0.2.14        ✅ OpenAI GPT integration
langchain-text-splitters     0.3.11        ✅ Text chunking utilities
langgraph                    0.4.10        ✅ State machine workflow
langsmith                    0.3.45        ✅ LangSmith observability
```

### Tier 2: LangGraph Infrastructure (2 packages)

```
langgraph-api                0.2.125       ✅ LangGraph API server
langgraph-cli                0.3.8         ✅ LangGraph CLI tools
```

### Tier 3: Google APIs (5 packages)

```
google-api-core              2.30.1        ✅ Google API core
google-api-python-client     2.185.0       ✅ Google APIs client
google-auth                  2.42.1        ✅ Google authentication
google-auth-httplib2         0.2.0         ✅ Google auth HTTP
google-auth-oauthlib         1.2.1         ✅ Google OAuth flow
```

### Tier 4: Web Framework (10+ packages)

```
uvicorn                      0.38.0        ✅ ASGI server
starlette                    0.49.1        ✅ Web framework
httpx                        0.28.1        ✅ Async HTTP client
httpx-sse                    0.4.3         ✅ Server-Sent Events
aiohttp                      3.13.2        ✅ Async HTTP framework
requests                     2.32.5        ✅ Sync HTTP client
urllib3                      2.5.0         ✅ HTTP library
httpcore                     1.0.9         ✅ HTTP core primitives
h11                          0.16.0        ✅ HTTP/1.1 protocol
websockets                   (via deps)    ✅ WebSocket support
```

### Tier 5: Data Handling (15+ packages)

```
pydantic                     2.12.3        ✅ Data validation
pydantic-core                2.41.4        ✅ Pydantic core (Rust)
pydantic-settings            2.11.0        ✅ Settings management
SQLAlchemy                   2.0.44        ✅ Database ORM
orjson                       3.11.4        ✅ Fast JSON parsing
PyYAML                       6.0.3         ✅ YAML parsing
jsonpatch                    1.33          ✅ JSON patching
jsonpointer                  3.0.0         ✅ JSON pointer
dataclasses-json             0.6.7         ✅ Dataclass JSON serialization
marshmallow                  3.26.1        ✅ Object serialization
numpy                        2.3.4         ✅ Numerical computing
pandas                       (optional)    ⚪ Data manipulation
```

### Tier 6: Utilities (20+ packages)

```
cryptography                 44.0.3        ✅ Cryptographic operations
python-dotenv                1.2.1         ✅ Environment variables
tenacity                     9.1.2         ✅ Retrying logic
zstandard                    0.23.0        ✅ Compression
click                        8.1.8         ✅ CLI framework
rich                         (via deps)    ✅ Terminal formatting
tqdm                         (via deps)    ✅ Progress bars
typing-extensions            4.15.0        ✅ Type hints
annotated-types              0.7.0         ✅ Type annotations
greenlet                     3.2.4         ✅ Lightweight concurrency
```

### Tier 7: Supporting Libraries (30+ packages)

```
aiohappyeyeballs             2.6.1         ✅ DNS resolution
aiosignal                    1.4.0         ✅ Async signals
attrs                        25.4.0        ✅ Classes without boilerplate
certifi                      2025.10.5     ✅ SSL certificates
charset-normalizer           3.4.4         ✅ Character encoding
frozenlist                   1.8.0         ✅ Frozen list data structure
idna                         3.11          ✅ Internationalized domain names
multidict                    6.7.0         ✅ Multi-valued dictionaries
mypy-extensions              1.1.0         ✅ Mypy extensions
propcache                    0.4.1         ✅ Property caching
requests-toolbelt            1.0.0         ✅ Requests utilities
sniffio                      1.3.1         ✅ Async library detection
typing-inspect               0.9.0         ✅ Runtime type inspection
typing-inspection            0.4.2         ✅ Type inspection utilities
yarl                         1.22.0        ✅ URL parsing
```

**Total**: 100+ packages installed

---

## Installation Order

### Critical Order Dependencies

The order of installation matters due to dependency resolution:

1. **Install main package** (`pip install -e .`)
   - Installs all core dependencies from pyproject.toml
   - May fail if langgraph-api version is yanked
   - Creates base environment

2. **Fix langgraph-api** (if needed)
   - Edit `pyproject.toml`: Change line 31 to `"^0.2.120"`
   - Reinstall: `pip install -e .`

3. **Install langchain-community**
   - `pip install langchain-community`
   - ⚠️ May pull in incompatible versions of langchain-core

4. **Fix version conflicts**
   - `pip install "langchain-core<1.0.0,>=0.3.78"`
   - `pip install "langchain-text-splitters<1.0.0,>=0.3.9"`
   - Downgrades to compatible versions

### Why Order Matters

```
Step 1: Base Install
├── Installs langchain 0.3.27
├── Requires langchain-core <1.0.0
└── Creates consistent base state

Step 2: Add Community
├── Pulls langchain-community 0.4.1
├── Brings langchain-core 1.0.2 (CONFLICT!)
└── Breaks compatibility with langchain 0.3.27

Step 3: Fix Conflicts
├── Downgrades langchain-core to 0.3.79
├── Satisfies all package requirements
└── Achieves stable state
```

---

## Dependency Graph

### High-Level Dependencies

```
Executive AI Assistant (eaia)
│
├── LangChain Ecosystem
│   ├── langchain (core framework)
│   ├── langchain-core (shared abstractions)
│   ├── langchain-community (Ollama integration)
│   ├── langchain-openai (GPT integration)
│   ├── langchain-anthropic (Claude integration)
│   └── langsmith (observability)
│
├── LangGraph (workflow orchestration)
│   ├── langgraph (state machines)
│   ├── langgraph-api (API server)
│   └── langgraph-cli[inmem] (CLI tools)
│
├── Google APIs (email/calendar)
│   ├── google-api-python-client
│   ├── google-auth
│   └── google-auth-oauthlib
│
├── Web Framework (API server)
│   ├── uvicorn (ASGI server)
│   ├── starlette (web framework)
│   ├── httpx (HTTP client)
│   └── aiohttp (async HTTP)
│
└── Utilities
    ├── pydantic (data validation)
    ├── cryptography (security)
    ├── python-dotenv (env vars)
    └── tenacity (retrying)
```

### Critical Dependency Chains

#### Chain 1: LangChain Core Compatibility

```
langchain 0.3.27
└── requires langchain-core <1.0.0, >=0.3.72
    ├── langchain-anthropic 0.3.22
    │   └── requires langchain-core <1.0.0, >=0.3.78  ← Most restrictive lower bound
    ├── langchain-openai 0.2.14
    │   └── requires langchain-core <0.4.0, >=0.3.27
    └── langchain-community 0.4.1
        └── pulls langchain-core 1.0.2 by default  ← CONFLICT!

RESOLUTION: Install langchain-core >=0.3.78, <1.0.0
```

#### Chain 2: LangGraph API Constraints

```
langgraph-cli[inmem] 0.3.8
└── requires langgraph-api <0.4.0, >=0.2.120
    ├── Original pyproject.toml: "^0.2.134"  ← Yanked version!
    └── Modified pyproject.toml: "^0.2.120"  ← Compatible version

RESOLUTION: Use langgraph-api ^0.2.120
```

---

## Future Dependency Updates

### Update Strategy

When updating dependencies:

1. **Check for yanked versions** on PyPI before updating
2. **Review constraint chains** (use `pip show <package>` to see requirements)
3. **Test in order**: Update pyproject.toml → Install main → Add extras → Fix conflicts
4. **Document changes** in this file

### Known Update Paths

#### Path 1: Upgrade LangChain to 0.4.x (Future)

**Blockers:**
- langchain-openai requires langchain-core <0.4.0
- langchain-anthropic requires langchain-core <1.0.0

**Prerequisites:**
- Wait for langchain-openai 0.3.x with langchain-core 1.0 support
- Wait for langchain-anthropic 1.0.x with langchain-core 1.0 support

**Impact**: HIGH - Core framework change

#### Path 2: Upgrade LangGraph API to 0.4.x (Future)

**Blocker:**
- langgraph-cli[inmem] requires langgraph-api <0.4.0

**Prerequisites:**
- Wait for langgraph-cli 0.4.x that supports langgraph-api >=0.4.0

**Impact**: MEDIUM - API server change

#### Path 3: Add Additional LLM Providers

**Required Packages:**
- `langchain-google-genai` - Google Gemini
- `langchain-mistralai` - Mistral AI
- `langchain-cohere` - Cohere

**Impact**: LOW - Additive changes only

**Installation:**
```bash
pip install langchain-google-genai langchain-mistralai langchain-cohere
```

---

## Testing Dependencies

### Test Requirements (Future)

```toml
[tool.poetry.group.test.dependencies]
pytest = "^8.0.0"
pytest-asyncio = "^0.24.0"
pytest-cov = "^6.0.0"
pytest-mock = "^3.14.0"
httpx-mock = "^0.11.0"
```

### Development Tools (Future)

```toml
[tool.poetry.group.dev.dependencies]
black = "^25.0.0"           # Code formatting
ruff = "^0.10.0"            # Linting
mypy = "^1.15.0"            # Type checking
pre-commit = "^4.0.0"       # Git hooks
```

---

## Docker Dependencies

### Base Image

```dockerfile
FROM python:3.12-slim
```

**Included packages:**
- Python 3.12.x
- pip 25.x
- Basic system libraries

### Additional System Dependencies

```dockerfile
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

### Python Dependencies in Docker

Same as development environment, installed via:

```dockerfile
COPY pyproject.toml poetry.lock* ./
RUN pip install --no-cache-dir poetry && \
    poetry config virtualenvs.create false && \
    poetry install --no-dev --no-interaction --no-ansi
```

---

## Maintenance Log

### 2025-10-30: Initial Setup
- ✅ Created dependency tracking system
- ✅ Documented all 100+ packages
- ✅ Identified critical constraints
- ✅ Resolved 3 major conflicts
- ✅ Established update procedures

**Issues Resolved:**
1. langgraph-api yanked versions (0.2.134 → 0.2.120)
2. langgraph-cli[inmem] upper bound conflict
3. langchain-core 1.0 compatibility issues

**Current State:** STABLE ✅

---

## Quick Reference

### Check Installed Versions

```powershell
# All langchain/langgraph packages
pip list | Select-String "langchain|langgraph"

# Specific package details
pip show langchain-core

# Dependency tree
pip show -f langchain-core | Select-String "Requires"
```

### Reinstall from Scratch

```powershell
# Remove environment
Remove-Item -Recurse -Force .\venv

# Create fresh environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install (follow order in DEVELOPMENT-SETUP.md)
pip install --upgrade pip
# ... (see installation steps)
```

### Verify Environment

```powershell
# Import test
python -c "from langchain_openai import ChatOpenAI; from langchain_anthropic import ChatAnthropic; from langchain_community.llms import Ollama; print('✅ OK')"

# Version check
python -c "import langchain, langgraph; print(f'LangChain {langchain.__version__}, LangGraph {langgraph.__version__}')"
```

---

**Maintained by**: Ryan Haver  
**Last Updated**: October 30, 2025  
**Status**: ✅ Stable and Verified
