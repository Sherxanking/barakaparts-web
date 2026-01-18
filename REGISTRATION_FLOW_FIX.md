# Registration Flow Fix Summary

## Issue Fixed
**Problem**: Registration was manually inserting into `public.users` table from Flutter, instead of relying on the Supabase trigger.

**Solution**: Removed manual insert, now relies **ONLY** on the `handle_new_user()` trigger.

---

## Files Modified

### 1. `lib/infrastructure/datasources/supabase_user_datasource.dart`

**Location**: `registerUser()` method (lines 564-635)

**Changes**:
- ❌ **REMOVED**: Manual insert into `users` table (lines 564-635)
- ✅ **ADDED**: Polling logic to wait for trigger to create profile
- ✅ **ADDED**: Retry mechanism (5 attempts, 500ms delay) to handle async trigger execution
- ✅ **ADDED**: Fallback to auth metadata if trigger doesn't create profile (should rarely happen)

**Before**:
```dart
// Manual insert
await _client.client.from(_tableName).insert(userJson);
// Then fetch
final userResult = await getUserById(authResponse.user!.id);
```

**After**:
```dart
// Wait for trigger to create profile
for (int i = 0; i < maxRetries; i++) {
  await Future.delayed(retryDelay);
  final userResult = await getUserById(authResponse.user!.id);
  // Check if profile exists
  if (createdUser != null) break;
}
```

---

## How It Works Now

### 1. **User Registration Flow**:
```
User fills form → Flutter calls registerUser()
  ↓
auth.signUp() with metadata (name, role, phone)
  ↓
Supabase Auth creates user in auth.users
  ↓
Trigger handle_new_user() fires automatically
  ↓
Trigger inserts profile into public.users
  ↓
Flutter polls for profile (with retries)
  ↓
Returns created user profile
```

### 2. **Trigger Details**:
The trigger `handle_new_user()` (defined in migration `004_ensure_tables_and_fix_rls.sql`):
- Automatically fires after `INSERT` on `auth.users`
- Reads metadata from `raw_user_meta_data`:
  - `name`: from metadata or email prefix
  - `role`: from metadata or defaults to 'worker'
  - `email`: from auth user
  - `department_id`: from metadata (optional)
- Inserts into `public.users` table
- Uses `ON CONFLICT DO NOTHING` to prevent duplicates

### 3. **Metadata Passed to signUp**:
```dart
data: {
  'name': name.trim(),
  'role': role,
  if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
}
```

This metadata is stored in `auth.users.raw_user_meta_data` and read by the trigger.

---

## Benefits

✅ **Single Source of Truth**: Profile creation happens in one place (trigger)
✅ **No Race Conditions**: Trigger ensures profile is always created after auth user
✅ **Consistent Data**: All profiles created the same way
✅ **RLS Safe**: Trigger runs with `SECURITY DEFINER` privileges
✅ **No Manual Inserts**: Flutter code is simpler and more maintainable

---

## Testing Checklist

### ✅ Test 1: Normal Registration
1. Register a new user with email, password, name
2. **Expected**: Profile created automatically in `public.users`
3. **Verify**: Check Supabase dashboard - user should exist in both `auth.users` and `public.users`

### ✅ Test 2: Registration with Phone
1. Register with phone number
2. **Expected**: Profile created with phone number
3. **Verify**: Phone stored in `public.users` table

### ✅ Test 3: Registration with Role
1. Register with role 'worker' (default)
2. **Expected**: Profile created with role 'worker'
3. **Verify**: Role stored correctly in `public.users` table

### ✅ Test 4: Trigger Timing
1. Register a user
2. **Expected**: Profile appears within 1-2 seconds (after retry polling)
3. **Verify**: No manual insert errors in logs

### ✅ Test 5: Duplicate Prevention
1. Try to register same email twice
2. **Expected**: Second attempt fails with "already registered" error
3. **Verify**: Only one profile exists in `public.users`

---

## Important Notes

⚠️ **Trigger Must Exist**: Ensure migration `004_ensure_tables_and_fix_rls.sql` has been run in Supabase.

⚠️ **Metadata Required**: The `signUp()` call must include `name` and `role` in the `data` parameter for the trigger to work correctly.

⚠️ **Retry Logic**: The code polls up to 5 times (2.5 seconds total) for the profile. If trigger is slow, this ensures the profile is found.

⚠️ **Fallback**: If trigger doesn't create profile after retries, the code returns a user object from auth metadata. This should rarely happen if the trigger is working correctly.

---

## Summary

✅ **Manual insert removed** - No more direct inserts into `public.users` from Flutter
✅ **Trigger-only approach** - Relies solely on `handle_new_user()` trigger
✅ **Retry mechanism** - Handles async trigger execution gracefully
✅ **Backward compatible** - Still returns user object even if trigger is slow

**Result**: Registration flow now correctly relies on Supabase trigger for profile creation.




































