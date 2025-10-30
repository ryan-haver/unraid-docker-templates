# LAM + Samba AD Validation & Prevention Plan

## Problem Analysis

### Why We Missed Critical Issues

1. **No Source Code Schema Validation**
   - Used "fixed" loginMethod that doesn't exist in LAM 9.3
   - Should have extracted valid values from LAMConfig constants
   - Never verified attr_user attributes exist in Samba AD schema

2. **Reactive Debugging Instead of Proactive Validation**
   - Discovered errors by trial and error in production
   - Should have validated config against source code BEFORE deployment
   - No automated checks for configuration correctness

3. **Incomplete Documentation Review**
   - Referenced LAM docs but didn't cross-check with actual source code
   - Assumed features existed without version-specific verification
   - Didn't validate Samba AD default schema attributes

4. **No Schema Cross-Reference**
   - attr_user specified attributes without checking Samba AD schema
   - Should have queried LDAP schema to confirm attribute availability
   - No validation that LAM expectations match Samba AD reality

## Comprehensive Prevention Strategy

### Phase 1: Documentation & Source Code Archive

#### 1.1 Download LAM Documentation
```bash
# Create documentation structure
mkdir -p docs/lam/{guides,api,modules,source}
mkdir -p docs/samba/{wiki,schema,examples}
mkdir -p docs/reference

# Download LAM official documentation
wget -r -np -k -P docs/lam/guides https://www.ldap-account-manager.org/lamcms/documentation
wget -P docs/lam/api https://www.ldap-account-manager.org/lamcms/releases/lam-9.3.tar.gz

# Extract LAM source for reference
cd docs/lam/source
tar -xzf ../api/lam-9.3.tar.gz
```

#### 1.2 Download Samba Documentation
```bash
# Samba AD DC documentation
wget -r -np -k -P docs/samba/wiki https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller
wget -r -np -k -P docs/samba/wiki https://wiki.samba.org/index.php/LDAP_Attributes
wget -r -np -k -P docs/samba/wiki https://wiki.samba.org/index.php/Samba_AD_DC_Port_Usage

# Download Samba source for schema definitions
git clone --depth 1 --branch v4.19.0 https://github.com/samba-team/samba.git docs/samba/source
```

#### 1.3 Extract Running Container Source Code
```bash
# Extract LAM source from running container
docker cp Samba-AD-LAM:/var/www/html/lam docs/lam/source/running-version

# Extract key schema files
docker exec Samba-AD-LAM find /usr/share/ldap-account-manager -name "*.schema" -o -name "*.ldif" \
  | xargs -I {} docker cp Samba-AD-LAM:{} docs/lam/schema/

# Extract Samba schema
docker exec Samba-AD bash -c "samba-tool schema objectclass list > /tmp/objectclasses.txt"
docker exec Samba-AD bash -c "samba-tool schema attribute list > /tmp/attributes.txt"
docker cp Samba-AD:/tmp/objectclasses.txt docs/samba/schema/
docker cp Samba-AD:/tmp/attributes.txt docs/samba/schema/
```

### Phase 2: Source Code Schema Extraction

#### 2.1 Extract LAM Configuration Schema
```python
#!/usr/bin/env python3
# scripts/extract_lam_schema.py

import re
import json
from pathlib import Path

def extract_lam_config_constants(lam_source_path):
    """Extract all configuration constants from LAM source code"""
    schema = {
        "loginMethods": [],
        "accessLevels": [],
        "configOptions": {},
        "typeSettings": {},
        "moduleSettings": {}
    }
    
    config_file = Path(lam_source_path) / "lib" / "config.inc"
    
    with open(config_file, 'r') as f:
        content = f.read()
        
        # Extract LOGIN constants
        login_methods = re.findall(r'const LOGIN_(\w+) = [\'"](\w+)[\'"]', content)
        schema["loginMethods"] = [method[1] for method in login_methods]
        
        # Extract ACCESS constants
        access_levels = re.findall(r'const ACCESS_(\w+) = (\d+)', content)
        schema["accessLevels"] = [int(level[1]) for level in access_levels]
        
        # Extract configuration options with types
        config_opts = re.findall(r'public \$(\w+)(?:\s*=\s*([^;]+))?;', content)
        for opt, default in config_opts:
            schema["configOptions"][opt] = {
                "default": default.strip() if default else None,
                "required": default is None
            }
    
    return schema

def extract_type_attributes(lam_source_path):
    """Extract valid attributes for each type (user, group, etc)"""
    types_file = Path(lam_source_path) / "lib" / "types.inc"
    attributes = {}
    
    with open(types_file, 'r') as f:
        content = f.read()
        
        # Find attribute definitions
        attr_defs = re.findall(r'function getAlias\(\)\s*{[^}]+return\s+[\'"]([^"\']+)["\']', content)
        # More extraction logic here
    
    return attributes

def main():
    lam_path = Path("docs/lam/source/running-version")
    schema = extract_lam_config_constants(lam_path)
    
    with open("docs/reference/lam-config-schema.json", 'w') as f:
        json.dump(schema, f, indent=2)
    
    print(f"✓ Extracted LAM schema: {len(schema['configOptions'])} config options")
    print(f"✓ Valid loginMethods: {schema['loginMethods']}")
    print(f"✓ Valid accessLevels: {schema['accessLevels']}")

if __name__ == "__main__":
    main()
```

#### 2.2 Extract Samba AD Schema Attributes
```python
#!/usr/bin/env python3
# scripts/extract_samba_schema.py

import json
import subprocess

def get_samba_attributes():
    """Query running Samba AD for all available attributes"""
    result = subprocess.run([
        "docker", "exec", "Samba-AD",
        "samba-tool", "schema", "attribute", "list"
    ], capture_output=True, text=True)
    
    attributes = [line.strip() for line in result.stdout.split('\n') if line.strip()]
    
    # Get details for each attribute
    attribute_details = {}
    for attr in attributes:
        result = subprocess.run([
            "docker", "exec", "Samba-AD",
            "samba-tool", "schema", "attribute", "show", attr
        ], capture_output=True, text=True)
        
        attribute_details[attr] = {
            "exists": True,
            "details": result.stdout
        }
    
    return attribute_details

def get_default_user_attributes():
    """Get attributes available on default Samba AD user objects"""
    result = subprocess.run([
        "docker", "exec", "Samba-AD",
        "ldapsearch", "-H", "ldaps://127.0.0.1:636",
        "-D", "CN=Administrator,CN=Users,DC=haver,DC=internal",
        "-w", "${DOMAINPASS}",
        "-b", "CN=Users,DC=haver,DC=internal",
        "-s", "one",
        "(objectClass=user)",
        "*"
    ], capture_output=True, text=True)
    
    # Parse LDIF output to extract available attributes
    attributes = set()
    for line in result.stdout.split('\n'):
        if ':' in line:
            attr = line.split(':')[0].strip()
            attributes.add(attr)
    
    return sorted(list(attributes))

def main():
    print("Extracting Samba AD schema...")
    
    all_attributes = get_samba_attributes()
    user_attributes = get_default_user_attributes()
    
    schema = {
        "all_attributes": list(all_attributes.keys()),
        "default_user_attributes": user_attributes,
        "attribute_details": all_attributes
    }
    
    with open("docs/reference/samba-schema.json", 'w') as f:
        json.dump(schema, f, indent=2)
    
    print(f"✓ Extracted {len(all_attributes)} Samba attributes")
    print(f"✓ Found {len(user_attributes)} default user attributes")

if __name__ == "__main__":
    main()
```

### Phase 3: Validation Scripts

#### 3.1 LAM Configuration Validator
```python
#!/usr/bin/env python3
# scripts/validate_lam_config.py

import json
import sys
from pathlib import Path

def load_schema(schema_file):
    """Load extracted LAM schema"""
    with open(schema_file, 'r') as f:
        return json.load(f)

def validate_config(config, schema):
    """Validate haver.conf against LAM schema"""
    errors = []
    warnings = []
    
    # Validate loginMethod
    if config.get("loginMethod") not in schema["loginMethods"]:
        errors.append(f"Invalid loginMethod '{config.get('loginMethod')}'. "
                     f"Valid values: {schema['loginMethods']}")
    
    # Validate accessLevel
    if config.get("accessLevel") not in schema["accessLevels"]:
        errors.append(f"Invalid accessLevel '{config.get('accessLevel')}'. "
                     f"Valid values: {schema['accessLevels']}")
    
    # Validate Admins format (should be string, not array)
    admins = config.get("Admins")
    if isinstance(admins, list):
        errors.append("Admins should be semicolon-separated string, not array")
    elif isinstance(admins, str) and ';' not in admins and ',' in admins:
        warnings.append("Admins appears to use comma separator; should be semicolon")
    
    # Validate typeSettings exists (not types/modules)
    if "types" in config or "modules" in config:
        errors.append("Config uses deprecated 'types'/'modules'; should use 'typeSettings'")
    
    if "typeSettings" not in config:
        errors.append("Missing required 'typeSettings' section")
    
    # Validate required config options
    for opt, details in schema["configOptions"].items():
        if details["required"] and opt not in config:
            errors.append(f"Missing required config option: {opt}")
    
    return errors, warnings

def validate_attributes(config, samba_schema):
    """Validate attr_user/attr_group against Samba schema"""
    errors = []
    warnings = []
    
    type_settings = config.get("typeSettings", {})
    
    # Validate user attributes
    attr_user = type_settings.get("attr_user", "")
    if attr_user:
        attributes = [a.lstrip('#') for a in attr_user.split(';') if a]
        available = samba_schema["default_user_attributes"]
        
        for attr in attributes:
            if attr not in available:
                errors.append(f"attr_user references unavailable attribute: {attr}")
                errors.append(f"  Available attributes: {', '.join(sorted(available))}")
    
    # Validate group attributes
    attr_group = type_settings.get("attr_group", "")
    if attr_group:
        attributes = [a.lstrip('#') for a in attr_group.split(';') if a]
        # Similar validation for group attributes
    
    return errors, warnings

def main():
    if len(sys.argv) < 2:
        print("Usage: validate_lam_config.py <haver.conf>")
        sys.exit(1)
    
    config_file = sys.argv[1]
    
    # Load schemas
    lam_schema = load_schema("docs/reference/lam-config-schema.json")
    samba_schema = load_schema("docs/reference/samba-schema.json")
    
    # Load config
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Validate
    config_errors, config_warnings = validate_config(config, lam_schema)
    attr_errors, attr_warnings = validate_attributes(config, samba_schema)
    
    errors = config_errors + attr_errors
    warnings = config_warnings + attr_warnings
    
    # Report results
    if errors:
        print(f"❌ VALIDATION FAILED: {len(errors)} errors")
        for error in errors:
            print(f"  ERROR: {error}")
    
    if warnings:
        print(f"⚠️  {len(warnings)} warnings")
        for warning in warnings:
            print(f"  WARNING: {warning}")
    
    if not errors and not warnings:
        print("✓ Configuration validated successfully")
    
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
```

#### 3.2 Pre-Deployment Validation Hook
```bash
#!/bin/bash
# scripts/pre_deploy_validation.sh

set -e

echo "=== LAM + Samba AD Pre-Deployment Validation ==="

# 1. Validate syntax
echo "1. Validating init.sh syntax..."
bash -n LAM_Samba-AD/init.sh || { echo "❌ Syntax error in init.sh"; exit 1; }

# 2. Validate LAM configuration
echo "2. Validating LAM configuration schema..."
python3 scripts/validate_lam_config.py appdata/lam/config/haver.conf || exit 1

# 3. Check Samba AD connectivity
echo "3. Testing Samba AD connectivity..."
docker exec Samba-AD ldapsearch -H ldaps://127.0.0.1:636 \
  -D "CN=Administrator,CN=Users,DC=haver,DC=internal" \
  -w "${DOMAINPASS}" \
  -b "DC=haver,DC=internal" \
  -s base || { echo "❌ Cannot connect to Samba AD"; exit 1; }

# 4. Validate attributes exist in schema
echo "4. Validating attributes against Samba schema..."
python3 scripts/validate_attributes.py || exit 1

# 5. Test LAM can parse config
echo "5. Testing LAM config parsing..."
docker exec Samba-AD-LAM php -r "
require_once '/var/www/html/lam/lib/config.inc';
\$config = new \LAMConfig('haver');
if (!\$config) { exit(1); }
echo 'Config loaded successfully\n';
" || { echo "❌ LAM cannot parse config"; exit 1; }

echo "✓ All pre-deployment validations passed"
```

### Phase 4: Automated Testing

#### 4.1 Integration Test Suite
```python
#!/usr/bin/env python3
# scripts/test_lam_integration.py

import requests
import subprocess
import time

def test_lam_initialization():
    """Test LAM starts and config is loaded"""
    response = requests.get("http://192.168.1.115:8080")
    assert response.status_code == 200
    assert "Login" in response.text

def test_lam_config_profile():
    """Test haver profile is available"""
    response = requests.get("http://192.168.1.115:8080")
    assert "haver" in response.text

def test_login_method_list():
    """Test LOGIN_LIST method shows dropdown"""
    response = requests.get("http://192.168.1.115:8080")
    assert '<select' in response.text
    assert 'Administrator' in response.text

def test_authentication():
    """Test can authenticate to Samba AD"""
    session = requests.Session()
    
    # Get login page
    response = session.get("http://192.168.1.115:8080/templates/login.php")
    
    # Extract CSRF token if present
    # Submit login
    data = {
        "config": "haver",
        "username": "CN=Administrator,CN=Users,DC=haver,DC=internal",
        "password": "${DOMAINPASS}"
    }
    response = session.post("http://192.168.1.115:8080/templates/login.php", data=data)
    
    # Should redirect to list page without error
    assert response.status_code == 200 or response.status_code == 302
    assert "Invalid credentials" not in response.text

def test_user_list_renders():
    """Test user list page renders without error"""
    # Authenticate first
    session = authenticate()
    
    # Request user list
    response = session.get("http://192.168.1.115:8080/templates/lists/list.php?type=user")
    
    # Should not have PHP errors
    assert "Fatal error" not in response.text
    assert "TypeError" not in response.text
    assert response.status_code == 200

def test_attributes_display():
    """Test configured attributes display in list"""
    session = authenticate()
    response = session.get("http://192.168.1.115:8080/templates/lists/list.php?type=user")
    
    # Check expected attribute columns
    assert "sAMAccountName" in response.text
    assert "givenName" in response.text
    assert "sn" in response.text
    assert "mail" in response.text

def main():
    tests = [
        test_lam_initialization,
        test_lam_config_profile,
        test_login_method_list,
        test_authentication,
        test_user_list_renders,
        test_attributes_display
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            test()
            print(f"✓ {test.__name__}")
            passed += 1
        except Exception as e:
            print(f"❌ {test.__name__}: {e}")
            failed += 1
    
    print(f"\n{passed} passed, {failed} failed")
    return failed == 0

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
```

#### 4.2 Pre-Commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running pre-commit validations..."

# Run validation scripts
./scripts/pre_deploy_validation.sh || {
    echo "❌ Validation failed. Commit aborted."
    echo "Fix errors and try again."
    exit 1
}

# Run integration tests if containers are running
if docker ps | grep -q "Samba-AD-LAM"; then
    echo "Running integration tests..."
    python3 scripts/test_lam_integration.py || {
        echo "⚠️  Integration tests failed"
        echo "Continue with commit? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    }
fi

echo "✓ Pre-commit validations passed"
```

### Phase 5: Documentation Cross-Reference

#### 5.1 Create Reference Matrix
```markdown
# LAM Configuration Reference Matrix

| Config Option | LAM Source | LAM Docs | Samba Docs | Validated |
|--------------|------------|----------|------------|-----------|
| loginMethod  | lib/config.inc:121 | [link] | N/A | ✓ |
| Admins       | lib/config.inc:89  | [link] | N/A | ✓ |
| attr_user    | lib/types.inc:245  | [link] | [schema] | ✓ |
| typeSettings | lib/config.inc:456 | [link] | N/A | ✓ |

## Login Methods

### Valid Values (LAM 9.3)
- `list` - Show dropdown of admin DNs (from LAMConfig::LOGIN_LIST)
- `search` - Search LDAP for users (from LAMConfig::LOGIN_SEARCH)

### Invalid Values
- ❌ `fixed` - Does NOT exist in LAM 9.3 (no LOGIN_FIXED constant)

## User Attributes (attr_user)

### Format
Semicolon-separated string with optional `#` prefix for display columns:
```
#sAMAccountName;#givenName;#sn;#mail
```

### Validated Samba AD Default Attributes
✓ sAMAccountName
✓ givenName (or firstName)
✓ sn (surname)
✓ mail
✓ description
✓ telephoneNumber
✓ memberOf (multi-valued)

### Attributes That May Not Exist
❌ employeeNumber (not in default schema)
❌ department (not in default schema)
❌ title (not in default schema)

**Validation Required**: Always check `samba-tool schema attribute show <attr>` before using
```

### Phase 6: Implementation Checklist

#### Before Every Configuration Change

- [ ] Extract current LAM source schema to reference/
- [ ] Extract current Samba schema to reference/
- [ ] Validate proposed config against schemas
- [ ] Check LAM docs for version-specific changes
- [ ] Cross-reference with Samba AD documentation
- [ ] Run pre-deployment validation script
- [ ] Review LAM source code for config option usage
- [ ] Test in isolated environment first

#### Before Every Deployment

- [ ] Run `scripts/pre_deploy_validation.sh`
- [ ] Run `scripts/validate_lam_config.py haver.conf`
- [ ] Run `scripts/validate_attributes.py`
- [ ] Check LAM error logs are being captured
- [ ] Verify LDAP connectivity test passes
- [ ] Run integration test suite
- [ ] Review recent LAM/Samba changelog

#### After Every Deployment

- [ ] Monitor `/var/log/nginx/lam-error.log` for 5 minutes
- [ ] Test authentication flow end-to-end
- [ ] Verify user/group list pages render
- [ ] Check all configured attributes display
- [ ] Run post-deployment integration tests
- [ ] Document any new issues in VALIDATION.md

### Phase 7: Maintenance Schedule

#### Weekly
- Review LAM and Samba-AD container logs
- Check for new LAM/Samba releases
- Update local documentation copies

#### Monthly
- Re-extract LAM source schema (in case of updates)
- Re-extract Samba schema (in case of extensions)
- Review and update validation scripts
- Run full integration test suite

#### Per Release
- Download new LAM/Samba documentation
- Extract new source code schemas
- Update validation scripts for new features
- Review changelog for breaking changes
- Update reference matrix

## Expected Outcomes

### Issues This Would Have Prevented

1. **"fixed" loginMethod Error**
   - Schema extraction would show only "list" and "search" exist
   - Validation script would reject "fixed" immediately
   - Pre-commit hook would prevent bad commit

2. **attr_user TypeError**
   - Samba schema validator would flag missing attributes
   - Pre-deployment test would catch null return error
   - Integration test would detect user list render failure

3. **Admins Array vs String**
   - LAM source schema would document string format
   - Validation script would reject array type
   - Pre-deployment test would catch parse error

### Success Metrics

- Zero production authentication failures
- 100% config validation before deployment
- All attributes validated against schema
- Integration tests pass before every commit
- Documentation always current with source code

## Implementation Priority

### Phase 1 (Immediate - This Week)
1. Download LAM and Samba documentation
2. Extract source code schemas
3. Create validation scripts
4. Add pre-commit hooks

### Phase 2 (Next Week)
1. Build integration test suite
2. Create reference matrix
3. Document all config options
4. Set up automated testing

### Phase 3 (Ongoing)
1. Maintain documentation updates
2. Monitor for new releases
3. Expand test coverage
4. Refine validation rules

## Tools Required

- Python 3.8+ (for validation scripts)
- jq (for JSON parsing)
- wget/curl (for documentation download)
- git hooks (for pre-commit validation)
- pytest (for test framework)
- requests (for integration testing)

## Conclusion

This plan ensures:
- **Proactive validation** instead of reactive debugging
- **Source code as source of truth** over documentation
- **Automated checking** at every stage
- **Comprehensive documentation** locally available
- **No more "going in circles"** with trial-and-error

Every configuration option will be validated against actual source code before deployment. Every attribute will be confirmed to exist in Samba schema. Every change will be tested automatically.

**No more surprises.**
