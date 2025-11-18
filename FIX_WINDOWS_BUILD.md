# Fix Windows Build Issue

## Problem
Windows build is looking for `http-1.5.0` but the lock file has `1.6.0`. This is a Windows desktop build cache issue.

## Quick Fix - Use Chrome Instead

Run with Chrome (more reliable for development):
```powershell
.\run_all.ps1 -Device chrome
.\run_counsellor.ps1 -Device chrome
```

## Fix Windows Build

If you need Windows desktop build, try:

1. **Clear all caches:**
```powershell
cd apps\app_user
flutter clean
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item pubspec.lock -Force
cd ..\..\packages\common
Remove-Item pubspec.lock -Force
flutter pub get
cd ..\..\apps\app_user
flutter pub get
```

2. **Repair pub cache:**
```powershell
flutter pub cache repair
```

3. **Try building again:**
```powershell
.\run_all.ps1 -Device windows
```

## Alternative: Use Android or Web

For development, Chrome is recommended:
```powershell
.\run_all.ps1 -Device chrome
.\run_counsellor.ps1 -Device chrome
```

For Android:
```powershell
.\run_all.ps1 -Device android
.\run_counsellor.ps1 -Device android
```

