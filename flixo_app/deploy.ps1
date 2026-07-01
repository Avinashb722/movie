# MovieNest Deployment & Release Automation Script
# Run this script using: .\deploy.ps1

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     MOVIENEST RELEASE AUTOMATOR         " -ForegroundColor Cyan
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

# 3. Update web/version.json
$webVersionPath = "web/version.json"
if (Test-Path $webVersionPath) {
    $content = Get-Content $webVersionPath -Raw
    $updatedContent = $content -replace '"latest_version":\s*"[^"]*"', "`"latest_version`": `"$newVersion`""
    Set-Content $webVersionPath $updatedContent
    Write-Host "✓ Updated web/version.json" -ForegroundColor Green
}

# 4. Update public/version.json
$publicVersionPath = "public/version.json"
if (Test-Path $publicVersionPath) {
    $content = Get-Content $publicVersionPath -Raw
    $updatedContent = $content -replace '"latest_version":\s*"[^"]*"', "`"latest_version`": `"$newVersion`""
    Set-Content $publicVersionPath $updatedContent
    Write-Host "✓ Updated public/version.json" -ForegroundColor Green
}

# 5. Optional Android Build
Write-Host ""
$buildApk = Read-Host "Do you want to compile the Android APK? (y/n)"
if ($buildApk -eq 'y' -or $buildApk -eq 'yes') {
    Write-Host "`nCompiling Android APK (Release)..." -ForegroundColor Yellow
    flutter build apk --release --target-platform=android-arm64
    
    $apkSource = "build/app/outputs/flutter-apk/app-release.apk"
    $apkDestination = "public/downloads/movienest.apk"
    
    if (Test-Path $apkSource) {
        # Create downloads folder in public if missing
        if (!(Test-Path "public/downloads")) {
            New-Item -ItemType Directory -Path "public/downloads" -Force | Out-Null
        }
        Copy-Item -Path $apkSource -Destination $apkDestination -Force
        Write-Host "✓ Copied new APK to public/downloads/movienest.apk" -ForegroundColor Green
    } else {
        Write-Host "✗ APK compilation failed or output not found!" -ForegroundColor Red
    }
}

# 6. Optional Web Build & Vercel Deploy
Write-Host ""
$deployWeb = Read-Host "Do you want to compile Web and Deploy to Vercel? (y/n)"
if ($deployWeb -eq 'y' -or $deployWeb -eq 'yes') {
    Write-Host "`nCompiling Flutter Web..." -ForegroundColor Yellow
    flutter build web --release
    
    Write-Host "`nSyncing compiled files to public folder..." -ForegroundColor Yellow
    Copy-Item -Path build/web/* -Destination public/ -Recurse -Force
    
    # Force ensure the updated version.json is copied over
    Copy-Item -Path web/version.json -Destination public/version.json -Force
    
    Write-Host "`nDeploying to Vercel Production..." -ForegroundColor Yellow
    vercel --prod
    
    Write-Host "`n✓ Deploy Completed Successfully!" -ForegroundColor Green
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "          RELEASE PROCESS DONE           " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
