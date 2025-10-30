#!/usr/bin/env python3
"""
Validate LAM configuration against extracted schemas
This prevents configuration errors before deployment
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple

def load_schema(schema_file: str) -> Dict:
    """Load extracted schema JSON"""
    path = Path(schema_file)
    if not path.exists():
        print(f"❌ Schema file not found: {schema_file}", file=sys.stderr)
        print(f"   Run extract scripts first to generate schemas", file=sys.stderr)
        return {}
    
    with open(path, 'r') as f:
        return json.load(f)

def validate_login_config(config: Dict, lam_schema: Dict) -> Tuple[List[str], List[str]]:
    """Validate login-related configuration"""
    errors = []
    warnings = []
    
    # Validate loginMethod
    login_method = config.get("loginMethod")
    valid_methods = lam_schema.get("loginMethods", [])
    
    if not valid_methods:
        warnings.append("LAM schema has no login methods defined - schema may be incomplete")
    elif login_method not in valid_methods:
        errors.append(
            f"❌ Invalid loginMethod: '{login_method}'\n"
            f"   Valid values: {', '.join(valid_methods)}\n"
            f"   Source: LAM source code lib/config.inc"
        )
    
    # Validate accessLevel
    access_level = config.get("accessLevel")
    valid_levels = lam_schema.get("accessLevels", [])
    
    if valid_levels and access_level not in valid_levels:
        errors.append(
            f"❌ Invalid accessLevel: {access_level}\n"
            f"   Valid values: {', '.join(map(str, valid_levels))}"
        )
    
    # Validate Admins format
    admins = config.get("Admins")
    if isinstance(admins, list):
        errors.append(
            f"❌ Admins must be semicolon-separated STRING, not array\n"
            f"   Current: {type(admins).__name__}\n"
            f"   Example: 'CN=Administrator,CN=Users,DC=haver,DC=internal'"
        )
    elif isinstance(admins, str):
        if ';' not in admins and ',' in admins:
            warnings.append(
                f"⚠️  Admins uses comma separators; should be semicolon\n"
                f"   Multiple admins: use ';' not ','"
            )
        # Validate DN format
        if admins and not admins.startswith("CN="):
            warnings.append(
                f"⚠️  Admins DN should start with 'CN='\n"
                f"   Current: {admins[:50]}"
            )
    
    return errors, warnings

def validate_structure(config: Dict) -> Tuple[List[str], List[str]]:
    """Validate overall config structure"""
    errors = []
    warnings = []
    
    # Check for deprecated structure
    if "types" in config or "modules" in config:
        errors.append(
            f"❌ Config uses deprecated 'types'/'modules' structure\n"
            f"   Should use 'typeSettings' instead\n"
            f"   LAM 9.x uses: typeSettings.suffix_user, typeSettings.attr_user, etc."
        )
    
    # Check for required sections
    if "typeSettings" not in config:
        errors.append(
            f"❌ Missing required 'typeSettings' section\n"
            f"   Required for LAM 9.x configuration"
        )
    
    # Check serverURL format
    server_url = config.get("ServerURL")
    if server_url:
        if not server_url.startswith("ldaps://"):
            warnings.append(
                f"⚠️  ServerURL should use ldaps:// for security\n"
                f"   Current: {server_url}"
            )
    
    return errors, warnings

def validate_attributes(config: Dict, samba_schema: Dict) -> Tuple[List[str], List[str]]:
    """Validate attr_user/attr_group against Samba schema"""
    errors = []
    warnings = []
    
    type_settings = config.get("typeSettings", {})
    safe_attrs = samba_schema.get("safe_attr_user", [])
    schema_warnings = samba_schema.get("warnings", {})
    
    # Validate user attributes
    attr_user = type_settings.get("attr_user", "")
    if attr_user:
        attributes = [a.lstrip('#') for a in attr_user.split(';') if a]
        
        for attr in attributes:
            # Check if attribute is in safe list
            if safe_attrs and attr not in safe_attrs:
                if attr in schema_warnings:
                    errors.append(
                        f"❌ attr_user uses problematic attribute: {attr}\n"
                        f"   {schema_warnings[attr]}\n"
                        f"   This will cause TypeError in LAM ListAttribute::getAlias()"
                    )
                else:
                    warnings.append(
                        f"⚠️  attr_user uses non-standard attribute: {attr}\n"
                        f"   Safe attributes: {', '.join(safe_attrs)}\n"
                        f"   Verify this exists in your Samba AD schema"
                    )
    else:
        warnings.append("⚠️  No attr_user configured - user list will be empty")
    
    # Validate group attributes
    attr_group = type_settings.get("attr_group", "")
    if attr_group:
        safe_group_attrs = samba_schema.get("safe_attr_group", [])
        attributes = [a.lstrip('#') for a in attr_group.split(';') if a]
        
        for attr in attributes:
            if safe_group_attrs and attr not in safe_group_attrs:
                warnings.append(
                    f"⚠️  attr_group uses non-standard attribute: {attr}\n"
                    f"   Safe attributes: {', '.join(safe_group_attrs)}"
                )
    
    return errors, warnings

def validate_module_settings(config: Dict) -> Tuple[List[str], List[str]]:
    """Validate moduleSettings format"""
    errors = []
    warnings = []
    
    module_settings = config.get("moduleSettings", {})
    if not module_settings:
        return errors, warnings
    
    # Check that values are arrays
    for key, value in module_settings.items():
        if not isinstance(value, list):
            errors.append(
                f"❌ moduleSettings['{key}'] must be array\n"
                f"   Current type: {type(value).__name__}\n"
                f"   Example: 'windowsUser_0': ['value1', 'value2']"
            )
    
    return errors, warnings

def main():
    if len(sys.argv) < 2:
        print("Usage: validate_lam_config.py <haver.conf>")
        print("\nValidates LAM configuration against extracted schemas")
        print("Run extract_lam_schema.py and extract_samba_schema.py first")
        sys.exit(1)
    
    config_file = sys.argv[1]
    
    # Load schemas
    print("Loading schemas...")
    lam_schema = load_schema("docs/reference/lam-config-schema.json")
    samba_schema = load_schema("docs/reference/samba-schema.json")
    
    if not lam_schema and not samba_schema:
        print("\n❌ No schemas found. Run extraction scripts first:")
        print("   python3 scripts/extract_lam_schema.py")
        print("   python3 scripts/extract_samba_schema.py")
        sys.exit(1)
    
    # Load config
    print(f"Loading config: {config_file}")
    config_path = Path(config_file)
    if not config_path.exists():
        print(f"❌ Config file not found: {config_file}")
        sys.exit(1)
    
    with open(config_path, 'r') as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON in config file: {e}")
            sys.exit(1)
    
    print(f"\n{'='*70}")
    print(f"Validating LAM Configuration")
    print(f"{'='*70}\n")
    
    # Run validations
    all_errors = []
    all_warnings = []
    
    if lam_schema:
        print("Checking login configuration...")
        errors, warnings = validate_login_config(config, lam_schema)
        all_errors.extend(errors)
        all_warnings.extend(warnings)
    
    print("Checking config structure...")
    errors, warnings = validate_structure(config)
    all_errors.extend(errors)
    all_warnings.extend(warnings)
    
    if samba_schema:
        print("Checking attributes against Samba schema...")
        errors, warnings = validate_attributes(config, samba_schema)
        all_errors.extend(errors)
        all_warnings.extend(warnings)
    
    print("Checking module settings...")
    errors, warnings = validate_module_settings(config)
    all_errors.extend(errors)
    all_warnings.extend(warnings)
    
    # Report results
    print(f"\n{'='*70}")
    print("Validation Results")
    print(f"{'='*70}\n")
    
    if all_errors:
        print(f"❌ VALIDATION FAILED: {len(all_errors)} error(s)\n")
        for i, error in enumerate(all_errors, 1):
            print(f"{i}. {error}\n")
    
    if all_warnings:
        print(f"⚠️  {len(all_warnings)} warning(s)\n")
        for i, warning in enumerate(all_warnings, 1):
            print(f"{i}. {warning}\n")
    
    if not all_errors and not all_warnings:
        print("✅ Configuration validated successfully!")
        print("   All checks passed")
    
    print(f"{'='*70}\n")
    
    # Exit with error code if validation failed
    sys.exit(1 if all_errors else 0)

if __name__ == "__main__":
    main()
