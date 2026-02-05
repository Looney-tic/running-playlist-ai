# Phase 01: User Setup

Manual configuration required for external services used in this phase.

## Supabase

**Why:** Backend database and API

### Environment Variables

Add these to your `.env` file in the project root:

| Variable | Source |
|----------|--------|
| `SUPABASE_URL` | Supabase Dashboard -> Project Settings -> API -> Project URL |
| `SUPABASE_ANON_KEY` | Supabase Dashboard -> Project Settings -> API -> anon/public key |

### Dashboard Configuration

1. **Create a Supabase project** (if not already created)
   - Location: https://supabase.com/dashboard -> New Project

2. **Create a `test_table`** with columns: `id` (int8, primary key, auto-increment) and `message` (text)
   - Location: Supabase Dashboard -> Table Editor -> New Table

3. **Disable RLS on `test_table`** (for testing only)
   - Location: Supabase Dashboard -> Table Editor -> test_table -> RLS policies

### Verification

After setup, run the app on any platform:
```bash
flutter run -d chrome
```

Check the debug console for any Supabase connection errors on startup. No errors means the connection is working.

---
*Generated from 01-02-PLAN.md user_setup frontmatter*
