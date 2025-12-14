# ✅ Testing Checklist - RLS Fix + Google OAuth

## 📋 Pre-Testing Setup

### 1. Run SQL Migration
```sql
-- Copy and paste the entire content of:
-- supabase/migrations/006_fix_users_rls_recursion.sql
-- into Supabase SQL Editor and run it
```

### 2. Verify RLS Policies
- Go to Supabase Dashboard → Table Editor → users
- Check that RLS is enabled
- Verify policies are created (should see 5 policies)

---

## ✅ TEST 1: User Registration (Email/Password)

### Steps:
1. Open app → Go to Register page
2. Fill in:
   - Name: `Test User`
   - Email: `test@example.com`
   - Password: `password123`
   - Phone: (optional)
3. Click "Register"

### Expected Result:
- ✅ No "infinite recursion" error
- ✅ User is created in `auth.users`
- ✅ User profile is created in `public.users` table
- ✅ User is redirected to Home page (or email verification dialog)
- ✅ App does NOT crash

### Verify in Supabase:
- Go to Authentication → Users → Find `test@example.com`
- Go to Table Editor → users → Find user with email `test@example.com`
- Check that `role = 'worker'`

---

## ✅ TEST 2: User Login (Email/Password)

### Steps:
1. If logged out, go to Login page
2. Enter:
   - Email: `test@example.com`
   - Password: `password123`
3. Click "Login"

### Expected Result:
- ✅ Login succeeds
- ✅ User is redirected to Home page
- ✅ No errors in console
- ✅ User profile is loaded correctly

---

## ✅ TEST 3: Google OAuth Login (First Time)

### Prerequisites:
- Google OAuth must be configured in Supabase Dashboard
- Redirect URL: `com.probaraka.barakaparts://login-callback`
- SHA-1 fingerprint added (Android)

### Steps:
1. Go to Login page
2. Click "Continue with Google" button
3. Select Google account in browser
4. Grant permissions
5. Wait for redirect back to app

### Expected Result:
- ✅ Browser opens for Google sign-in
- ✅ User selects account and grants permissions
- ✅ App redirects back automatically
- ✅ User profile is **automatically created** in `public.users` table
- ✅ User is redirected to Home page
- ✅ No errors

### Verify in Supabase:
- Go to Authentication → Users → Find Google account email
- Go to Table Editor → users → Find user with Google email
- Check that `role = 'worker'` (default)

---

## ✅ TEST 4: Google OAuth Login (Existing User)

### Steps:
1. Logout if logged in
2. Go to Login page
3. Click "Continue with Google"
4. Select the **same Google account** as Test 3
5. Grant permissions

### Expected Result:
- ✅ Login succeeds immediately
- ✅ Existing user profile is loaded (not recreated)
- ✅ User is redirected to Home page
- ✅ No duplicate user created

---

## ✅ TEST 5: Session Restore (App Restart)

### Steps:
1. Login successfully (email or Google)
2. **Close the app completely** (not just minimize)
3. **Reopen the app**

### Expected Result:
- ✅ App shows loading indicator (Splash page)
- ✅ Session is detected
- ✅ User profile is loaded automatically
- ✅ User is redirected to Home page (NOT Login page)
- ✅ No white screen
- ✅ No errors

---

## ✅ TEST 6: Session Expired / No Session

### Steps:
1. Logout from app
2. Close app completely
3. Reopen app

### Expected Result:
- ✅ App shows loading indicator
- ✅ No session detected
- ✅ User is redirected to Login page
- ✅ No errors

---

## ✅ TEST 7: Registration Error Handling

### Test 7a: Duplicate Email
1. Try to register with email that already exists
2. Expected: Error message "This email is already registered"

### Test 7b: Weak Password
1. Try to register with password less than 6 characters
2. Expected: Error message about password length

### Test 7c: Invalid Email
1. Try to register with invalid email format
2. Expected: Error message about invalid email

### Test 7d: Network Error
1. Turn off internet
2. Try to register
3. Expected: Error message about network connection
4. App does NOT crash

---

## ✅ TEST 8: Login Error Handling

### Test 8a: Wrong Password
1. Enter correct email but wrong password
2. Expected: Error message "Invalid email or password"

### Test 8b: Non-existent Email
1. Enter email that doesn't exist
2. Expected: Error message "No account found with this email"

### Test 8c: Unverified Email (if email verification enabled)
1. Register but don't verify email
2. Try to login
3. Expected: Error message about email verification

---

## ✅ TEST 9: RLS Policy Verification

### Test 9a: User Can Read Own Profile
1. Login as user A
2. App should load user A's profile
3. Expected: ✅ Success

### Test 9b: User Cannot Read Other Users
- This is tested automatically by RLS
- User should only see their own data in app

### Test 9c: Boss Can Read All Users
1. Login as boss (role = 'boss')
2. App should load boss profile
3. Expected: ✅ Success (boss policies allow reading all users)

---

## ✅ TEST 10: Edge Cases

### Test 10a: Rapid Registration
1. Click "Register" multiple times quickly
2. Expected: Only one registration happens, no duplicates

### Test 10b: App Background During OAuth
1. Start Google OAuth
2. Put app in background during OAuth flow
3. Complete OAuth in browser
4. Return to app
5. Expected: OAuth completes, user is logged in

### Test 10c: Multiple Devices
1. Login on Device A
2. Login on Device B (same account)
3. Expected: Both devices work independently

---

## ❌ Known Issues to Watch For

### Issue 1: "infinite recursion detected"
- **Should NOT happen** after migration 006
- If it happens: Check that migration 006 was run correctly

### Issue 2: "policy already exists"
- **Solution**: Migration 006 uses `DROP POLICY IF EXISTS` - should not happen

### Issue 3: Google OAuth "provider not enabled"
- **Solution**: Enable Google provider in Supabase Dashboard

### Issue 4: Google OAuth "redirect_uri_mismatch"
- **Solution**: Check redirect URLs in Supabase and Google Cloud Console

---

## 📊 Success Criteria

All tests should pass:
- ✅ Registration works without recursion error
- ✅ Login works (email/password)
- ✅ Google OAuth works (first time + existing user)
- ✅ Session restore works
- ✅ Error handling works (no crashes)
- ✅ RLS policies work correctly

---

## 🔧 If Tests Fail

1. **Check Supabase Logs**: Dashboard → Logs → Check for errors
2. **Check Flutter Console**: Look for error messages
3. **Verify SQL Migration**: Ensure migration 006 was run
4. **Verify RLS Policies**: Check that policies exist in Supabase Dashboard
5. **Check Google OAuth Config**: Verify settings in Supabase Dashboard

---

## ✅ Final Verification

After all tests pass:
- [ ] Registration works
- [ ] Login works
- [ ] Google OAuth works
- [ ] Session restore works
- [ ] No crashes
- [ ] No infinite recursion errors
- [ ] RLS policies working correctly

**Status**: ✅ Ready for Production (if all tests pass)

