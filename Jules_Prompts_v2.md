# Jules_Prompts.md — Version 2.0
## Issue-Driven Development Roadmap with MCP Probing Protocol
**Constraint**: 15 asynchronous tasks per day (free tier).
**Rule**: One Issue = one atomic, independently testable feature.
**Non-negotiable**: Every issue begins with the MANDATORY DIRECTIVE block. No exceptions.

---

## EXECUTION SEQUENCE

```
DAY 1 (Issues 1–3):   Foundation → Schema + Triggers → Auth
DAY 2 (Issues 4–7):   Matrix → KPIs → Payments → Incidents
DAY 3 (Issues 8–11):  Residents → AG Workflow → Documents Archive → Settings
DAY 4 (Issues 12–15): pdfmake Engine → Signing Pipeline → PWA → Hardening
```

---

## ─────────────────────────────────────────────
## DAY 1 — FOUNDATION
## ─────────────────────────────────────────────

---

### ISSUE #1 — Project Foundation & Supabase Connection

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Initialize the Next.js 14 App Router project with complete structure, TypeScript strict configuration, Tailwind CSS, `next-pwa`, and a verified live Supabase connection. Every subsequent Issue depends on this foundation being correct.

**Pre-Flight MCP Verification:**

Before writing any file, Jules MUST run these MCP queries:

```sql
-- Verify Supabase project is reachable and PostgreSQL version is 15+
SELECT version();

-- Verify the public schema exists and is empty (no tables yet)
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';
-- EXPECTED: 0 rows (clean slate)

-- Verify Supabase Auth schema is present
SELECT schema_name FROM information_schema.schemata
WHERE schema_name = 'auth';
-- EXPECTED: 1 row

-- Verify auth.users table structure (Jules will reference this for FK)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;
```

Record the exact PostgreSQL version and auth.users column structure. These will constrain how `public.users` is defined in Issue #2.

**Implementation Vector:**
- `npx create-next-app@latest amandier-b --typescript --tailwind --app --src-dir --import-alias "@/*"`
- `tsconfig.json`: `strict`, `noImplicitAny`, `strictNullChecks`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` all set to `true`
- Install: `npm install @supabase/supabase-js @supabase/ssr next-pwa`
- Create `src/lib/supabase/client.ts` — browser singleton using `createBrowserClient` from `@supabase/ssr`
- Create `src/lib/supabase/server.ts` — server client using `createServerClient` from `@supabase/ssr`, reads cookies
- Create `.env.local.example` with all required vars from AGENTS.md §6
- Create `src/lib/constants.ts`: `FLOOR_COUNT = 5`, `APT_PER_FLOOR = 3`, `TOTAL_APTS = 15`
- Create `src/lib/env.ts` — startup env validation: throws if any required var is missing
- Scaffold complete directory structure from AGENTS.md §4 (empty files with TODO comments)
- Configure `next.config.js` with `next-pwa` (disabled in dev)
- Create `src/app/api/health/route.ts` — queries Supabase, returns connection status JSON

**Critic Mandate:**
- Critic must verify `tsconfig.json` has ALL 5 strictness flags set — not just `"strict": true`
- Critic must verify `SUPABASE_SERVICE_ROLE_KEY` is referenced ONLY in `server.ts` and `env.ts` — grep `src/` must return no other hits
- Critic must verify `npm run build` exits with code 0
- Critic must verify `npx tsc --noEmit` returns 0 errors
- Critic must verify `next-pwa` config has `disable: process.env.NODE_ENV === 'development'`
- Critic must verify no `any` type exists in any generated `.ts` or `.tsx` file

**Post-Execution MCP Audit:**
```sql
-- Verify Supabase connection is live from the health endpoint perspective
-- Run the same query the health endpoint runs:
SELECT NOW() AS server_time, current_database() AS db_name;
-- EXPECTED: Returns current timestamp and database name without error
```

**Acceptance Testing (Human Operator):**
1. Open Vercel preview URL → `/api/health` → verify `{"status":"ok","supabase":"connected"}`
2. DevTools → Application → Service Workers → verify NO service worker registered
3. Run `npx tsc --noEmit` locally → 0 errors
4. Verify `.env.local.example` lists all required variables

---

### ISSUE #2 — Database Schema, Triggers, Views, RLS, RPC Functions

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Deploy the complete database schema: all DDL, enums, constraints, triggers, views, RPC functions, and RLS policies. This is the single most critical Issue in the entire project. Financial integrity, security isolation, and all business logic depend on this being executed correctly.

**Pre-Flight MCP Verification:**

```sql
-- 1. Confirm clean public schema before migration
SELECT COUNT(*) AS existing_tables
FROM information_schema.tables
WHERE table_schema = 'public';
-- EXPECTED: 0 (if running fresh) or document existing tables before proceeding

-- 2. Verify auth.users id column type (must be UUID — FK dependency)
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'auth'
  AND table_name = 'users'
  AND column_name = 'id';
-- EXPECTED: data_type = 'uuid'

-- 3. Verify PostgreSQL extensions available (needed for gen_random_uuid)
SELECT extname FROM pg_extension;
-- EXPECTED: 'uuid-ossp' or 'pgcrypto' in results
-- If neither present: CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 4. Verify btree_gist extension available (needed for EXCLUDE constraint on payments)
SELECT extname FROM pg_extension WHERE extname = 'btree_gist';
-- If not present: CREATE EXTENSION IF NOT EXISTS btree_gist;
```

Run the above queries FIRST. Do not write any migration SQL until these preconditions are confirmed.

**Implementation Vector:**

Create `supabase/migrations/001_schema.sql`:
- All ENUM types (`user_role`, `user_statut`, `apt_statut`, `resident_type`, `payment_mode`, `payment_statut`, `flux_type`, `flux_categorie`, `compte_type`, `incident_priorite`, `incident_statut`, `ag_type`, `ag_statut`, `doc_type`)
- All 11 tables with exact column definitions, check constraints, FK constraints with explicit ON DELETE rules, and performance indexes — as defined in CCT_CCI.md §3
- Partial EXCLUDE index on `payments(appartement_id, periode) WHERE statut='valide'` — requires `btree_gist` extension
- Sequences and `generate_serial_id()` function

Create `supabase/migrations/002_rls.sql`:
- `ALTER TABLE <every_table> ENABLE ROW LEVEL SECURITY;` — 11 statements
- All RLS policies for all 4 roles on all relevant tables
- Naming convention: `"<role>_<table>_<action>"` e.g. `"resident_payments_select"`

Create `supabase/migrations/003_triggers.sql`:
- `fn_on_payment_validated` + `tg_payment_validated`
- `fn_protect_flux_tresorerie` + `tg_protect_flux`
- `fn_protect_audit_log` + `tg_protect_audit`
- `fn_incident_fsm` + `tg_incident_fsm`

Create `supabase/migrations/004_views_rpc.sql`:
- `v_apartment_balance` view
- `get_kpi_dashboard()` RPC — returns single JSON object, `SECURITY DEFINER`
- `get_matrix_data()` RPC — returns table, `SECURITY DEFINER`

Create `supabase/seed.sql` — 15 apartments + 1 `residence_settings` row.

Run: `npx supabase gen types typescript --project-id $SUPABASE_PROJECT_ID > src/lib/supabase/types.ts`

**Critic Mandate:**
- Critic must verify the `btree_gist` extension is enabled before the EXCLUDE constraint migration runs — if not, the migration will fail silently on some Supabase plans
- Critic must verify all 11 tables have `relrowsecurity = true` (verified via MCP Post-Execution Audit below)
- Critic must verify the partial EXCLUDE index on `payments` blocks a second `valide` payment for same `(appartement_id, periode)` — tested via MCP
- Critic must verify `fn_on_payment_validated` fires: after UPDATE sets `statut='valide'`, `flux_tresorerie` contains exactly 1 new row and `audit_log` contains exactly 1 new row
- Critic must verify `fn_protect_flux_tresorerie` raises on UPDATE attempt
- Critic must verify `npx tsc --noEmit` passes after type generation — type drift is a blocking error

**Post-Execution MCP Audit:**

```sql
-- AUDIT 1: Verify all tables have RLS enabled
SELECT relname AS table_name, relrowsecurity AS rls_enabled
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relkind = 'r'  -- ordinary tables only
ORDER BY relname;
-- EXPECTED: relrowsecurity = true for ALL 11 tables
-- FAILURE: Any row showing false = critical security defect, PR blocked

-- AUDIT 2: Verify ENUM types exist with correct values
SELECT t.typname, e.enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname IN ('payment_statut', 'user_role', 'incident_statut', 'flux_type')
ORDER BY t.typname, e.enumsortorder;
-- EXPECTED: All enum values present as defined in CCT_CCI.md

-- AUDIT 3: Fire the payment trigger and verify side effects
DO $$
DECLARE
  v_apt_id UUID;
  v_user_id UUID;
  v_payment_id UUID;
  v_flux_count INT;
  v_audit_count INT;
BEGIN
  SELECT id INTO v_apt_id FROM apartments WHERE code = 'E1A1' LIMIT 1;
  SELECT id INTO v_user_id FROM users WHERE role = 'syndic' LIMIT 1;

  INSERT INTO payments (appartement_id, periode, montant, mode_paiement, date_paiement, statut, created_by)
  VALUES (v_apt_id, '2025-01-01', 1200.00, 'especes', CURRENT_DATE, 'en_attente', v_user_id)
  RETURNING id INTO v_payment_id;

  UPDATE payments SET statut = 'valide', valide_par = v_user_id WHERE id = v_payment_id;

  SELECT COUNT(*) INTO v_flux_count FROM flux_tresorerie WHERE source_id = v_payment_id;
  SELECT COUNT(*) INTO v_audit_count FROM audit_log WHERE objet_id = v_payment_id AND action = 'payment.validated';

  ASSERT v_flux_count = 1, 'TRIGGER FAILURE: flux_tresorerie entry not created';
  ASSERT v_audit_count = 1, 'TRIGGER FAILURE: audit_log entry not created';

  -- Test immutability
  BEGIN
    UPDATE flux_tresorerie SET montant = 0 WHERE source_id = v_payment_id;
    RAISE EXCEPTION 'PROTECTION FAILURE: flux_tresorerie UPDATE was not blocked';
  EXCEPTION WHEN others THEN
    -- Expected exception from protection trigger — this is correct
    NULL;
  END;

  -- Cleanup
  DELETE FROM payments WHERE id = v_payment_id;
  RAISE NOTICE 'AUDIT PASSED: All trigger assertions verified';
END;
$$;

-- AUDIT 4: Verify EXCLUDE constraint blocks duplicate validated payment
-- (Run after AUDIT 3 cleanup to ensure no residual data)
DO $$
DECLARE
  v_apt_id UUID;
  v_user_id UUID;
  v_p1_id UUID;
BEGIN
  SELECT id INTO v_apt_id FROM apartments WHERE code = 'E2A2' LIMIT 1;
  SELECT id INTO v_user_id FROM users WHERE role = 'syndic' LIMIT 1;

  INSERT INTO payments (appartement_id, periode, montant, mode_paiement, date_paiement, statut, created_by)
  VALUES (v_apt_id, '2025-03-01', 1200.00, 'especes', CURRENT_DATE, 'valide', v_user_id)
  RETURNING id INTO v_p1_id;

  -- Second payment, same apartment, same period, same statut='valide' — must fail
  BEGIN
    INSERT INTO payments (appartement_id, periode, montant, mode_paiement, date_paiement, statut, created_by)
    VALUES (v_apt_id, '2025-03-01', 1200.00, 'virement', CURRENT_DATE, 'valide', v_user_id);
    RAISE EXCEPTION 'CONSTRAINT FAILURE: Duplicate validated payment was allowed — CRITICAL';
  EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'AUDIT PASSED: Duplicate payment blocked with exclusion_violation';
  END;

  DELETE FROM payments WHERE id = v_p1_id;
END;
$$;

-- AUDIT 5: RLS Cross-tenant isolation check
-- (Requires at least 2 test users in auth.users — confirm with seed data)
SELECT COUNT(*) AS total_payments FROM payments;
-- Record this count for comparison against resident-scoped query in Issue #3 acceptance tests
```

**Acceptance Testing (Human Operator):**
1. Open Supabase dashboard → Table Editor → verify 11 tables exist with correct columns
2. Open Supabase → Authentication → Policies → verify every table shows "RLS Enabled"
3. SQL Editor → run `SELECT * FROM get_kpi_dashboard();` → verify valid JSON returned
4. SQL Editor → run `SELECT * FROM get_matrix_data();` → verify 15 rows
5. SQL Editor → run `SELECT * FROM v_apartment_balance;` → verify 15 rows with `balance_state` column
6. Verify seed: 15 rows in `apartments`, 1 row in `residence_settings`

---

### ISSUE #3 — Authentication System (Topographical Login + Role-Based Routing)

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Implement complete authentication: 3-step topographical PIN flow for residents, email+password for syndic/admin, role-based middleware protecting all routes.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify users table structure matches what Auth will populate
SELECT column_name, data_type, udt_name, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;
-- Jules must confirm: id (uuid), role (user_role ENUM), pin_hash (text, nullable)
-- Any column mismatch with planned TypeScript interfaces must be resolved NOW

-- 2. Verify user_role ENUM values
SELECT enumlabel FROM pg_enum
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')
ORDER BY enumsortorder;
-- EXPECTED: 'syndic', 'gestionnaire', 'gardien', 'resident'

-- 3. Verify RLS on users table — resident must not read other users' pin_hash
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public';
-- Jules must confirm a policy exists that restricts pin_hash visibility

-- 4. Verify apartments table has the 'code' generated column for derived email construction
SELECT column_name, data_type, is_generated
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'apartments'
  AND column_name IN ('code', 'etage', 'numero');
```

**Implementation Vector:**
- `src/app/(auth)/login/page.tsx` — 3-step flow managed by `useReducer` with states `'floor' | 'apartment' | 'pin'`; floor buttons 1–5; apt buttons 1–3; 4-dot PIN input; derived email: `apt_E{floor}A{apt}@amandier-b.internal`; calls `supabase.auth.signInWithPassword`
- `src/app/admin/login/page.tsx` — email+password form; reads `session.user.app_metadata.role` on success; redirects to `/syndic/dashboard`
- `src/middleware.ts` — reads Supabase session from cookies via `createServerClient`; blocks unauthenticated access; enforces role→route mapping; redirects on mismatch; generates a 16-byte base64 nonce using `crypto.getRandomValues()`; injects strict Content-Security-Policy (CSP) via `Content-Security-Policy` and `X-Content-Security-Policy` headers; CSP must use the nonce for `script-src` and `style-src` (e.g., `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'; style-src 'self' 'nonce-${nonce}';`); the nonce is passed to the request headers (e.g., `x-nonce`) so it can be consumed by `src/app/layout.tsx` for inline scripts and styles.
- `src/contexts/AuthContext.tsx` — provides `user`, `role`, `apartmentId`, `signOut()`; subscribes to `supabase.auth.onAuthStateChange`; calls `supabase.auth.refreshSession()` on 401 errors

**Critic Mandate:**
- Critic must verify: the PIN value is NEVER logged to `console.log`, `console.error`, or any audit mechanism — grep `login/page.tsx` for PIN variable references
- Critic must verify: direct navigation to `/syndic/dashboard` without a valid session cookie returns a redirect (HTTP 307), NOT a 200 with empty data or a 500
- Critic must verify: a resident JWT (`app_metadata.role = 'resident'`) accessing `/syndic/dashboard` is redirected, not granted access
- Critic must verify: `signOut()` clears the Supabase session cookie AND redirects — not just redirects
- Critic must verify: the PIN input field has `type="password"` or equivalent masking — never `type="text"`
- **Race condition check**: Critic must verify that rapid successive PIN submit attempts (double-tap scenario) do not result in two concurrent `signInWithPassword` calls. Implement a `isSubmitting` ref-based guard, not a state-based one (state updates are asynchronous and will miss rapid taps)

**Post-Execution MCP Audit:**

```sql
-- Verify test user creation and role assignment
-- (After creating a test syndic user via Supabase Auth dashboard)
SELECT u.id, u.email, pu.role, pu.nom, pu.statut
FROM auth.users u
JOIN public.users pu ON pu.id = u.id
WHERE u.email LIKE '%amandier-b.internal%'
   OR pu.role IN ('syndic', 'gestionnaire');
-- EXPECTED: At least 1 syndic user, at least 1 resident user

-- Verify resident cannot read other users data (RLS simulation)
-- Jules must document which test user IDs are used for cross-tenant checks
SELECT COUNT(*) FROM users;
-- With resident JWT: should return 1 (own row only)
-- With syndic JWT: should return full count
```

**Acceptance Testing (Human Operator):**
1. Open `/login` on 375px viewport → verify 5 floor buttons render in a clean grid
2. Select Floor 3 → Apt 2 → enter correct PIN → verify redirect to `/resident/dashboard`
3. Enter wrong PIN → verify: "Code PIN incorrect. Veuillez réessayer." (no redirect)
4. Open `/syndic/dashboard` directly without login → verify 307 redirect to `/login`
5. Log in as syndic via `/admin/login` → verify redirect to `/syndic/dashboard`
6. As syndic, call `signOut()` → verify session cookie is cleared (DevTools → Application → Cookies)

---

## ─────────────────────────────────────────────
## DAY 2 — CORE FEATURE UI
## ─────────────────────────────────────────────

---

### ISSUE #4 — Apartment Matrix Component

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Build `<ApartmentMatrix />` — 5×3 CSS Grid, real-time financial state per unit. No data-grid libraries. Pure CSS Grid + Tailwind. The most critical UI rendering component.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify get_matrix_data() exists and returns the correct column set
SELECT proname, pg_get_function_result(oid) AS return_type
FROM pg_proc
WHERE proname = 'get_matrix_data'
  AND pronamespace = 'public'::regnamespace;
-- EXPECTED: 1 row — if 0 rows, Issue #2 migration was incomplete — STOP

-- 2. Verify the RPC return columns match the TypeScript interface Jules will write
SELECT * FROM get_matrix_data() LIMIT 1;
-- Jules must compare the column names against the planned MatrixCell interface:
-- { appartement_id, code, etage, numero, resident_nom, apt_statut, balance_state, balance }
-- Any column name mismatch = update the TypeScript interface before writing the component

-- 3. Verify v_apartment_balance view exists and includes balance_state
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'v_apartment_balance';
-- EXPECTED: includes 'balance_state' column

-- 4. Verify Realtime is enabled on the payments table (required for cache invalidation)
SELECT tablename, replica_identity
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename = 'payments';
-- If payments is not in the publication, Realtime subscriptions will not fire
-- Jules must add it: ALTER PUBLICATION supabase_realtime ADD TABLE payments;
```

**Implementation Vector:**
- `src/hooks/useMatrixData.ts` — **MUST implement the exact cleanup pattern from AGENTS.md §17.2**: `isMountedRef`, `channelRef`, explicit `supabase.removeChannel()` in useEffect cleanup
- `src/lib/utils/colors.ts` — `BALANCE_STATE_CLASSES` record as defined in AGENTS.md §14
- `src/components/dashboard/ApartmentCell.tsx` — props typed from `get_matrix_data()` return type (sourced from `types.ts`); min-h-[80px]; name truncated at 14 chars; clickable
- `src/components/dashboard/ApartmentMatrix.tsx` — single `supabase.rpc('get_matrix_data')` call; skeleton loader; CSS Grid `grid-cols-3`; floor labels between groups; etage 5 at top
- `src/components/dashboard/ApartmentDetailModal.tsx` — slide-up drawer; resident info; last 6 payments; link to filtered payments page

**Critic Mandate:**
- Critic must verify: NO import of `ag-grid`, `@tanstack/react-table`, `@mui/x-data-grid`, `react-window`, or any data-grid library appears in any component file
- Critic must verify: `get_matrix_data()` is called exactly ONCE per mount — not once per cell, not once per floor group
- Critic must verify: the `useEffect` cleanup function calls `supabase.removeChannel(channelRef.current)` — absence of this is a **memory leak defect** and blocks the PR
- Critic must verify: the `isMountedRef.current = false` assignment happens BEFORE the async cleanup — not after
- Critic must verify: when the RPC returns 0 rows (empty DB), the component renders 0 cells without crashing (no `data[0].etage` access on empty array)
- **Race condition check**: Critic must verify the Realtime subscription `fetchData` callback is guarded by `if (isMountedRef.current)` — a subscription event firing after unmount must not call `dispatch`

**Post-Execution MCP Audit:**

```sql
-- Trigger a matrix state change and verify the component would pick it up
-- Simulate a payment validation that should change an apartment's balance_state

-- Check current state of E1A1
SELECT appartement_id, balance_state, balance
FROM v_apartment_balance
WHERE code = 'E1A1';

-- If E1A1 has an active resident, create and validate a payment
-- (reuse the test script from Issue #2 AUDIT 3)
-- Then re-query v_apartment_balance to confirm balance_state changed
-- This proves the view is live and the Realtime subscription would trigger a refetch

-- Verify Realtime publication includes payments table
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime';
-- EXPECTED: 'payments' in the results
```

**Acceptance Testing (Human Operator):**
1. Load `/syndic/dashboard` → verify exactly 15 colored cells within 2 seconds
2. Verify floor 5 is at the TOP of the matrix, floor 1 at the BOTTOM
3. Verify each cell shows: apt code, resident name (or "Vacant"), color state
4. Click any cell → verify detail drawer opens without page navigation
5. Throttle to "Slow 3G" → reload → verify skeleton (15 pulsing gray cells) appears during load
6. Mobile viewport 375px → verify no horizontal scroll, all 3 columns readable

---

### ISSUE #5 — KPI Cards, Runway Indicator & Dashboard Assembly

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Build the 6-KPI financial strip and Runway indicator above the apartment matrix. All data sourced from a single `get_kpi_dashboard()` RPC call. Dashboard page assembled with correct render order.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify get_kpi_dashboard() exists and has correct return structure
SELECT proname, prosecdef AS security_definer
FROM pg_proc
WHERE proname = 'get_kpi_dashboard'
  AND pronamespace = 'public'::regnamespace;
-- EXPECTED: 1 row, prosecdef = true (SECURITY DEFINER is mandatory for KPI aggregation)

-- 2. Execute the RPC and verify all expected keys are present
SELECT get_kpi_dashboard();
-- Jules must confirm the returned JSON contains ALL of:
-- solde_total, solde_caisse, solde_banque, runway, runway_state,
-- nb_impayes, nb_actifs, taux_recouvrement, generated_at
-- Missing key = Issue #2 migration is incomplete — STOP and fix before proceeding

-- 3. Verify charges_fixes_mensuelles is set (runway calculation requires it)
SELECT charges_fixes_mensuelles FROM residence_settings LIMIT 1;
-- If 0: runway will return 999 (infinity guard) — this is expected behavior, not a bug

-- 4. Verify residence_settings has exactly 1 row (single-row table invariant)
SELECT COUNT(*) FROM residence_settings;
-- EXPECTED: 1
-- If 0: seed data was not applied — run supabase/seed.sql before proceeding
```

**Implementation Vector:**
- `src/hooks/useKPIs.ts` — single `supabase.rpc('get_kpi_dashboard')` call; typed return using `KPIDashboard` interface derived from the MCP-verified JSON structure; 60-second auto-refresh via `setInterval` with cleanup; Realtime invalidation on `payments` UPDATE events; **cleanup pattern from AGENTS.md §17.2 applies here too**
- `src/lib/utils/runway.ts` — `classifyRunway()` and `RUNWAY_CLASSES` as defined in AGENTS.md §13; division-by-zero guard: if `chargesFixesMensuelles = 0`, return `999` and state `'healthy'`
- `src/components/dashboard/KPICard.tsx` — compact card; MAD currency formatting via `toLocaleString('fr-MA', { style: 'currency', currency: 'MAD' })`
- `src/components/dashboard/RunwayIndicator.tsx` — full-width card; color-coded by `RunwayState`; `animate-pulse` when `critical`; shows month count with 1 decimal
- `src/components/dashboard/KPIStrip.tsx` — 2×3 responsive grid of 6 `<KPICard />` instances
- `src/app/(syndic)/dashboard/page.tsx` — React Server Component; parallel fetch: `Promise.all([supabase.rpc('get_kpi_dashboard'), supabase.rpc('get_matrix_data')])`; render order: `<KPIStrip />` → `<RunwayIndicator />` → `<ApartmentMatrix />` → `<IncidentAlertList />`

**Critic Mandate:**
- Critic must verify: `get_kpi_dashboard()` is invoked exactly ONCE — not once per `<KPICard />` instance
- Critic must verify: when `taux_recouvrement` is 0 (no active apartments), the KPICard renders "N/A", not `NaN%` or `0/0%`
- Critic must verify: when `solde_total` is negative, the Solde Total card renders in red, not default styling
- Critic must verify: the `setInterval` inside `useKPIs` is cleared in the `useEffect` cleanup — missing clearInterval is a memory leak
- Critic must verify: the Realtime subscription in `useKPIs` follows the `isMountedRef` + `channelRef` pattern from AGENTS.md §17.2
- **Race condition check**: Critic must verify that if `useKPIs` and `useMatrixData` both subscribe to `payments` changes, they use DIFFERENT channel names — two subscriptions on the same channel name will conflict

**Post-Execution MCP Audit:**

```sql
-- Verify the KPI values are mathematically consistent
SELECT
  (SELECT COALESCE(SUM(montant) FILTER (WHERE type_flux='entree'), 0) -
          COALESCE(SUM(montant) FILTER (WHERE type_flux='sortie'), 0)
   FROM flux_tresorerie) AS manual_solde_total,
  (get_kpi_dashboard()->>'solde_total')::NUMERIC AS rpc_solde_total;
-- EXPECTED: manual_solde_total = rpc_solde_total
-- Discrepancy = bug in get_kpi_dashboard() function — report and fix before PR

-- Verify runway calculation consistency
SELECT
  (get_kpi_dashboard()->>'runway')::NUMERIC AS runway_value,
  (get_kpi_dashboard()->>'runway_state')::TEXT AS runway_state;
-- Manually verify: if runway_value > 6 then runway_state = 'healthy', etc.
```

**Acceptance Testing (Human Operator):**
1. Load `/syndic/dashboard` → verify 6 KPI cards all show numeric values (no NaN, no undefined)
2. Supabase SQL Editor → set `charges_fixes_mensuelles = 50000` in `residence_settings` → verify runway KPI updates within 60 seconds (auto-refresh)
3. Verify Runway shows red/pulsing when < 3 months
4. Mobile viewport: verify 2-column KPI grid, no overflow
5. Verify currency format: "1 200,00 MAD" (French locale, MAD)

---

### ISSUE #6 — Payment Management: List, Create, Validate, Receipt

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Complete payment management: list with filters, create form, inline validation with optimistic lock, receipt generation. Financial core of the application.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify payments table full column structure
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'payments'
ORDER BY ordinal_position;
-- Jules must map EVERY column to the PaymentForm fields and TypeScript interfaces
-- Especially: verify 'periode' is DATE type (not TIMESTAMPTZ) — affects form date picker behavior

-- 2. Verify payment_statut ENUM values
SELECT enumlabel FROM pg_enum
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_statut')
ORDER BY enumsortorder;
-- EXPECTED: 'en_attente', 'valide', 'rejete', 'annule'

-- 3. Verify payment_mode ENUM values
SELECT enumlabel FROM pg_enum
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_mode')
ORDER BY enumsortorder;
-- EXPECTED: 'especes', 'virement', 'cheque', 'mobile_money'

-- 4. Verify the EXCLUDE constraint on payments exists and is partial
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.payments'::regclass
  AND contype = 'x';  -- exclusion constraints
-- EXPECTED: constraint definition includes WHERE (statut = 'valide')

-- 5. Verify fn_on_payment_validated trigger is active on payments table
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'payments'
  AND trigger_schema = 'public';
-- EXPECTED: tg_payment_validated present with BEFORE UPDATE
```

**Implementation Vector:**
- `src/hooks/usePayments.ts` — paginated query (page size 20); joins `apartments`, `residents`, `users`; filters by `appartement_id?`, `periode?`, `statut?`
- `src/app/(syndic)/payments/page.tsx` — filter bar (month picker, apt selector, status tabs); list/table view; FAB "Nouveau Paiement"
- `src/components/payments/PaymentForm.tsx` — form fields with `appartement_id` and `periode` required; `montant` pre-filled from `apartments.cotisation_mensuelle`; INSERT with `statut='en_attente'`; catches PostgreSQL error code `23505` → French error message
- `src/components/payments/ValidationButton.tsx` — **MUST implement the optimistic lock from AGENTS.md §17.1**: `.eq('statut', 'en_attente')` on the UPDATE query; surfaces concurrent modification error to user; confirmation dialog before submission; `isSubmitting` ref-based guard (not state-based) against double-tap
- `src/components/payments/ReceiptButton.tsx` — visible ONLY for `statut='valide'`; calls `generateReceipt()` from Issue #12; loading spinner during generation
- `src/components/ui/Toast.tsx` + `src/contexts/ToastContext.tsx` — success/error/warning/info; auto-dismiss 4s; max 3 stacked; bottom-right positioning

**Critic Mandate:**
- Critic must verify: the optimistic lock `.eq('statut', 'en_attente')` is present on the validation UPDATE — its absence is a **race condition defect** and blocks the PR
- Critic must verify: the double-tap guard is implemented with `useRef<boolean>` (not `useState`) — state-based guards have a render-cycle lag that allows rapid double-taps through
- Critic must verify: "Reçu" button is ABSENT from DOM (not just disabled) for `statut !== 'valide'` payments
- Critic must verify: PostgreSQL error code `23505` surfaces the message "Un paiement validé existe déjà pour cet appartement sur cette période." — not a raw error object
- Critic must verify: after validation, the KPI cache is invalidated — `useKPIs` must refetch (via Realtime event or explicit refetch call)
- **Race condition check**: Critic must verify that a concurrent validation scenario is handled gracefully — the second validation attempt must receive the "already processed" error, not silently succeed or crash

**Post-Execution MCP Audit:**

```sql
-- After a payment is validated via UI, verify all trigger side effects
-- Query from Supabase SQL Editor using the payment ID from the UI

-- Replace <payment_id> with the actual UUID from the validated payment
SELECT p.id, p.statut, p.serial_id, p.valide_at,
       ft.id AS flux_id, ft.type_flux, ft.montant AS flux_montant,
       al.action AS audit_action, al.created_at AS audit_ts
FROM payments p
LEFT JOIN flux_tresorerie ft ON ft.source_id = p.id
LEFT JOIN audit_log al ON al.objet_id = p.id AND al.action = 'payment.validated'
WHERE p.id = '<payment_id>';
-- EXPECTED: statut='valide', serial_id NOT NULL, flux_id NOT NULL, audit_action='payment.validated'

-- Verify immutability of the flux entry
UPDATE flux_tresorerie SET montant = 9999 WHERE source_id = '<payment_id>';
-- EXPECTED: ERROR — "flux_tresorerie is append-only"

-- Verify concurrent validation is blocked
-- Create a second 'en_attente' payment for same apt+period (different payment ID is fine)
-- Then attempt to validate BOTH simultaneously via two SQL UPDATE statements in one block
-- The EXCLUDE constraint should block the second one at DB level
```

**Acceptance Testing (Human Operator):**
1. Create new payment → submit → verify "En Attente" badge in list
2. Click "Valider" → confirm dialog → verify badge changes to "Validé" (optimistic update)
3. Supabase dashboard → `flux_tresorerie` → verify new entry exists for this payment
4. Click "Reçu" on validated payment → verify PDF downloads with correct data
5. Try to create a second payment for same apt+month → validate it → verify French error message
6. Verify toast appears after validation with ✅ success icon
7. Open DevTools → Network → click "Reçu" → verify ZERO network requests during PDF generation

---

### ISSUE #7 — Incident Management: FSM + List + Assignation

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Full incident management with DB-enforced FSM transitions, role-filtered access, and dashboard alert embedding.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify incidents table full column structure
SELECT column_name, data_type, udt_name, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'incidents'
ORDER BY ordinal_position;

-- 2. Verify incident ENUM types
SELECT t.typname, e.enumlabel
FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname IN ('incident_priorite', 'incident_statut')
ORDER BY t.typname, e.enumsortorder;
-- EXPECTED: priorite = {basse, normale, haute, critique}
--           statut   = {ouvert, en_cours, resolu, cloture}

-- 3. Verify fn_incident_fsm trigger exists and is BEFORE UPDATE
SELECT trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'incidents'
  AND trigger_name = 'tg_incident_fsm';
-- EXPECTED: 1 row, action_timing = 'BEFORE', event_manipulation = 'UPDATE'
-- If missing: Issue #2 migration incomplete — STOP

-- 4. Verify RLS policies on incidents — gardien must only see assigned incidents
SELECT policyname, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'incidents' AND schemaname = 'public'
ORDER BY policyname;
-- Jules must verify a policy exists restricting gardien SELECT to rows where assigne_a = auth.uid()
```

**Implementation Vector:**
- `src/hooks/useIncidents.ts` — query with joins; filters: `statut[]`, `priorite[]`, `assigne_a?`; sorted by priorite DESC (critique first), `date_ouverture DESC`
- `src/app/(syndic)/incidents/page.tsx` — tab navigation (Ouverts/En Cours/Résolus/Clôturés); priority filter chips with color coding
- `src/components/incidents/IncidentCard.tsx` — priority color left border; FSM action buttons filtered by role; elapsed time via `Intl.RelativeTimeFormat('fr')`
- `src/components/incidents/IncidentFSM.tsx` — validates transition legality; calls UPDATE; catches PostgreSQL RAISE EXCEPTION from trigger; surfaces "Transition invalide: [reason]" to user
- `src/components/incidents/IncidentForm.tsx` — create modal; available to all roles; apartment is optional
- `src/app/(syndic)/dashboard/IncidentAlertList.tsx` — top 3 critique/haute open incidents; embedded in dashboard below matrix

**Critic Mandate:**
- Critic must verify: attempting to set `statut='en_cours'` with `assigne_a=NULL` surfaces the PostgreSQL trigger exception as a user-readable French message — not a raw error
- Critic must verify: the gardien role cannot access the "Clôturer" action button in the UI (role check in component)
- Critic must verify: elapsed time renders as human-readable French ("Il y a 3 jours", not "72 hours ago" or a raw timestamp)
- Critic must verify: the incident list uses a stable sort — critique incidents always appear before haute, regardless of creation order
- **Race condition check**: Critic must verify that if two users simultaneously attempt to assign an incident to different gardiens, the second assignment does not silently fail — the FSM trigger is idempotent for `assigne_a` changes, but the UI must refetch after assignment to show the current state

**Post-Execution MCP Audit:**

```sql
-- Test FSM transitions via direct SQL (bypasses UI, tests trigger in isolation)

-- Test: en_cours without assigne_a must fail
DO $$
DECLARE v_incident_id UUID;
BEGIN
  INSERT INTO incidents (type_incident, description, priorite, statut, rapporte_par)
  VALUES ('Fuite eau', 'Test incident', 'haute', 'ouvert',
          (SELECT id FROM users WHERE role = 'syndic' LIMIT 1))
  RETURNING id INTO v_incident_id;

  BEGIN
    UPDATE incidents SET statut = 'en_cours', assigne_a = NULL WHERE id = v_incident_id;
    RAISE EXCEPTION 'FSM FAILURE: en_cours without assigne_a was allowed';
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE '%assign%' THEN
      RAISE NOTICE 'AUDIT PASSED: FSM correctly blocked en_cours without assignee';
    ELSE
      RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
    END IF;
  END;

  -- Cleanup
  DELETE FROM incidents WHERE id = v_incident_id;
END;
$$;

-- Test: legal transition ouvert → en_cours with assigne_a
-- (verify date_resolution is NOT set on this transition)
-- Test: en_cours → resolu (verify date_resolution IS set automatically)
-- Test: resolu → cloture (verify date_cloture IS set automatically)
-- Run each as separate DO $$ blocks and verify via SELECT after UPDATE
```

**Acceptance Testing (Human Operator):**
1. Create incident with priority "Critique" → verify it appears first in list
2. Assign to gardien → verify status badge changes to "En Cours"
3. Log in as gardien → verify only assigned incident is visible
4. Gardien resolves → verify `date_resolution` set in Supabase dashboard
5. Attempt to move from "Ouvert" directly to "Clôturé" → verify FSM blocks or allows (per design — syndic CAN direct-close)
6. Verify dashboard alert list shows this incident with priority indicator

---

## ─────────────────────────────────────────────
## DAY 3 — SECONDARY FEATURES
## ─────────────────────────────────────────────

---

### ISSUE #8 — Resident Management: CRUD, History, PIN Management

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Full resident lifecycle: create, link to apartment, deactivate on move-out, view occupancy history, syndic-side PIN reset, resident self-service dashboard.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify residents table including the EXCLUDE constraint for overlap prevention
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.residents'::regclass;
-- EXPECTED: uq_active_resident EXCLUDE constraint with daterange overlap check

-- 2. Verify btree_gist is enabled (required for daterange EXCLUDE)
SELECT extname FROM pg_extension WHERE extname = 'btree_gist';
-- EXPECTED: 1 row — if missing, the EXCLUDE constraint from Issue #2 may not be active

-- 3. Verify users table pin_hash column
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name = 'pin_hash';
-- EXPECTED: data_type = 'text', is_nullable = 'YES' (nullable — unset until first PIN creation)

-- 4. Verify RLS: resident cannot read pin_hash of other users
SELECT policyname, qual FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public';
-- Confirm a SELECT policy exists that prevents cross-user pin_hash access
```

**Implementation Vector:**
- `src/app/(syndic)/residents/page.tsx` — searchable list; filters Active/All/By Floor; actions: Modifier, Départ, Réinitialiser PIN
- `src/components/residents/ResidentForm.tsx` — fields: Prénom, Nom, Téléphone, Email (optional), Type, Apartment selector (vacant/current only), Date d'entrée; on create: INSERT `auth.users` + INSERT `public.users` + INSERT `residents`; auto-generate 4-digit PIN; display PIN once in success modal ("PIN créé: 4782 — Ce code ne sera plus affiché")
- `src/components/residents/ResidentHistory.tsx` — timeline of all residents per apartment
- `src/components/residents/PINResetModal.tsx` — syndic enters new 4-digit PIN; calls server-side Route Handler `/api/residents/reset-pin` to update `pin_hash` (bcrypt) — PIN never sent client→server in plain text, only hashed
- `src/app/(resident)/dashboard/page.tsx` — resident-facing: own apartment info, own balance, own last 3 payments, own incidents

**Critic Mandate:**
- Critic must verify: the plain-text PIN is stored as bcrypt hash in `users.pin_hash` — the actual PIN value exists only in the one-time display modal and is never persisted to any log, cookie, or database column in plain form
- Critic must verify: the PIN reset Route Handler is `POST /api/residents/reset-pin` — it accepts only the hashed PIN (bcrypt computed server-side), not the plain PIN from the client
- Critic must verify: creating a resident for an occupied apartment fails with the `uq_active_resident` EXCLUDE constraint error — the UI must catch this and display "Cet appartement est déjà occupé sur cette période"
- Critic must verify: deactivating a resident (`actif=false, date_sortie=TODAY`) updates `apartments.statut` to `'vacant'` — this must happen atomically (trigger or explicit server-side UPDATE)
- **Edge case check**: Critic must verify `src/app/(resident)/dashboard/page.tsx` fetches data using the resident's JWT — the RLS policies on `payments` and `v_apartment_balance` must restrict results to their own apartment without any application-level filtering

**Post-Execution MCP Audit:**

```sql
-- Verify EXCLUDE constraint prevents overlapping active residents
DO $$
DECLARE
  v_apt_id UUID;
  v_user1_id UUID;
  v_user2_id UUID;
  v_res1_id UUID;
BEGIN
  SELECT id INTO v_apt_id FROM apartments WHERE code = 'E3A2' LIMIT 1;
  SELECT id INTO v_user1_id FROM users LIMIT 1 OFFSET 0;
  SELECT id INTO v_user2_id FROM users LIMIT 1 OFFSET 1;

  INSERT INTO residents (user_id, appartement_id, type_residence, date_entree, actif)
  VALUES (v_user1_id, v_apt_id, 'locataire', '2025-01-01', true)
  RETURNING id INTO v_res1_id;

  -- Attempt overlapping resident (same apt, overlapping dates)
  BEGIN
    INSERT INTO residents (user_id, appartement_id, type_residence, date_entree, actif)
    VALUES (v_user2_id, v_apt_id, 'proprietaire', '2025-06-01', true);
    RAISE EXCEPTION 'CONSTRAINT FAILURE: Overlapping resident was allowed';
  EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'AUDIT PASSED: Overlapping resident blocked by EXCLUDE constraint';
  END;

  DELETE FROM residents WHERE id = v_res1_id;
END;
$$;
```

**Acceptance Testing (Human Operator):**
1. Create new resident for a vacant apartment → verify PIN shown once in modal
2. Verify new resident appears in list with "Actif" badge
3. Click "Départ" → confirm → verify apartment shows "Vacant" in matrix within 30 seconds
4. Log in as resident → verify dashboard shows ONLY their apartment data (no other apartments visible)
5. Attempt to create a second active resident for the same apartment → verify conflict error

---

### ISSUE #9 — Assemblée Générale Workflow

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Complete AG lifecycle: plan, convoke, record attendance, calculate quorum, record votes, generate PV. The most complex workflow in the application.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify ag_sessions and ag_presences tables
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('ag_sessions', 'ag_presences')
ORDER BY table_name, ordinal_position;

-- 2. Verify ag_type and ag_statut ENUM values
SELECT t.typname, e.enumlabel
FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname IN ('ag_type', 'ag_statut')
ORDER BY t.typname, e.enumsortorder;

-- 3. Verify uq_presence_per_session UNIQUE constraint on ag_presences
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.ag_presences'::regclass
  AND contype = 'u';
-- EXPECTED: unique constraint on (session_id, appartement_id)

-- 4. Verify documents table has columns for convocation_doc_id and pv_doc_id links
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'ag_sessions'
  AND column_name IN ('convocation_doc_id', 'pv_doc_id');
```

**Implementation Vector:**
- `src/app/(syndic)/ag/page.tsx` — AG session list with status badges; "Nouvelle AG" button
- `src/components/ag/AGForm.tsx` — Titre, Date/Heure, Lieu, Type, Quorum requis (%); dynamic agenda builder (add/remove/reorder items stored as JSONB)
- `src/components/ag/AGWorkflowStepper.tsx` — 4-step visual stepper; each step unlocks next action; "Clôturer AG" button DISABLED when `quorum_atteint < quorum_requis`
- `src/components/ag/AttendanceSheet.tsx` — shows ALL active apartments (not just those present); présent/absent toggle; pouvoir checkbox; quorum calculator: `ROUND((present_count / total_active) * 100, 1)`; INSERT/UPDATE `ag_presences`; quorum insufficiency warning
- `src/components/ag/VotingPanel.tsx` — per agenda item: vote buttons (Pour/Contre/Abstention) per apartment; tally; stored in `ag_sessions.ordre_du_jour` JSONB array

**Critic Mandate:**
- Critic must verify: "Clôturer AG" is disabled both in UI AND the server-side action rejects if `quorum_atteint < quorum_requis` — UI-only guard is insufficient
- Critic must verify: `ag_presences` INSERT handles `23505` duplicate errors gracefully (concurrent presence recording by two users for same apt in same session)
- **Race condition check**: Critic must verify that simultaneous attendance recording for the same `(session_id, appartement_id)` pair by two users is caught at DB level via the UNIQUE constraint, and both UI sessions receive a clear error rather than a silent failure

**Post-Execution MCP Audit:**

```sql
-- Verify quorum calculation from ag_presences data
-- After recording attendance for a test AG session:
SELECT
  s.id,
  s.quorum_requis,
  s.quorum_atteint,
  COUNT(p.id) FILTER (WHERE p.present = true) AS present_count,
  COUNT(p.id) AS total_recorded,
  ROUND(COUNT(p.id) FILTER (WHERE p.present = true)::NUMERIC /
        NULLIF(COUNT(p.id), 0) * 100, 1) AS calculated_quorum
FROM ag_sessions s
JOIN ag_presences p ON p.session_id = s.id
WHERE s.id = '<test_session_id>'
GROUP BY s.id, s.quorum_requis, s.quorum_atteint;
-- EXPECTED: calculated_quorum = quorum_atteint (consistency check)

-- Verify vote data is correctly stored in JSONB
SELECT jsonb_pretty(ordre_du_jour) FROM ag_sessions WHERE id = '<test_session_id>';
-- EXPECTED: array of agenda items with vote tallies per item
```

**Acceptance Testing (Human Operator):**
1. Create AG → verify "Planifiée" status
2. Start AG → fill attendance (10/15 present) → verify quorum shows e.g. "66.7%"
3. If quorum < quorum_requis → verify "Clôturer" is disabled
4. Record votes for 2 agenda items → verify tally updates in real time
5. Increase attendance to meet quorum → verify "Clôturer" button enables
6. Close AG → verify status = "Terminée" in Supabase

---

### ISSUE #10 — Document Archive Screen + QR Verification

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Document library with metadata display, re-download, and QR-code-based public verification endpoint.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify documents table full structure
SELECT column_name, data_type, udt_name, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'documents'
ORDER BY ordinal_position;
-- Jules must verify: serial_id (text, UNIQUE), storage_path (text, nullable),
-- signe (boolean), signature_hash (text, nullable)

-- 2. Verify doc_type ENUM values
SELECT enumlabel FROM pg_enum
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'doc_type')
ORDER BY enumsortorder;

-- 3. Verify Supabase Storage bucket configuration
-- Jules cannot directly query storage via SQL, but must verify via Supabase dashboard:
-- Bucket 'legal-documents' must exist with: private = true (signed URLs required for download)
-- Bucket 'public/logos' must exist with: public = true

-- 4. Verify documents RLS policies
SELECT policyname, cmd, qual FROM pg_policies
WHERE tablename = 'documents' AND schemaname = 'public';
-- Syndic: full access; Gestionnaire: SELECT + INSERT; Resident: SELECT own documents only
```

**Implementation Vector:**
- `src/app/(syndic)/documents/page.tsx` — filter tabs by `doc_type`; table: Serial ID, Type, Date, Signed badge, Download + Verify actions
- `src/app/api/documents/verify/route.ts` — GET; **no auth required** (public endpoint for QR scanning); looks up `documents` by `serial_id`; returns `{ found, serial_id, type, created_at, signed, signature_valid }`; for signed documents: re-fetches file from Storage and re-computes SHA-256 to compare against `signature_hash`
- `src/components/documents/DocumentCard.tsx` — signed: green lock + "Signé cryptographiquement"; unsigned: gray icon + "Document dynamique"
- `src/lib/utils/qr.ts` — `npm install qrcode @types/qrcode`; encodes `${APP_URL}/api/documents/verify?serial_id={id}`; returns data URL for embedding in PDFs

**Critic Mandate:**
- Critic must verify: the verify endpoint returns HTTP 200 for unknown `serial_id` with `{ found: false }` — NOT 404 — to prevent document existence enumeration via status codes
- Critic must verify: the Supabase Storage download for frozen documents uses signed URLs (time-limited) — not public URLs — because the bucket is private
- Critic must verify: the verify endpoint does NOT require a Supabase session cookie — it must work from a mobile QR scanner without any auth header

**Post-Execution MCP Audit:**

```sql
-- After a signed document is created (Issue #13 will complete this pipeline,
-- but the table row should exist after any INSERT into documents):
SELECT serial_id, type_document, signe, signature_hash, storage_path
FROM documents
ORDER BY created_at DESC LIMIT 5;
-- Verify: signe = true, signature_hash IS NOT NULL, storage_path IS NOT NULL
-- for any frozen document type (proces_verbal_ag, etc.)

-- Verify uniqueness constraint on serial_id
SELECT COUNT(*), serial_id FROM documents GROUP BY serial_id HAVING COUNT(*) > 1;
-- EXPECTED: 0 rows (no duplicate serial IDs)
```

**Acceptance Testing (Human Operator):**
1. Open `/syndic/documents` → verify filter tabs render, list shows any existing documents
2. Open `/api/documents/verify?serial_id=NONEXISTENT-ID` → verify `{"found": false}` with 200
3. After Issue #13: scan QR code from a signed PDF → verify browser shows `{"found": true, "signature_valid": true}`
4. DevTools → verify the verify endpoint sends NO `Set-Cookie` or `Authorization` response headers

---

### ISSUE #11 — Settings Screen + Resident Dashboard Completion

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Syndic-only settings panel (4 tabs) and finalized resident self-service dashboard.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify residence_settings table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'residence_settings'
ORDER BY ordinal_position;
-- Jules must map every settings field to a form input — no orphaned columns

-- 2. Verify single-row invariant
SELECT COUNT(*) FROM residence_settings;
-- EXPECTED: exactly 1 (from seed.sql)
-- If 0: seed was not applied — run it before proceeding

-- 3. Verify RLS on residence_settings
SELECT policyname, cmd, roles FROM pg_policies
WHERE tablename = 'residence_settings' AND schemaname = 'public';
-- EXPECTED: syndic has full access; no other role can UPDATE
```

**Implementation Vector:**
- 4-tab settings page: Résidence (name, address, logo upload), Financiers (cotisation, charges fixes), KPI (seuil runway critique/alerte, taux recouvrement alerte), Application (theme color, language)
- Logo upload → Supabase Storage bucket `public/logos/`, stores URL in `residence_settings.logo_url`
- Updating `cotisation_mensuelle` → `UPDATE apartments SET cotisation_mensuelle = $1` (all 15 apartments)
- All settings → `UPDATE residence_settings SET ... WHERE id = (SELECT id FROM residence_settings LIMIT 1)` with optimistic update + toast
- `src/app/(resident)/dashboard/page.tsx` — full implementation: own balance card, last 6 payments, active incidents for own apt; all data from RLS-filtered queries

**Critic Mandate:**
- Critic must verify: the settings page is inaccessible to gestionnaire, gardien, resident roles — middleware enforces this and the server-side query would also be blocked by RLS
- Critic must verify: logo upload validates `file.type` in `['image/png', 'image/jpeg']` AND `file.size < 2 * 1024 * 1024` (2MB) before uploading — invalid files must be rejected with a clear message before any Supabase Storage call is made
- Critic must verify: updating cotisation affects ALL 15 apartments via a single `UPDATE` without a `WHERE id =` filter — not per-apartment

**Post-Execution MCP Audit:**

```sql
-- Verify cotisation update propagates to all apartments
-- After changing cotisation in settings UI:
SELECT COUNT(DISTINCT cotisation_mensuelle) AS distinct_values,
       MIN(cotisation_mensuelle) AS min_value,
       MAX(cotisation_mensuelle) AS max_value
FROM apartments;
-- EXPECTED: distinct_values = 1 (all apartments have the same cotisation after bulk update)

-- Verify residence_settings still has exactly 1 row (no accidental INSERT)
SELECT COUNT(*) FROM residence_settings;
-- EXPECTED: 1
```

**Acceptance Testing (Human Operator):**
1. Open settings → update cotisation to 1500 MAD → save → verify toast
2. Open Supabase → apartments → verify all 15 rows show 1500
3. Log in as resident → open `/resident/dashboard` → verify own balance and payments visible
4. Resident attempts to access `/syndic/settings` → verify redirect
5. Try to upload a .pdf file as logo → verify rejection with error message

---

## ─────────────────────────────────────────────
## DAY 4 — PDF ENGINES + PWA + HARDENING
## ─────────────────────────────────────────────

---

### ISSUE #12 — pdfmake Receipt Engine

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Client-side PDF receipt engine using pdfmake. Deterministic output. French number-to-words. Dynamic import to keep pdfmake out of the main bundle.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify payments includes ALL fields needed for receipt generation
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'payments'
  AND column_name IN ('id', 'serial_id', 'montant', 'periode', 'date_paiement',
                      'mode_paiement', 'statut', 'valide_par', 'appartement_id', 'resident_id');
-- Every column in this list must exist with the expected type
-- serial_id must be TEXT (not UUID) — it holds the formatted string like RCP-2025-00042

-- 2. Verify the payment joined query Jules will use for receipt data
SELECT
  p.serial_id, p.montant, p.periode, p.date_paiement, p.mode_paiement,
  u_val.nom || ' ' || u_val.prenom AS validateur_nom,
  u_res.nom || ' ' || u_res.prenom AS resident_nom,
  r.type_residence,
  a.code AS apt_code, a.etage, a.numero,
  rs.nom AS residence_nom, rs.adresse, rs.syndic_nom
FROM payments p
JOIN users u_val ON u_val.id = p.valide_par
JOIN residents res ON res.id = p.resident_id
JOIN users u_res ON u_res.id = res.user_id
JOIN apartments a ON a.id = p.appartement_id
CROSS JOIN residence_settings rs
WHERE p.id = (SELECT id FROM payments WHERE statut = 'valide' LIMIT 1);
-- This is the exact query the receipt engine will use — verify it runs without error
-- Any missing FK (e.g. resident_id is NULL on a payment) = data integrity issue to report

-- 3. Verify generate_serial_id function and sequence
SELECT generate_serial_id('recu_paiement');
-- EXPECTED: Returns a string like 'recu_paiement-2025-00001'
-- Jules must adjust the format in application code if the DB function uses a different format
```

**Implementation Vector:**
- Install: `npm install pdfmake`; install types: `npm install -D @types/pdfmake`
- `src/lib/utils/numberToWords.ts` — French language, MAD currency, range 0–999,999; edge cases: 0→"Zéro dirham", 1→"Un dirham", 71→"Soixante-onze dirhams", 80→"Quatre-vingts dirhams", 81→"Quatre-vingt-un dirhams", 1000→"Mille dirhams", 1200→"Mille deux cents dirhams"
- `src/lib/pdf/letterhead.ts` — common header/footer for all documents; residence name + address from params; footer with serial_id + page X/N + generation timestamp
- `src/lib/pdf/receipt.ts` — `generateReceipt(data: ReceiptData): Promise<void>`; pdfmake loaded via dynamic `import()`; `TDocumentDefinitions` typed; full field set as specified in AGENTS.md §9; calls `montantEnLettres()`; calls `pdfMake.createPdf(def).download(...)`
- `src/lib/utils/qr.ts` — QR code data URL generation for embedding in PDFs

**Critic Mandate:**
- Critic must verify: `import pdfmake from 'pdfmake/build/pdfmake'` is inside an `async function` using dynamic `await import(...)` — NOT at the top of the file. A static import would bundle pdfmake into the main JS bundle and violate the < 2 second TTI constraint
- Critic must verify: `generateReceipt` called twice with identical `ReceiptData` input produces PDFs with identical logical content (same serial_id, same amounts, same resident name) — determinism must be verified
- Critic must verify: `montantEnLettres(0, 'MAD')` returns "Zéro dirham" without throwing
- Critic must verify: `montantEnLettres(80, 'MAD')` returns "Quatre-vingts dirhams" (with the final 's' on vingts when not followed by another number)
- Critic must verify: `montantEnLettres(81, 'MAD')` returns "Quatre-vingt-un dirhams" (without the 's' on vingt when followed by a number)
- **Edge case check**: Critic must verify the `ReceiptData.payment.resident_id` is not null before calling `generateReceipt` — a payment where `resident_id` is NULL (edge case: payment recorded before resident was linked) must render "Résident non renseigné" instead of crashing

**Post-Execution MCP Audit:**

```sql
-- Verify the receipt data query returns complete data for a test payment
-- (Use the validated payment from Issue #6 acceptance test)
SELECT
  p.serial_id,
  p.montant,
  TO_CHAR(p.periode, 'MM/YYYY') AS periode_formatted,
  u_val.nom || ' ' || u_val.prenom AS validateur,
  u_res.nom || ' ' || u_res.prenom AS resident,
  a.code,
  rs.nom AS residence_nom
FROM payments p
JOIN users u_val ON u_val.id = p.valide_par
LEFT JOIN residents res ON res.id = p.resident_id
LEFT JOIN users u_res ON u_res.id = res.user_id
JOIN apartments a ON a.id = p.appartement_id
CROSS JOIN residence_settings rs
WHERE p.statut = 'valide'
LIMIT 1;
-- EXPECTED: all fields non-null (except u_res fields if resident_id is null — acceptable edge case)
-- serial_id must be non-null for validated payments (trigger sets it)
```

**Acceptance Testing (Human Operator):**
1. Click "Reçu" on a validated payment → verify PDF downloads within 300ms
2. Open PDF → verify: Serial ID, resident name, apt code, period (French format), amount in digits AND words
3. Click "Reçu" again on same payment → compare two PDFs → verify identical content
4. DevTools → Network → verify ZERO HTTP requests during PDF generation
5. Open PDF in Adobe Acrobat → verify text is selectable (not rasterized images)
6. Test edge cases: 71 → "Soixante-onze", 1000 → "Mille", 1200 → "Mille deux cents"

---

### ISSUE #13 — pdf-lib + WebCrypto Legal Document Signing Pipeline

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Server-side PKCS#7 digital signature pipeline for frozen legal documents. Route Handler only. Private key never leaves the server.

**Pre-Flight MCP Verification:**

```sql
-- 1. Verify documents table has all columns needed by the signing pipeline
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'documents'
  AND column_name IN ('id', 'serial_id', 'storage_path', 'storage_bucket',
                      'signe', 'signature_hash', 'genere_par', 'reference_metier',
                      'reference_table', 'metadata');

-- 2. Verify generate_serial_id function works for all document types
SELECT
  generate_serial_id('proces_verbal') AS pv_serial,
  generate_serial_id('bon_intervention') AS bi_serial,
  generate_serial_id('convocation_ag') AS ca_serial;
-- EXPECTED: formatted strings for each type

-- 3. Verify the documents INSERT RLS policy for syndic
SELECT policyname, cmd, qual FROM pg_policies
WHERE tablename = 'documents'
  AND schemaname = 'public'
  AND cmd IN ('INSERT', 'ALL');

-- 4. Verify Supabase Storage bucket 'legal-documents' exists
-- (Cannot verify via SQL — Jules must check via Supabase dashboard or Storage API)
-- Required state: bucket exists, private = true, max file size = 50MB

-- 5. Verify ag_sessions table has data that the PV signing will reference
SELECT id, titre, statut, quorum_atteint, ordre_du_jour
FROM ag_sessions
WHERE statut = 'terminee'
LIMIT 1;
-- If no 'terminee' AG exists yet: create test data via SQL before testing this issue
```

**Implementation Vector:**
- Install: `npm install pdf-lib node-forge @types/node-forge`
- `scripts/generate-signing-key.js` — generates RSA-2048 self-signed cert for "Syndic Résidence L'Amandier B"; outputs `SIGNING_PRIVATE_KEY_PEM` and `SIGNING_CERTIFICATE_PEM` values for Vercel env vars; run once, never commit output to repository
- `src/lib/pdf/signer.ts` — exports `createSignedPDF(pdfBytes, privateKeyPem, certificatePem): Promise<Uint8Array>`; implements full pipeline from AGENTS.md §9 (AcroForm field → SHA-256 → RSA sign → PKCS#7 via node-forge → pdf-lib incremental update)
- `src/app/api/documents/sign/route.ts` — POST; requires `role='syndic'` JWT; reads `SIGNING_PRIVATE_KEY_PEM` from `process.env`; generates PDF content; calls `createSignedPDF`; uploads to Supabase Storage with signed URL; INSERTs into `documents` table; returns `{ serial_id, storage_path, document_id }`

**Critic Mandate:**
- Critic must verify: `grep -r "SIGNING_PRIVATE_KEY_PEM" src/ --include="*.ts" --include="*.tsx"` returns ONLY `src/app/api/documents/sign/route.ts` and `src/lib/env.ts` — any other hit is a critical security defect blocking the PR
- Critic must verify: the Route Handler returns HTTP 403 when called with a `gestionnaire` or `resident` JWT — role check must be server-side, not UI-only
- Critic must verify: if the Supabase Storage upload fails, the Route Handler does NOT insert a row into `documents` — the DB INSERT must happen AFTER the storage upload succeeds (no orphaned rows with null `storage_path`)
- **Edge case check**: Critic must verify the PKCS#7 reserved byte space (8192 bytes) is sufficient for the generated signature — if the signature exceeds this space, `pdf-lib` will corrupt the PDF silently. Test with the actual key size used

**Post-Execution MCP Audit:**

```sql
-- After generating a signed PV document, verify all metadata was recorded
SELECT
  d.serial_id,
  d.type_document,
  d.signe,
  d.signature_hash,
  d.storage_path,
  d.storage_bucket,
  d.created_at,
  u.nom || ' ' || u.prenom AS generated_by_name
FROM documents d
JOIN users u ON u.id = d.genere_par
WHERE d.type_document = 'proces_verbal_ag'
ORDER BY d.created_at DESC LIMIT 1;
-- EXPECTED: signe = true, signature_hash IS NOT NULL (64 hex chars for SHA-256),
-- storage_path IS NOT NULL, storage_bucket = 'legal-documents'

-- Verify no orphaned documents (signe=true but storage_path=null)
SELECT COUNT(*) AS orphaned_count
FROM documents
WHERE signe = true AND storage_path IS NULL;
-- EXPECTED: 0

-- Cross-verify signature_hash
-- Fetch the file bytes from Supabase Storage (via signed URL) and compute SHA-256
-- Compare against documents.signature_hash — must match
-- This step is manual but must be documented in the PR description
```

**Acceptance Testing (Human Operator):**
1. Terminate a test AG → click "Générer PV signé" → verify success toast within 3 seconds
2. Open `/syndic/documents` → verify new PV entry with green lock icon
3. Click download → open in Adobe Acrobat → Signature Panel → verify "Valid Signature"
4. Open `/api/documents/verify?serial_id=PVA-2025-00001` → verify `{"signature_valid": true}`
5. As gestionnaire: attempt POST to `/api/documents/sign` → verify HTTP 403
6. Supabase Storage → `legal-documents` bucket → verify PDF file exists

---

### ISSUE #14 — PWA Configuration, Service Worker & Install Prompt

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Transform the Next.js app into a fully installable PWA with offline capabilities (Last Known Good Cache), proper install prompt, and service worker lifecycle management.

**Pre-Flight MCP Verification:**

```sql
-- No schema changes in this Issue — pre-flight MCP verifies the app's current data
-- health rather than schema structure

-- Verify the KPI endpoint returns quickly (baseline before PWA caching layer is added)
SELECT NOW() - query_start AS query_duration,
       state, query
FROM pg_stat_activity
WHERE query LIKE '%get_kpi_dashboard%'
  AND state != 'idle';
-- EXPECTED: 0 rows (no long-running KPI queries)

-- Verify all 15 apartments have data (matrix data completeness check)
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE apt_statut = 'occupe') AS occupied,
       COUNT(*) FILTER (WHERE apt_statut = 'vacant') AS vacant
FROM v_apartment_balance;
-- EXPECTED: total = 15
```

**Implementation Vector:**
- `next.config.js` — `next-pwa` with `disable: process.env.NODE_ENV === 'development'`; full runtime caching config from AGENTS.md §11
- `public/manifest.json` — all mandatory fields from AGENTS.md §11; `theme_color: "#1e3a2f"`
- `public/offline.html` — static fallback: residence name + "Vous êtes hors ligne. Données affichées depuis le cache."
- `src/components/ui/InstallPrompt.tsx` — `beforeinstallprompt` event listener; bottom banner; "Installer" + "Plus tard" (7-day localStorage dismiss); mobile-only (hidden on viewport > 768px)
- `src/components/ui/OfflineIndicator.tsx` — monitors `navigator.onLine` + event listeners; top banner when offline; auto-hides when reconnected

**Critic Mandate:**
- Critic must verify: `next-pwa` config has `disable: process.env.NODE_ENV === 'development'` — missing this causes hot reload failures in development
- Critic must verify: the Supabase Auth caching strategy is `NetworkFirst` with a 5-second timeout — NOT `CacheFirst` (caching auth responses is a security risk)
- Critic must verify: the offline fallback is served for app page routes, NOT for Supabase API calls — API failures when offline should surface as "cached data" state, not a redirect to `offline.html`
- Critic must verify: the `beforeinstallprompt` event handler calls `event.preventDefault()` to hold the prompt for the custom UI — not calling this causes the browser to show its default prompt immediately
- **Edge case check**: Critic must verify that the install prompt does NOT appear when `window.matchMedia('(display-mode: standalone)').matches` is true (already installed) — showing "Install" to a user who already installed is a UX defect

**Post-Execution MCP Audit:**

```sql
-- Verify the Last Known Good Cache strategy works for matrix data
-- This cannot be verified via SQL — it requires browser-level testing
-- Jules must document in the PR description:
-- 1. The exact SW runtime caching config applied to supabase.co REST endpoints
-- 2. The TTL of the StaleWhileRevalidate cache (300 seconds)
-- 3. Confirmation that the matrix data endpoint is covered by this cache rule

-- Verify no sensitive data leakage via service worker cache
-- Supabase Auth endpoints MUST use NetworkFirst — verify the URL pattern covers:
SELECT 'Verify these URL patterns are covered by NetworkFirst:' AS check_item,
       '*/auth/v1/*' AS auth_pattern,
       '*/rest/v1/users*' AS users_pattern;
-- Manual verification required against next.config.js runtimeCaching array
```

**Acceptance Testing (Human Operator):**
1. Open on Android Chrome → verify install banner appears within 30 seconds
2. Install PWA → open from home screen → verify standalone mode (no browser chrome)
3. Load dashboard → disconnect WiFi → reload → verify cached data shown + offline banner
4. Reconnect WiFi → verify banner disappears and data refreshes
5. Lighthouse PWA audit (Chrome DevTools) → verify score ≥ 90
6. DevTools → Application → Cache Storage → verify `supabase-rest-cache` exists after first load

---

### ISSUE #15 — Final Security Audit, Error Boundaries & Production Hardening

> 🛑 **MANDATORY DIRECTIVE: YOU MUST READ AND INGEST AGENTS.md BEFORE PROCEEDING. NO EXCEPTIONS.**

**Context & Objective:**
Production hardening: comprehensive error boundary coverage, loading state standardization, environment validation, HTTP security headers, and a final comprehensive RLS penetration audit.

**Pre-Flight MCP Verification:**

```sql
-- FINAL SCHEMA INTEGRITY AUDIT — run ALL of these before touching any file

-- 1. RLS status on every table — must all show true
SELECT relname AS table_name, relrowsecurity
FROM pg_class
WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
ORDER BY relname;
-- EXPECTED: relrowsecurity = true for ALL tables — any false is a critical security defect

-- 2. Trigger inventory — verify all required triggers are present
SELECT event_object_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
-- EXPECTED: tg_payment_validated, tg_protect_flux, tg_protect_audit, tg_incident_fsm

-- 3. View inventory — verify all required views exist
SELECT viewname FROM pg_views WHERE schemaname = 'public';
-- EXPECTED: v_apartment_balance

-- 4. Function inventory — verify all RPC functions exist
SELECT proname FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('get_kpi_dashboard', 'get_matrix_data', 'generate_serial_id')
ORDER BY proname;
-- EXPECTED: all 3 functions present

-- 5. Index inventory — verify performance indexes exist
SELECT tablename, indexname FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
-- Verify presence of: idx_payments_apt_periode, idx_incidents_statut, idx_residents_actif, etc.

-- 6. Constraint inventory — verify the EXCLUDE constraint on payments
SELECT conname, contype FROM pg_constraint
WHERE conrelid = 'public.payments'::regclass AND contype = 'x';
-- EXPECTED: 1 row (uq_validated_payment_period)
```

**Implementation Vector:**
- `src/components/ui/ErrorBoundary.tsx` — React class component; catches render errors; displays "Une erreur est survenue. Veuillez rafraîchir la page." + Signaler button; logs to console.error
- Wrap ALL page-level components (`dashboard/page.tsx`, `payments/page.tsx`, etc.) with `<ErrorBoundary />`
- `src/components/ui/LoadingSpinner.tsx` and `src/components/ui/Skeleton.tsx` — standardize all loading states
- Every async action button: `isLoading` state → spinner + disabled during pending; implemented with `useRef<boolean>` not `useState` for rapid-tap protection
- `src/lib/env.ts` — called from `next.config.js` build phase; throws if any required env var is missing
- `next.config.js` HTTP security headers:
```javascript
async headers() {
  return [{
    source: '/(.*)',
    headers: [
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' }
    ]
  }];
}
```

**Critic Mandate:**
- Critic must run: `grep -r "SUPABASE_SERVICE_ROLE_KEY\|SIGNING_PRIVATE_KEY_PEM" src/ --include="*.ts" --include="*.tsx" | grep -v "env.ts"` → ZERO matches required — any hit is a critical security defect blocking the PR
- Critic must run: `grep -r "any" src/ --include="*.ts" --include="*.tsx" | grep -v "//.*any\|node_modules"` → ZERO unescaped `any` types allowed
- Critic must verify: the app renders an `<ErrorBoundary />` component wrapping every page — missing boundaries mean one crashing component takes down the entire page
- Critic must verify: every `useEffect` that sets up an async operation or subscription has a cleanup function — list all `useEffect` calls in hooks and verify cleanup
- **Race condition final check**: Critic must verify the full payment validation flow under concurrent access: two browser sessions both attempt to validate the same payment simultaneously. The optimistic lock (`.eq('statut', 'en_attente')`) on the UPDATE ensures only one succeeds. The Critic must trace this code path end-to-end and confirm the losing session receives the "Ce paiement a déjà été traité" error, not a silent success or a 500
- **Memory leak final check**: Critic must enumerate ALL `supabase.channel(...)` subscriptions in the codebase and verify every one has a corresponding `supabase.removeChannel(...)` in a `useEffect` cleanup function

**Post-Execution MCP Audit — COMPREHENSIVE FINAL RLS PENETRATION TEST:**

```sql
-- PENETRATION TEST SUITE — run in Supabase SQL Editor
-- Each test must pass before PR is submitted

-- TEST 1: Resident isolation on payments
DO $$
DECLARE
  v_apt1_id UUID;
  v_apt2_id UUID;
  v_user1_id UUID;
  v_payment_count INT;
BEGIN
  SELECT id INTO v_apt1_id FROM apartments WHERE code = 'E1A1';
  SELECT id INTO v_apt2_id FROM apartments WHERE code = 'E2A1';
  SELECT id INTO v_user1_id FROM users WHERE role = 'resident' LIMIT 1;

  -- Simulate resident from E1A1 querying all payments
  -- This requires setting the JWT context — document that this was verified
  -- via the Supabase dashboard's "Table Editor > Policies > Test" feature
  -- OR via a dedicated test script with a resident-scoped client

  RAISE NOTICE 'TEST 1: Document resident payment isolation in PR description with screenshot';
END;
$$;

-- TEST 2: flux_tresorerie immutability (direct SQL attempt)
DO $$
BEGIN
  BEGIN
    UPDATE flux_tresorerie SET montant = 1 WHERE id = (SELECT id FROM flux_tresorerie LIMIT 1);
    RAISE EXCEPTION 'PENETRATION TEST FAILED: flux_tresorerie is mutable';
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE '%append-only%' THEN
      RAISE NOTICE 'TEST 2 PASSED: flux_tresorerie immutability confirmed';
    ELSE
      RAISE EXCEPTION 'Unexpected error message: %', SQLERRM;
    END IF;
  END;
END;
$$;

-- TEST 3: audit_log immutability
DO $$
BEGIN
  BEGIN
    DELETE FROM audit_log WHERE id = (SELECT id FROM audit_log LIMIT 1);
    RAISE EXCEPTION 'PENETRATION TEST FAILED: audit_log is deletable';
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'TEST 3 PASSED: audit_log immutability confirmed';
  END;
END;
$$;

-- TEST 4: Concurrent payment validation deadlock scenario
-- Verify the optimistic lock handles this gracefully
-- (Cannot simulate true concurrency in SQL Editor — must be documented as
-- having been verified via browser-level test with two simultaneous sessions)

-- TEST 5: Service role key not in client bundle
-- Run from terminal: grep -r "service_role" .next/ --include="*.js" | head -5
-- EXPECTED: 0 matches in the .next/static directory
-- Jules must include the output of this command in the PR description

-- FINAL VERIFICATION
SELECT
  'Schema version' AS check_type,
  COUNT(*) || ' tables in public schema' AS result
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Trigger count', COUNT(*) || ' triggers active'
FROM information_schema.triggers WHERE trigger_schema = 'public'
UNION ALL
SELECT 'RPC functions', COUNT(*) || ' functions in public'
FROM pg_proc WHERE pronamespace = 'public'::regnamespace
UNION ALL
SELECT 'View count', COUNT(*) || ' views in public'
FROM pg_views WHERE schemaname = 'public';
-- Jules must include this output in the PR description as the final state attestation
```

**Acceptance Testing (Human Operator):**
1. DevTools → Network → verify `Content-Security-Policy` and `X-Frame-Options` headers on every page response
2. DevTools → Console → complete full user flow (login → dashboard → payment → receipt → logout) → verify ZERO console errors
3. Open with empty Supabase (delete all payments) → verify dashboard shows "0" values, no NaN, no crashes
4. Run Lighthouse Performance on `/syndic/dashboard` (mobile preset) → verify score ≥ 75
5. Run Lighthouse PWA audit → verify score ≥ 90
6. Verify Vercel deployment → Settings → Environment Variables → verify all 6 required vars are set
7. **Final penetration check**: As a resident user, attempt to access the Supabase REST API directly via `fetch('https://<project>.supabase.co/rest/v1/payments', { headers: { Authorization: 'Bearer <resident_jwt>' } })` → verify response contains only own apartment's payments, not all payments

---

## APPENDIX — ISSUE DEPENDENCY GRAPH

```
#1 Foundation
  └── #2 Schema + Triggers + RLS
        ├── #3 Authentication
        │     ├── #4 Apartment Matrix ──────────────────────────┐
        │     ├── #5 KPI Dashboard                             │
        │     ├── #6 Payment Management (depends on #4, #5)    │
        │     └── #7 Incident Management                       │
        │           ├── #8 Resident Management (dep #6)        │
        │           ├── #9 AG Workflow (dep #7)                │
        │           ├── #10 Document Archive (dep #9)          │
        │           └── #11 Settings (dep #8)                  │
        │                                                      │
        ├── #12 pdfmake Engine (dep #6) ◄────────────────────┘
        ├── #13 Signing Pipeline (dep #9, #10, #12)
        ├── #14 PWA Config (dep all UI issues)
        └── #15 Production Hardening (dep all)
```

## APPENDIX — OPERATOR RULES

1. **Never submit Day N+1 Issues until all Day N PRs are merged and Vercel deployment is confirmed green.**
2. **If a PR fails the mandatory pre-PR commands, Jules must fix all errors before resubmitting — do not merge a broken PR and "fix forward".**
3. **If a Post-Execution MCP Audit fails, Jules must not submit the PR. Fix the trigger/RLS/constraint and re-run the audit.**
4. **The 🛑 MANDATORY DIRECTIVE line is not decorative. Jules must re-read AGENTS.md at the start of every task without exception.**
