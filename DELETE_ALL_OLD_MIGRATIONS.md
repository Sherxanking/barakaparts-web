# Barcha Eski Migration Fayllarini O'chirish

## ⚠️ MUHIM: Avval FINAL_CLEAN_MIGRATION.sql ni Supabase'da ishga tushiring!

1. Supabase Dashboard → SQL Editor
2. `FINAL_CLEAN_MIGRATION.sql` ni ochib, SQL'ni ishga tushiring
3. Keyin quyidagi fayllarni o'chiring

## O'chirilishi kerak bo'lgan fayllar:

### supabase/migrations/ papkasidagi fayllar:
- 001_auth_and_users.sql
- 001_auth_and_users_FIXED.sql
- 002_auth_email_verification.sql
- 003_fix_rls_policies.sql
- 004_ensure_tables_and_fix_rls.sql
- 005_drop_all_policies_and_recreate.sql
- 006_fix_users_rls_recursion.sql
- 007_enable_realtime_for_parts.sql
- 008_rbac_parts_policies.sql
- 009_fix_parts_realtime_and_rls.sql
- 010_create_test_accounts.sql
- 011_fix_rls_use_public_users_role.sql
- 012_fix_trigger_rls_bypass.sql
- 013_complete_user_creation_fix.sql
- 014_fix_trigger_test_accounts_role.sql
- 015_fix_role_for_dashboard_users.sql
- 015_fix_role_for_dashboard_users_FIXED.sql
- 016_fix_missing_users_trigger.sql
- 017_COMPLETE_FIX_ALL_USER_ISSUES.sql
- 018_FIX_UPDATED_AT_COLUMN.sql
- 019_COMPLETE_AUTH_FIX.sql
- 020_fix_parts_permissions.sql
- 021_QUICK_FIX_BOSS_USER.sql
- 022_FIX_USERS_RLS_AND_BOSS_USER.sql
- 999_mvp_permissions_reset.sql

### Root papkadagi eski SQL fayllar:
- FIX_015_MIGRATION.sql
- COMPLETE_LOGIN_FIX.sql
- FIX_USERS_RLS_RECURSION.sql
- CHECK_REALTIME_STATUS.sql (bu tekshirish uchun, o'chirish shart emas)
- FIX_BOSS_USER_CLEAN.sql
- FIX_RLS_RECURSION.sql
- DIRECT_FIX_BOSS_USER.sql
- QUICK_FIX_BOSS_USER_DIRECT.sql
- QUICK_FIX_REALTIME.sql (bu tekshirish uchun, o'chirish shart emas)
- FIX_GOOGLE_USER_ROLE.sql
- FINAL_COMPLETE_FIX.sql
- CREATE_MISSING_TEST_USERS.sql
- COPY_PASTE_THIS_SQL.sql
- QUICK_FIX_POLICY_DROP.sql
- FIX_PARTS_CREATE_PERMISSION_FINAL.sql
- FINAL_GOOGLE_MANAGER_FIX.sql
- FIX_PARTS_PERMISSION_FINAL.sql
- COMPLETE_PARTS_PERMISSION_FIX.sql
- DEBUG_PARTS_PERMISSION.sql
- SET_GOOGLE_LOGIN_MANAGER_ROLE.sql
- FIX_PARTS_CREATE_PERMISSION.sql
- VERIFICATION_QUERIES.sql
- SET_DEFAULT_ROLE_MANAGER.sql
- FIX_RLS_PERMISSION_ERROR.sql
- QUICK_FIX_UPDATED_AT.sql
- RUN_MIGRATION_015.sql
- XAVFSIZ_SQL_QUERY.sql
- SUPABASE_SQL_COMPLETE.sql
- SQL_TO'G'RI_VERSIYA.sql

## Qoldirilishi kerak bo'lgan fayllar:

✅ **FINAL_CLEAN_MIGRATION.sql** - Bu asosiy migration
✅ **QUICK_FIX_REALTIME.sql** - Realtime tekshirish uchun (ixtiyoriy)
✅ **CHECK_REALTIME_STATUS.sql** - Realtime tekshirish uchun (ixtiyoriy)
✅ **supabase/migrations/023_enable_realtime_products_orders.sql** - Realtime uchun (agar kerak bo'lsa)

## Qadamlar:

1. **Avval** `FINAL_CLEAN_MIGRATION.sql` ni Supabase'da ishga tushiring
2. **Keyin** quyidagi fayllarni o'chiring
3. **Test qiling** - app ishlayotganini tekshiring














