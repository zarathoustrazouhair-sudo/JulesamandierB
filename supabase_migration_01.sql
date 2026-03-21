-- Enums
CREATE TYPE user_role AS ENUM ('syndic', 'resident', 'gardien');
CREATE TYPE payment_mode AS ENUM ('especes', 'virement', 'cheque');
CREATE TYPE payment_status AS ENUM ('en_attente', 'valide', 'rejete');
CREATE TYPE incident_status AS ENUM ('ouvert', 'en_cours', 'resolu', 'ferme');

-- users (public profile linking to auth.users)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  nom VARCHAR(255) NOT NULL,
  prenom VARCHAR(255) NOT NULL,
  telephone VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- apartments
CREATE TABLE public.apartments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code VARCHAR(10) NOT NULL UNIQUE, -- e.g., 'E1A1'
  etage INT NOT NULL,
  numero INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- residents (links users to apartments)
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

-- payments
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  appartement_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE RESTRICT,
  periode DATE NOT NULL, -- First day of the month paid for
  montant NUMERIC(10, 2) NOT NULL,
  mode_paiement payment_mode NOT NULL,
  date_paiement DATE NOT NULL,
  statut payment_status NOT NULL DEFAULT 'en_attente',
  reference_transaction VARCHAR(255),
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  valide_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prevent double-payment at DB level regardless of UI state
ALTER TABLE public.payments ADD CONSTRAINT uq_validated_payment_period
  EXCLUDE USING btree (appartement_id WITH =, periode WITH =)
  WHERE (statut = 'valide');

-- flux_tresorerie
CREATE TABLE public.flux_tresorerie (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  serial_id VARCHAR(50) NOT NULL UNIQUE,
  type VARCHAR(50) NOT NULL, -- 'recette' or 'depense'
  montant NUMERIC(10, 2) NOT NULL,
  date_flux DATE NOT NULL,
  description TEXT NOT NULL,
  payment_id UUID REFERENCES public.payments(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- incidents
CREATE TABLE public.incidents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titre VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  statut incident_status NOT NULL DEFAULT 'ouvert',
  reported_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- documents
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titre VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL,
  storage_path VARCHAR(255) NOT NULL,
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ag_sessions
CREATE TABLE public.ag_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date_session DATE NOT NULL,
  titre VARCHAR(255) NOT NULL,
  statut VARCHAR(50) NOT NULL DEFAULT 'planifiee', -- 'planifiee', 'en_cours', 'terminee'
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ag_presences
CREATE TABLE public.ag_presences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ag_session_id UUID NOT NULL REFERENCES public.ag_sessions(id) ON DELETE CASCADE,
  resident_id UUID NOT NULL REFERENCES public.residents(id) ON DELETE CASCADE,
  present BOOLEAN NOT NULL DEFAULT FALSE,
  pouvoir_a UUID REFERENCES public.residents(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(ag_session_id, resident_id)
);

-- audit_log
CREATE TABLE public.audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_name VARCHAR(100) NOT NULL,
  record_id UUID NOT NULL,
  action VARCHAR(50) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
  old_data JSONB,
  new_data JSONB,
  changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- residence_settings
CREATE TABLE public.residence_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cle VARCHAR(100) NOT NULL UNIQUE,
  valeur JSONB NOT NULL,
  updated_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Settings seeding (Charges fixes mensuelles = 200 MAD per apartment)
-- Insert initial settings when syndic is created, or leave empty for now

-- Sequence for serial_id
CREATE SEQUENCE flux_tresorerie_serial_seq START 1;

-- fn_on_payment_validated trigger
CREATE OR REPLACE FUNCTION fn_on_payment_validated()
RETURNS TRIGGER AS $$
DECLARE
  v_serial_id VARCHAR(50);
BEGIN
  -- Only fire when status changes to 'valide'
  IF NEW.statut = 'valide' AND (OLD.statut IS NULL OR OLD.statut != 'valide') THEN
    NEW.valide_at = NOW();

    -- Generate serial ID format: REC-YYYY-MM-0001
    v_serial_id := 'REC-' || TO_CHAR(NOW(), 'YYYY-MM') || '-' || LPAD(nextval('flux_tresorerie_serial_seq')::TEXT, 4, '0');

    INSERT INTO flux_tresorerie (
      serial_id, type, montant, date_flux, description, payment_id
    ) VALUES (
      v_serial_id, 'recette', NEW.montant, NEW.date_paiement,
      'Paiement validé pour appartement ' || (SELECT code FROM apartments WHERE id = NEW.appartement_id) || ' - Période ' || NEW.periode,
      NEW.id
    );

    INSERT INTO audit_log (
      table_name, record_id, action, new_data, changed_by
    ) VALUES (
      'payments', NEW.id, 'UPDATE_VALIDATE', row_to_json(NEW)::jsonb, NEW.created_by
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_on_payment_validated
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION fn_on_payment_validated();

-- fn_protect_flux_tresorerie trigger
CREATE OR REPLACE FUNCTION fn_protect_flux_tresorerie()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Les modifications ou suppressions dans flux_tresorerie sont strictement interdites.';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_protect_flux_tresorerie
BEFORE UPDATE OR DELETE ON flux_tresorerie
FOR EACH ROW
EXECUTE FUNCTION fn_protect_flux_tresorerie();

-- fn_protect_audit_log trigger
CREATE OR REPLACE FUNCTION fn_protect_audit_log()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Les modifications ou suppressions dans audit_log sont strictement interdites.';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_protect_audit_log
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW
EXECUTE FUNCTION fn_protect_audit_log();

-- fn_incident_fsm trigger
CREATE OR REPLACE FUNCTION fn_incident_fsm()
RETURNS TRIGGER AS $$
BEGIN
  -- Transitions from 'ouvert'
  IF OLD.statut = 'ouvert' THEN
    IF NEW.statut NOT IN ('en_cours', 'ferme') THEN
      RAISE EXCEPTION 'Transition invalide: ouvert -> %', NEW.statut;
    END IF;
  END IF;

  -- Transitions from 'en_cours'
  IF OLD.statut = 'en_cours' THEN
    IF NEW.statut NOT IN ('resolu', 'ferme') THEN
      RAISE EXCEPTION 'Transition invalide: en_cours -> %', NEW.statut;
    END IF;
  END IF;

  -- Transitions from 'resolu'
  IF OLD.statut = 'resolu' THEN
    IF NEW.statut != 'ferme' THEN
      RAISE EXCEPTION 'Transition invalide: resolu -> %', NEW.statut;
    END IF;
  END IF;

  -- Terminal state
  IF OLD.statut = 'ferme' AND NEW.statut != 'ferme' THEN
    RAISE EXCEPTION 'Transition invalide: Un incident fermé ne peut pas changer de statut.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_incident_fsm
BEFORE UPDATE OF statut ON incidents
FOR EACH ROW
EXECUTE FUNCTION fn_incident_fsm();


-- View: v_apartment_balance
CREATE OR REPLACE VIEW v_apartment_balance AS
WITH total_charges AS (
  SELECT a.id, a.code, (SELECT COALESCE(SUM((valeur->>'montant_fixe')::NUMERIC), 200) FROM residence_settings WHERE cle = 'charges_mensuelles') *
    ((EXTRACT(YEAR FROM CURRENT_DATE) - 2024) * 12 + EXTRACT(MONTH FROM CURRENT_DATE) - 1) as charge_totale
  FROM apartments a
),
total_paiements AS (
  SELECT appartement_id, SUM(montant) as total_paye
  FROM payments
  WHERE statut = 'valide'
  GROUP BY appartement_id
)
SELECT
  tc.id,
  tc.code,
  tc.charge_totale,
  COALESCE(tp.total_paye, 0) as total_paye,
  COALESCE(tp.total_paye, 0) - tc.charge_totale as balance,
  CASE
    WHEN (COALESCE(tp.total_paye, 0) - tc.charge_totale) > 0 THEN 'credit'
    WHEN (COALESCE(tp.total_paye, 0) - tc.charge_totale) = 0 THEN 'balanced'
    ELSE 'debt'
  END as statut_financier
FROM total_charges tc
LEFT JOIN total_paiements tp ON tc.id = tp.appartement_id;

-- RPC: get_matrix_data
CREATE OR REPLACE FUNCTION get_matrix_data()
RETURNS TABLE (
  id UUID,
  code VARCHAR(10),
  etage INT,
  numero INT,
  resident_nom VARCHAR,
  balance NUMERIC,
  statut_financier TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.code,
    a.etage,
    a.numero,
    (SELECT u.nom || ' ' || u.prenom FROM residents r JOIN users u ON r.user_id = u.id WHERE r.appartement_id = a.id AND r.date_sortie IS NULL LIMIT 1) as resident_nom,
    vb.balance,
    vb.statut_financier
  FROM apartments a
  LEFT JOIN v_apartment_balance vb ON a.id = vb.id
  ORDER BY a.etage DESC, a.numero ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: get_dashboard_metrics
CREATE OR REPLACE FUNCTION get_dashboard_metrics()
RETURNS JSON AS $$
DECLARE
  v_total_tresorerie NUMERIC;
  v_charges_mensuelles NUMERIC := 200; -- Default if not found in settings
  v_runway NUMERIC;
  v_taux_recouvrement NUMERIC;
  v_paiements_valides_count INT;
  v_total_appartements_actifs INT;
BEGIN
  SELECT COALESCE(SUM(montant), 0) INTO v_total_tresorerie FROM flux_tresorerie WHERE type = 'recette';
  SELECT COALESCE(SUM(montant), 0) INTO v_total_tresorerie FROM flux_tresorerie WHERE type = 'depense' AND v_total_tresorerie > 0;

  -- Use actual values if available
  -- Calculate Runway
  IF v_charges_mensuelles > 0 THEN
    v_runway := v_total_tresorerie / v_charges_mensuelles;
  ELSE
    v_runway := 0;
  END IF;

  SELECT COUNT(DISTINCT appartement_id) INTO v_paiements_valides_count FROM payments WHERE statut = 'valide';
  SELECT COUNT(id) INTO v_total_appartements_actifs FROM apartments;

  -- Calculate Recovery Rate
  IF v_total_appartements_actifs > 0 THEN
    v_taux_recouvrement := (v_paiements_valides_count::NUMERIC / v_total_appartements_actifs::NUMERIC) * 100;
  ELSE
    v_taux_recouvrement := 0;
  END IF;

  RETURN json_build_object(
    'total_tresorerie', v_total_tresorerie,
    'runway', v_runway,
    'runway_status', CASE WHEN v_runway > 6 THEN 'healthy' WHEN v_runway >= 3 THEN 'warning' ELSE 'critical' END,
    'taux_recouvrement', v_taux_recouvrement
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: get_server_time for healthchecks
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS TIMESTAMPTZ AS $$
BEGIN
  RETURN NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE residents ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE flux_tresorerie ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE ag_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ag_presences ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE residence_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to get resident's apartment_id from JWT
CREATE OR REPLACE FUNCTION auth.jwt_resident_apartment_id()
RETURNS UUID AS $$
  SELECT (NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'resident_apartment_id', ''))::UUID;
$$ LANGUAGE SQL STABLE;

-- RLS: users
CREATE POLICY "Users can read all users"
ON users FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile"
ON users FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Syndic can manage users"
ON users FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: apartments
CREATE POLICY "Everyone can view apartments"
ON apartments FOR SELECT USING (true);

CREATE POLICY "Syndic can manage apartments"
ON apartments FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: residents
CREATE POLICY "Everyone can view residents"
ON residents FOR SELECT USING (true);

CREATE POLICY "Syndic can manage residents"
ON residents FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: payments
CREATE POLICY "Residents can view their own apartment payments"
ON payments FOR SELECT USING (
  appartement_id = auth.jwt_resident_apartment_id()
  OR (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

CREATE POLICY "Syndic can insert payments"
ON payments FOR INSERT WITH CHECK (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

CREATE POLICY "Syndic can update payments"
ON payments FOR UPDATE USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

CREATE POLICY "Syndic can delete payments"
ON payments FOR DELETE USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: flux_tresorerie
CREATE POLICY "Syndic can view flux_tresorerie"
ON flux_tresorerie FOR SELECT USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);
-- Note: Inserts handled by trigger `fn_on_payment_validated` which bypasses RLS (SECURITY DEFINER / Trigger context)
-- Note: Updates/Deletes blocked by trigger `fn_protect_flux_tresorerie`

-- RLS: incidents
CREATE POLICY "Residents can view all incidents"
ON incidents FOR SELECT USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') IN ('resident', 'syndic', 'gardien')
);

CREATE POLICY "Residents can insert incidents"
ON incidents FOR INSERT WITH CHECK (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') IN ('resident', 'syndic', 'gardien')
);

CREATE POLICY "Syndic can update incidents"
ON incidents FOR UPDATE USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

CREATE POLICY "Syndic can delete incidents"
ON incidents FOR DELETE USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: documents
CREATE POLICY "Everyone can view documents"
ON documents FOR SELECT USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') IN ('resident', 'syndic')
);

CREATE POLICY "Syndic can manage documents"
ON documents FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: ag_sessions
CREATE POLICY "Everyone can view ag_sessions"
ON ag_sessions FOR SELECT USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') IN ('resident', 'syndic')
);

CREATE POLICY "Syndic can manage ag_sessions"
ON ag_sessions FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: ag_presences
CREATE POLICY "Everyone can view ag_presences"
ON ag_presences FOR SELECT USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') IN ('resident', 'syndic')
);

CREATE POLICY "Residents can update their own presence"
ON ag_presences FOR UPDATE USING (
  resident_id IN (SELECT id FROM residents WHERE user_id = auth.uid())
);

CREATE POLICY "Syndic can manage ag_presences"
ON ag_presences FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);

-- RLS: audit_log
CREATE POLICY "Syndic can view audit_log"
ON audit_log FOR SELECT USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);
-- Note: Inserts handled by trigger `fn_on_payment_validated`
-- Note: Updates/Deletes blocked by trigger `fn_protect_audit_log`

-- RLS: residence_settings
CREATE POLICY "Everyone can view residence_settings"
ON residence_settings FOR SELECT USING (true);

CREATE POLICY "Syndic can manage residence_settings"
ON residence_settings FOR ALL USING (
  (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role') = 'syndic'
);
