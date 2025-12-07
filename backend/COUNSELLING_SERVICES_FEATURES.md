# Counselling Services - Feature Verification Document

This document verifies the implementation status of all counselling service features.

## Table of Contents
1. [Sessions](#sessions)
2. [Chat](#chat)
3. [Voice/Video Calls](#voicevideo-calls)

---

## Sessions

### ✅ Schedule counselling sessions
**Status:** Implemented  
**Endpoint:** `POST /api/sessions/`  
**View:** `UpcomingSessionListCreateView`  
**Description:** Users can create scheduled counselling sessions with counsellors.

**Features:**
- Create sessions with title, type, start time, and counsellor
- Support for one-on-one, group, workshop, and webinar session types
- Session confirmation status tracking

### ✅ Quick session creation
**Status:** Implemented  
**Endpoint:** `POST /api/sessions/quick/`  
**View:** `QuickSessionView`  
**Description:** Quick session creation with minimal required fields (date, time).

**Features:**
- Simple date/time-based session creation
- Optional title and notes
- Auto-assignment of counsellor

### ✅ Session management (create, update, delete)
**Status:** Implemented  
**Endpoints:**
- `POST /api/sessions/` - Create session
- `GET /api/sessions/<id>/` - Retrieve session
- `PATCH /api/sessions/<id>/` - Update session
- `DELETE /api/sessions/<id>/` - Delete session

**Views:**
- `UpcomingSessionListCreateView` - List and create
- `UpcomingSessionDetailView` - Retrieve, update, delete

**Features:**
- Full CRUD operations for sessions
- User-specific session access control
- Session metadata management

### ✅ Session start/end tracking
**Status:** Implemented  
**Endpoints:**
- `POST /api/sessions/<id>/start/` - Start session
- `POST /api/sessions/<id>/end/` - End session

**Views:**
- `SessionStartView` - Track session start time
- `SessionEndView` - Track session end time and calculate duration

**Features:**
- Actual start/end time tracking (separate from scheduled time)
- Session status updates (scheduled → in_progress → completed)
- Automatic duration calculation
- Support for starting/ending sessions via chat_id or session_id

### ✅ Session duration tracking
**Status:** Implemented  
**Endpoint:** `GET /api/sessions/<id>/duration/`  
**View:** `SessionDurationView`  
**Model Properties:** `duration_seconds`, `duration_minutes`

**Features:**
- Real-time duration calculation
- Duration in seconds and minutes
- Automatic calculation based on start/end times
- Live duration for in-progress sessions

### ✅ Session summary generation
**Status:** Implemented  
**Endpoint:** `GET /api/sessions/<id>/summary/`  
**View:** `SessionSummaryView`

**Features:**
- Complete session summary with all metadata
- Includes: client name, session type, timestamps, duration
- Message count from associated chat
- Risk level and manual flags
- Notes and status information

### ✅ Session rating system
**Status:** Implemented  
**Endpoints:**
- `POST /api/sessions/ratings/create/` - Create rating
- `GET /api/sessions/ratings/` - List ratings
- `GET /api/sessions/ratings/<id>/` - Get specific rating

**Views:**
- `SessionRatingCreateView` - Create rating for completed session
- `SessionRatingListView` - List ratings (user's given ratings or counsellor's received ratings)
- `SessionRatingDetailView` - Get specific rating details

**Features:**
- 1-5 star rating system
- Optional written feedback
- One rating per session (enforced)
- Only completed sessions can be rated
- Counsellors can view ratings they received
- Users can view ratings they gave

**Model:** `SessionRating`

### ✅ Upcoming sessions list
**Status:** Implemented  
**Endpoint:** `GET /api/sessions/`  
**View:** `UpcomingSessionListCreateView`

**Features:**
- List all sessions for authenticated user
- Ordered by start time
- Includes scheduled, in-progress, and upcoming sessions
- User-specific filtering

### ✅ Session history
**Status:** Implemented  
**Endpoint:** `GET /api/sessions/history/`  
**View:** `SessionHistoryView`

**Features:**
- List completed sessions only
- Filter by date range (optional query params: `start_date`, `end_date`)
- Separate views for users and counsellors
- Ordered by end time (most recent first)

---

## Chat

### ✅ Create chat sessions
**Status:** Implemented  
**Endpoint:** `POST /api/chats/`  
**View:** `ChatCreateView`

**Features:**
- Create new chat sessions
- Optional initial message
- Wallet balance check before creation
- Automatic queuing for counsellor assignment

### ✅ Real-time chat messaging
**Status:** Implemented  
**Endpoints:**
- `GET /api/chats/<id>/messages/` - Get messages
- `POST /api/chats/<id>/messages/` - Send message

**View:** `ChatMessageListView`  
**WebSocket:** `ChatConsumer` (in `consumers.py`)

**Features:**
- Real-time message delivery via WebSocket
- Message persistence in database
- Automatic chat activation on user message
- Auto-disconnect after 1 hour of inactivity

### ✅ Chat history viewing
**Status:** Implemented  
**Endpoint:** `GET /api/chats/<id>/messages/`  
**View:** `ChatMessageListView`

**Features:**
- Retrieve all messages for a chat
- Ordered chronologically
- Access control (user or assigned counsellor only)
- Message metadata (sender, timestamp, text)

### ✅ Queued chats for counsellors
**Status:** Implemented  
**Endpoint:** `GET /api/counselor/queued-chats/`  
**View:** `QueuedChatsView`

**Features:**
- List all queued chats (waiting for counsellor)
- Counsellor-only access
- Ordered by creation time (oldest first)
- Shows user information and initial message

### ✅ Accept/end chat sessions
**Status:** Implemented  
**Endpoints:**
- `PATCH /api/chats/<id>/accept/` - Accept chat
- Chat ending handled via status updates

**Views:**
- `ChatAcceptView` - Assign counsellor to queued chat
- Chat status management (queued → active → completed)

**Features:**
- Counsellors can accept queued chats
- Automatic status update to 'active'
- Chat can be ended by completing or cancelling
- Automatic billing on completion

### ✅ Chat message retrieval
**Status:** Implemented  
**Endpoint:** `GET /api/chats/<id>/messages/`  
**View:** `ChatMessageListView`

**Features:**
- Retrieve all messages for a specific chat
- Real-time updates via WebSocket
- Message ordering and pagination support
- Access control enforcement

### ✅ Chat transcript (read-only view)
**Status:** Implemented  
**Endpoint:** `GET /api/chats/<id>/transcript/`  
**View:** `ChatTranscriptView`

**Features:**
- Read-only complete chat transcript
- Includes all messages in chronological order
- Chat metadata (user, counsellor, timestamps, duration)
- Message count and status information
- Access control (user or assigned counsellor only)

### ✅ Active vs completed chat separation
**Status:** Implemented  
**Endpoints:**
- `GET /api/chats/list/` - All chats (with status field)
- `GET /api/chats/filtered/` - Filtered by status

**Views:**
- `ChatListView` - List all chats with status
- `ChatFilteredListView` - Filter by status (active/completed)

**Features:**
- Status-based filtering via query parameter (`?status=active` or `?status=completed`)
- Chat statuses: `queued`, `active`, `inactive`, `completed`, `cancelled`
- Frontend can separate active vs completed chats
- Backend filtering support for efficient queries

**Status Values:**
- `active` - Returns chats with status 'active' or 'queued'
- `completed` - Returns chats with status 'completed' or 'cancelled'
- Specific status values also supported

---

## Voice/Video Calls

### ✅ Create call sessions
**Status:** Implemented  
**Endpoint:** `POST /api/calls/create/`  
**View:** `CallCreateView`

**Features:**
- Create video or voice calls
- Optional counsellor assignment
- Wallet balance check before call creation
- Automatic TURN credentials generation
- WebSocket URL for signaling

**Call Types:**
- `video` - Video call with camera
- `voice` - Audio-only call

### ✅ WebRTC integration for video calls
**Status:** Implemented  
**Components:**
- `WebRTCManager` (Flutter apps)
- `WebRTCSignaling` (WebSocket-based)
- TURN server credentials

**Features:**
- Full WebRTC peer-to-peer connection
- STUN/TURN server support
- ICE candidate exchange
- Offer/Answer SDP exchange
- Video track handling
- Connection state management

**Endpoints:**
- `GET /api/calls/turn-credentials/` - Get TURN credentials
- `POST /api/calls/create/` - Create call with TURN config
- `GET /api/calls/<id>/token/` - Get TURN credentials for active call

### ✅ Voice call support
**Status:** Implemented  
**Features:**
- Audio-only call option (`call_type: 'voice'`)
- WebRTC audio track handling
- Works on web and mobile platforms
- Same WebRTC infrastructure as video calls

### ✅ Call token generation
**Status:** Implemented  
**Endpoints:**
- `GET /api/calls/turn-credentials/` - General TURN credentials
- `GET /api/calls/<id>/token/` - Call-specific TURN credentials

**Views:**
- `get_turn_credentials_view` - General credentials
- `CallTokenView` - Call-specific credentials

**Features:**
- TURN server credentials for WebRTC
- Redis caching for performance
- User-specific credential generation
- Automatic credential refresh support

### ✅ Queued calls for counsellors
**Status:** Implemented  
**Endpoint:** `GET /api/calls/queued/`  
**View:** `QueuedCallsView`

**Features:**
- List all queued/ringing calls without assigned counsellor
- Counsellor-only access
- Ordered by creation time
- Shows caller information and call type

### ✅ Accept/end call sessions
**Status:** Implemented  
**Endpoints:**
- `PATCH /api/calls/<id>/accept/` - Accept call
- `POST /api/calls/<id>/end/` - End call

**Views:**
- `CallAcceptView` - Assign counsellor and activate call
- `CallEndView` - Mark call as ended and calculate duration

**Features:**
- Counsellors can accept queued calls
- Automatic status update (ringing → active)
- Call duration calculation on end
- Billing integration
- Idempotent accept (safe to retry)

### ✅ Call history
**Status:** Implemented  
**Endpoint:** `GET /api/calls/history/`  
**View:** `CallHistoryView`

**Features:**
- List ended calls only
- Filter by date range (optional query params: `start_date`, `end_date`)
- Separate views for users and counsellors
- Ordered by end time (most recent first)
- Includes call metadata (duration, type, participants)

---

## Summary

### Implementation Status
- **Sessions:** ✅ 9/9 features implemented
- **Chat:** ✅ 8/8 features implemented
- **Voice/Video Calls:** ✅ 7/7 features implemented

**Total:** ✅ 24/24 features implemented

### New Endpoints Added

#### Sessions
- `GET /api/sessions/history/` - Session history
- `POST /api/sessions/ratings/create/` - Create session rating
- `GET /api/sessions/ratings/` - List session ratings
- `GET /api/sessions/ratings/<id>/` - Get session rating

#### Chat
- `GET /api/chats/filtered/` - Filtered chat list
- `GET /api/chats/<id>/transcript/` - Chat transcript

#### Calls
- `GET /api/calls/history/` - Call history

### Models Used
- `UpcomingSession` - Session management
- `SessionRating` - Session ratings
- `Chat` - Chat sessions
- `ChatMessage` - Chat messages
- `Call` - Voice/video calls

### Key Features
1. **Complete CRUD operations** for all session types
2. **Real-time communication** via WebSocket for chat
3. **WebRTC integration** for voice/video calls
4. **Comprehensive history tracking** for all service types
5. **Rating system** for session feedback
6. **Access control** ensuring users only see their own data
7. **Billing integration** for chat and calls
8. **Status management** with proper state transitions

---

## API Usage Examples

### Create Session Rating
```http
POST /api/sessions/ratings/create/
Content-Type: application/json
Authorization: Bearer <token>

{
  "session_id": 123,
  "rating": 5,
  "feedback": "Great session, very helpful!"
}
```

### Get Session History
```http
GET /api/sessions/history/?start_date=2024-01-01T00:00:00Z&end_date=2024-12-31T23:59:59Z
Authorization: Bearer <token>
```

### Get Chat Transcript
```http
GET /api/chats/456/transcript/
Authorization: Bearer <token>
```

### Filter Chats by Status
```http
GET /api/chats/filtered/?status=active
Authorization: Bearer <token>
```

### Get Call History
```http
GET /api/calls/history/?start_date=2024-01-01T00:00:00Z
Authorization: Bearer <token>
```

---

## Notes

- All endpoints require authentication (JWT token)
- Access control is enforced at the view level
- Billing is automatically processed for chat and calls
- WebSocket connections are required for real-time chat
- TURN credentials are cached for performance
- Session ratings can only be created for completed sessions
- History endpoints support optional date range filtering

