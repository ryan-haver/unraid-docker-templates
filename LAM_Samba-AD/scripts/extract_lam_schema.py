#!/usr/bin/env python3
"""
Extract LAM configuration schema from source code
This creates a JSON schema of all valid configuration options
"""

import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Any

def extract_lam_config_constants(lam_source_path: Path) -> Dict[str, Any]:
    """Extract all configuration constants from LAM source code"""
    schema = {
        "version": "9.3",
        "loginMethods": [],
        "accessLevels": [],
        "configOptions": {},
        "typeSettings": {},
        "validationRules": {}
    }
    
    config_file = lam_source_path / "lib" / "config.inc"
    
    if not config_file.exists():
        print(f"❌ Config file not found: {config_file}", file=sys.stderr)
        print("   Run: docker cp Samba-AD-LAM:/var/www/html/lam {lam_source_path}", file=sys.stderr)
        return schema
    
    with open(config_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        # Extract LOGIN constants
        login_methods = re.findall(r'const\s+LOGIN_(\w+)\s*=\s*[\'"](\w+)[\'"]', content)
        schema["loginMethods"] = [method[1] for method in login_methods]
        
        # Extract ACCESS constants  
        access_levels = re.findall(r'const\s+ACCESS_(\w+)\s*=\s*(\d+)', content)
        schema["accessLevels"] = [int(level[1]) for level in access_levels]
        
        # Extract public properties (configuration options)
        # Match: public $propertyName = defaultValue;
        config_opts = re.findall(r'public\s+\$(\w+)(?:\s*=\s*([^;]+))?;', content)
        for opt, default in config_opts:
            default_val = default.strip() if default else None
            schema["configOptions"][opt] = {
                "default": default_val,
                "required": default is None or 'null' in str(default).lower()
            }
        
        # Extract validation methods
        validation_methods = re.findall(r'function\s+validate_(\w+)\s*\([^)]*\)', content)
        schema["validationRules"] = {method: True for method in validation_methods}
    
    return schema

def extract_type_attributes(lam_source_path: Path) -> Dict[str, List[str]]:
    """Extract valid attributes for each type (user, group, etc)"""
    types_file = lam_source_path / "lib" / "types.inc"
    attributes = {
        "user": [],
        "group": [],
        "computer": []
    }
    
    if not types_file.exists():
        print(f"⚠️  Types file not found: {types_file}", file=sys.stderr)
        return attributes
    
    with open(types_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        # Find attribute handling code
        # This is complex and version-specific, so we do basic extraction
        attr_patterns = re.findall(r'[\'"]([a-zA-Z]+Name|mail|description|memberOf)[\'"]', content)
        common_attrs = list(set(attr_patterns))
        
        # Common attributes for all types
        for type_name in attributes.keys():
            attributes[type_name] = common_attrs
    
    return attributes

def main():
    # Check if LAM source exists
    lam_source_path = Path("docs/lam/source")
    
    if not lam_source_path.exists():
        print("LAM source not found. Extracting from container...")
        import subprocess
        lam_source_path.mkdir(parents=True, exist_ok=True)
        result = subprocess.run([
            "docker", "cp", 
            "Samba-AD-LAM:/var/www/html/lam/.",
            str(lam_source_path)
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ Failed to extract LAM source: {result.stderr}")
            sys.exit(1)
    
    print("Extracting LAM schema from source code...")
    schema = extract_lam_config_constants(lam_source_path)
    
    print("Extracting type attributes...")
    attributes = extract_type_attributes(lam_source_path)
    schema["typeAttributes"] = attributes
    
    # Save schema
    output_file = Path("docs/reference/lam-config-schema.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(schema, f, indent=2)
    
    # Print summary
    print(f"\n✓ Extracted LAM schema to {output_file}")
    print(f"  • Config options: {len(schema['configOptions'])}")
    print(f"  • Login methods: {', '.join(schema['loginMethods']) if schema['loginMethods'] else 'None found'}")
    print(f"  • Access levels: {', '.join(map(str, schema['accessLevels'])) if schema['accessLevels'] else 'None found'}")
    print(f"  • Type attributes: {', '.join(attributes.keys())}")
    
    if not schema['loginMethods']:
        print("\n⚠️  Warning: No login methods found. Check LAM source extraction.")

if __name__ == "__main__":
    main()
