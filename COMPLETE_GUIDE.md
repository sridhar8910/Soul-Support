# SoulSupport - Complete Project Guide

**One file to understand everything about the project.**

> **Note:** For detailed technical documentation, see [PROJECT_DOCUMENTATION.md](../PROJECT_DOCUMENTATION.md).  
> For multi-app architecture patterns, see [MULTI_APP_ARCHITECTURE.md](../MULTI_APP_ARCHITECTURE.md).

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Project Overview](#project-overview)
3. [Architecture](#architecture)
4. [Setup & Installation](#setup--installation)
5. [Running the Project](#running-the-project)
6. [WebRTC Implementation](#webrtc-implementation)
7. [Features](#features)
8. [Testing](#testing)
9. [Deployment](#deployment)
10. [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Flutter 3.24.0+
- Docker (optional, for TURN server)

### Run Everything
```powershell
# Set execution policy (one time)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Run all apps
.\run_all_apps_simple.ps1
```

This starts:
- Backend: http://127.0.0.1:8000
- User App: Flutter on Chrome
- Counsellor App: Flutter on Chrome

---

## 📖 Project Overview

**SoulSupport** is a mental health platform connecting users with counsellors via:
- **Video/Audio Calls** (WebRTC)
- **Real-time Chat** (WebSocket)
- **Wellness Tools** (mood tracking, journaling, meditation)
- **Session Scheduling**

### Apps
- **User App** (`apps/app_user/`) - Patient-facing app
- **Counsellor App** (`apps/app_counsellor/`) - Provider-facing app
- **Common Package** (`packages/common/`) - Shared code

### Backend
- **Django REST Framework** - API server
- **Django Channels** - WebSocket support
- **PostgreSQL/SQLite** - Database
- **Redis** - Caching & Channels layer
- **Coturn** - TURN server for WebRTC

---

## 🏗️ Architecture

### Multi-App Structure
```
project/
├── backend/              # Django API
├── apps/
│   ├── app_user/        # User app (com.soulsupport.user)
│   └── app_counsellor/  # Counsellor app (com.soulsupport.counsellor)
└── packages/
    └── common/          # Shared code (API client, models, widgets)
```

### Key Components

**Backend:**
- `api/models.py` - Database models
- `api/views/` - API endpoints
- `api/consumers_webrtc.py` - WebRTC WebSocket handler
- `api/utils/turn_credentials.py` - TURN server credentials

**Frontend:**
- `lib/webrtc/webrtc_manager.dart` - WebRTC connection manager
- `lib/webrtc/webrtc_signaling.dart` - WebSocket signaling
- `lib/screens/video_call_screen.dart` - Call UI

**Common:**
- `lib/api/api_client.dart` - HTTP client with JWT
- `lib/auth/token_manager.dart` - Token storage
- `lib/widgets/` - Shared UI components

---

## ⚙️ Setup & Installation

### 1. Backend Setup

```powershell
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
```

### 2. Flutter Setup

```powershell
# Common package
cd packages/common
flutter pub get

# User app
cd ../../apps/app_user
flutter pub get

# Counsellor app
cd ../app_counsellor
flutter pub get
```

### 3. TURN Server (Optional - for WebRTC)

```bash
# Using Docker
docker compose up -d coturn

# Or configure in backend/api/utils/turn_credentials.py
TURN_SERVER=localhost
TURN_PORT=3478
TURN_SHARED_SECRET=your-secret-key
```

---

## 🏃 Running the Project

### Option 1: All-in-One Script
```powershell
.\run_all_apps_simple.ps1
```

### Option 2: Manual

**Terminal 1 - Backend:**
```powershell
cd backend
.\venv\Scripts\activate
python manage.py runserver 0.0.0.0:8000
```

**Terminal 2 - User App:**
```powershell
cd apps/app_user
flutter run -d chrome
```

**Terminal 3 - Counsellor App:**
```powershell
cd apps/app_counsellor
flutter run -d chrome
```

---

## 📞 WebRTC Implementation

### Overview
WebRTC enables video/audio calls between users and counsellors.

### How It Works

1. **User Creates Call**
   - API: `POST /api/calls/create/`
   - Returns: `call_id`, `turn_config`, `websocket_url`

2. **User Connects**
   - WebSocket: `ws://host/ws/webrtc/{call_id}/?token={jwt}`
   - Creates offer → sends via WebSocket

3. **Counsellor Accepts**
   - API: `PATCH /api/calls/{call_id}/accept/`
   - Connects to WebSocket
   - Receives offer → creates answer → sends answer

4. **Connection Established**
   - ICE candidates exchanged
   - Media streams flow
   - Audio/video works

### Key Files

**Backend:**
- `api/consumers_webrtc.py` - WebSocket handler with message replay
- `api/views/call_views.py` - Call API endpoints
- `api/utils/turn_credentials.py` - TURN credentials (cached in Redis)

**Frontend:**
- `lib/webrtc/webrtc_manager.dart` - WebRTC connection manager
- `lib/webrtc/webrtc_signaling.dart` - WebSocket signaling
- `lib/screens/video_call_screen.dart` - Call UI

### Features

✅ **Message Replay** - Handles race conditions (offers sent before callee connects)
✅ **TURN Caching** - Redis-based credential caching (faster responses)
✅ **Platform Detection** - Works on Chrome, Android, iOS (graceful fallback on desktop)
✅ **Audio Fix** - Hidden renderer for audio-only calls on web
✅ **Idempotent Accept** - Counsellor can retry accept without 404 errors

### Audio Playback Fix

**Problem:** Audio tracks received but not playing on web.

**Solution:**
- For audio-only calls: Initialize hidden `RTCVideoRenderer` on web
- For video calls: Renderer handles audio automatically
- Always enable audio tracks explicitly
- Works on all platforms (web, Android, iOS)

---

## ✨ Features

### Authentication
- Email registration with OTP
- JWT token-based login
- Password reset
- Role-based access (user, counsellor, doctor, admin)

### Wallet System
- Balance in rupees (₹)
- Recharge functionality
- Billing: Calls ₹5/min, Chat ₹1/min
- Minimum balance checks

### Mood Tracking
- Daily mood check-in (1-5 scale)
- 3 updates per day limit
- Timezone-aware resets
- Analytics and trends

### Wellness Tools
- Wellness tasks (daily/evening)
- Journaling with mood tags
- Meditation sessions
- Breathing exercises
- MindCare boosters

### Counselling
- Session scheduling
- Video/audio calls (WebRTC)
- Real-time chat (WebSocket)
- Support groups
- History tracking

---

## 🧪 Testing

### WebRTC Testing

**Prerequisites:**
- Backend running on port 8000
- TURN server configured (for NAT traversal)
- Two devices/browsers
- Camera and microphone permissions

**Test Flow:**
1. User creates call → appears in counsellor queue
2. Counsellor accepts → both connect
3. Verify audio/video works
4. Test controls (mute, video toggle, speaker)
5. End call → verify cleanup

**Network Scenarios:**
- **Same network** (Wi-Fi) - May use STUN only, fast connection
- **Different networks** - Requires TURN, connection may take 5-10 seconds
- **Mobile data** - Requires TURN, quality depends on signal

**Physical Device Testing Checklist:**
- [ ] Camera/microphone permissions granted
- [ ] Backend accessible from device
- [ ] TURN server accessible
- [ ] WebSocket connection works
- [ ] Audio/video quality acceptable
- [ ] Controls work (mute, video, speaker, switch camera)
- [ ] Call timer updates correctly
- [ ] Call ends properly
- [ ] No memory leaks (test multiple calls)

### API Testing

```bash
# Get TURN credentials
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:8000/api/calls/turn-credentials/

# Create call
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"call_type": "video"}' \
  http://localhost:8000/api/calls/create/

# Accept call (counsellor)
curl -X PATCH -H "Authorization: Bearer TOKEN" \
  http://localhost:8000/api/calls/1/accept/
```

### TURN Server Testing

```bash
# Test STUN
turnutils_stunclient localhost:3478

# Test TURN (with credentials from API)
turnutils_client localhost:3478 -u username -w password
```

---

## 🚢 Deployment

### Docker Setup (Recommended)

**Quick Start:**
```bash
# Build and start all services
docker compose up -d --build

# Run migrations
docker compose exec web python manage.py migrate

# Create superuser
docker compose exec web python manage.py createsuperuser

# View logs
docker compose logs -f
```

**Services:**
- **PostgreSQL** - Database
- **Redis** - Channel layer & caching
- **Django (Daphne)** - ASGI server
- **Nginx** - Reverse proxy
- **Coturn** - TURN server

**Ports:**
- `80` - HTTP (Nginx)
- `443` - HTTPS (Nginx)
- `3478` - STUN/TURN (Coturn)
- `5349` - TURN over TLS (Coturn)
- `49152-65535` - TURN relay ports

### Backend Deployment

**Production Settings:**
```python
DEBUG = False
SECRET_KEY = os.environ.get('SECRET_KEY')
ALLOWED_HOSTS = ['your-domain.com']
CORS_ALLOWED_ORIGINS = ['https://your-frontend.com']
```

**Environment Variables:**
```bash
TURN_SERVER=your-turn-server.com
TURN_SHARED_SECRET=your-secret-key
REDIS_HOST=redis
REDIS_PORT=6379
```

**TURN Server Configuration:**
- Edit `deploy/coturn/turnserver.conf`
- Set `external-ip` to your public IP
- Generate `static-auth-secret`: `openssl rand -hex 32`
- Configure `realm` to your domain

### Flutter Apps

**Build Commands:**
```bash
# Android
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

**App Store Deployment:**
- User App: `com.soulsupport.user`
- Counsellor App: `com.soulsupport.counsellor`
- Separate listings on Google Play & App Store

---

## 🐛 Troubleshooting

### Backend Issues

**Port 8000 in use:**
```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

**Migration errors:**
```bash
python manage.py migrate --run-syncdb
```

### Flutter Issues

**Build errors:**
```bash
flutter clean
flutter pub get
flutter run
```

**Import errors:**
- Verify `packages/common` is set up
- Run `flutter pub get` in all apps

### WebRTC Issues

**No audio:**
- Check permissions (camera/microphone)
- Verify audio tracks are enabled
- Check browser console for errors
- Ensure renderer is initialized for audio-only calls

**Connection fails:**
- Verify TURN server is running
- Check TURN credentials are valid
- Verify firewall allows ports 3478, 49152-65535
- Check WebSocket connection

**Race condition (caller connects first):**
- ✅ Fixed with message replay in backend
- Backend stores and replays missed offers/answers

---

## 📚 Additional Documentation

For more details, see:
- **MULTI_APP_ARCHITECTURE.md** - Detailed architecture guide
- **PROJECT_DOCUMENTATION.md** - Comprehensive technical docs
- **TESTING_GUIDE.md** - Detailed testing instructions

---

## 🔗 Key Endpoints

### Authentication
- `POST /api/auth/token/` - Login
- `POST /api/auth/register/` - Register
- `POST /api/auth/token/refresh/` - Refresh token

### Calls
- `POST /api/calls/create/` - Create call
- `GET /api/calls/queued/` - List queued calls
- `PATCH /api/calls/{id}/accept/` - Accept call
- `POST /api/calls/{id}/end/` - End call
- `GET /api/calls/turn-credentials/` - Get TURN config

### WebSocket
- `ws://host/ws/webrtc/{call_id}/?token={jwt}` - WebRTC signaling

---

## 📝 Notes

- **WebRTC** works on Chrome, Android, iOS (not Windows desktop)
- **TURN server** required for NAT traversal in production
- **Message replay** handles race conditions automatically
- **TURN credentials** cached in Redis (55 min TTL)
- **Audio** works via hidden renderer on web for audio-only calls

---

**Last Updated:** 2025-01-07
**Version:** 1.0.0

