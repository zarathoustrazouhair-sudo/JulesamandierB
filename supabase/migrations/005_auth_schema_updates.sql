ALTER TABLE public.users ADD COLUMN IF NOT EXISTS pin_hash TEXT;

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'gestionnaire' AFTER 'syndic';

-- Replace old RLS policy to secure pin_hash
DROP POLICY IF EXISTS "Users can read all users" ON public.users;

-- Residents can only view their own user data, syndic/gestionnaire can view all
CREATE POLICY "Users can view their own data"
ON public.users FOR SELECT USING (id = auth.uid());

CREATE POLICY "Syndic and Gestionnaire can view all users"
ON public.users FOR SELECT USING (
  public.jwt_user_role() IN ('syndic', 'gestionnaire', 'admin')
);

-- Note: We assume the UI logic doesn't require residents to read other residents' data from the 'users' table directly. If they need to see names, they can use a secure view or an RPC function.
