# Step-by-Step Login + Google + RLS Fix Guide

This guide provides step-by-step instructions to fix email/password authentication, Google OAuth, and Row-Level Security (RLS) policies.

## Step 1: Fix Email/Password Registration/Login ✅

### Changes Made:
1. **Improved error handling** in `lib/infrastructure/datasources/supabase_user_datasource.dart`:
   - Added `AuthException` handling for specific Supabase errors
   - Better error messages for invalid credentials, email verification, network errors
   - Added input validation before API calls
   - Added debug logging for troubleshooting

### Key Improvements:
- **PostgrestException handling**: Catches database errors gracefully
- **Null user handling**: Checks if user is null after signup/login
- **Network error detection**: Identifies connection issues
- **Email verification**: Clear messages when email is not verified

### Testing:
1. **Test Login with Valid Credentials**:
   - Enter correct email and password
   - Should navigate to HomePage
   - Check debug console for "✅ Login successful" message

2. **Test Login with Invalid Credentials**:
   - Enter wrong email or password
   - Should show: "Invalid email or password. Please check and try again."
   - Should NOT crash

3. **Test Login with Unverified Email**:
   - Register new account
   - Try to login without verifying email
   - Should show email verification dialog
   - Should allow resending verification email

4. **Test Registration**:
   - Register with new email
   - Should create account and show verification dialog
   - Try registering with existing email → should show error

5. **Test Network Error**:
   - Disable internet
   - Try to login
   - Should show: "No internet connection. Please check your network and try again."

---

## Step 2: Fix Google OAuth Login ✅

### Changes Made:
1. **Fixed redirect URL configuration** in `signInWithGoogle()`:
   - Uses proper Supabase callback URL format
   - Added error handling for code 400 errors
   - Better error messages for OAuth configuration issues

### Configuration Required:

#### For Android:
1. **Get SHA-1 Fingerprint**:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 from the output (look for `Variant: debug`)

2. **Add to Supabase Dashboard**:
   - Go to Authentication → Providers → Google
   - Add SHA-1 fingerprint in "Authorized client IDs"
   - Add redirect URL: `com.yourapp://login-callback` (replace with your app package)

#### For iOS:
1. **Get Bundle ID**:
   - Check `ios/Runner/Info.plist` → `CFBundleIdentifier`
   - Example: `com.example.barakaparts`

2. **Add to Supabase Dashboard**:
   - Go to Authentication → Providers → Google
   - Add Bundle ID in "Authorized client IDs"
   - Add redirect URL: `com.yourapp://login-callback`

#### For Web:
- Redirect URL should be: `https://yourdomain.com/auth/callback`
- Add this to Supabase Dashboard → Authentication → URL Configuration

### Testing:
1. **Test Google Login**:
   - Click "Continue with Google" button
   - Should open browser/WebView
   - Complete Google sign-in
   - Should redirect back to app
   - Should navigate to HomePage

2. **Test OAuth Error (400)**:
   - If redirect URL is misconfigured, should show:
     ```
     OAuth configuration error. Please check:
     1. Google OAuth is enabled in Supabase Dashboard
     2. Redirect URL is configured correctly
     3. Android SHA-1 / iOS Bundle ID matches Supabase settings
     ```

3. **Test First-Time Google User**:
   - Sign in with Google account that hasn't been used before
   - Should automatically create user profile with role "worker"
   - Should navigate to HomePage

---

## Step 3: Fix Row-Level Security (RLS) Policies ✅

### SQL Migration File:
Created `supabase/migrations/003_fix_rls_policies.sql` with fixed RLS policies for:
- `users` table
- `parts` table
- `products` table
- `orders` table
- `departments` table

### Key Fixes:
1. **Non-Recursive Policies**: All policies check roles from `auth.users.raw_user_meta_data` instead of querying `public.users` table
2. **Safe Role Checks**: Uses `auth.users` metadata to avoid infinite recursion
3. **Proper Permissions**: Each role has correct permissions:
   - **Worker**: Read all, create parts/orders
   - **Manager**: Read all, create/update parts/products/orders/departments
   - **Boss**: Full access (read/update/delete all)
   - **Supplier**: Read all, create/update parts

### How to Apply:
1. **Open Supabase Dashboard**:
   - Go to SQL Editor
   - Create new query

2. **Run Migration**:
   - Copy contents of `supabase/migrations/003_fix_rls_policies.sql`
   - Paste into SQL Editor
   - Click "Run"

3. **Verify Policies**:
   - Go to Authentication → Policies
   - Check that all tables have the new policies

### Testing RLS Policies:

#### Test 1: Create Part (Worker Role)
1. Login as worker
2. Go to Parts page
3. Click "Add Part"
4. Fill in name, quantity, min quantity
5. Click "Add"
6. **Expected**: Part should be created successfully
7. **Should NOT see**: "Permission denied" or "Forbidden" error

#### Test 2: Update Part (Manager Role)
1. Login as manager
2. Go to Parts page
3. Click on a part to edit
4. Change quantity
5. Click "Save"
6. **Expected**: Part should be updated successfully
7. **Should NOT see**: "Permission denied" error

#### Test 3: Create Product (Manager Role)
1. Login as manager
2. Go to Products page
3. Create a new product
4. **Expected**: Product should be created successfully

#### Test 4: Create Order (Worker Role)
1. Login as worker
2. Go to Orders page
3. Create a new order
4. **Expected**: Order should be created successfully

#### Test 5: Delete Part (Boss Role Only)
1. Login as boss
2. Go to Parts page
3. Try to delete a part
4. **Expected**: Part should be deleted successfully
5. Login as worker/manager
6. Try to delete a part
7. **Expected**: Delete option should not be available (or show error)

---

## Step 4: Testing & Verification Checklist

### Email/Password Auth:
- [ ] Register new user → Account created, verification email sent
- [ ] Login with verified email → Success, navigates to HomePage
- [ ] Login with unverified email → Shows verification dialog
- [ ] Login with wrong password → Shows error, doesn't crash
- [ ] Login with non-existent email → Shows error, doesn't crash
- [ ] Login without internet → Shows network error, doesn't crash

### Google OAuth:
- [ ] Click "Continue with Google" → Opens browser
- [ ] Complete Google sign-in → Redirects to app, navigates to HomePage
- [ ] First-time Google user → Profile created automatically
- [ ] Existing Google user → Logs in successfully
- [ ] OAuth error (if misconfigured) → Shows helpful error message

### RLS Policies:
- [ ] Worker can create part → Success
- [ ] Worker can read parts → Success
- [ ] Worker CANNOT delete part → Error or option hidden
- [ ] Manager can update part → Success
- [ ] Manager can create product → Success
- [ ] Boss can delete part → Success
- [ ] No "Forbidden" or "Permission denied" errors when performing allowed actions

### General:
- [ ] No crashes on any auth flow
- [ ] Error messages are user-friendly
- [ ] Loading indicators show during async operations
- [ ] App handles network errors gracefully

---

## Troubleshooting

### Issue: "Permission denied" when creating part
**Solution**: 
1. Check user role in `public.users` table
2. Verify RLS policies are applied (run migration)
3. Check that `created_by` field is set correctly

### Issue: Google OAuth returns 400 error
**Solution**:
1. Check Supabase Dashboard → Authentication → Providers → Google
2. Verify redirect URL matches app configuration
3. For Android: Add SHA-1 fingerprint
4. For iOS: Add Bundle ID
5. Ensure Google OAuth is enabled

### Issue: Email verification not working
**Solution**:
1. Check Supabase Dashboard → Authentication → Settings
2. Enable "Enable email confirmations"
3. Check email templates are configured
4. Verify SMTP settings (if using custom SMTP)

### Issue: User profile not created after registration
**Solution**:
1. Check trigger `handle_new_user()` exists
2. Verify trigger is enabled
3. Check `public.users` table has correct RLS policies
4. Check auth.users metadata has role information

---

## Files Modified

1. `lib/infrastructure/datasources/supabase_user_datasource.dart`
   - Improved error handling for login/registration
   - Fixed Google OAuth redirect URLs
   - Added AuthException handling

2. `supabase/migrations/003_fix_rls_policies.sql`
   - Fixed RLS policies for all tables
   - Made policies non-recursive
   - Added proper role-based permissions

---

## Next Steps

After applying these fixes:
1. Test all authentication flows
2. Test creating/updating/deleting parts/products/orders
3. Verify no "Forbidden" errors occur
4. Monitor debug logs for any issues
5. Update app configuration (SHA-1, Bundle ID) if needed

---

## Support

If you encounter issues:
1. Check debug console for error messages
2. Verify Supabase Dashboard configuration
3. Check RLS policies are applied correctly
4. Ensure user roles are set correctly in database



































