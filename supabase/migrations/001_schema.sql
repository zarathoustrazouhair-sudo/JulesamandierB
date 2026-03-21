-- Extension requirements
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ENUMs
CREATE TYPE public.user_role AS ENUM ('syndic', 'resident', 'gardien', 'admin');
CREATE TYPE public.payment_mode AS ENUM ('especes', 'virement', 'cheque');
CREATE TYPE public.payment_statut AS ENUM ('en_attente', 'valide', 'rejete');
CREATE TYPE public.incident_statut AS ENUM ('ouvert', 'en_cours', 'resolu', 'ferme');
CREATE TYPE public.flux_type AS ENUM ('recette', 'depense');

-- 1. users
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.user_role NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  nom VARCHAR(255) NOT NULL,
  prenom VARCHAR(255) NOT NULL,
  telephone VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. apartments
CREATE TABLE public.apartments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(10) NOT NULL UNIQUE, -- e.g., 'E1A1'
  etage INT NOT NULL,
  numero INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. residents
CREATE TABLE public.residents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  appartement_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
  is_proprietaire BOOLEAN NOT NULL DEFAULT FALSE,
  date_entree DATE NOT NULL,
  date_sortie DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, appartement_id)
);

-- 4. payments
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  appartement_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE RESTRICT,
  periode DATE NOT NULL, -- First day of the month paid for
  montant NUMERIC(10, 2) NOT NULL,
  mode_paiement public.payment_mode NOT NULL,
  date_paiement DATE NOT NULL,
  statut public.payment_statut NOT NULL DEFAULT 'en_attente',
  reference_transaction VARCHAR(255),
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  valide_par UUID REFERENCES public.users(id) ON DELETE RESTRICT,
  valide_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prevent double-payment at DB level regardless of UI state using EXCLUDE index
ALTER TABLE public.payments ADD CONSTRAINT uq_validated_payment_period
  EXCLUDE USING btree (appartement_id WITH =, periode WITH =)
  WHERE (statut = 'valide');

-- 5. flux_tresorerie
CREATE TABLE public.flux_tresorerie (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  serial_id VARCHAR(50) NOT NULL UNIQUE,
  type public.flux_type NOT NULL,
  montant NUMERIC(10, 2) NOT NULL,
  date_flux DATE NOT NULL,
  description TEXT NOT NULL,
  source_id UUID, -- Using source_id to link to payment per audit script
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Explicit fk not set on source_id because it could technically reference other tables if depense,
-- but we will enforce referential integrity within business logic/triggers if needed.
ALTER TABLE public.flux_tresorerie ADD CONSTRAINT fk_flux_payment
  FOREIGN KEY (source_id) REFERENCES public.payments(id) ON DELETE RESTRICT;

-- 6. incidents
CREATE TABLE public.incidents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titre VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  statut public.incident_statut NOT NULL DEFAULT 'ouvert',
  reported_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. documents
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titre VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL,
  storage_path VARCHAR(255) NOT NULL,
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. ag_sessions
CREATE TABLE public.ag_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date_session DATE NOT NULL,
  titre VARCHAR(255) NOT NULL,
  statut VARCHAR(50) NOT NULL DEFAULT 'planifiee', -- 'planifiee', 'en_cours', 'terminee'
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. ag_presences
CREATE TABLE public.ag_presences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ag_session_id UUID NOT NULL REFERENCES public.ag_sessions(id) ON DELETE CASCADE,
  resident_id UUID NOT NULL REFERENCES public.residents(id) ON DELETE CASCADE,
  present BOOLEAN NOT NULL DEFAULT FALSE,
  pouvoir_a UUID REFERENCES public.residents(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(ag_session_id, resident_id)
);

-- 10. audit_log
CREATE TABLE public.audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_name VARCHAR(100) NOT NULL,
  objet_id UUID NOT NULL, -- renamed to objet_id based on audit script
  action VARCHAR(50) NOT NULL,
  old_data JSONB,
  new_data JSONB,
  changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. residence_settings
CREATE TABLE public.residence_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cle VARCHAR(100) NOT NULL UNIQUE,
  valeur JSONB NOT NULL,
  updated_by UUID REFERENCES public.users(id) ON DELETE RESTRICT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sequence for flux_tresorerie serial ID
CREATE SEQUENCE public.flux_tresorerie_serial_seq START 1;

-- Function to generate serial ID
CREATE OR REPLACE FUNCTION public.generate_serial_id(prefix VARCHAR)
RETURNS VARCHAR AS $$
BEGIN
  RETURN prefix || '-' || TO_CHAR(NOW(), 'YYYY-MM') || '-' || LPAD(nextval('public.flux_tresorerie_serial_seq')::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;
