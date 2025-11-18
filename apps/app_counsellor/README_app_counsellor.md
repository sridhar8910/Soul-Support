# Counselor App

A comprehensive Flutter application for counselors to manage therapy sessions, client records, availability, and performance tracking.

## Features

### 1. Dashboard
- Welcome card with counselor profile
- Quick stats: Today's sessions, queued chats, pending tasks
- Quick actions: Manage schedule, view clients, block time off, profile management
- Upcoming sessions preview
- Bottom navigation for easy access

### 2. Profile Setup
- Complete profile with bio and specialization
- Upload profile photo
- Add certifications and licenses
- Upload professional documents
- Account status tracking (profile completion, email verification, license verification)
- Calendar integration (Google Calendar, Outlook)

### 3. Appointments Management
- View all appointments with filtering (All, Upcoming, Completed, Cancelled)
- Session cards with client info, time, type, and status
- Session types: Video, Voice, Chat
- Status tracking: Scheduled, In Progress, Completed, Cancelled, No Show
- Risk level indicators
- Escalation status badges

### 4. Session Flow
Complete session lifecycle management:

#### Pre-Session
- View client details
- Session information (type, duration, scheduled time)
- Start session button

#### During Session
- Live timer showing session duration
- Session type interface (Video/Voice/Chat simulation)
- Real-time notes taking (private, encrypted)
- Risk assessment (None, Low, Medium, High, Critical)
- Incident creation for risk management
- Escalation to doctor with context

#### Post-Session
- End session with duration confirmation
- Session summary dialog
- Recommended next steps
- Automatic billing calculation
- Client notification

### 5. Availability Management
- Weekly schedule configuration
- Time slot management per day
- Add/Edit/Delete time slots
- Block dates for PTO
- Calendar integration sync
- Visual schedule overview

### 6. Client Records
- Searchable client list
- Client details with session history
- Access logging for security
- View session history
- View all private notes
- Schedule new sessions
- Send messages to clients
- Confidentiality indicators

### 7. Performance & Payments Dashboard
- Time period filtering (Week, Month, Year)
- Total earnings tracking
- Monthly earnings display
- Payout request system
- Performance metrics:
  - Total sessions
  - Average rating
  - Completion rate
  - Average response time
- Session breakdown by type
- Client satisfaction ratings
- Payout history

### 8. Security & Compliance
- Access logging for client records
- Encrypted notes storage
- Permission-based access control
- Audit trail for sensitive operations
- MFA support (recommended)
- Re-authentication for inactive sessions

## Getting Started

### Prerequisites
- Flutter SDK 3.3.0 or higher (3.9.2+ recommended)
- Dart SDK
- IDE (VS Code or Android Studio)
- iOS Simulator / Android Emulator / Physical Device

### Installation

1. Navigate to the project directory:
```bash
cd apps/app_counsellor
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building for Production

**Android App Bundle (Google Play):**
```bash
flutter build appbundle --release
```

**Android APK:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── models/
│   ├── counselor.dart                  # Counselor model
│   ├── session.dart                    # Session model with enums
│   ├── availability.dart               # Availability & TimeSlot models
│   ├── client_intake.dart              # Client intake model
│   └── mock_client_data.dart           # Mock data for development
├── screens/
│   ├── counselor_dashboard.dart        # Main dashboard
│   ├── profile_setup_screen.dart       # Profile & onboarding
│   ├── appointments_screen.dart        # Appointments list
│   ├── session_screen.dart             # Active session management
│   ├── audio_call_screen.dart          # Voice session interface
│   ├── chat_session_screen.dart        # Chat session interface
│   ├── availability_screen.dart        # Schedule management
│   ├── client_records_screen.dart      # Client records & history
│   └── performance_screen.dart         # Stats & payments
├── widgets/
│   ├── counsellor_quick_info_widget.dart
│   └── user_medical_details_card.dart
└── utils/
    └── responsive.dart                 # Responsive layout utilities
```

## API Integration

The app is designed to integrate with the following API endpoints:

### Authentication
- `POST /api/auth/login` - Login with JWT + roles
- `POST /api/auth/logout` - Revoke tokens

### Profile Management
- `POST /api/providers/{id}/profile` - Update profile
- `POST /api/providers/{id}/documents` - Upload certificates
- `PUT /api/providers/{id}/availability` - Set availability

### Appointments
- `GET /api/counselor/appointments?status=upcoming` - Get appointments
- `POST /api/counselor/availability/block` - Block time for PTO

### Sessions
- `POST /api/sessions/{id}/start` - Start session
- `POST /api/sessions/{id}/notes` - Add private notes
- `POST /api/sessions/{id}/risk` - Mark risk level
- `POST /api/sessions/{id}/escalate` - Escalate to doctor
- `POST /api/sessions/{id}/end` - End session

### Incidents & Escalations
- `POST /api/incidents` - Create incident report
- `POST /api/consults` - Request doctor consultation

### Performance
- `GET /api/counselor/stats` - Get performance statistics
- `POST /api/counselor/payouts` - Request payout

## Configuration

### API Base URL
Update the API base URL in your network configuration file before deployment.

### Authentication
The app expects JWT tokens with counselor role from the login endpoint.

### Permissions Required
- `start_session`
- `view_assigned_clients`
- `create_incident`
- `escalate_session`
- And others as per your backend RBAC implementation

## Data Models

### Counselor
- ID, name, email, specialization
- Bio, photo URL
- Certifications list
- Verification status
- Rating and total sessions

### Session
- Client and counselor IDs
- Scheduled, start, and end times
- Session type (Video, Voice, Chat)
- Status (Scheduled, In Progress, Completed, etc.)
- Private notes (encrypted)
- Risk level
- Escalation status

### Availability
- Counselor ID
- Weekly schedule (Map of day → TimeSlots)
- Blocked dates list

## Key Features Implementation

### Session Timer
- Real-time elapsed time tracking
- Automatic duration calculation
- Post-session billing integration

### Risk Assessment
- 5-level risk system (None to Critical)
- Automatic incident creation for high-risk cases
- Admin and doctor notifications
- Emergency contact request capability

### Escalation System
- Context-based doctor consultations
- Session data included in escalation
- Notification to medical team
- Ticket creation for tracking

### Access Control
- View assigned clients only
- Permission-based operations
- Access logging for audit trails
- Re-authentication for sensitive operations

### Confidentiality
- Encrypted notes storage
- Admin access requires special permission
- All access logged for compliance
- HIPAA-ready architecture

## Edge Cases Handled

1. **Forced Breaks**: Prevent counselor burnout with session limits
2. **Training Reminders**: Compliance check notifications
3. **Note Privacy**: Counselors can't see other counselors' notes
4. **Inactive Sessions**: Re-auth required after X minutes
5. **No-Show Handling**: Status tracking and billing adjustments
6. **Emergency Protocols**: SOP-based incident management

## Dependencies

- `flutter` - Flutter SDK
- `common` - Shared package from `../../packages/common`
- `intl: ^0.19.0` - Internationalization
- `http: ^1.2.2` - HTTP client
- `flutter_secure_storage: ^9.2.2` - Secure storage for tokens
- `shared_preferences: ^2.2.0` - Local preferences

## Development Notes

- This is a static implementation with mock data
- Replace mock data with actual API calls
- Implement proper error handling for production
- Add loading states and error messages
- Implement WebRTC for video/voice sessions
- Add push notifications for session reminders
- Implement secure storage for tokens

## Android Build Configuration

The app uses:
- Gradle 8.11.1
- Android Gradle Plugin 8.9.1
- Kotlin 2.1.0
- NDK version 27.0.12077973
- Java 11

## License

This project is private and confidential.
