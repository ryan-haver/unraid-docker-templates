#!/usr/bin/env pwsh
# Quick setup script for validation system

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "LAM + Samba AD Validation System Setup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker is running
Write-Host "[1/5] Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker is available: $dockerVersion" -ForegroundColor Green
        $dockerAvailable = $true
    } else {
        throw "Docker not found"
    }
} catch {
    Write-Host "⚠️  Docker is not available in this environment" -ForegroundColor Yellow
    Write-Host "   This is OK if you're editing templates locally" -ForegroundColor Cyan
    Write-Host "   Run this script on Unraid server where containers are running" -ForegroundColor Cyan
    $dockerAvailable = $false
}

# Check containers
Write-Host ""
Write-Host "[2/5] Checking containers..." -ForegroundColor Yellow
if ($dockerAvailable) {
    try {
        $sambaAD = docker ps --filter "name=Samba-AD" --format "{{.Names}}" 2>$null
        $lamAD = docker ps --filter "name=Samba-AD-LAM" --format "{{.Names}}" 2>$null
    } catch {
        $sambaAD = $null
        $lamAD = $null
    }
} else {
    $sambaAD = $null
    $lamAD = $null
}

if (-not $sambaAD) {
    Write-Host "⚠️  Samba-AD container not running" -ForegroundColor Yellow
} else {
    Write-Host "✓ Samba-AD container running" -ForegroundColor Green
}

if (-not $lamAD) {
    Write-Host "⚠️  Samba-AD-LAM container not running" -ForegroundColor Yellow
} else {
    Write-Host "✓ Samba-AD-LAM container running" -ForegroundColor Green
}

# Extract LAM source
Write-Host ""
Write-Host "[3/5] Extracting LAM source code..." -ForegroundColor Yellow
if ($dockerAvailable -and $lamAD) {
    $lamSourceDir = "LAM_Samba-AD\docs\lam\source"
    if (-not (Test-Path $lamSourceDir)) {
        New-Item -ItemType Directory -Path $lamSourceDir -Force | Out-Null
    }
    
    try {
        docker cp Samba-AD-LAM:/var/www/html/lam/. $lamSourceDir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ LAM source extracted to $lamSourceDir" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to extract LAM source" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Failed to extract LAM source: $_" -ForegroundColor Red
    }
} else {
    if (-not $dockerAvailable) {
        Write-Host "⚠️  Skipping (Docker not available)" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Skipping (LAM container not running)" -ForegroundColor Yellow
    }
}

# Run schema extraction
Write-Host ""
Write-Host "[4/5] Extracting schemas..." -ForegroundColor Yellow

if ($dockerAvailable -and $lamAD) {
    Write-Host "  Extracting LAM schema..." -ForegroundColor Cyan
    try {
        python LAM_Samba-AD\scripts\extract_lam_schema.py 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ LAM schema extracted" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  LAM schema extraction had issues" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  LAM schema extraction failed: $_" -ForegroundColor Yellow
    }
} else {
    if (-not $dockerAvailable) {
        Write-Host "  ⚠️  Skipping LAM schema (Docker not available)" -ForegroundColor Yellow
    } else {
        Write-Host "  ⚠️  Skipping LAM schema (container not running)" -ForegroundColor Yellow
    }
}

if ($dockerAvailable -and $sambaAD) {
    Write-Host "  Extracting Samba schema..." -ForegroundColor Cyan
    try {
        python LAM_Samba-AD\scripts\extract_samba_schema.py 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Samba schema extracted" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Samba schema extraction had issues" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  Samba schema extraction failed: $_" -ForegroundColor Yellow
    }
} else {
    if (-not $dockerAvailable) {
        Write-Host "  ⚠️  Skipping Samba schema (Docker not available)" -ForegroundColor Yellow
    } else {
        Write-Host "  ⚠️  Skipping Samba schema (container not running)" -ForegroundColor Yellow
    }
}

# Test validation
Write-Host ""
Write-Host "[5/5] Testing validation system..." -ForegroundColor Yellow

# Check if haver.conf exists
$haverConf = "appdata\lam\config\haver.conf"
if (Test-Path $haverConf) {
    Write-Host "  Running validation on $haverConf..." -ForegroundColor Cyan
    python LAM_Samba-AD\scripts\validate_lam_config.py $haverConf
    $validationResult = $LASTEXITCODE
    if ($validationResult -eq 0) {
        Write-Host "  ✓ Validation passed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Validation found issues (see above)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ℹ️  No haver.conf found at $haverConf" -ForegroundColor Cyan
    Write-Host "  Deploy container to generate config file" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

if ($dockerAvailable) {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Review generated schemas in LAM_Samba-AD\docs\reference\" -ForegroundColor White
    Write-Host "2. Run validation before deployment:" -ForegroundColor White
    Write-Host "   python LAM_Samba-AD\scripts\validate_lam_config.py appdata\lam\config\haver.conf" -ForegroundColor Gray
    Write-Host "3. Review validation plan: LAM_Samba-AD\VALIDATION-PLAN.md" -ForegroundColor White
} else {
    Write-Host "Docker not available in this environment" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To use validation system:" -ForegroundColor White
    Write-Host "1. Copy these scripts to your Unraid server:" -ForegroundColor White
    Write-Host "   - LAM_Samba-AD/scripts/" -ForegroundColor Gray
    Write-Host "2. SSH to Unraid and run:" -ForegroundColor White
    Write-Host "   bash LAM_Samba-AD/scripts/setup_validation.sh" -ForegroundColor Gray
    Write-Host "3. Validate configs before deployment:" -ForegroundColor White
    Write-Host "   python3 LAM_Samba-AD/scripts/validate_lam_config.py <haver.conf>" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Validation scripts are committed and ready to use on server" -ForegroundColor Green
}
Write-Host ""
Write-Host "For full documentation download, see VALIDATION-PLAN.md Phase 1" -ForegroundColor Yellow
Write-Host ""
