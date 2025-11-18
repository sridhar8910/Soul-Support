# 🏗️ Multi-App Architecture & Deployment Guide

## Complete Guide to Building and Deploying Multiple Flutter Apps from a Single Repository

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Project Structure](#project-structure)
4. [Code Sharing Strategy](#code-sharing-strategy)
5. [Authentication & Authorization](#authentication--authorization)
6. [Build Configuration](#build-configuration)
7. [Deployment Strategy](#deployment-strategy)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Version Management](#version-management)
10. [Real-World Scenarios](#real-world-scenarios)
11. [Troubleshooting](#troubleshooting)
12. [Best Practices](#best-practices)
13. [Migration Guide](#migration-guide)
14. [Execution Plan](#execution-plan)

---

## 1. Executive Summary

### What is Multi-App Architecture?

Multi-app architecture allows you to build **multiple independent Flutter applications** from a **single codebase repository** while maintaining:

- ✅ **Separate app store listings** (Google Play, Apple App Store)
- ✅ **Independent versioning** (different release schedules)
- ✅ **Shared codebase** (common business logic, API clients, models)
- ✅ **Independent deployment** (deploy one app without affecting others)
- ✅ **Role-based user experiences** (different UIs for different user types)

### Why Use This Architecture?

| Benefit | Description |
|---------|------------|
| **Code Reusability** | Share 60-80% of code between apps (API clients, models, utilities) |
| **Faster Development** | Build new apps faster by reusing existing code |
| **Easier Maintenance** | Fix bugs once, update all apps |
| **Consistent Behavior** | Same business logic across all apps |
| **Independent Releases** | Deploy updates to one app without affecting others |
| **Team Scalability** | Different teams can work on different apps |
| **Cost Efficiency** | Single backend, shared infrastructure |

### When to Use This Pattern

✅ **Use when:**
- You have multiple user types (patients, doctors, admins)
- Apps share significant business logic
- You want separate app store listings
- Different apps need different branding/UX
- You want independent release cycles

❌ **Don't use when:**
- Apps are completely different (no shared code)
- You want a single app with role switching
- You have very different technology requirements

---

## 2. Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Django Backend (API)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ User API │  │ Admin   │  │ Chat API │  │ Call API │   │
│  │          │  │ API     │  │          │  │          │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Authentication & Authorization Layer          │  │
│  │  (JWT Tokens, Role-Based Access Control)              │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│  User App    │  │ Doctor App  │  │ Admin App   │
│  (Flutter)   │  │ (Flutter)   │  │ (Flutter)   │
│              │  │             │  │             │
│  Package ID: │  │ Package ID: │  │ Package ID: │
│  com.org.user│  │com.org.doctor│ │com.org.admin│
└───────┬──────┘  └──────┬──────┘  └──────┬──────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                  ┌──────▼──────┐
                  │   Common    │
                  │   Package   │
                  │  (Shared)   │
                  └─────────────┘
```

### Component Breakdown

#### Backend Layer
- **Django REST Framework**: RESTful API endpoints
- **JWT Authentication**: Token-based authentication
- **Role-Based Access Control**: User, Doctor, Admin roles
- **WebSocket Support**: Real-time chat/call signaling (Django Channels)
- **Database**: Shared PostgreSQL/SQLite database

#### Frontend Layer
- **User App**: Patient/end-user mobile application
- **Doctor App**: Healthcare provider mobile application
- **Admin App**: Administrative mobile application
- **Common Package**: Shared Dart code (API client, models, utilities)

#### Shared Components
- **API Client**: HTTP request handling, token management
- **Data Models**: User, Session, Message, etc.
- **WebSocket Client**: Real-time communication
- **Authentication Helpers**: Token storage, refresh logic
- **Utility Functions**: Date formatting, validation, etc.

---

## 3. Project Structure

### Recommended Folder Structure

```
project/
├── backend/                          # Django Backend
│   ├── api/                          # Main API app
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── serializers.py
│   │   └── urls.py
│   ├── admin_api/                    # Admin/Counsellor/Doctor API
│   │   ├── models.py                  # Role models
│   │   ├── views.py
│   │   ├── serializers.py
│   │   └── urls.py
│   ├── chat/                         # Chat system
│   │   ├── models.py
│   │   ├── consumers.py              # WebSocket handlers
│   │   └── views.py
│   ├── calls/                        # Call system
│   │   ├── models.py
│   │   └── views.py
│   ├── core/
│   │   ├── settings.py
│   │   └── urls.py
│   ├── manage.py
│   └── requirements.txt
│
├── apps/                             # Flutter Applications
│   ├── app_user/                     # User App (App A)
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── screens/
│   │   │   │   ├── home_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── ...
│   │   │   └── services/
│   │   │       └── app_specific_service.dart
│   │   ├── pubspec.yaml
│   │   ├── android/
│   │   │   └── app/
│   │   │       └── build.gradle      # applicationId: "com.org.app_user"
│   │   └── ios/
│   │       └── Runner/
│   │           └── Info.plist        # Bundle ID: com.org.appUser
│   │
│   ├── app_doctor/                   # Doctor App (App B)
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── screens/
│   │   │   │   ├── dashboard_screen.dart
│   │   │   │   ├── chat_screen.dart
│   │   │   │   └── ...
│   │   │   └── services/
│   │   │       └── doctor_service.dart
│   │   ├── pubspec.yaml
│   │   ├── android/
│   │   │   └── app/
│   │   │       └── build.gradle      # applicationId: "com.org.app_doctor"
│   │   └── ios/
│   │       └── Runner/
│   │           └── Info.plist        # Bundle ID: com.org.appDoctor
│   │
│   └── app_admin/                    # Admin App (App C) - Optional
│       ├── lib/
│       ├── pubspec.yaml
│       └── ...
│
├── packages/                         # Shared Dart Packages
│   └── common/                      # Common Package
│       ├── lib/
│       │   ├── api/
│       │   │   ├── api_client.dart
│       │   │   └── endpoints.dart
│       │   ├── models/
│       │   │   ├── user.dart
│       │   │   ├── session.dart
│       │   │   ├── message.dart
│       │   │   └── ...
│       │   ├── websocket/
│       │   │   └── websocket_client.dart
│       │   ├── auth/
│       │   │   ├── token_manager.dart
│       │   │   └── auth_helper.dart
│       │   └── utils/
│       │       ├── date_formatter.dart
│       │       └── validators.dart
│       ├── pubspec.yaml
│       └── README.md
│
├── .github/                          # CI/CD Workflows
│   └── workflows/
│       ├── deploy-user-app.yml
│       ├── deploy-doctor-app.yml
│       └── deploy-admin-app.yml
│
├── docs/                             # Documentation
│   ├── MULTI_APP_ARCHITECTURE.md     # This file
│   ├── API_DOCUMENTATION.md
│   └── DEPLOYMENT_GUIDE.md
│
└── README.md                         # Main project README
```

### Directory Purpose

| Directory | Purpose |
|-----------|---------|
| `backend/` | Django REST API backend |
| `apps/app_user/` | End-user Flutter application |
| `apps/app_doctor/` | Healthcare provider Flutter application |
| `apps/app_admin/` | Administrative Flutter application |
| `packages/common/` | Shared Dart code package |
| `.github/workflows/` | CI/CD automation scripts |

---

## 4. Code Sharing Strategy

### What to Share in Common Package

#### ✅ Share These:

1. **API Client**
   - HTTP request handling
   - Token management
   - Error handling
   - Request/response interceptors

2. **Data Models**
   - User, Session, Message models
   - DTOs (Data Transfer Objects)
   - Enums and constants

3. **Authentication**
   - Token storage/retrieval
   - Token refresh logic
   - Auth state management

4. **WebSocket Client**
   - Connection management
   - Message sending/receiving
   - Reconnection logic

5. **Utilities**
   - Date/time formatting
   - Input validation
   - String manipulation
   - Network helpers

6. **Shared Widgets** (Optional)
   - Common UI components
   - Loading indicators
   - Error displays

#### ❌ Don't Share These:

1. **App-Specific Screens**
   - Each app has its own UI screens
   - Different navigation flows
   - Different user experiences

2. **App-Specific Services**
   - Business logic unique to each app
   - App-specific API endpoints

3. **App Configuration**
   - App names, icons, colors
   - Environment variables
   - Feature flags

### Creating the Common Package

#### Step 1: Create Package Structure

```bash
# Create package directory
mkdir -p packages/common

# Initialize Flutter package
cd packages/common
flutter create --template=package .

# This creates:
# packages/common/
#   ├── lib/
#   │   └── common.dart
#   ├── pubspec.yaml
#   └── README.md
```

#### Step 2: Configure pubspec.yaml

```yaml
name: common
description: Shared code package for multi-app architecture
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.0
  web_socket_channel: ^2.4.0
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
```

#### Step 3: Organize Code Structure

```
packages/common/lib/
├── api/
│   ├── api_client.dart          # Main HTTP client
│   ├── endpoints.dart            # API endpoint constants
│   └── interceptors.dart        # Request/response interceptors
│
├── models/
│   ├── user.dart                 # User model
│   ├── session.dart              # Session model
│   ├── message.dart              # Message model
│   └── base_model.dart           # Base model class
│
├── websocket/
│   ├── websocket_client.dart     # WebSocket client
│   └── message_handler.dart      # Message handling logic
│
├── auth/
│   ├── token_manager.dart        # Token storage/retrieval
│   ├── auth_helper.dart          # Auth utilities
│   └── auth_state.dart           # Auth state management
│
├── utils/
│   ├── date_formatter.dart       # Date formatting utilities
│   ├── validators.dart           # Input validation
│   └── constants.dart            # App constants
│
└── common.dart                   # Package entry point
```

#### Step 4: Example API Client Implementation

```dart
// packages/common/lib/api/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:common/auth/token_manager.dart';

class ApiClient {
  final String baseUrl;
  final TokenManager tokenManager;
  
  ApiClient({
    required this.baseUrl,
    required this.tokenManager,
  });

  Future<Map<String, dynamic>> get(String path) async {
    final token = await tokenManager.getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 401) {
      // Token expired, try refresh
      final refreshed = await tokenManager.refreshToken();
      if (refreshed) {
        return get(path); // Retry request
      }
      throw Exception('Authentication failed');
    }
    
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await tokenManager.getAccessToken();
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    
    if (response.statusCode == 401) {
      final refreshed = await tokenManager.refreshToken();
      if (refreshed) {
        return post(path, body); // Retry request
      }
      throw Exception('Authentication failed');
    }
    
    return json.decode(response.body);
  }
}
```

#### Step 5: Using Common Package in Apps

In each app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  common:
    path: ../../packages/common
  # ... other dependencies
```

In app code:

```dart
// apps/app_user/lib/services/user_service.dart
import 'package:common/api/api_client.dart';
import 'package:common/models/user.dart';
import 'package:common/auth/token_manager.dart';

class UserService {
  final ApiClient apiClient;
  
  UserService({required this.apiClient});
  
  Future<User> getProfile() async {
    final data = await apiClient.get('/api/profile/');
    return User.fromJson(data);
  }
}
```

---

## 5. Authentication & Authorization

### Backend Authentication Flow

#### User Registration/Login

```python
# backend/api/views.py
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework.response import Response

class CustomTokenObtainPairView(TokenObtainPairView):
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        
        if response.status_code == 200:
            user = self.user
            profile = user.profile
            
            # Determine user role
            role = 'user'
            if hasattr(user, 'adminprofile'):
                role = 'admin'
            elif hasattr(user, 'counsellorprofile'):
                role = 'counsellor'
            elif hasattr(user, 'doctorprofile'):
                role = 'doctor'
            
            # Add role to response
            data = response.data
            data['role'] = role
            data['user_id'] = user.id
            data['username'] = user.username
            
            return Response(data)
        return response
```

#### Role-Based Permissions

```python
# backend/api/permissions.py
from rest_framework import permissions

class IsAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and hasattr(request.user, 'adminprofile')

class IsCounsellor(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and (
            hasattr(request.user, 'counsellorprofile') or
            hasattr(request.user, 'adminprofile')
        )

class IsDoctor(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and (
            hasattr(request.user, 'doctorprofile') or
            hasattr(request.user, 'adminprofile')
        )
```

### Frontend Authentication

#### Token Manager Implementation

```dart
// packages/common/lib/auth/token_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userRoleKey = 'user_role';
  static const String _userIdKey = 'user_id';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String role,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_userRoleKey, role);
    await prefs.setInt(_userIdKey, userId);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  Future<bool> refreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveAccessToken(data['access']);
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userIdKey);
  }
}
```

#### Login Flow in Apps

```dart
// apps/app_user/lib/screens/login_screen.dart
import 'package:common/api/api_client.dart';
import 'package:common/auth/token_manager.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tokenManager = TokenManager();
  final _apiClient = ApiClient(
    baseUrl: 'https://api.example.com',
    tokenManager: _tokenManager,
  );

  Future<void> _login(String username, String password) async {
    try {
      final response = await _apiClient.post('/api/auth/token/', {
        'username': username,
        'password': password,
      });

      await _tokenManager.saveTokens(
        accessToken: response['access'],
        refreshToken: response['refresh'],
        role: response['role'],
        userId: response['user_id'],
      );

      // Navigate based on role
      final role = response['role'];
      if (role == 'user') {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Show error - wrong app
        _showError('Please use the correct app for your role');
      }
    } catch (e) {
      _showError('Login failed: $e');
    }
  }
}
```

---

## 6. Build Configuration

### Android Configuration

#### app_user/android/app/build.gradle

```gradle
android {
    namespace "com.yourorg.app_user"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.yourorg.app_user"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        
        // App-specific configuration
        resValue "string", "app_name", "Soul Support"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

#### app_doctor/android/app/build.gradle

```gradle
android {
    namespace "com.yourorg.app_doctor"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.yourorg.app_doctor"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        
        // App-specific configuration
        resValue "string", "app_name", "Soul Support Pro"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### iOS Configuration

#### app_user/ios/Runner/Info.plist

```xml
<key>CFBundleIdentifier</key>
<string>com.yourorg.appUser</string>
<key>CFBundleName</key>
<string>Soul Support</string>
<key>CFBundleDisplayName</key>
<string>Soul Support</string>
```

#### app_doctor/ios/Runner/Info.plist

```xml
<key>CFBundleIdentifier</key>
<string>com.yourorg.appDoctor</string>
<key>CFBundleName</key>
<string>Soul Support Pro</string>
<key>CFBundleDisplayName</key>
<string>Soul Support Pro</string>
```

### Environment Configuration

#### Using Dart Defines

```dart
// apps/app_user/lib/config/app_config.dart
class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.example.com',
  );
  
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Soul Support',
  );
  
  static const String packageId = 'com.yourorg.app_user';
}
```

Build commands:

```bash
# Development
flutter run --dart-define=API_URL=http://localhost:8000

# Production
flutter build apk --release --dart-define=API_URL=https://api.example.com
```

#### Using Config Files

```dart
// apps/app_user/lib/config/config.dart
class Config {
  static const String apiBaseUrl = 'https://api.example.com';
  static const String appName = 'Soul Support';
  static const String packageId = 'com.yourorg.app_user';
  static const bool enableDebugLogging = true;
}

// apps/app_doctor/lib/config/config.dart
class Config {
  static const String apiBaseUrl = 'https://api.example.com';
  static const String appName = 'Soul Support Pro';
  static const String packageId = 'com.yourorg.app_doctor';
  static const bool enableDebugLogging = true;
}
```

---

## 7. Deployment Strategy

### Separate Deployment Process

#### Step 1: Build Each App Independently

```bash
# Build User App
cd apps/app_user
flutter clean
flutter pub get
flutter build appbundle --release  # Android
flutter build ios --release          # iOS

# Build Doctor App
cd ../app_doctor
flutter clean
flutter pub get
flutter build appbundle --release  # Android
flutter build ios --release        # iOS
```

#### Step 2: App Store Listings

##### Google Play Store

1. **Create Two Separate App Listings:**
   - "Soul Support" (User App)
     - Package Name: `com.yourorg.app_user`
     - App ID: Unique Play Store ID
   - "Soul Support Pro" (Doctor App)
     - Package Name: `com.yourorg.app_doctor`
     - App ID: Unique Play Store ID

2. **Upload AAB Files:**
   - User App: `apps/app_user/build/app/outputs/bundle/release/app-release.aab`
   - Doctor App: `apps/app_doctor/build/app/outputs/bundle/release/app-release.aab`

3. **Configure Store Listings:**
   - Different app icons
   - Different descriptions
   - Different screenshots
   - Different pricing (if applicable)

##### Apple App Store

1. **Create Two Separate App Records:**
   - "Soul Support" (User App)
     - Bundle ID: `com.yourorg.appUser`
   - "Soul Support Pro" (Doctor App)
     - Bundle ID: `com.yourorg.appDoctor`

2. **Upload IPA Files:**
   - Use Xcode or `flutter build ipa`
   - Upload via App Store Connect

3. **Configure App Store Listings:**
   - Different app names
   - Different descriptions
   - Different screenshots
   - Different categories

### Deployment Checklist

#### Pre-Deployment

- [ ] Update version numbers in `pubspec.yaml`
- [ ] Update build numbers
- [ ] Test on physical devices
- [ ] Verify API endpoints
- [ ] Check app icons and splash screens
- [ ] Review app permissions
- [ ] Test authentication flow
- [ ] Verify push notifications (if applicable)

#### Android Deployment

- [ ] Generate signed AAB file
- [ ] Verify package name matches Play Console
- [ ] Upload to Play Console (Internal/Alpha/Beta)
- [ ] Complete store listing information
- [ ] Submit for review
- [ ] Monitor release status

#### iOS Deployment

- [ ] Configure signing certificates
- [ ] Update provisioning profiles
- [ ] Build IPA file
- [ ] Upload to App Store Connect
- [ ] Complete App Store listing
- [ ] Submit for review
- [ ] Monitor review status

---

## 8. CI/CD Pipeline

### GitHub Actions Workflow

#### Separate Workflows (Recommended)

##### Deploy User App

```yaml
# .github/workflows/deploy-user-app.yml
name: Deploy User App

on:
  push:
    branches: [main]
    paths:
      - 'apps/app_user/**'
      - 'packages/common/**'
  workflow_dispatch:

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Get dependencies
        run: |
          cd apps/app_user
          flutter pub get
          cd ../../packages/common
          flutter pub get

      - name: Build Android App Bundle
        run: |
          cd apps/app_user
          flutter build appbundle --release

      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.yourorg.app_user
          releaseFiles: apps/app_user/build/app/outputs/bundle/release/app-release.aab
          track: internal
          status: completed

  build-ios:
    runs-on: macos-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'

      - name: Get dependencies
        run: |
          cd apps/app_user
          flutter pub get
          cd ../../packages/common
          flutter pub get

      - name: Build iOS
        run: |
          cd apps/app_user/ios
          pod install
          cd ..
          flutter build ios --release --no-codesign

      - name: Upload to App Store
        # Add App Store Connect upload steps
```

##### Deploy Doctor App

```yaml
# .github/workflows/deploy-doctor-app.yml
name: Deploy Doctor App

on:
  push:
    branches: [main]
    paths:
      - 'apps/app_doctor/**'
      - 'packages/common/**'
  workflow_dispatch:

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'

      - name: Get dependencies
        run: |
          cd apps/app_doctor
          flutter pub get
          cd ../../packages/common
          flutter pub get

      - name: Build Android App Bundle
        run: |
          cd apps/app_doctor
          flutter build appbundle --release

      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.yourorg.app_doctor
          releaseFiles: apps/app_doctor/build/app/outputs/bundle/release/app-release.aab
          track: internal
          status: completed
```

#### Single Workflow with Conditions

```yaml
# .github/workflows/deploy-apps.yml
name: Deploy Apps

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      deploy_user:
        description: 'Deploy User App'
        type: boolean
        default: false
      deploy_doctor:
        description: 'Deploy Doctor App'
        type: boolean
        default: false

jobs:
  deploy-user-app:
    if: |
      contains(github.event.head_commit.message, '[deploy-user]') ||
      github.event.inputs.deploy_user == 'true' ||
      (github.event_name == 'push' && contains(github.event.head_commit.message, 'user'))
    runs-on: ubuntu-latest
    steps:
      # ... build and deploy user app

  deploy-doctor-app:
    if: |
      contains(github.event.head_commit.message, '[deploy-doctor]') ||
      github.event.inputs.deploy_doctor == 'true' ||
      (github.event_name == 'push' && contains(github.event.head_commit.message, 'doctor'))
    runs-on: ubuntu-latest
    steps:
      # ... build and deploy doctor app
```

### CI/CD Best Practices

1. **Separate Build Jobs**: Each app has its own build job
2. **Conditional Deployment**: Only deploy when relevant files change
3. **Version Management**: Auto-increment version numbers
4. **Testing**: Run tests before deployment
5. **Artifact Storage**: Store build artifacts for rollback
6. **Notification**: Notify team on deployment success/failure

---

## 9. Version Management

### Independent Versioning

Each app can have different version numbers:

```yaml
# apps/app_user/pubspec.yaml
version: 1.2.0+10
# 1.2.0 = version name
# 10 = build number

# apps/app_doctor/pubspec.yaml
version: 1.0.5+3
# 1.0.5 = version name
# 3 = build number
```

### Version Strategy

#### Semantic Versioning

- **Major (1.x.x)**: Breaking changes
- **Minor (x.1.x)**: New features, backward compatible
- **Patch (x.x.1)**: Bug fixes
- **Build Number (+N)**: Increment for each build

#### Version Update Scenarios

**Scenario 1: Update User App Only**
```yaml
# apps/app_user/pubspec.yaml
version: 1.2.0+10 → 1.3.0+11

# apps/app_doctor/pubspec.yaml
version: 1.0.5+3 (unchanged)
```

**Scenario 2: Update Doctor App Only**
```yaml
# apps/app_user/pubspec.yaml
version: 1.2.0+10 (unchanged)

# apps/app_doctor/pubspec.yaml
version: 1.0.5+3 → 1.0.6+4
```

**Scenario 3: Update Shared Package**
```yaml
# packages/common/pubspec.yaml
version: 1.0.0 → 1.1.0

# Both apps need rebuild, but versions can differ
# apps/app_user/pubspec.yaml
version: 1.2.0+10 → 1.2.1+11

# apps/app_doctor/pubspec.yaml
version: 1.0.5+3 → 1.0.6+4
```

### Automated Version Management

```bash
# scripts/update_version.sh
#!/bin/bash

APP=$1
VERSION_TYPE=$2  # major, minor, patch

if [ "$APP" == "user" ]; then
    cd apps/app_user
elif [ "$APP" == "doctor" ]; then
    cd apps/app_doctor
else
    echo "Invalid app name"
    exit 1
fi

# Read current version
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | cut -d' ' -f2)
MAJOR=$(echo $CURRENT_VERSION | cut -d'.' -f1 | cut -d'+' -f1)
MINOR=$(echo $CURRENT_VERSION | cut -d'.' -f2)
PATCH=$(echo $CURRENT_VERSION | cut -d'.' -f3 | cut -d'+' -f1)
BUILD=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Increment version
case $VERSION_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

BUILD=$((BUILD + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD"

# Update pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

echo "Updated $APP app version to $NEW_VERSION"
```

---

## 10. Real-World Scenarios

### Scenario 1: Update User App Only

**Situation**: Bug fix needed in user app only

**Steps**:
```bash
# 1. Make changes to user app
cd apps/app_user
# ... edit code ...

# 2. Update version
# Edit pubspec.yaml: version: 1.2.0+10 → 1.2.1+11

# 3. Build
flutter build appbundle --release

# 4. Deploy
# Upload to Play Store / App Store

# Doctor app remains unchanged
```

### Scenario 2: Update Doctor App Only

**Situation**: New feature for doctors

**Steps**:
```bash
# 1. Make changes to doctor app
cd apps/app_doctor
# ... add new feature ...

# 2. Update version
# Edit pubspec.yaml: version: 1.0.5+3 → 1.1.0+4

# 3. Build
flutter build appbundle --release

# 4. Deploy
# Upload to Play Store / App Store

# User app remains unchanged
```

### Scenario 3: Update Shared Package

**Situation**: Fix bug in common API client

**Steps**:
```bash
# 1. Fix bug in common package
cd packages/common
# ... fix API client bug ...

# 2. Update common package version
# Edit pubspec.yaml: version: 1.0.0 → 1.0.1

# 3. Update both apps to use new common version
cd ../apps/app_user
flutter pub get  # Updates common package

cd ../apps/app_doctor
flutter pub get  # Updates common package

# 4. Test both apps
cd ../apps/app_user
flutter test

cd ../apps/app_doctor
flutter test

# 5. Build and deploy both (or just one if needed)
cd ../apps/app_user
flutter build appbundle --release

cd ../apps/app_doctor
flutter build appbundle --release

# 6. Deploy both apps
```

### Scenario 4: Add New App

**Situation**: Add admin app

**Steps**:
```bash
# 1. Create new app
flutter create apps/app_admin

# 2. Configure package IDs
# Edit android/app/build.gradle: applicationId "com.yourorg.app_admin"
# Edit ios/Runner/Info.plist: Bundle ID com.yourorg.appAdmin

# 3. Add common package
# Edit pubspec.yaml:
# dependencies:
#   common:
#     path: ../../packages/common

# 4. Build app structure
# Create screens, services, etc.

# 5. Build and deploy
cd apps/app_admin
flutter build appbundle --release
# Upload to stores
```

---

## 11. Troubleshooting

### Common Issues and Solutions

#### Issue 1: Package ID Conflicts

**Problem**: Both apps have same package ID

**Solution**:
```gradle
// Verify in android/app/build.gradle
applicationId "com.yourorg.app_user"  // Must be unique
```

#### Issue 2: Common Package Not Found

**Problem**: `Error: Could not find package 'common'`

**Solution**:
```bash
# 1. Verify path in pubspec.yaml
dependencies:
  common:
    path: ../../packages/common  # Relative path from app

# 2. Run pub get
flutter pub get

# 3. Verify common package exists
ls packages/common/lib/
```

#### Issue 3: Build Fails After Common Package Update

**Problem**: App fails to build after updating common package

**Solution**:
```bash
# 1. Clean build
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Rebuild
flutter build apk --release
```

#### Issue 4: Token Not Shared Between Apps

**Problem**: User logs in on one app, but other app doesn't recognize login

**Solution**: This is expected behavior. Each app maintains its own token storage. If you need shared authentication, implement a shared token storage mechanism (e.g., Keychain on iOS, AccountManager on Android).

#### Issue 5: Different API URLs Per App

**Problem**: Need different API endpoints for different apps

**Solution**:
```dart
// Use environment variables or config files
class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.example.com',
  );
}
```

---

## 12. Best Practices

### Code Organization

1. **Keep App-Specific Code Separate**
   - Don't mix user app code with doctor app code
   - Use common package for shared logic only

2. **Consistent Naming Conventions**
   - Use clear, descriptive names
   - Follow Dart/Flutter naming conventions

3. **Documentation**
   - Document shared code thoroughly
   - Keep README files updated

### Version Management

1. **Semantic Versioning**
   - Follow semantic versioning strictly
   - Document breaking changes

2. **Version Coordination**
   - Coordinate major version updates
   - Keep patch versions independent

### Testing

1. **Test Shared Code**
   - Write tests for common package
   - Test each app independently

2. **Integration Testing**
   - Test API integration
   - Test authentication flows

### Security

1. **Token Management**
   - Store tokens securely
   - Implement token refresh logic

2. **API Security**
   - Use HTTPS in production
   - Validate all API responses

### Performance

1. **Code Splitting**
   - Minimize common package size
   - Lazy load when possible

2. **Build Optimization**
   - Use release builds for production
   - Enable code obfuscation

---

## 13. Migration Guide

### Migrating Existing Single App to Multi-App

#### Step 1: Create Project Structure

```bash
# Create new structure
mkdir -p apps/app_user
mkdir -p apps/app_doctor
mkdir -p packages/common

# Move existing app
mv flutter_app apps/app_user
```

#### Step 2: Extract Common Code

```bash
# Identify shared code
# - API client
# - Models
# - Utilities

# Move to common package
mkdir -p packages/common/lib/api
mkdir -p packages/common/lib/models
mkdir -p packages/common/lib/utils

# Move files
mv apps/app_user/lib/services/api_client.dart packages/common/lib/api/
mv apps/app_user/lib/models/* packages/common/lib/models/
```

#### Step 3: Update Dependencies

```yaml
# apps/app_user/pubspec.yaml
dependencies:
  common:
    path: ../../packages/common
```

#### Step 4: Create Second App

```bash
# Create doctor app
flutter create apps/app_doctor

# Configure package IDs
# Add common package dependency
```

#### Step 5: Test and Deploy

```bash
# Test both apps
cd apps/app_user && flutter test
cd ../app_doctor && flutter test

# Build both
cd apps/app_user && flutter build appbundle --release
cd ../app_doctor && flutter build appbundle --release
```

---

## 14. Execution Plan

### Phase 1: Setup (Week 1)

**Day 1-2: Project Structure**
- [ ] Create folder structure
- [ ] Set up common package
- [ ] Configure package dependencies

**Day 3-4: Extract Common Code**
- [ ] Identify shared code
- [ ] Move to common package
- [ ] Update imports

**Day 5: Testing**
- [ ] Test common package
- [ ] Verify app builds
- [ ] Fix any issues

### Phase 2: Multi-App Setup (Week 2)

**Day 1-2: Create Second App**
- [ ] Create app_doctor structure
- [ ] Configure package IDs
- [ ] Set up dependencies

**Day 3-4: App-Specific Development**
- [ ] Build doctor app screens
- [ ] Implement doctor-specific features
- [ ] Test doctor app

**Day 5: Integration Testing**
- [ ] Test both apps
- [ ] Verify API integration
- [ ] Test authentication

### Phase 3: Build & Deploy (Week 3)

**Day 1-2: Build Configuration**
- [ ] Configure Android builds
- [ ] Configure iOS builds
- [ ] Set up signing

**Day 3: CI/CD Setup**
- [ ] Create GitHub Actions workflows
- [ ] Configure secrets
- [ ] Test CI/CD pipeline

**Day 4-5: Deployment**
- [ ] Create app store listings
- [ ] Upload builds
- [ ] Submit for review

### Phase 4: Maintenance (Ongoing)

- [ ] Monitor app performance
- [ ] Collect user feedback
- [ ] Plan future updates
- [ ] Maintain documentation

---

## Conclusion

This multi-app architecture provides:

✅ **Flexibility**: Deploy apps independently
✅ **Efficiency**: Share code between apps
✅ **Scalability**: Easy to add new apps
✅ **Maintainability**: Single source of truth for shared code
✅ **Independence**: Each app can evolve separately

By following this guide, you can successfully build and deploy multiple Flutter applications from a single repository while maintaining code reusability and independent deployment capabilities.

---

## Additional Resources

- [Flutter Package Documentation](https://flutter.dev/docs/development/packages-and-plugins/developing-packages)
- [Dart Package Conventions](https://dart.dev/guides/libraries/create-library-packages)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)

---

**Last Updated**: 2024
**Version**: 1.0.0

