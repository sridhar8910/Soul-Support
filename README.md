# SoulSupport - Mental Health & Wellness Platform

A comprehensive mental health and wellness application built with Django REST Framework backend and Flutter mobile/desktop frontend. The platform provides counselling services, mood tracking, wellness tasks, journaling, meditation sessions, and professional guidance resources.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Configuration](#configuration)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Key Components](#key-components)
- [Running the Application](#running-the-application)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## 🎯 Project Overview

SoulSupport is a full-stack mental health platform that connects users with counsellors, provides self-care tools, and tracks wellness progress. The system includes:

- **User Authentication**: Email-based registration with OTP verification
- **Mood Tracking**: Daily mood check-ins with timezone-aware reset cycles
- **Wallet System**: Balance management for counselling sessions (calls/chat billing)
- **Wellness Tools**: Tasks, journaling, meditation, breathing exercises
- **Counselling Services**: Session scheduling, expert connect, support groups
- **Analytics**: Progress reports and mood trend visualization

## 🏗️ Architecture

### Backend (Django REST Framework)
- **Framework**: Django 5.2.8 with Django REST Framework
- **Authentication**: JWT tokens (Simple JWT)
- **Database**: SQLite (default, configurable for production)
- **CORS**: Enabled for cross-origin requests
- **API Style**: RESTful JSON APIs

### Frontend (Flutter)
- **Framework**: Flutter 3.3.0+
- **Platforms**: Android, iOS, Web, Windows, macOS, Linux
- **State Management**: StatefulWidget with setState
- **HTTP Client**: Custom ApiClient service
- **Navigation**: MaterialApp with named routes

### Communication
- **Protocol**: HTTP/HTTPS
- **Format**: JSON
- **Base URL**: `http://127.0.0.1:8000/api` (development)
- **Emulator URL**: `http://10.0.2.2:8000/api` (Android emulator)

## ✨ Features

### User Management
- ✅ Email-based registration with OTP verification
- ✅ Login with email/username and password
- ✅ Password reset functionality
- ✅ Profile management with nickname support
- ✅ User settings (notifications, dark mode, language, timezone)

### Mood Tracking
- ✅ Daily mood check-in (1-5 scale with half-point precision)
- ✅ 3 updates per day limit (resets at midnight in user's timezone)
- ✅ Mood history and analytics
- ✅ Timezone-aware reset cycles

### Wallet System
- ✅ Balance tracking in rupees (₹)
- ✅ Recharge functionality
- ✅ Service-based billing:
  - **Calls**: ₹5 per minute, minimum balance ₹100
  - **Chat**: ₹1 per minute, minimum balance ₹50
- ✅ New user welcome bonus: ₹100
- ✅ Insufficient balance warnings

### Wellness Features
- ✅ **Wellness Tasks**: Daily and evening tasks with completion tracking
- ✅ **Journaling**: Wellness journal entries with mood tags
- ✅ **Meditation**: Guided meditation sessions by category
- ✅ **Breathing Exercises**: Interactive breathing exercises with customizable cycle lengths
- ✅ **MindCare Boosters**: Quick wellness activities (breathing, movement, reflection, audio)
- ✅ **Music Tracks**: Mood-based music library

### Counselling Services
- ✅ **Session Scheduling**: Book counselling sessions (minimum 10 minutes ahead, recommended 1 hour)
- ✅ **Expert Connect**: Browse and connect with counsellors
- ✅ **Support Groups**: Join community support groups
- ✅ **Chat Interface**: Real-time chat with counsellors (wallet-based)
- ✅ **History Center**: View past sessions and activities

### Analytics & Reports
- ✅ Mood trends (weekly/monthly)
- ✅ Task completion statistics
- ✅ Session attendance tracking
- ✅ Personalized insights

### Content Library
- ✅ Professional guidance resources (articles, podcasts, videos)
- ✅ Meditation sessions by category
- ✅ Music tracks by mood
- ✅ MindCare booster activities

## 📁 Project Structure

```
project/
├── backend/                    # Django backend application
│   ├── api/                    # Main API app
│   │   ├── models.py          # Database models
│   │   ├── views.py           # API view handlers
│   │   ├── serializers.py     # Request/response serializers
│   │   ├── urls.py            # URL routing
│   │   ├── migrations/        # Database migrations
│   │   └── admin.py           # Django admin configuration
│   ├── core/                   # Django project settings
│   │   ├── settings.py        # Main configuration
│   │   ├── urls.py            # Root URL configuration
│   │   └── wsgi.py            # WSGI application
│   ├── manage.py              # Django management script
│   ├── requirements.txt       # Python dependencies
│   ├── db.sqlite3             # SQLite database (development)
│   └── venv/                   # Python virtual environment
│
├── flutter_app/                # Flutter frontend application
│   ├── lib/
│   │   ├── main.dart          # Application entry point
│   │   ├── services/
│   │   │   └── api_client.dart # API communication service
│   │   └── screens/           # UI screens
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       ├── home_screen.dart
│   │       ├── wallet_page.dart
│   │       ├── schedule_session_page.dart
│   │       └── ... (other screens)
│   ├── android/               # Android-specific configuration
│   ├── ios/                   # iOS-specific configuration
│   ├── pubspec.yaml           # Flutter dependencies
│   └── assets/                # Images, fonts, etc.
│
├── run_android.ps1            # Android launch script
├── run_all.ps1               # Full stack launch script
└── README.md                 # This file
```

## 🔧 Prerequisites

### Required Software
- **Windows 10/11** (or macOS/Linux with appropriate script modifications)
- **PowerShell** (for Windows scripts)
- **Python 3.11+**
- **Flutter SDK 3.3.0+**
- **Git**

### Optional (for mobile development)
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **Android SDK** (via Android Studio)
- **Android Emulator** or physical device

### Development Tools
- **Code Editor**: VS Code, Android Studio, or any IDE with Flutter/Dart support
- **Postman/Insomnia**: For API testing (optional)
- **Database Browser**: SQLite Browser (optional)

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd project
```

### 2. Backend Setup

#### Option A: Use Pre-configured Virtual Environment
The repository includes a virtual environment at `backend/venv/`. You can use it directly.

#### Option B: Create New Virtual Environment
```powershell
# Windows PowerShell
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Or use backend/venv
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
```

#### Install Dependencies
```powershell
cd backend
pip install -r requirements.txt
```

#### Run Migrations
```powershell
python manage.py migrate
```

#### Create Superuser (Optional)
```powershell
python manage.py createsuperuser
```

### 3. Flutter Setup

#### Install Flutter Dependencies
```powershell
cd flutter_app
flutter pub get
```

#### Verify Flutter Installation
```powershell
flutter doctor
```

#### Fix Android Setup (if needed)
```powershell
flutter doctor --android-licenses
```

### 4. Environment Configuration

#### Backend Settings (`backend/core/settings.py`)
Update these for production:
- `SECRET_KEY`: Generate a secure key
- `DEBUG`: Set to `False` in production
- `ALLOWED_HOSTS`: Specify your domain
- `CORS_ALLOW_ALL_ORIGINS`: Set to `False` and specify allowed origins
- `EMAIL_BACKEND`: Configure SMTP for production

#### Flutter Configuration
- Base URL is configured in `flutter_app/lib/services/api_client.dart`
- Default: `http://127.0.0.1:8000/api`
- For Android emulator: `http://10.0.2.2:8000/api`
- Can be overridden via `BACKEND_BASE_URL` environment variable

## ⚙️ Configuration

### Backend Environment Variables
Create a `.env` file in `backend/` (or set environment variables):

```env
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
DATABASE_URL=sqlite:///db.sqlite3
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@example.com
EMAIL_HOST_PASSWORD=your-password
```

### Flutter Environment Variables
Set `BACKEND_BASE_URL` before running:
```powershell
$env:BACKEND_BASE_URL="http://your-backend-url/api"
flutter run
```

### Android Configuration
- **Internet Permission**: Already configured in `AndroidManifest.xml`
- **Cleartext Traffic**: Enabled for HTTP connections (development only)
- **Network Security**: Configure in `android/app/src/main/res/xml/network_security_config.xml` for production

## 📡 API Documentation

### Authentication Endpoints

#### Register User
```
POST /api/auth/register/
Body: {
  "username": "string",
  "email": "string",
  "password": "string",
  "full_name": "string",
  "nickname": "string",
  "phone": "string",
  "age": integer,
  "gender": "string",
  "otp_token": "string"
}
```

#### Send Registration OTP
```
POST /api/auth/send-otp/
Body: {
  "email": "string"
}
```

#### Verify OTP
```
POST /api/auth/verify-otp/
Body: {
  "email": "string",
  "code": "string"
}
Response: {
  "token": "string"
}
```

#### Login
```
POST /api/auth/token/
Body: {
  "username": "string",  // or email
  "password": "string"
}
Response: {
  "access": "jwt-token",
  "refresh": "refresh-token"
}
```

#### Refresh Token
```
POST /api/auth/token/refresh/
Body: {
  "refresh": "refresh-token"
}
```

### User Profile Endpoints

#### Get Profile
```
GET /api/profile/
Headers: Authorization: Bearer <token>
Response: {
  "username": "string",
  "email": "string",
  "full_name": "string",
  "nickname": "string",
  "phone": "string",
  "age": integer,
  "gender": "string",
  "wallet_minutes": integer,
  "last_mood": integer,
  "timezone": "string",
  ...
}
```

#### Update Profile
```
PUT /api/profile/
Headers: Authorization: Bearer <token>
Body: {
  "full_name": "string",
  "nickname": "string",
  "phone": "string",
  "age": integer,
  "gender": "string"
}
```

#### Get User Settings
```
GET /api/settings/
Headers: Authorization: Bearer <token>
```

#### Update User Settings
```
PUT /api/settings/
Headers: Authorization: Bearer <token>
Body: {
  "full_name": "string",
  "nickname": "string",
  "phone": "string",
  "age": integer,
  "gender": "string",
  "timezone": "string",
  "notifications_enabled": boolean,
  "prefers_dark_mode": boolean,
  "language": "string"
}
```

### Mood Tracking Endpoints

#### Update Mood
```
POST /api/mood/
Headers: Authorization: Bearer <token>
Body: {
  "value": integer,  // 1-5
  "timezone": "string"  // optional
}
Response: {
  "status": "ok",
  "mood": integer,
  "updates_used": integer,
  "updates_remaining": integer
}
// Or if limit reached:
Response: {
  "status": "limit_reached",
  "reset_at_local": "ISO datetime",
  "timezone": "string",
  "updates_used": integer,
  "updates_remaining": integer
}
```

### Wallet Endpoints

#### Get Wallet Balance
```
GET /api/wallet/
Headers: Authorization: Bearer <token>
Response: {
  "wallet_minutes": integer,  // Balance in rupees
  "rates": {
    "call": 5,  // ₹5 per minute
    "chat": 1   // ₹1 per minute
  },
  "minimum_balance": {
    "call": 100,  // ₹100 minimum
    "chat": 50    // ₹50 minimum
  }
}
```

#### Recharge Wallet
```
POST /api/wallet/recharge/
Headers: Authorization: Bearer <token>
Body: {
  "minutes": integer  // Amount in rupees
}
Response: {
  "status": "ok",
  "wallet_minutes": integer
}
```

#### Use Wallet (Deduct for Service)
```
POST /api/wallet/use/
Headers: Authorization: Bearer <token>
Body: {
  "service": "call" | "chat",
  "minutes": integer
}
Response: {
  "status": "ok",
  "wallet_minutes": integer,
  "amount_charged": integer,
  "rate_per_minute": integer
}
// Or if insufficient balance:
Response: {
  "error": "Insufficient balance",
  "required": integer,
  "available": integer
}
```

### Wellness Endpoints

#### Wellness Tasks
```
GET /api/wellness/tasks/
POST /api/wellness/tasks/
GET /api/wellness/tasks/<id>/
PUT /api/wellness/tasks/<id>/
DELETE /api/wellness/tasks/<id>/
```

#### Wellness Journal
```
GET /api/wellness/journals/
POST /api/wellness/journals/
GET /api/wellness/journals/<id>/
PUT /api/wellness/journals/<id>/
DELETE /api/wellness/journals/<id>/
```

### Session Endpoints

#### List/Create Sessions
```
GET /api/sessions/
POST /api/sessions/
```

#### Session Detail
```
GET /api/sessions/<id>/
PUT /api/sessions/<id>/
DELETE /api/sessions/<id>/
```

#### Quick Session
```
POST /api/sessions/quick/
Body: {
  "date": "YYYY-MM-DD",
  "time": "HH:MM:SS",
  "title": "string",
  "notes": "string"
}
```

### Content Endpoints

#### Meditation Sessions
```
GET /api/content/meditations/
Query Params: ?category=<category>
```

#### Music Tracks
```
GET /api/content/music/
Query Params: ?mood=<mood>
```

#### MindCare Boosters
```
GET /api/content/boosters/
Query Params: ?category=<category>
```

#### Professional Guidance
```
GET /api/guidance/resources/
Query Params: ?resource_type=<type>&category=<category>
```

### Analytics Endpoints

#### Reports & Analytics
```
GET /api/reports/analytics/
Headers: Authorization: Bearer <token>
Response: {
  "mood": {
    "weekly": [...],
    "monthly": [...]
  },
  "tasks": {...},
  "sessions": {...},
  "wallet": {...},
  "insight": "string"
}
```

## 🗄️ Database Schema

### Core Models

#### UserProfile
- `user` (OneToOne with Django User)
- `full_name` (CharField, max 120)
- `nickname` (CharField, max 80) - Shown to counsellors
- `phone` (CharField, max 30)
- `age` (PositiveIntegerField)
- `gender` (CharField, max 50)
- `wallet_minutes` (PositiveIntegerField, default 100) - Balance in rupees
- `last_mood` (PositiveSmallIntegerField, 1-5)
- `last_mood_updated` (DateTimeField)
- `mood_updates_count` (PositiveSmallIntegerField)
- `mood_updates_date` (DateField)
- `timezone` (CharField, max 64)
- `notifications_enabled` (BooleanField)
- `prefers_dark_mode` (BooleanField)
- `language` (CharField, default "English")

#### WellnessTask
- `user` (ForeignKey)
- `title` (CharField)
- `category` (CharField: "daily" | "evening")
- `is_completed` (BooleanField)
- `order` (PositiveIntegerField)

#### WellnessJournalEntry
- `user` (ForeignKey)
- `title` (CharField)
- `note` (TextField)
- `mood` (CharField)
- `entry_type` (CharField: "3-Day Journal" | "Weekly Journal" | "Custom")

#### UpcomingSession
- `user` (ForeignKey)
- `title` (CharField)
- `session_type` (CharField)
- `start_time` (DateTimeField)
- `counsellor_name` (CharField)
- `notes` (TextField)
- `is_confirmed` (BooleanField)

#### SupportGroup & SupportGroupMembership
- Groups with slug, name, description
- Many-to-many relationship with users

#### MoodLog
- `user` (ForeignKey)
- `value` (PositiveSmallIntegerField)
- `recorded_at` (DateTimeField)

#### Content Models
- `MeditationSession`: Guided meditation content
- `MusicTrack`: Mood-based music library
- `MindCareBooster`: Quick wellness activities
- `GuidanceResource`: Articles, podcasts, videos

## 🔑 Key Components

### Backend Components

#### ApiClient Service (`flutter_app/lib/services/api_client.dart`)
Centralized HTTP client handling:
- JWT token management (storage, refresh)
- Request/response serialization
- Error handling
- Base URL configuration

#### Authentication Flow
1. User registers with email → OTP sent
2. User verifies OTP → receives token
3. User completes registration with token
4. User logs in → receives access/refresh tokens
5. Tokens stored in shared preferences
6. Auto-refresh on 401 responses

#### Wallet Billing Logic
- **Call Sessions**: ₹5/minute, minimum ₹100 balance
- **Chat Sessions**: ₹1/minute, minimum ₹50 balance
- Real-time balance checks before service start
- Automatic deduction on session end

#### Mood Tracking Logic
- Timezone-aware daily reset (midnight in user's timezone)
- 3 updates per day limit
- Half-point precision (1.0 to 5.0)
- Reset time display in UI

### Frontend Components

#### Home Screen (`home_screen.dart`)
Main dashboard featuring:
- Welcome header with nickname
- Daily mood check-in card
- Upcoming sessions card
- Quick access grid (Schedule, Mental Health, Expert Connect, etc.)
- Wellness extras section
- Drawer navigation
- Floating chat button

#### Registration Flow (`register_screen.dart`)
Multi-step registration:
1. Basic info (username, name, age, gender, phone, email)
2. Email OTP verification
3. Password creation with validation
4. Terms & Privacy agreement

#### Schedule Session (`schedule_session_page.dart`)
Session booking with:
- Date/time pickers
- 1-hour ahead recommendation
- 10-minute minimum validation
- Optional notes for counsellor

#### Wallet Management (`wallet_page.dart`)
- Balance display in rupees
- Recharge options (₹100, ₹200, ₹300, ₹500, custom)
- Service rate display
- Minimum balance warnings

## 🏃 Running the Application

### Quick Start (Full Stack)

#### Windows PowerShell
```powershell
# Run everything (backend + Flutter)
.\run_all.ps1

# Run on Android
.\run_android.ps1

# Run on specific device
.\run_all.ps1 -Device chrome
.\run_all.ps1 -Device windows
```

### Individual Components

#### Backend Only
```powershell
cd backend
.\venv\Scripts\Activate.ps1
python manage.py runserver 0.0.0.0:8000
```

#### Flutter Only
```powershell
cd flutter_app
flutter run -d windows
flutter run -d chrome
flutter run -d <device-id>  # For Android/iOS
```

### Android Development

#### Check Connected Devices
```powershell
adb devices
```

#### Launch Emulator
```powershell
emulator -avd <avd-name>
```

#### Run on Android
```powershell
cd flutter_app
flutter run -d <device-id>
```

## 💻 Development Workflow

### Backend Development

1. **Make Model Changes**
   ```powershell
   cd backend
   python manage.py makemigrations
   python manage.py migrate
   ```

2. **Create Superuser** (if needed)
   ```powershell
   python manage.py createsuperuser
   ```

3. **Access Admin Panel**
   ```
   http://localhost:8000/admin/
   ```

4. **Run Tests**
   ```powershell
   python manage.py test
   ```

### Flutter Development

1. **Hot Reload**: Press `r` in terminal
2. **Hot Restart**: Press `R` in terminal
3. **Full Restart**: Stop and run again
4. **Clear Build**: `flutter clean && flutter pub get`

### Code Structure

#### Adding New API Endpoint
1. Add model in `backend/api/models.py`
2. Create migration: `python manage.py makemigrations`
3. Add serializer in `backend/api/serializers.py`
4. Add view in `backend/api/views.py`
5. Add URL in `backend/api/urls.py`
6. Update Flutter `ApiClient` service
7. Create Flutter screen/widget

#### Adding New Flutter Screen
1. Create file in `flutter_app/lib/screens/`
2. Add route in `main.dart` or use `Navigator.push`
3. Update navigation in parent screens
4. Test on target platform

## 🧪 Testing

### Backend Tests
```powershell
cd backend
python manage.py test
python manage.py test api.tests
```

### Flutter Tests
```powershell
cd flutter_app
flutter test
flutter test test/widget_test.dart
```

### Integration Testing
1. Start backend: `python manage.py runserver`
2. Run Flutter: `flutter run`
3. Test user flows manually
4. Check API responses in browser/Postman

## 🚢 Deployment

### Backend Deployment

#### Production Settings
Update `backend/core/settings.py`:
```python
DEBUG = False
SECRET_KEY = os.environ.get('SECRET_KEY')
ALLOWED_HOSTS = ['your-domain.com']
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = ['https://your-frontend-domain.com']
```

#### Database Migration
```powershell
python manage.py migrate
python manage.py collectstatic
```

#### WSGI Server
Use Gunicorn or uWSGI:
```bash
gunicorn core.wsgi:application --bind 0.0.0.0:8000
```

### Flutter Deployment

#### Android APK
```powershell
cd flutter_app
flutter build apk --release
flutter build appbundle --release
```

#### iOS
```powershell
flutter build ios --release
```

#### Web
```powershell
flutter build web --release
```

### Environment Variables
Set production backend URL:
```powershell
$env:BACKEND_BASE_URL="https://api.yourdomain.com/api"
```

## 🐛 Troubleshooting

### Common Issues

#### Backend Issues

**Migration Errors**
```powershell
# Reset migrations (development only)
python manage.py migrate api zero
python manage.py migrate
```

**Port Already in Use**
```powershell
# Find process using port 8000
netstat -ano | findstr :8000
# Kill process
taskkill /PID <process-id> /F
```

**Import Errors**
```powershell
# Reinstall dependencies
pip install -r requirements.txt --force-reinstall
```

#### Flutter Issues

**Build Errors**
```powershell
flutter clean
flutter pub get
flutter run
```

**Android Build Issues**
```powershell
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**Emulator Not Detected**
```powershell
adb kill-server
adb start-server
adb devices
```

**Asset Not Found**
```powershell
flutter clean
flutter pub get
# Ensure assets are listed in pubspec.yaml
```

#### Connection Issues

**Backend Not Reachable from Flutter**
- Check backend is running: `http://localhost:8000/api/`
- For Android emulator, use `http://10.0.2.2:8000/api`
- Check CORS settings in `settings.py`
- Verify firewall isn't blocking port 8000

**JWT Token Expired**
- Tokens auto-refresh on 401
- Check token storage in shared preferences
- Verify `SIMPLE_JWT` settings in `settings.py`

### Debug Tips

1. **Enable Debug Logging**
   - Backend: Set `DEBUG=True` in `settings.py`
   - Flutter: Use `debugPrint()` statements

2. **Check Network Requests**
   - Use browser DevTools (Network tab)
   - Use Flutter DevTools
   - Check backend logs

3. **Database Inspection**
   - Use SQLite Browser for `db.sqlite3`
   - Use Django admin: `/admin/`
   - Use Django shell: `python manage.py shell`

4. **Flutter Hot Reload Issues**
   - Full restart: Stop app, run again
   - Clear build: `flutter clean`

## 📝 Additional Notes

### Wallet System Details
- New users receive ₹100 welcome bonus
- Balance stored as `wallet_minutes` (represents rupees)
- Minimum balances enforced before service start
- Real-time deduction on session completion

### Mood Tracking Details
- Updates limited to 3 per day
- Resets at midnight in user's timezone
- Half-point precision (1.0, 1.5, 2.0, ..., 5.0)
- Timezone stored in user profile

### Session Scheduling
- Minimum 10 minutes ahead required
- Recommended 1 hour ahead
- Validation on both frontend and backend
- Timezone-aware scheduling

### Nickname System
- Collected during registration
- Shown to counsellors/doctors instead of full name
- Editable in profile settings
- Used in all user-facing displays

## 📄 License

[Specify your license here]

## 👥 Contributors

[Add contributor information]

## 📞 Support

For issues, questions, or contributions, please [create an issue] or [contact support].

---

**Last Updated**: [Current Date]
**Version**: 1.0.0
