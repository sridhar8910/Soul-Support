# Chat Billing Implementation

> **Quick Start:** For general project info, see [COMPLETE_GUIDE.md](../COMPLETE_GUIDE.md)

## Overview
Implemented **time-based billing** for chat sessions at **1 rupee per minute** of active conversation time. Money is automatically deducted from the user's wallet when the chat ends.

## Implementation Details

### 1. Database Changes (`backend/api/models.py`)
Added billing fields to `Chat` model:
- `billed_amount` (DecimalField): Total amount billed in rupees
- `duration_minutes` (PositiveIntegerField): Total active chat duration in minutes
- `is_billed` (BooleanField): Whether billing has been processed
- `billing_processed_at` (DateTimeField): When billing was processed

**Migration:** `0026_chat_billed_amount_chat_billing_processed_at_and_more.py`

### 2. Billing Utility (`backend/api/utils/billing.py`)
Created comprehensive billing utility with functions:

#### `calculate_chat_duration_minutes(chat)` → int
- Calculates active chat duration in minutes
- Uses `started_at` and `ended_at` timestamps
- Rounds up to nearest minute for billing

#### `calculate_chat_billing(chat)` → Decimal
- Calculates billing amount: **1 rupee × duration_minutes**
- Returns billing amount in rupees

#### `deduct_chat_billing(chat, billing_amount)` → bool
- Deducts billing amount from user's wallet
- Uses `select_for_update()` to prevent race conditions
- Returns `True` if deduction successful, `False` if insufficient balance

#### `calculate_and_deduct_chat_billing(chat)` → bool
- Main function that calculates and deducts billing
- Automatically called when chat ends
- Updates chat with billing information
- Handles insufficient balance gracefully

#### `check_chat_wallet_balance(user)` → tuple[bool, str, int]
- Checks if user has minimum balance (1 rupee) to start chat
- Returns: (has_balance, message, current_balance)

#### `get_chat_estimated_cost(chat)` → dict
- Gets estimated billing for active chats
- Returns duration, estimated amount, and billing status

### 3. API Updates

#### `ChatCreateView` (`backend/api/views.py`)
- **Before creating chat:** Checks wallet balance
- Requires minimum **1 rupee** (1 minute) balance
- Returns error if insufficient balance

#### `SessionEndView` (`backend/api/views.py`)
- **When session ends:** Automatically processes billing for associated chat
- Calculates duration and deducts from wallet
- Returns billing information in response

#### `Chat.save()` (`backend/api/models.py`)
- **When chat ends:** Automatically triggers billing calculation
- Called for status changes: `inactive`, `completed`, `cancelled`
- Uses recursion prevention flag to avoid infinite loops

#### `ChatConsumer.save_message()` (`backend/api/consumers.py`)
- **Before activating chat:** Checks wallet balance (warning only)
- Allows activation even with low balance (billing happens at end)
- Logs warning if balance is insufficient

### 4. Serializer Updates (`backend/api/serializers.py`)
Updated `ChatSerializer` to include billing fields:
- `billed_amount`: Amount charged for this chat
- `duration_minutes`: Chat duration in minutes
- `is_billed`: Whether billing was processed
- `billing_processed_at`: When billing was processed

## Billing Flow

### Chat Lifecycle & Billing:

1. **Chat Creation** (`ChatCreateView`)
   - ✅ Check wallet balance (minimum ₹1 required)
   - ✅ Create chat with `status='queued'`
   - ❌ If insufficient balance → Return error

2. **Chat Activation** (User sends message or Counselor accepts)
   - ✅ Set `started_at = now()`
   - ✅ Change `status = 'active'`
   - ⚠️ Log warning if balance is low (but allow activation)

3. **Chat Active** (Conversation ongoing)
   - ⏱️ Duration accumulates based on `started_at` to current time
   - 💰 Estimated cost: `duration_minutes × ₹1/minute`

4. **Chat Ends** (`Chat.save()` triggered)
   - ✅ Calculate final duration: `ended_at - started_at`
   - ✅ Calculate billing: `duration_minutes × ₹1`
   - ✅ Deduct from wallet: `wallet_minutes -= billing_amount`
   - ✅ Mark as billed: `is_billed = True`
   - ❌ If insufficient balance → Log error, mark unpaid

## Billing Calculation Example

```
Chat starts: 10:00:00
Chat ends:   10:15:30

Duration: 15 minutes 30 seconds
Rounded: 16 minutes (rounds up)
Billing: ₹16 (16 minutes × ₹1/minute)

Wallet before: ₹100
Wallet after:  ₹84
```

## Error Handling

### Insufficient Balance Scenarios:

1. **Before Chat Creation:**
   - ✅ Blocked with error message
   - User must recharge wallet

2. **During Active Chat:**
   - ⚠️ Warning logged but chat continues
   - Billing calculated at end

3. **At Chat End (Billing Time):**
   - ❌ If insufficient balance:
     - Billing amount calculated and stored
     - Deduction fails
     - `is_billed = False`
     - Error logged for admin review
   - User can recharge and pay later

## API Response Examples

### Chat Create (Insufficient Balance):
```json
{
  "error": "Insufficient wallet balance. Minimum ₹1 required to start chat. Current balance: ₹0",
  "wallet_minutes": 0,
  "required_minimum": 1
}
```

### Session End (With Billing):
```json
{
  "status": "ended",
  "session_id": 123,
  "message": "Session ended successfully",
  "end_time": "2025-11-22T10:15:30Z",
  "duration_seconds": 930,
  "duration_minutes": 16,
  "billing": {
    "billed_amount": 16.0,
    "duration_minutes": 16
  }
}
```

### Chat List (Includes Billing Info):
```json
{
  "id": 456,
  "status": "completed",
  "started_at": "2025-11-22T10:00:00Z",
  "ended_at": "2025-11-22T10:15:30Z",
  "billed_amount": "16.00",
  "duration_minutes": 16,
  "is_billed": true,
  "billing_processed_at": "2025-11-22T10:15:31Z"
}
```

## Database Schema

### Chat Model Billing Fields:
```python
billed_amount = DecimalField(max_digits=10, decimal_places=2, default=0.00)
duration_minutes = PositiveIntegerField(default=0)
is_billed = BooleanField(default=False, db_index=True)
billing_processed_at = DateTimeField(null=True, blank=True)
```

## Testing Checklist

- [ ] Create chat with sufficient balance → ✅ Success
- [ ] Create chat with insufficient balance → ❌ Blocked
- [ ] Chat active for 1 minute → Billed ₹1
- [ ] Chat active for 15 minutes 30 seconds → Billed ₹16 (rounded up)
- [ ] Chat ends with insufficient balance → Error logged, unpaid marked
- [ ] Multiple chats in parallel → Each billed separately
- [ ] Wallet balance updated correctly after billing

## Frontend Integration

Frontend should:
1. **Check wallet before creating chat** - Show error if insufficient
2. **Display estimated cost** for active chats - `duration × ₹1/minute`
3. **Show billing information** when chat ends - Display final amount charged
4. **Update wallet display** after chat ends - Show new balance

## Next Steps

1. ✅ Run migration: `python manage.py migrate`
2. ✅ Test billing calculation
3. ✅ Test wallet deduction
4. ⏳ Update frontend to show billing information
5. ⏳ Add wallet balance display in chat UI
6. ⏳ Handle insufficient balance scenarios in UI

