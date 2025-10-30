#!/usr/bin/env python3
"""
Extract Samba AD schema attributes from running container
This creates a reference of all available LDAP attributes
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set

def run_docker_command(container: str, command: List[str]) -> str:
    """Execute command in Docker container and return output"""
    full_cmd = ["docker", "exec", container] + command
    result = subprocess.run(full_cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ Command failed: {' '.join(full_cmd)}", file=sys.stderr)
        print(f"   Error: {result.stderr}", file=sys.stderr)
        return ""
    
    return result.stdout

def get_samba_attributes(container: str = "Samba-AD") -> List[str]:
    """Query running Samba AD for all available attributes"""
    print("Querying Samba AD for attribute list...")
    output = run_docker_command(container, [
        "samba-tool", "schema", "attribute", "list"
    ])
    
    if not output:
        print("⚠️  Failed to get attribute list from Samba", file=sys.stderr)
        return []
    
    attributes = [line.strip() for line in output.split('\n') if line.strip()]
    return sorted(attributes)

def get_default_user_attributes(container: str = "Samba-AD", domain_pass: str = "") -> Set[str]:
    """Get attributes available on default Samba AD user objects"""
    print("Querying actual user objects for available attributes...")
    
    if not domain_pass:
        print("⚠️  No domain password provided, using placeholder", file=sys.stderr)
        domain_pass = "PLACEHOLDER"
    
    output = run_docker_command(container, [
        "ldapsearch", "-LLL",
        "-H", "ldaps://127.0.0.1:636",
        "-D", "CN=Administrator,CN=Users,DC=haver,DC=internal",
        "-w", domain_pass,
        "-b", "CN=Users,DC=haver,DC=internal",
        "-s", "one",
        "(&(objectClass=user)(!(objectClass=computer)))",
        "*"
    ])
    
    if not output:
        return set()
    
    # Parse LDIF output to extract available attributes
    attributes = set()
    for line in output.split('\n'):
        if ':' in line and not line.startswith('#'):
            attr = line.split(':', 1)[0].strip()
            if attr and not attr.startswith('dn'):
                attributes.add(attr)
    
    return attributes

def get_common_user_attributes() -> Dict[str, Dict[str, str]]:
    """Return list of common AD user attributes with descriptions"""
    return {
        "sAMAccountName": {
            "description": "User logon name (required)",
            "required": True,
            "multi_valued": False
        },
        "cn": {
            "description": "Common name",
            "required": True,
            "multi_valued": False
        },
        "givenName": {
            "description": "First name",
            "required": False,
            "multi_valued": False
        },
        "sn": {
            "description": "Surname/Last name",
            "required": False,
            "multi_valued": False
        },
        "displayName": {
            "description": "Display name",
            "required": False,
            "multi_valued": False
        },
        "mail": {
            "description": "Email address",
            "required": False,
            "multi_valued": False
        },
        "description": {
            "description": "User description",
            "required": False,
            "multi_valued": False
        },
        "telephoneNumber": {
            "description": "Phone number",
            "required": False,
            "multi_valued": False
        },
        "memberOf": {
            "description": "Group memberships",
            "required": False,
            "multi_valued": True
        },
        "userPrincipalName": {
            "description": "User principal name (UPN)",
            "required": False,
            "multi_valued": False
        },
        "employeeNumber": {
            "description": "Employee number (may not exist in default schema)",
            "required": False,
            "multi_valued": False,
            "warning": "Not in default Samba AD schema"
        },
        "department": {
            "description": "Department name (may not exist in default schema)",
            "required": False,
            "multi_valued": False,
            "warning": "Not in default Samba AD schema"
        },
        "title": {
            "description": "Job title (may not exist in default schema)",
            "required": False,
            "multi_valued": False,
            "warning": "Not in default Samba AD schema"
        }
    }

def main():
    container = "Samba-AD"
    
    # Check if container is running
    result = subprocess.run(
        ["docker", "ps", "--filter", f"name={container}", "--format", "{{.Names}}"],
        capture_output=True,
        text=True
    )
    
    if container not in result.stdout:
        print(f"❌ Container '{container}' is not running", file=sys.stderr)
        print("   Start the container and try again", file=sys.stderr)
        sys.exit(1)
    
    print(f"Extracting Samba AD schema from container '{container}'...")
    
    # Get all attributes
    all_attributes = get_samba_attributes(container)
    
    # Get attributes from actual user objects (requires password)
    user_attributes = get_default_user_attributes(container)
    
    # Get common attribute definitions
    common_attrs = get_common_user_attributes()
    
    # Build schema
    schema = {
        "version": "4.x",
        "all_attributes": all_attributes,
        "default_user_attributes": sorted(list(user_attributes)) if user_attributes else [],
        "common_user_attributes": common_attrs,
        "safe_attr_user": [
            "sAMAccountName",
            "cn",
            "givenName",
            "sn",
            "displayName",
            "mail",
            "description"
        ],
        "safe_attr_group": [
            "sAMAccountName",
            "cn",
            "description",
            "member"
        ],
        "warnings": {
            "employeeNumber": "Not in default Samba AD schema, may cause errors",
            "department": "Not in default Samba AD schema, may cause errors",
            "title": "Not in default Samba AD schema, may cause errors"
        }
    }
    
    # Save schema
    output_file = Path("docs/reference/samba-schema.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(schema, f, indent=2)
    
    # Print summary
    print(f"\n✓ Extracted Samba schema to {output_file}")
    print(f"  • Total attributes: {len(all_attributes)}")
    if user_attributes:
        print(f"  • User object attributes: {len(user_attributes)}")
    print(f"  • Safe attr_user attributes: {', '.join(schema['safe_attr_user'])}")
    print(f"  • Attributes with warnings: {len(schema['warnings'])}")
    
    if not user_attributes:
        print("\n⚠️  Note: Could not query actual user objects (needs domain password)")
        print("   Run with domain password for complete attribute list")

if __name__ == "__main__":
    main()
