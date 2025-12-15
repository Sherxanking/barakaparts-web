# Supabase Migration Execution Guide

## STEP 1: Run Migration

**File:** `supabase/migrations/015_fix_role_for_dashboard_users.sql`

**Action:** Copy the entire SQL content below and paste it into Supabase Dashboard → SQL Editor → Run

---

## STEP 2: Verification Queries

After running the migration, execute these queries in Supabase SQL Editor:

### Query 1: Check auth.users for test accounts
```sql
SELECT id, email 
FROM auth.users 
WHERE email IN ('boss@test.com', 'manager@test.com');
```

### Query 2: Check public.users for test accounts
```sql
SELECT id, email, role 
FROM public.users 
WHERE email IN ('boss@test.com', 'manager@test.com');
```

### Query 3: Check trigger exists
```sql
SELECT tgname 
FROM pg_trigger 
WHERE tgrelid = 'auth.users'::regclass;
```

### Query 4: Final counts
```sql
SELECT COUNT(*) as public_users_count FROM public.users;
SELECT COUNT(*) as auth_users_count FROM auth.users;
```

---

## STEP 3: Handle Missing Test Accounts

**IF** `auth.users` does NOT contain `boss@test.com` or `manager@test.com`:

1. **Create users via Supabase Dashboard:**
   - Go to **Authentication** → **Users** → **Add User**
   - Create `boss@test.com`:
     - Email: `boss@test.com`
     - Password: `Boss123!`
     - Email confirmed: ✅ **true**
   - Create `manager@test.com`:
     - Email: `manager@test.com`
     - Password: `Manager123!`
     - Email confirmed: ✅ **true**

2. **After creating, get their IDs:**
   ```sql
   SELECT id, email 
   FROM auth.users 
   WHERE email IN ('boss@test.com', 'manager@test.com');
   ```

3. **Insert into public.users (replace `<ID>` with actual IDs):**
   ```sql
   -- For boss@test.com
   INSERT INTO public.users (id, name, email, role, created_at)
   VALUES ('<BOSS_ID>', 'Boss', 'boss@test.com', 'boss', NOW())
   ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;
   
   -- For manager@test.com
   INSERT INTO public.users (id, name, email, role, created_at)
   VALUES ('<MANAGER_ID>', 'Manager', 'manager@test.com', 'manager', NOW())
   ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;
   ```

---

## STEP 4: Permission Errors

**IF** migration fails with permission error (e.g., "permission denied to create trigger"):

**Error:** `ERROR: permission denied to create trigger on table "auth.users"`

**Solution:** 
- You need **service_role** or **owner** permissions
- Contact your Supabase project owner to run this migration
- OR use Supabase CLI with service_role key

---

## Expected Results

### Migration Output:
- ✅ `NOTICE: ✅ Barcha userlar role ga ega`
- ✅ `NOTICE: ✅ Barcha userlar valid role ga ega`
- ✅ `NOTICE: ✅ Jami userlar: X`
- ✅ `NOTICE: ✅ Trigger yangilandi!`

### Query 1 Result:
Should show 2 rows (boss@test.com and manager@test.com) IF they exist in auth.users

### Query 2 Result:
Should show 2 rows with correct roles:
- `boss@test.com` → role: `boss`
- `manager@test.com` → role: `manager`

### Query 3 Result:
Should show `on_auth_user_created` trigger

### Query 4 Result:
- `public_users_count` should match or be close to `auth_users_count`
- Both should be > 0

---

## Report Back

After running, provide:
1. Migration execution result (success/errors)
2. Output of all 4 verification queries
3. Any NOTICE messages from the migration
4. Any errors encountered




