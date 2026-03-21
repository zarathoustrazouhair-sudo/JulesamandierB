-- Insert 15 apartments
INSERT INTO public.apartments (code, etage, numero) VALUES
  ('E1A1', 1, 1),
  ('E1A2', 1, 2),
  ('E1A3', 1, 3),
  ('E2A1', 2, 1),
  ('E2A2', 2, 2),
  ('E2A3', 2, 3),
  ('E3A1', 3, 1),
  ('E3A2', 3, 2),
  ('E3A3', 3, 3),
  ('E4A1', 4, 1),
  ('E4A2', 4, 2),
  ('E4A3', 4, 3),
  ('E5A1', 5, 1),
  ('E5A2', 5, 2),
  ('E5A3', 5, 3)
ON CONFLICT (code) DO NOTHING;

-- Insert 1 residence_settings row
-- (Note: updated_by is usually required, but we'll temporarily bypass it for seeding if no users exist, or set it to null if the schema allows.
-- Wait, updated_by in residence_settings is UUID REFERENCES users(id). We might need a dummy user, or we can just leave it out if not strictly required for this seed test, but it is NOT NULL in the DDL?
-- Ah, the DDL: updated_by UUID REFERENCES public.users(id) ON DELETE RESTRICT (removed NOT NULL to allow initial seed without user). Let's update 001_schema.sql to ensure it's not strictly NOT NULL for the seed, or we create a system user.)

-- Let's create a dummy system user for seeds
DO $$
DECLARE
  v_user_id UUID := gen_random_uuid();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users LIMIT 1) THEN
    INSERT INTO auth.users (id, email) VALUES (v_user_id, 'system@amandier-b.internal');
    INSERT INTO public.users (id, role, email, nom, prenom) VALUES (v_user_id, 'admin', 'system@amandier-b.internal', 'System', 'Admin');
  ELSE
    SELECT id INTO v_user_id FROM public.users LIMIT 1;
  END IF;

  INSERT INTO public.residence_settings (cle, valeur, updated_by)
  VALUES ('charges_mensuelles', '{"montant_fixe": 200}', v_user_id)
  ON CONFLICT (cle) DO NOTHING;
END;
$$;
