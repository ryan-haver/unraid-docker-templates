# LAM + Samba AD Validation System

This directory contains scripts and documentation for validating LAM configuration against actual source code and Samba AD schemas.

## Quick Start

1. **Setup validation system** (one-time):
   ```powershell
   .\LAM_Samba-AD\scripts\setup_validation.ps1
   ```

2. **Validate configuration before deployment**:
   ```powershell
   python LAM_Samba-AD\scripts\validate_lam_config.py appdata\lam\config\haver.conf
   ```

3. **If validation fails**, fix errors before rebuilding container

## What This Prevents

### Issues Caught Automatically

✅ **Invalid loginMethod** (e.g., "fixed" doesn't exist in LAM 9.3)
```
❌ Invalid loginMethod: 'fixed'
   Valid values: list, search
   Source: LAM source code lib/config.inc
```

✅ **Missing Samba AD attributes** (e.g., employeeNumber not in default schema)
```
❌ attr_user uses problematic attribute: employeeNumber
   Not in default Samba AD schema, may cause errors
   This will cause TypeError in LAM ListAttribute::getAlias()
```

✅ **Wrong data types** (e.g., Admins as array instead of string)
```
❌ Admins must be semicolon-separated STRING, not array
   Current: list
   Example: 'CN=Administrator,CN=Users,DC=haver,DC=internal'
```

✅ **Deprecated config structure** (e.g., types/modules instead of typeSettings)
```
❌ Config uses deprecated 'types'/'modules' structure
   Should use 'typeSettings' instead
   LAM 9.x uses: typeSettings.suffix_user, typeSettings.attr_user, etc.
```

## Directory Structure

```
LAM_Samba-AD/
├── scripts/
│   ├── extract_lam_schema.py      # Extract LAM config schema from source
│   ├── extract_samba_schema.py    # Extract Samba AD attribute schema
│   ├── validate_lam_config.py     # Validate haver.conf against schemas
│   └── setup_validation.ps1       # Quick setup script
├── docs/
│   ├── lam/
│   │   └── source/                # LAM source code (extracted from container)
│   ├── samba/
│   │   └── schema/                # Samba schema files
│   └── reference/
│       ├── lam-config-schema.json # Extracted LAM schema
│       └── samba-schema.json      # Extracted Samba schema
└── VALIDATION-PLAN.md             # Comprehensive prevention plan
```

## Scripts

### 1. `extract_lam_schema.py`

Extracts configuration schema from LAM source code.

**What it extracts**:
- Valid loginMethod values (LOGIN_LIST, LOGIN_SEARCH constants)
- Valid accessLevel values
- All configuration options and their types
- Type-specific settings

**Output**: `docs/reference/lam-config-schema.json`

**Usage**:
```powershell
python LAM_Samba-AD\scripts\extract_lam_schema.py
```

**Example output**:
```json
{
  "loginMethods": ["list", "search"],
  "accessLevels": [0, 100, 200],
  "configOptions": {
    "ServerURL": {"default": null, "required": true},
    "Admins": {"default": null, "required": true}
  }
}
```

### 2. `extract_samba_schema.py`

Extracts attribute schema from running Samba AD container.

**What it extracts**:
- All available LDAP attributes
- Attributes on actual user objects
- Safe attributes for attr_user/attr_group
- Known problematic attributes

**Output**: `docs/reference/samba-schema.json`

**Usage**:
```powershell
python LAM_Samba-AD\scripts\extract_samba_schema.py
```

**Example output**:
```json
{
  "safe_attr_user": [
    "sAMAccountName",
    "givenName",
    "sn",
    "mail"
  ],
  "warnings": {
    "employeeNumber": "Not in default Samba AD schema, may cause errors",
    "department": "Not in default Samba AD schema, may cause errors"
  }
}
```

### 3. `validate_lam_config.py`

Validates haver.conf against extracted schemas.

**What it checks**:
- loginMethod is valid
- accessLevel is valid
- Admins format is correct (string not array)
- Config structure uses typeSettings (not types/modules)
- attr_user attributes exist in Samba schema
- moduleSettings values are arrays

**Usage**:
```powershell
python LAM_Samba-AD\scripts\validate_lam_config.py appdata\lam\config\haver.conf
```

**Exit codes**:
- `0` = Validation passed (warnings OK)
- `1` = Validation failed (errors found)

### 4. `setup_validation.ps1`

One-time setup script that:
1. Checks Docker is running
2. Checks containers are running
3. Extracts LAM source code
4. Runs schema extraction
5. Tests validation on existing config

**Usage**:
```powershell
.\LAM_Samba-AD\scripts\setup_validation.ps1
```

## Workflow

### Before Every Deployment

1. **Extract schemas** (if not already done):
   ```powershell
   python LAM_Samba-AD\scripts\extract_lam_schema.py
   python LAM_Samba-AD\scripts\extract_samba_schema.py
   ```

2. **Generate config** (from init.sh):
   ```powershell
   # Your normal deployment process that generates haver.conf
   ```

3. **Validate config**:
   ```powershell
   python LAM_Samba-AD\scripts\validate_lam_config.py appdata\lam\config\haver.conf
   ```

4. **If validation passes**, deploy:
   ```powershell
   docker restart Samba-AD-LAM
   ```

5. **If validation fails**, fix errors in init.sh and retry

### After LAM Version Update

1. **Re-extract LAM schema**:
   ```powershell
   # Remove old source
   Remove-Item LAM_Samba-AD\docs\lam\source -Recurse -Force
   
   # Re-extract
   python LAM_Samba-AD\scripts\extract_lam_schema.py
   ```

2. **Review changes**:
   ```powershell
   git diff docs/reference/lam-config-schema.json
   ```

3. **Update init.sh** if schema changed

## Reference Files

### `lam-config-schema.json`

Contains all valid configuration values extracted from LAM source code.

**Key sections**:
- `loginMethods`: Valid values for loginMethod config option
- `accessLevels`: Valid values for accessLevel config option
- `configOptions`: All available config options with types
- `typeSettings`: Valid type-specific settings

**Example usage**:
```python
schema = json.load(open('docs/reference/lam-config-schema.json'))
valid_login_methods = schema['loginMethods']  # ['list', 'search']
```

### `samba-schema.json`

Contains Samba AD attribute information.

**Key sections**:
- `safe_attr_user`: Attributes guaranteed to exist in default schema
- `safe_attr_group`: Safe group attributes
- `warnings`: Attributes known to cause issues
- `common_user_attributes`: Common AD attributes with descriptions

**Example usage**:
```python
schema = json.load(open('docs/reference/samba-schema.json'))
safe_attrs = schema['safe_attr_user']  # Use these in attr_user
```

## Common Issues and Solutions

### Issue: "loginMethod 'fixed' invalid"
**Cause**: LAM 9.3 doesn't have a "fixed" login method
**Solution**: Use "list" or "search" instead

### Issue: "attr_user attribute causing TypeError"
**Cause**: Attribute doesn't exist in Samba AD schema
**Solution**: Use only attributes from `samba-schema.json` `safe_attr_user`

### Issue: "Admins must be string, not array"
**Cause**: Admins field formatted as JSON array
**Solution**: Use semicolon-separated string: `"CN=Admin,DC=...;CN=Admin2,DC=..."`

### Issue: "typeSettings section missing"
**Cause**: Using old LAM config structure (types/modules)
**Solution**: Use typeSettings structure in init.sh

## Integration with Git

### Pre-Commit Hook (Future)

Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
echo "Validating LAM configuration..."
python LAM_Samba-AD/scripts/validate_lam_config.py appdata/lam/config/haver.conf
if [ $? -ne 0 ]; then
    echo "❌ Validation failed. Fix errors and try again."
    exit 1
fi
```

## Troubleshooting

### Schemas not found
**Problem**: `Schema file not found: docs/reference/lam-config-schema.json`
**Solution**: Run `setup_validation.ps1` or extract scripts manually

### Container not running
**Problem**: `Container 'Samba-AD-LAM' is not running`
**Solution**: Start container first: `docker start Samba-AD-LAM`

### Python not found
**Problem**: `'python' is not recognized`
**Solution**: Install Python 3.8+ or use `python3` command

### LAM source extraction fails
**Problem**: `Failed to extract LAM source`
**Solution**: Check container name is correct: `docker ps --filter name=LAM`

## Next Steps

See `VALIDATION-PLAN.md` for:
- Complete documentation download strategy
- Comprehensive test suite plan
- Automated testing integration
- Long-term maintenance schedule

## Benefits

✅ **Catch errors before deployment** - No more trial and error in production
✅ **Source code as truth** - Validate against actual LAM code, not docs
✅ **Schema validation** - Ensure attributes exist before LAM tries to use them
✅ **Fast feedback** - Know immediately if config is invalid
✅ **No more circles** - Stop repeating same failed attempts

## Status

**Phase 1 Complete** ✅
- [x] Validation scripts created
- [x] Schema extraction working
- [x] Config validation working
- [x] Quick setup script

**Phase 2 Planned** ⏳
- [ ] Integration test suite
- [ ] Pre-commit hooks
- [ ] Automated testing
- [ ] Documentation download

See TODO list in VALIDATION-PLAN.md for full roadmap.
