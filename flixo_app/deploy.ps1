# MovieNest Deployment & Release Automation Script
# Run this script using: .\deploy.ps1

function Confirm-Step($message) {
    $answer = Read-Host "$message (y/n)"
    $answer = $answer.ToLower().Trim()
    return ($answer -eq "y" -or $answer -eq "yes")
}

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
    $updatedContent = $content -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion+1"
    Set-Content $pubspecPath $updatedContent
    Write-Host "Updated pubspec.yaml" -ForegroundColor Green
} else {
    Write-Host "Could not find pubspec.yaml!" -ForegroundColor Red
}

# Helper to update JSON configs
function Update-VersionJson($path, $ver) {
    if (Test-Path $path) {
        $json = Get-Content $path | ConvertFrom-Json
        $json.latest_version = $ver
        $json | ConvertTo-Json | Set-Content $path
        Write-Host "Updated $path" -ForegroundColor Green
    }
}

# 3. Update version.json files
Update-VersionJson "web/version.json" $newVersion
Update-VersionJson "public/version.json" $newVersion

# 4. Build Flutter Web
Write-Host "`n-----------------------------------------" -ForegroundColor DarkCyan
Write-Host " [1/4] Flutter Web Build" -ForegroundColor DarkCyan
Write-Host "-----------------------------------------" -ForegroundColor DarkCyan
if (Confirm-Step "Do you want to build Flutter Web?") {
    flutter build web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Flutter Web build failed!" -ForegroundColor Red
        Exit
    }
    Copy-Item -Path "build\web\*" -Destination "public\" -Recurse -Force
    Copy-Item -Path "web\privacy-policy.html" -Destination "public\privacy-policy.html" -Force
    Copy-Item -Path "web\terms-of-service.html" -Destination "public\terms-of-service.html" -Force
    Write-Host "Flutter Web compiled and copied to public/" -ForegroundColor Green
} else {
    Write-Host "Skipped Flutter Web build." -ForegroundColor DarkGray
}

# 5. Build Android APK
Write-Host "`n-----------------------------------------" -ForegroundColor DarkCyan
Write-Host " [2/4] Android APK Build" -ForegroundColor DarkCyan
Write-Host "-----------------------------------------" -ForegroundColor DarkCyan
if (Confirm-Step "Do you want to build the Android APK?") {
    flutter build apk --release --target-platform=android-arm64
    $apkSource = "build/app/outputs/flutter-apk/app-release.apk"
    if (Test-Path $apkSource) {
        Copy-Item -Path $apkSource -Destination "web/downloads/movienest.apk" -Force
        Copy-Item -Path $apkSource -Destination "public/downloads/movienest.apk" -Force
        Write-Host "Android APK compiled and copied successfully!" -ForegroundColor Green
    } else {
        Write-Host "Android build failed!" -ForegroundColor Red
        Exit
    }
} else {
    Write-Host "Skipped Android APK build." -ForegroundColor DarkGray
}

# 5.1. Build Android TV APK
Write-Host "`n-----------------------------------------" -ForegroundColor DarkCyan
Write-Host " [2.1/4] Android TV APK Build" -ForegroundColor DarkCyan
Write-Host "-----------------------------------------" -ForegroundColor DarkCyan
if (Confirm-Step "Do you want to build the Android TV APK?") {
    flutter build apk --release --target-platform=android-arm
    $apkSource = "build/app/outputs/flutter-apk/app-release.apk"
    if (Test-Path $apkSource) {
        Copy-Item -Path $apkSource -Destination "web/downloads/movienest-tv.apk" -Force
        Copy-Item -Path $apkSource -Destination "public/downloads/movienest-tv.apk" -Force
        Write-Host "Android TV APK compiled and copied successfully!" -ForegroundColor Green
    } else {
        Write-Host "Android TV build failed!" -ForegroundColor Red
        Exit
    }
} else {
    Write-Host "Skipped Android TV APK build." -ForegroundColor DarkGray
}


# 6. Build Windows App
Write-Host "`n-----------------------------------------" -ForegroundColor DarkCyan
Write-Host " [3/4] Windows App Build" -ForegroundColor DarkCyan
Write-Host "-----------------------------------------" -ForegroundColor DarkCyan
if (Confirm-Step "Do you want to build the Windows app?") {
    flutter build windows --release
    $winSourceDir = "build/windows/x64/runner/Release"
    $winDestDir = "build/windows/x64/runner/movienest-windows"
    if (Test-Path $winSourceDir) {
        Copy-Item -Path "$winSourceDir/*" -Destination $winDestDir -Recurse -Force
        $oldExe = "$winDestDir/movienest.exe"
        $newExe = "$winDestDir/flixo_app.exe"
        if (Test-Path $oldExe) { Remove-Item -Path $oldExe -Force }
        if (Test-Path $newExe) { Rename-Item -Path $newExe -NewName "movienest.exe" -Force }
        Write-Host "Windows files compiled and prepared!" -ForegroundColor Green

        # Prompt to run Inno Setup
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
    } else {
        Write-Host "Windows build failed!" -ForegroundColor Red
        Exit
    }
} else {
    Write-Host "Skipped Windows build." -ForegroundColor DarkGray
}

# 8. Deploy to Vercel
Write-Host "`n-----------------------------------------" -ForegroundColor DarkCyan
Write-Host " [4/4] Deploy to Vercel" -ForegroundColor DarkCyan
Write-Host "-----------------------------------------" -ForegroundColor DarkCyan
if (Confirm-Step "Do you want to deploy live to Vercel now?") {
    $setupPath = "web/downloads/movienest-setup.exe"
    $setupDest = "public/downloads/movienest-setup.exe"
    if (Test-Path $setupPath) {
        Copy-Item -Path $setupPath -Destination $setupDest -Force
        Write-Host "Copied Windows Setup Installer to public folder." -ForegroundColor Green
    } else {
        Write-Host "No Windows installer found, deploying without it." -ForegroundColor DarkGray
    }
    vercel --prod
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "  SUCCESS: RELEASE VERSION $newVersion IS LIVE!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
} else {
    Write-Host "Skipped Vercel deployment." -ForegroundColor DarkGray
}
