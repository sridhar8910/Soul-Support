# SoulSupport Multi-App Project - Complete Documentation

This comprehensive guide consolidates all project documentation including setup, running, troubleshooting, code architecture, and maintenance.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Quick Start Guide](#quick-start-guide)
3. [Project Setup](#project-setup)
4. [Running the Project](#running-the-project)
5. [Code Architecture & Algorithms](#code-architecture--algorithms)
6. [Errors Fixed & Status](#errors-fixed--status)
7. [Android Build Configuration](#android-build-configuration)
8. [Package Upgrade Plan](#package-upgrade-plan)
9. [Troubleshooting](#troubleshooting)
10. [Project Structure](#project-structure)

---

## Project Overview

### System Architecture

- **Backend**: Django REST Framework (DRF) with JWT authentication
- **Frontend**: Two Flutter apps sharing a common package
  - `app_user`: User-facing application
  - `app_counsellor`: Counsellor-facing application
- **Shared Code**: `packages/common` - Shared API client, token management, and endpoints

### App Package IDs

- **User App**: `com.soulsupport.user`
- **Counsellor App**: `com.soulsupport.counsellor`

### Authentication

The backend returns user roles in the login response:
- `role`: "user", "counsellor", "doctor", or "admin"
- `user_id`: User ID
- `username`: Username

---

## Quick Start Guide

### Prerequisites

1. **Backend Setup**
   ```powershell
   cd backend
   python -m venv venv
   .\venv\Scripts\activate
   pip install -r requirements.txt
   python manage.py migrate
   ```

2. **Flutter Setup**
   ```powershell
   # Common package
   cd packages/common
   flutter pub get
   
   # Counsellor app
   cd ../../apps/app_counsellor
   flutter pub get
   
   # User app
   cd ../app_user
   flutter pub get
   ```

### Running All Apps

#### Option 1: Simple Script (Recommended - Separate Windows)

```powershell
# Set execution policy (one time per session)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Run all apps
.\run_all_apps_simple.ps1
```

This opens 3 separate windows:
- **Window 1**: Django Backend (http://127.0.0.1:8000)
- **Window 2**: Counsellor App (Flutter)
- **Window 3**: User App (Flutter)

**To stop:** Close each window individually.

#### Option 2: Unified Script (Single Window)

```powershell
# Set execution policy (one time per session)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Run on Chrome (default)
.\run_all_apps.ps1

# Run on Windows desktop
.\run_all_apps.ps1 -Device windows

# Run on Android (requires connected device/emulator)
.\run_all_apps.ps1 -Device android

# Run in release mode
.\run_all_apps.ps1 -Release
```

**To stop:** Press `Ctrl+C` in the PowerShell window.

#### Option 3: Manual Method

**Terminal 1: Django Backend**
```powershell
cd backend
.\venv\Scripts\activate
python manage.py runserver 0.0.0.0:8000
```

**Terminal 2: Counsellor App**
```powershell
cd apps/app_counsellor
flutter run -d chrome
```

**Terminal 3: User App**
```powershell
cd apps/app_user
flutter run -d chrome
```

### Available Devices

- **`chrome`** - Chrome browser (default, recommended for development)
- **`windows`** - Windows desktop app
- **`android`** - Android device/emulator (requires setup)
- **`edge`** - Edge browser
- **`web-server`** - Web server mode

---

## Project Setup

### Completed Steps

1. ✅ Created `apps/` directory structure
2. ✅ Moved existing Flutter app to `apps/app_user/`
3. ✅ Copied counselor app to `apps/app_counsellor/`
4. ✅ Created `packages/common/` package structure
5. ✅ Created token manager and endpoints in common package
6. ✅ Copied API client to common package

### App Dependencies

#### `apps/app_user/pubspec.yaml`:
```yaml
name: app_user
dependencies:
  flutter:
    sdk: flutter
  common:
    path: ../../packages/common
  http: ^1.2.2
  flutter_secure_storage: ^9.2.2
  intl: ^0.19.0
  shared_preferences: ^2.2.0
```

#### `apps/app_counsellor/pubspec.yaml`:
```yaml
name: app_counsellor
dependencies:
  flutter:
    sdk: flutter
  common:
    path: ../../packages/common
  http: ^1.2.2
  flutter_secure_storage: ^9.2.2
  intl: ^0.19.0
  shared_preferences: ^2.2.0
```

### Import Updates

All imports should use:
```dart
import 'package:common/api/api_client.dart';
import 'package:common/auth/token_manager.dart';
```

Instead of:
```dart
import 'package:flutter_app/services/api_client.dart';
```

### Android Package IDs

#### `apps/app_user/android/app/build.gradle`:
```gradle
namespace = "com.soulsupport.user"
applicationId = "com.soulsupport.user"
```

#### `apps/app_counsellor/android/app/build.gradle.kts`:
```kotlin
namespace = "com.soulsupport.counsellor"
applicationId = "com.soulsupport.counsellor"
```

### iOS Bundle IDs

#### `apps/app_user/ios/Runner/Info.plist`:
```xml
<key>CFBundleIdentifier</key>
<string>com.soulsupport.user</string>
```

#### `apps/app_counsellor/ios/Runner/Info.plist`:
```xml
<key>CFBundleIdentifier</key>
<string>com.soulsupport.counsellor</string>
```

### Backend Role Models

Added to `backend/api/models.py`:
```python
class CounsellorProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="counsellorprofile")
    specialization = models.CharField(max_length=200, blank=True)
    experience_years = models.PositiveIntegerField(default=0)
    languages = models.JSONField(default=list)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.0)
    is_available = models.BooleanField(default=True)
    bio = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class DoctorProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="doctorprofile")
    specialization = models.CharField(max_length=200, blank=True)
    experience_years = models.PositiveIntegerField(default=0)
    license_number = models.CharField(max_length=100, blank=True)
    languages = models.JSONField(default=list)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.0)
    is_available = models.BooleanField(default=True)
    bio = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
```

Run migrations:
```bash
cd backend
python manage.py makemigrations
python manage.py migrate
```

### Authentication View

The `EmailOrUsernameTokenObtainPairView` in `backend/api/views.py` returns user role in login response:
```python
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework.response import Response

class CustomTokenObtainPairView(TokenObtainPairView):
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        
        if response.status_code == 200:
            user = self.user
            role = 'user'
            if hasattr(user, 'counsellorprofile'):
                role = 'counsellor'
            elif hasattr(user, 'doctorprofile'):
                role = 'doctor'
            elif user.is_superuser:
                role = 'admin'
            
            data = response.data
            data['role'] = role
            data['user_id'] = user.id
            data['username'] = user.username
            
            return Response(data)
        return response
```

### Create Test Users with Roles

```python
from django.contrib.auth.models import User
from api.models import CounsellorProfile, DoctorProfile

# Create counsellor
user = User.objects.create_user('counsellor1', 'counsellor@example.com', 'password')
CounsellorProfile.objects.create(user=user, specialization='Mental Health')

# Create doctor
user2 = User.objects.create_user('doctor1', 'doctor@example.com', 'password')
DoctorProfile.objects.create(user=user2, specialization='Psychiatry')
```

---

## Running the Project

### Backend Server

The Django backend runs on `http://127.0.0.1:8000`

```bash
cd backend
.\venv\Scripts\Activate.ps1
python manage.py runserver
```

### Flutter Apps

#### Run User App:
```bash
cd apps/app_user
flutter run -d chrome
# or for Android:
flutter run -d android
# or for iOS:
flutter run -d ios
```

#### Run Counsellor App:
```bash
cd apps/app_counsellor
flutter run -d chrome
# or for Android:
flutter run -d android
# or for iOS:
flutter run -d ios
```

### Development Workflow

1. **Start all services:**
   ```powershell
   .\run_all_apps_simple.ps1
   ```

2. **Make changes:**
   - Flutter apps: Hot reload will work automatically (press `r` in Flutter terminal)
   - Backend: Restart backend window after code changes

3. **Test:**
   - Test user app features
   - Test counsellor app features
   - Verify API calls work from both apps

4. **Stop services:**
   - Close each window, or
   - Press `Ctrl+C` if using unified script

### Service Status

When all services are running:

| Service | URL/Status | Port |
|---------|-----------|------|
| Django Backend | http://127.0.0.1:8000 | 8000 |
| Counsellor App | Running on selected device | - |
| User App | Running on selected device | - |

---

## Code Architecture & Algorithms

### System Overview

- **Backend**: Django REST Framework (DRF) provides the API surface. Authentication uses JWT. Models live in `backend/api/models.py`, and everything is exposed via `backend/api/views.py`.
- **Frontend**: Flutter apps located under `apps/app_user/` and `apps/app_counsellor/`. `main.dart` bootstraps each app. Screen-level widgets live in `lib/screens/`, and network calls happen through the shared `packages/common/lib/api/api_client.dart`.
- **Communication**: All client requests go through `ApiClient`, which adds JWT headers, handles token refresh, and serializes responses into typed models or dictionaries.

### Backend Architecture

#### API Modules

| File | Responsibility |
|------|----------------|
| `api/models.py` | Database schema (UserProfile, WellnessTask, MoodLog, etc.) |
| `api/serializers.py` | Validation & (de)serialization rules |
| `api/views.py` | REST endpoints (auth, wallet, mood, content, sessions, etc.) |
| `api/urls.py` | URL routing to view classes |
| `api/migrations/` | Schema migrations (nickname field, wallet defaults, etc.) |

#### Data Models (Highlights)

- `UserProfile`: Extends Django User with full name, nickname, phone, age, gender, wallet balance (rupees), mood tracking fields, timezone, UI preferences.
- `WellnessTask`: Stores customizable tasks categorized as daily or evening.
- `WellnessJournalEntry`: Personal journal with mood tags and entry types.
- `SupportGroup` & `SupportGroupMembership`: Manage community groups.
- `UpcomingSession`: Scheduled counselling sessions with metadata.
- `MoodLog`, `GuidanceResource`, `MindCareBooster`, `MeditationSession`, `MusicTrack`: Content and tracking models.

#### Views & Algorithms

Key endpoints inside `api/views.py`:

| View | Purpose |
|------|---------|
| `RegisterView`, `RegistrationSendOTPView`, `RegistrationVerifyOTPView` | OTP-driven signup pipeline |
| `EmailOrUsernameTokenObtainPairView` | JWT login |
| `ProfileView`, `UserSettingsView` | Profile + nickname + settings management |
| `WalletDetailView`, `WalletRechargeView`, `WalletUsageView` | Balance tracking and service billing |
| `MoodUpdateView` | Mood recording with timezone reset logic |
| `WellnessTaskListCreateView`, `WellnessTaskDetailView` | Task CRUD |
| `WellnessJournalEntry*` | Journal CRUD |
| `SupportGroupListView` | Group listing/join/leave |
| `UpcomingSessionListCreateView`, `QuickSessionView` | Session management |
| `MindCareBoosterListView`, `MeditationSessionListView`, `ProfessionalGuidanceListView` | Content APIs |

#### Example Algorithm: Mood Update

Pseudo-code summarizing `MoodUpdateView.post()`:

```
if profile.timezone missing:
    detect from request or fallback to server tz
if provided timezone differs from stored:
    update profile.timezone

local_now = utc_now -> convert to timezone
if last_mood_updates_date != local_now.date:
    reset mood_updates_count to 0

if mood_updates_count >= 3:
    compute next midnight in timezone
    return {"status": "limit_reached", "reset_at_local": ...}

record mood:
    profile.last_mood = payload.value
    profile.last_mood_updated = now
    profile.mood_updates_count += 1
    MoodLog.create(...)
return {"status": "ok", "updates_used": mood_updates_count}
```

#### Example Algorithm: Wallet Deduction

```
rate = SERVICE_RATE_MAP[service]  # call=5, chat=1
min_balance = SERVICE_MIN_BALANCE_MAP[service]
charge = minutes * rate

if wallet < min_balance:
    return 400: minimum balance required
if wallet < charge:
    return 400: insufficient funds

wallet -= charge
save profile
return {"charged": charge, "wallet_minutes": wallet}
```

#### URL Routing Graph

```
/api/
  auth/
    register/
    send-otp/
    verify-otp/
    token/
    token/refresh/
  profile/
  settings/
  mood/
  wallet/, wallet/recharge/, wallet/use/
  wellness/
    tasks/, tasks/<id>/
    journals/, journals/<id>/
  support-groups/
  sessions/, sessions/<id>/, sessions/quick/
  reports/analytics/
  guidance/resources/
  content/
    boosters/
    meditations/
    music/
```

### Frontend Architecture

#### App Entry & Routing

- `lib/main.dart` bootstraps `MyApp`, sets global theme, routes to `SplashScreen`.
- Routing strategy:
  - `SplashScreen` checks stored tokens → loads profile → navigates to `HomeScreen` or `LoginScreen`.
  - `Navigator.push` is used for sub-pages (Wallet, Settings, Profile, etc.).

#### Service Layer (`ApiClient`)

Located at `packages/common/lib/api/api_client.dart`. Responsibilities:

1. **Token Storage**: Stores JWT access/refresh tokens in secure storage / shared preferences.
2. **HTTP Helpers**: `_sendAuthorized` attaches Authorization header, handles 401 by refreshing token.
3. **Endpoints**: Each API call is encapsulated (login, register, send OTP, wallet, mood, tasks, sessions, etc.).
4. **Models**: Local Dart classes (`UserSettings`, `WalletInfo`, `MindCareBoosterItem`, etc.) parse JSON responses.

#### Screen-by-Screen Reference

| Screen | File | Highlights |
|--------|------|------------|
| Splash | `splash_screen.dart` | Animated splash, profile fetch, navigation |
| Login | `login_screen.dart` | Gradient design, form validation, Enter-to-submit |
| Register | `register_screen.dart` | Three-step wizard (basic info → OTP → password) |
| Home | `home_screen.dart` | Massive dashboard: header, mood card, quick access grid, wallet indicator, chat button |
| Wallet | `wallet_page.dart` | Shows balance (₹), recharge options, custom amount input |
| Schedule Session | `schedule_session_page.dart` | Date/time pickers, 1-hour recommendation, 10-min minimum logic |
| Settings | `settings_page.dart` | Account info, notification toggles, dark mode, logout |
| MindCare Booster | `mindcare_booster_page.dart` | Grid of boosters, bottom sheet details, filtered categories |
| Meditation | `meditation_page.dart` | List by category, play buttons |
| Support Groups | `support_groups_page.dart` | Join/leave groups with counters |
| Reports & Analytics | `reports_analytics_page.dart` | Graphs for mood/task/session data |
| Breathing | `breathing_page.dart` | Animated inhale/exhale circle with adjustable phase length |

### End-to-End Algorithms

#### Registration & OTP Flow

1. **User enters basic info** (username, name, nickname, age, gender, phone, email).
2. `sendRegistrationOtp(email)` → backend sends OTP email (console backend in dev).
3. User enters OTP → `verifyRegistrationOtp(email, code)` → returns OTP token.
4. User sets password → `register` call with OTP token + personal info.
5. Backend validates OTP via `EmailOTP` model, creates Django `User` + `UserProfile`.
6. On success, user is prompted to login.

#### Mood Update & Reset Logic

1. Flutter mood card calls `_api.updateMood(value, timezone)`.
2. Backend resolves timezone (request payload → stored profile → server default).
3. If new day in timezone → reset `mood_updates_count`.
4. If user already used 3 updates → respond with limit reached + reset time.
5. Otherwise record mood, increment count, return updated data.
6. Flutter updates UI and caches timezone for future resets.

#### Wallet Billing

1. Wallet detail: `GET /wallet/` returns balance, per-service rates, minimums.
2. Recharge: `POST /wallet/recharge/` adds amount directly (integers represent rupees).
3. During services (call/chat) Flutter calls `POST /wallet/use/` with service type + duration.
4. Backend enforces minimum and per-minute rate, deducts, and returns new balance.

#### Session Scheduling Rules

Pseudo-code from `schedule_session_page.dart`:

```
start = combine(selected_date, selected_time)
now = DateTime.now()
earliest = now + 10 minutes
recommended = now + 1 hour

if start < earliest:
    show snackbar "choose at least 10 minutes from now"
else if start < recommended:
    show dialog explaining recommendation
    if user cancels -> abort
    else -> proceed

call _api.scheduleQuickSession(start, title, notes)
```

#### Nickname Propagation

1. **Registration** collects nickname (defaults to username if blank).
2. Backend stores it in `UserProfile.nickname`.
3. API responses include nickname everywhere.
4. Home screen uses `nickname` → `full_name` → `username` fallback for greeting and avatar.
5. Profile page includes nickname field; updates call `updateUserSettings` to persist to backend.
6. Settings account sheet shows nickname separate from full name.

#### Breathing Animation Cycle

Located in `breathing_page.dart`:

```
phaseSeconds = dropdown value (3,4,5,6,8,10)
_controller.duration = Duration(seconds: phaseSeconds)
_expanding flag indicates inhale/exhale state

Animation flow:
  start -> forward -> complete -> set expanding=false -> reverse
  reverse complete -> set expanding=true -> forward

Displayed text = "Inhale" if expanding else "Exhale"
```

### Data Flow Examples

#### Example: Updating Mood

```
Flutter UI (slider) -> _attemptMoodChange() -> ApiClient.updateMood()
 -> HTTP POST /api/mood/
 -> MoodUpdateView validates, updates DB, returns JSON
 -> ApiClient parses MoodUpdateResult
 -> HomeScreen updates state, shows snackbar, adjusts counters
```

#### Example: Scheduling Session

```
User selects date/time -> _saveSession()
 -> validation (10 min min, 1 hr recommended)
 -> ApiClient.scheduleQuickSession()
 -> POST /api/sessions/quick/
 -> QuickSessionView handles creation, returns UpcomingSessionSerializer data
 -> Flutter shows success message + pops back with new session object
```

#### Example: Wallet Recharge

```
WalletPage -> tap amount -> _recharge()
 -> ApiClient.rechargeWallet(amount)
 -> POST /api/wallet/recharge/
 -> WalletRechargeView increments wallet_minutes, returns new balance
 -> Flutter updates card + notifies parent (HomeScreen)
```

### Extending the Codebase

#### Adding a New Backend Feature

1. **Model**: Update `models.py`, run `makemigrations`.
2. **Serializer**: Add serialization/validation logic.
3. **View**: Create API view using DRF classes.
4. **URL**: Register endpoint in `api/urls.py`.
5. **Flutter**: Implement matching method in `ApiClient`, update UI screen.

#### Adding a New Screen

1. Create file in `apps/app_user/lib/screens/` or `apps/app_counsellor/lib/screens/`.
2. Add route or direct `Navigator.push`.
3. Fetch data via `ApiClient`.
4. Style with theme classes.

#### Ensuring Nickname Privacy

Display logic should prefer `nickname` when showing names to counsellors or other users. When implementing new features, follow this pattern:

```dart
String get displayName {
  if (profile.nickname?.isNotEmpty ?? false) return profile.nickname!;
  if (profile.fullName?.isNotEmpty ?? false) return profile.fullName!;
  return profile.username ?? 'Soul Support User';
}
```

---

## Errors Fixed & Status

### All Critical Errors Resolved

#### 1. Flutter Lint Errors Fixed ✅
- ✅ Added `flutter_lints: ^5.0.0` to `app_user/pubspec.yaml`
- ✅ Fixed `CardThemeData` → `CardTheme` in `app_counsellor/lib/main.dart`
- ✅ Fixed deprecated `WillPopScope` → `PopScope` with `onPopInvokedWithResult` in `wallet_page.dart`
- ✅ Removed unnecessary cast in `reports_analytics_page.dart`
- ✅ Fixed local variable naming (`_mapToInt` → `mapToInt`) in `api_client.dart`
- ✅ Added curly braces to if statements for better code style

#### 2. Test Files Fixed ✅
- ✅ Updated `app_user/test/widget_test.dart` to use correct package name
- ✅ Updated `packages/common/test/common_test.dart` to test actual exports

#### 3. Android Configuration ✅
- ✅ Created `local.properties` for `app_counsellor` with correct Flutter SDK path
- ✅ Updated package IDs for both apps:
  - `app_user`: `com.soulsupport.user`
  - `app_counsellor`: `com.soulsupport.counsellor`

#### 4. iOS Configuration ✅
- ✅ Updated Bundle IDs in `project.pbxproj` files
- ✅ Updated display names in `Info.plist` files

#### 5. Backend Updates ✅
- ✅ Added `CounsellorProfile` and `DoctorProfile` models
- ✅ Updated authentication to return user roles
- ✅ Migrations created and applied

### Current Status

#### Flutter Analysis Results:
- **app_user**: Only minor style warnings (info level), no errors
- **app_counsellor**: No issues found ✅

### Project Status: READY

All critical errors have been fixed. The apps should now:
- ✅ Compile without errors
- ✅ Run successfully
- ✅ Connect to the backend API
- ✅ Use the shared common package

The Android build warnings in the IDE are likely false positives from the linter. The actual Flutter analysis shows no errors.

---

## Android Build Configuration

### Build Configuration Summary

| Component | Counsellor App | User App | Location |
|-----------|---------------|----------|----------|
| Gradle | 8.11.1 | 8.11.1 | `android/gradle/wrapper/gradle-wrapper.properties` |
| AGP | 8.9.1 | 8.1.0 | `android/settings.gradle(.kts)` |
| Kotlin | 2.1.0 | 1.8.22 | `android/settings.gradle(.kts)` |
| NDK | 27.0.12077973 | 27.0.12077973 | `android/app/build.gradle(.kts)` |
| Java | 11 | 11 | `android/app/build.gradle(.kts)` |
| CompileSdk | 34 | 34 | Flutter default |

### CI/CD Configuration

#### Required CI Environment

- **JDK**: 11 or 17 (Temurin/OpenJDK recommended)
- **Gradle**: 8.11.1 (via wrapper, not system Gradle)
- **Android NDK**: 27.0.12077973
- **Android SDK**: Platform 34, Build Tools 34.0.0
- **Flutter**: 3.24.0 (stable channel)

#### GitHub Actions Setup

The workflow at `.github/workflows/android-build.yml` is configured with:
- ✅ JDK 11
- ✅ Gradle 8.11.1 (via wrapper)
- ✅ Android NDK 27.0.12077973
- ✅ Proper caching for Gradle and pub cache
- ✅ Builds both apps (counsellor and user)

**To trigger builds:**
- Push to `main`, `master`, or `develop` branches
- Create a pull request
- Manual trigger via GitHub Actions UI
- Use commit messages: `[counsellor]` or `[user]` to target specific apps

### Dependency Management

#### Repository Configuration

Both projects use `PREFER_SETTINGS` mode in `settings.gradle(.kts)`:
- Centralizes repository management
- Allows plugins to add repos (warnings are informational)
- Ensures `mavenCentral()` and `google()` are always available

#### Package Version Pinning (Optional)

For reproducible builds, consider pinning critical packages:

**Current versions in use:**
- `flutter_secure_storage: ^9.2.2` (using 9.2.4)
- `shared_preferences: ^2.2.0` (using 2.4.7)
- `path_provider_android: ^2.2.15` (transitive)
- `http: ^1.2.2` (using 1.5.0 in app_user, 1.2.2 in app_counsellor)

**To pin versions:**
```yaml
dependencies:
  flutter_secure_storage: 9.2.4  # Remove ^ for exact version
  shared_preferences: 2.4.7
```

### Verification Commands

```bash
# Test Gradle configuration
cd apps/app_counsellor/android
./gradlew tasks --all

cd ../../app_user/android
./gradlew tasks --all

# Test Flutter builds
cd apps/app_counsellor
flutter build apk --debug

cd ../app_user
flutter build apk --debug

# Check for dependency issues
flutter pub outdated
flutter analyze
```

### Maintenance Schedule

#### Weekly
- [ ] Check for Gradle/AGP updates
- [ ] Review Flutter dependency updates (`flutter pub outdated`)
- [ ] Verify CI builds are green

#### Monthly
- [ ] Review and update pinned package versions if needed
- [ ] Check for Android SDK/NDK updates
- [ ] Review and update CI workflow if Flutter version changes

#### Before Major Releases
- [ ] Test builds on clean environment
- [ ] Verify all dependencies are compatible
- [ ] Update version numbers in `pubspec.yaml`
- [ ] Test CI/CD pipeline end-to-end

---

## Package Upgrade Plan

### Overview

This section provides a safe upgrade path for Flutter packages that have newer versions available but are currently constrained by dependency requirements.

**Current Status:** 37-38 packages have newer versions incompatible with current constraints.

### Critical Packages (Recommended to Pin)

These packages are core to the app functionality and should be pinned for stability:

#### app_counsellor & app_user (Shared)

```yaml
dependencies:
  # Security & Storage
  flutter_secure_storage: 9.2.4  # Currently: ^9.2.2, using 9.2.4
  shared_preferences: 2.4.7       # Currently: ^2.2.0, using 2.4.7
  
  # HTTP & Networking
  http: 1.5.0                     # Currently: ^1.2.2, using 1.5.0 (app_user)
  
  # Internationalization
  intl: 0.19.0                    # Currently: ^0.19.0, using 0.19.0
```

#### app_user (Specific)

```yaml
dependencies:
  flutter_native_timezone_updated_gradle: 2.0.3  # Currently: ^2.0.3
```

### Safe Upgrade Path

#### Phase 1: Pin Current Working Versions (Immediate)

**Goal:** Lock in versions that are currently working to prevent drift.

**Action:** Update `pubspec.yaml` files to use exact versions (remove `^`):

```yaml
# apps/app_counsellor/pubspec.yaml
dependencies:
  flutter_secure_storage: 9.2.4  # was: ^9.2.2
  shared_preferences: 2.4.7      # was: ^2.2.0
  http: 1.2.2                    # was: ^1.2.2 (keep current)

# apps/app_user/pubspec.yaml
dependencies:
  flutter_secure_storage: 9.2.4  # was: ^9.2.2
  shared_preferences: 2.4.7      # was: ^2.2.0
  http: 1.5.0                    # was: ^1.2.2 (already using newer)
  flutter_native_timezone_updated_gradle: 2.0.3  # was: ^2.0.3
```

**Test after pinning:**
```bash
cd apps/app_counsellor
flutter pub get
flutter analyze
flutter test  # if tests exist

cd ../app_user
flutter pub get
flutter analyze
flutter test  # if tests exist
```

#### Phase 2: Update Compatible Packages (After Testing)

**Goal:** Update packages that have compatible newer versions.

**Packages with compatible updates:**

1. **http**: `1.2.2` → `1.6.0` (major version available)
   - **Risk:** Low (minor API changes)
   - **Test:** HTTP requests, API calls
   - **Action:** Update to `^1.6.0` and test

2. **intl**: `0.19.0` → `0.20.2` (minor update)
   - **Risk:** Low (backward compatible)
   - **Test:** Date/time formatting, localization
   - **Action:** Update to `^0.20.2` and test

3. **flutter_lints**: `5.0.0` → `6.0.0` (major version)
   - **Risk:** Low (linting rules only)
   - **Test:** Run `flutter analyze`
   - **Action:** Update to `^6.0.0` and fix any new lint warnings

#### Phase 3: Major Version Upgrades (Careful Testing Required)

**Packages requiring major version updates:**

1. **shared_preferences**: `2.4.7` → `2.4.16` (patch updates available)
   - **Risk:** Very Low (patch updates)
   - **Action:** Update to `^2.4.16`

2. **path_provider_android**: `2.2.15` → `2.2.21` (transitive dependency)
   - **Risk:** Low (patch updates)
   - **Action:** Update `shared_preferences` will pull newer version

3. **flutter_secure_storage**: `9.2.4` → `9.2.4` (latest in 9.x)
   - **Risk:** None (already at latest)
   - **Note:** Version 10.x may be available but requires testing

### Detailed Package Analysis

#### High Priority (Core Functionality)

| Package | Current | Available | Risk | Recommendation |
|---------|---------|-----------|------|----------------|
| `flutter_secure_storage` | 9.2.4 | 9.2.4 | None | ✅ Already latest |
| `shared_preferences` | 2.4.7 | 2.4.16 | Low | Update to `^2.4.16` |
| `http` | 1.2.2/1.5.0 | 1.6.0 | Medium | Test `^1.6.0` in dev first |
| `intl` | 0.19.0 | 0.20.2 | Low | Update to `^0.20.2` |

#### Medium Priority (Development Tools)

| Package | Current | Available | Risk | Recommendation |
|---------|---------|-----------|------|----------------|
| `flutter_lints` | 5.0.0 | 6.0.0 | Low | Update to `^6.0.0` |
| `cupertino_icons` | 1.0.8 | Latest | Low | Keep current (minor) |

#### Low Priority (Transitive Dependencies)

These are pulled in by other packages and will update automatically:
- `path_provider_android`: Updates with `shared_preferences`
- `path_provider_foundation`: Updates with `shared_preferences`
- `shared_preferences_android`: Updates with `shared_preferences`
- `shared_preferences_foundation`: Updates with `shared_preferences`

### Recommended Upgrade Sequence

#### Step 1: Pin Current Versions (This Week)

```bash
# Update pubspec.yaml files with exact versions
# Test builds
cd apps/app_counsellor && flutter pub get && flutter build apk --debug
cd ../app_user && flutter pub get && flutter build apk --debug
```

#### Step 2: Update Linting (Low Risk)

```yaml
# Both apps
dev_dependencies:
  flutter_lints: ^6.0.0  # was: ^5.0.0
```

```bash
flutter pub get
flutter analyze  # Fix any new warnings
```

#### Step 3: Update Intl (Low Risk)

```yaml
# Both apps
dependencies:
  intl: ^0.20.2  # was: ^0.19.0
```

```bash
flutter pub get
# Test date/time formatting in app
flutter build apk --debug
```

#### Step 4: Update Shared Preferences (Low Risk)

```yaml
# Both apps
dependencies:
  shared_preferences: ^2.4.16  # was: ^2.2.0
```

```bash
flutter pub get
# Test storage functionality
flutter build apk --debug
```

#### Step 5: Update HTTP (Medium Risk - Test Thoroughly)

```yaml
# Both apps
dependencies:
  http: ^1.6.0  # was: ^1.2.2
```

```bash
flutter pub get
# Test all API calls
flutter test  # Run API-related tests
flutter build apk --debug
```

### Testing Checklist

After each upgrade phase:

- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` passes (or only expected warnings)
- [ ] `flutter test` passes (if tests exist)
- [ ] Debug build succeeds: `flutter build apk --debug`
- [ ] Release build succeeds: `flutter build apk --release`
- [ ] App launches and core features work
- [ ] API calls function correctly (if HTTP updated)
- [ ] Storage/secure storage works (if shared_preferences updated)
- [ ] Date/time formatting works (if intl updated)

### Rollback Plan

If an upgrade causes issues:

1. **Revert pubspec.yaml changes:**
   ```bash
   git checkout apps/app_counsellor/pubspec.yaml
   git checkout apps/app_user/pubspec.yaml
   ```

2. **Clean and reinstall:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Verify build:**
   ```bash
   flutter build apk --debug
   ```

### Version Compatibility Matrix

| Flutter SDK | Dart SDK | http | shared_preferences | flutter_secure_storage |
|-------------|----------|------|---------------------|------------------------|
| 3.24.0 | >=3.3.0 | 1.6.0 ✅ | 2.4.16 ✅ | 9.2.4 ✅ |
| 3.24.0 | >=3.3.0 | 1.5.0 ✅ | 2.4.7 ✅ | 9.2.4 ✅ |
| 3.24.0 | >=3.3.0 | 1.2.2 ✅ | 2.2.0 ✅ | 9.2.2 ✅ |

All recommended versions are compatible with current Flutter/Dart SDK constraints.

### Next Steps

1. **Immediate:** Pin current working versions (Phase 1)
2. **This Week:** Update linting and intl (Phase 2, low risk)
3. **Next Week:** Update shared_preferences (Phase 2, low risk)
4. **After Testing:** Update HTTP (Phase 2, medium risk)

**Remember:** Always test in a development environment before updating production dependencies!

---

## Troubleshooting

### Execution Policy Error

If you see "cannot be loaded. The file is not digitally signed":

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This only affects the current PowerShell session.

### Backend Not Starting

**Error:** "Python virtualenv not found"

**Solution:**
```powershell
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
```

**Error:** "Port 8000 already in use"

**Solution:**
```powershell
# Find process using port 8000
netstat -ano | findstr :8000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

### Flutter Apps Not Starting

**Error:** "Flutter dependencies not found"

**Solution:**
```powershell
# Common package
cd packages/common
flutter pub get

# Counsellor app
cd ../../apps/app_counsellor
flutter pub get

# User app
cd ../app_user
flutter pub get
```

**Error:** "No devices found"

**Solution:**
```powershell
# Check available devices
flutter devices

# For Chrome, ensure Chrome is installed
# For Android, ensure device/emulator is connected
```

### API Connection Issues

**Error:** "Failed to connect to API"

**Solution:**
1. Verify backend is running: Open http://127.0.0.1:8000 in browser
2. Check API base URL in Flutter app configuration
3. Verify CORS settings in `backend/core/settings.py`

### Android Build Issues

#### Build Fails with "error_prone_annotations" Error

**Solution:** Already fixed with resolution strategy in `build.gradle(.kts)`:
```groovy
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.google.errorprone:error_prone_annotations:2.18.0")
        }
    }
}
```

#### NDK Version Mismatch

**Error:** "Your project is configured with Android NDK X, but plugin requires Y"

**Solution:** NDK version is set to `27.0.12077973` in `app/build.gradle(.kts)`:
```groovy
ndkVersion = "27.0.12077973"
```

#### Repository Warnings

**Warning:** "Build was configured to prefer settings repositories but repository 'X' was added"

**Status:** ✅ **Informational only** - This is expected with `PREFER_SETTINGS` mode. Plugins can add repositories, but settings repos are preferred.

#### Flutter Dependency Cache Issues

**Symptoms:** Missing `path_provider_linux` or `path_provider_windows` errors

**Solution:**
```bash
cd apps/app_counsellor  # or app_user
flutter clean
flutter pub get
```

#### IDE Shows "Duplicate root element android"

**Solution:** This is a false positive from IDE cache:
1. Invalidate IDE caches
2. Re-sync Gradle project
3. The actual Gradle build works fine

### Import Errors

**Error:** "Import errors in Flutter apps"

**Solution:**
1. Verify `packages/common` is properly set up
2. Run `flutter pub get` in all three locations:
   - `packages/common`
   - `apps/app_user`
   - `apps/app_counsellor`
3. Check that imports use `package:common/...` instead of relative paths

---

## Project Structure

```
project/
├── backend/                    # Django backend
│   ├── api/
│   │   ├── models.py          # ✅ Includes CounsellorProfile, DoctorProfile
│   │   ├── views.py           # ✅ Updated authentication view
│   │   ├── serializers.py     # Validation & (de)serialization
│   │   └── urls.py            # URL routing
│   ├── core/
│   │   └── settings.py        # Django settings, CORS config
│   └── manage.py
├── apps/
│   ├── app_user/              # ✅ User app
│   │   ├── lib/
│   │   │   ├── main.dart      # App entry point
│   │   │   └── screens/       # ✅ All imports updated to use common package
│   │   ├── android/           # ✅ Package ID: com.soulsupport.user
│   │   ├── ios/              # ✅ Bundle ID: com.soulsupport.user
│   │   └── pubspec.yaml      # ✅ Uses common package
│   └── app_counsellor/        # ✅ Counsellor app
│       ├── lib/
│       │   ├── main.dart
│       │   └── screens/
│       ├── android/          # ✅ Package ID: com.soulsupport.counsellor
│       ├── ios/              # ✅ Bundle ID: com.soulsupport.counsellor
│       └── pubspec.yaml      # ✅ Uses common package
└── packages/
    └── common/                # ✅ Shared package
        ├── lib/
        │   ├── api/
        │   │   ├── api_client.dart    # Shared API client
        │   │   └── endpoints.dart     # API endpoint constants
        │   ├── auth/
        │   │   └── token_manager.dart # Role-based token management
        │   └── common.dart            # Package exports
        └── pubspec.yaml
```

---

## Quick Checklist

Before running:

- [ ] Backend virtual environment created and activated
- [ ] Backend dependencies installed (`pip install -r requirements.txt`)
- [ ] Backend migrations run (`python manage.py migrate`)
- [ ] Flutter installed and in PATH
- [ ] Common package dependencies installed (`flutter pub get`)
- [ ] Counsellor app dependencies installed (`flutter pub get`)
- [ ] User app dependencies installed (`flutter pub get`)
- [ ] Chrome browser installed (for `-Device chrome`)

---

## Notes

- **Hot Reload**: Flutter apps support hot reload (press `r` in Flutter terminal)
- **Hot Restart**: Press `R` in Flutter terminal for full restart
- **Backend Changes**: Backend requires manual restart after code changes
- **Database**: SQLite database is at `backend/db.sqlite3`
- **Testing**: Use `run_all_apps_simple.ps1` to spin everything up, then exercise flows (register, login, mood update, wallet, scheduling)

---

## Summary

- ✅ Backend provides a rich set of REST endpoints via Django/DRF, with JWT auth, OTP registration, wallet billing, and timezone-aware mood tracking.
- ✅ Frontend uses Flutter with a centralized `ApiClient` for all HTTP requests, stateful widgets for each major feature, and consistent styling.
- ✅ Algorithms covering OTP registration, wallet deductions, mood limits, session scheduling, nickname usage, and breathing animations are carefully implemented.
- ✅ Both apps can share code through the `common` package, have unique package/bundle IDs for independent deployment, support role-based authentication from the backend, and be built and deployed separately.
- ✅ All critical errors have been fixed and the project is ready for development.

**Ready to go?** Run `.\run_all_apps_simple.ps1` and start developing! 🚀

