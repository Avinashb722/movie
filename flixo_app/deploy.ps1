# MovieNest Deployment & Release Automation Script
# Run this script using: .\deploy.ps1

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     MOVIENEST ALL-IN-ONE RELEASE        " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Ask for the new version number
$newVersion = Read-Host "Enter the new version number (e.g., 1.1.0)"
if ($newVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "Error: Version must follow the format 'X.Y.Z' (e.g., 1.1.0)" -ForegroundColor Red
    Exit
}

Write-Host "`nUpdating local configurations to version $newVersion..." -ForegroundColor Yellow

# 2. Update pubspec.yaml
$pubspecPath = "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $content = Get-Content $pubspecPath -Raw
    # Replaces 'version: X.Y.Z+W' with 'version: newVersion+1'
    $updatedContent = $content -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion+1"
    Set-Content $pubspecPath $updatedContent
    Write-Host "✓ Updated pubspec.yaml" -ForegroundColor Green
} else {
    Write-Host "✗ Could not find pubspec.yaml!" -ForegroundColor Red
}

# Helper to update JSON configs
function Update-VersionJson($path, $ver) {
    if (Test-Path $path) {
        $json = Get-Content $path | ConvertFrom-Json
        $json.latest_version = $ver
        $json | ConvertTo-Json | Set-Content $path
        Write-Host "✓ Updated $path" -ForegroundColor Green
    }
}

# 3. Update web/version.json & public/version.json
Update-VersionJson "web/version.json" $newVersion
Update-VersionJson "public/version.json" $newVersion

# 4. Build Android APK
Write-Host "`n[1/3] Compiling Android APK (Release)..." -ForegroundColor Yellow
flutter build apk --release --target-platform=android-arm64

$apkSource = "build/app/outputs/flutter-apk/app-release.apk"
if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination "web/downloads/movienest.apk" -Force
    Copy-Item -Path $apkSource -Destination "public/downloads/movienest.apk" -Force
    Write-Host "✓ Android APK compiled and copied successfully!" -ForegroundColor Green
} else {
    Write-Host "✗ Android build failed!" -ForegroundColor Red
    Exit
}

# 5. Build Windows App
Write-Host "`n[2/3] Compiling Windows App (Release)..." -ForegroundColor Yellow
flutter build windows --release

$winSourceDir = "build/windows/x64/runner/Release"
$winDestDir = "build/windows/x64/runner/movienest-windows"

if (Test-Path $winSourceDir) {
    # Copy files
    Copy-Item -Path "$winSourceDir/*" -Destination $winDestDir -Recurse -Force
    
    # Rename executable
    $oldExe = "$winDestDir/movienest.exe"
    $newExe = "$winDestDir/flixo_app.exe"
    if (Test-Path $oldExe) {
        Remove-Item -Path $oldExe -Force
    }
    if (Test-Path $newExe) {
        Rename-Item -Path $newExe -NewName "movienest.exe" -Force
    }
    Write-Host "✓ Windows files compiled and prepared in movienest-windows!" -ForegroundColor Green
} else {
    Write-Host "✗ Windows build failed!" -ForegroundColor Red
    Exit
}

# 6. Prompt to run Inno Setup
Write-Host "`n=========================================" -ForegroundColor Yellow
Write-Host "ACTION REQUIRED: Open Inno Setup and compile 'movienest.iss' now." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

$innoComplete = ""
while ($innoComplete -ne "y" -and $innoComplete -ne "yes") {
    $innoComplete = Read-Host "Has the Inno Setup compilation completed successfully? (y/n)"
    $innoComplete = $innoComplete.ToLower().Trim()
    if ($innoComplete -eq "n" -or $innoComplete -eq "no") {
        Write-Host "Please compile the installer first before proceeding." -ForegroundColor Red
    }
}

# 7. Copy Installer & Deploy to Vercel
$setupPath = "web/downloads/movienest-setup.exe"
$setupDest = "public/downloads/movienest-setup.exe"

if (Test-Path $setupPath) {
    Copy-Item -Path $setupPath -Destination $setupDest -Force
    Write-Host "✓ Copied Windows Setup Installer to public folder." -ForegroundColor Green
} else {
    Write-Host "✗ Could not find compiled setup installer at $setupPath!" -ForegroundColor Red
    Exit
}

Write-Host "`n[3/3] Deploying live to Vercel Production..." -ForegroundColor Yellow
vercel --prod

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "  SUCCESS: RELEASE VERSION $newVersion IS LIVE!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
