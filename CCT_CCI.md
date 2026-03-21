# CCT_CCI.md — Cahier des Charges Technique & Informatique
## Application de Gestion de Syndic — Résidence L'Amandier B
**Version**: 1.0 — Document de référence fonctionnel et technique exhaustif
**Juridiction**: Casablanca, Maroc | **Classification**: Spécification produit niveau production

---

## SECTION 1 — VISION ET PÉRIMÈTRE

### 1.1 Objectif Système
Créer une plateforme de pilotage financier et administratif couvrant intégralement la gestion d'une copropriété résidentielle. L'application est un outil de décision rapide pour le syndic et un portail de consultation pour les résidents.

**Fonctions capitales :**
- Gestion complète d'une copropriété (appartements, résidents, historiques)
- Pilotage financier en temps réel (trésorerie, KPIs, runway)
- Gouvernance administrative (assemblées générales, votes, PV)
- Archivage légal (documents figés, signés cryptographiquement)
- Audit intégral (journal immuable de toutes les mutations financières)
- Décision rapide du syndic (dashboard < 5 secondes à la compréhension)

### 1.2 Contraintes Fondamentales
| Contrainte | Valeur |
|---|---|
| Budget total | 0 EUR |
| Plateforme cible | PWA Android + navigateurs desktop |
| Performance | Temps de réponse < 2 secondes |
| Confidentialité | Isolation données par rôle (RLS) |
| Fiabilité | Aucune corruption financière tolérée |

---

## SECTION 2 — MODÈLE CONCEPTUEL DU SYSTÈME

Le système repose sur **7 domaines métier** interconnectés :

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│ Utilisateurs│────▶│   Résidence  │────▶│   Finances    │
│  (Auth/IAM) │     │ (Appartements│     │ (Paiements,   │
└─────────────┘     │  Résidents)  │     │  Trésorerie)  │
                    └──────────────┘     └───────────────┘
                           │                      │
                    ┌──────▼──────┐     ┌─────────▼─────┐
                    │ Maintenance │     │   Documents   │
                    │ (Incidents) │     │ (PDF légaux)  │
                    └─────────────┘     └───────────────┘
                           │
                    ┌──────▼──────┐     ┌───────────────┐
                    │Gouvernance  │────▶│     Audit     │
                    │    (AG)     │     │   (Journal)   │
                    └─────────────┘     └───────────────┘
```

---

## SECTION 3 — MODÈLE DE DONNÉES (LOGIQUE ET PHYSIQUE)

### 3.1 Table `users` (extension de `auth.users` Supabase)

```sql
CREATE TABLE public.users (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom             VARCHAR(100) NOT NULL,
  prenom          VARCHAR(100) NOT NULL,
  telephone       VARCHAR(20),
  role            user_role NOT NULL DEFAULT 'resident',  -- ENUM
  statut          user_statut NOT NULL DEFAULT 'actif',   -- ENUM
  pin_hash        TEXT,          -- bcrypt hash du PIN 4 chiffres (résidents)
  avatar_url      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at   TIMESTAMPTZ,
  CONSTRAINT chk_role CHECK (role IN ('syndic','gestionnaire','gardien','resident'))
);

CREATE TYPE user_role AS ENUM ('syndic', 'gestionnaire', 'gardien', 'resident');
CREATE TYPE user_statut AS ENUM ('actif', 'inactif', 'suspendu');
```

**Index**: `CREATE INDEX idx_users_role ON users(role);`

### 3.2 Table `apartments`

```sql
CREATE TABLE public.apartments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero          SMALLINT NOT NULL,          -- 1, 2, 3 (per floor)
  etage           SMALLINT NOT NULL,          -- 1 to 5
  code            VARCHAR(10) GENERATED ALWAYS AS ('E' || etage || 'A' || numero) STORED,
  surface_m2      NUMERIC(6,2),              -- optional
  statut          apt_statut NOT NULL DEFAULT 'vacant',
  cotisation_mensuelle NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_apt_floor_number UNIQUE (etage, numero),
  CONSTRAINT chk_etage CHECK (etage BETWEEN 1 AND 5),
  CONSTRAINT chk_numero CHECK (numero BETWEEN 1 AND 3)
);

CREATE TYPE apt_statut AS ENUM ('occupe', 'vacant', 'travaux');
```

**Seed**: 15 rows — all combinations of etage ∈ {1..5} × numero ∈ {1..3}.

### 3.3 Table `residents`

```sql
CREATE TABLE public.residents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  appartement_id  UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
  type_residence  resident_type NOT NULL,
  date_entree     DATE NOT NULL,
  date_sortie     DATE,                      -- NULL = current occupant
  actif           BOOLEAN NOT NULL DEFAULT true,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_dates CHECK (date_sortie IS NULL OR date_sortie > date_entree),
  -- Only one active resident per apartment at a time
  CONSTRAINT uq_active_resident EXCLUDE USING gist (
    appartement_id WITH =,
    daterange(date_entree, COALESCE(date_sortie, 'infinity'::date)) WITH &&
  ) WHERE (actif = true)
);

CREATE TYPE resident_type AS ENUM ('proprietaire', 'locataire');

CREATE INDEX idx_residents_apt ON residents(appartement_id);
CREATE INDEX idx_residents_user ON residents(user_id);
CREATE INDEX idx_residents_actif ON residents(actif) WHERE actif = true;
```

### 3.4 Table `payments`

```sql
CREATE TABLE public.payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appartement_id  UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
  resident_id     UUID REFERENCES residents(id) ON DELETE SET NULL,
  periode         DATE NOT NULL,             -- First day of the month: 2025-03-01
  montant         NUMERIC(10,2) NOT NULL CHECK (montant > 0),
  mode_paiement   payment_mode NOT NULL,
  date_paiement   DATE NOT NULL DEFAULT CURRENT_DATE,
  statut          payment_statut NOT NULL DEFAULT 'en_attente',
  valide_par      UUID REFERENCES users(id) ON DELETE SET NULL,
  valide_at       TIMESTAMPTZ,
  notes           TEXT,
  serial_id       TEXT UNIQUE,               -- RCP-2025-00042, auto-generated
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by      UUID NOT NULL REFERENCES users(id),
  -- CRITICAL: Only one validated payment per apartment per period
  CONSTRAINT uq_validated_payment_period
    EXCLUDE USING btree (appartement_id WITH =, periode WITH =)
    WHERE (statut = 'valide')
);

CREATE TYPE payment_mode AS ENUM ('especes', 'virement', 'cheque', 'mobile_money');
CREATE TYPE payment_statut AS ENUM ('en_attente', 'valide', 'rejete', 'annule');

CREATE INDEX idx_payments_apt_periode ON payments(appartement_id, periode);
CREATE INDEX idx_payments_statut ON payments(statut);
CREATE INDEX idx_payments_periode ON payments(periode);
```

**Error handling**: Application layer MUST catch PostgreSQL error code `23505` (unique_violation) and display: "Un paiement validé existe déjà pour cet appartement sur cette période."

### 3.5 Table `flux_tresorerie`

```sql
CREATE TABLE public.flux_tresorerie (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type_flux       flux_type NOT NULL,
  categorie       flux_categorie NOT NULL,
  montant         NUMERIC(10,2) NOT NULL CHECK (montant > 0),
  date_flux       DATE NOT NULL DEFAULT CURRENT_DATE,
  compte          compte_type NOT NULL DEFAULT 'caisse',
  source_type     VARCHAR(50),               -- 'payment', 'depense', 'autre'
  source_id       UUID,                      -- FK to payments.id or other
  reference       TEXT,
  description     TEXT NOT NULL,
  saisi_par       UUID NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Immutable: no UPDATE or DELETE allowed (append-only ledger)
  CONSTRAINT chk_montant_positive CHECK (montant > 0)
);

CREATE TYPE flux_type AS ENUM ('entree', 'sortie');
CREATE TYPE flux_categorie AS ENUM (
  'cotisation', 'travaux', 'entretien', 'salaire',
  'assurance', 'electricite', 'eau', 'autre'
);
CREATE TYPE compte_type AS ENUM ('caisse', 'banque');

CREATE INDEX idx_flux_date ON flux_tresorerie(date_flux DESC);
CREATE INDEX idx_flux_type ON flux_tresorerie(type_flux);
CREATE INDEX idx_flux_source ON flux_tresorerie(source_type, source_id);
```

**Immutability**: A trigger must prevent `UPDATE` and `DELETE` on `flux_tresorerie` for all roles except the Supabase service role.

### 3.6 Table `incidents`

```sql
CREATE TABLE public.incidents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appartement_id  UUID REFERENCES apartments(id) ON DELETE SET NULL,
  type_incident   VARCHAR(100) NOT NULL,
  description     TEXT NOT NULL,
  priorite        incident_priorite NOT NULL DEFAULT 'normale',
  statut          incident_statut NOT NULL DEFAULT 'ouvert',
  assigne_a       UUID REFERENCES users(id) ON DELETE SET NULL,
  rapporte_par    UUID NOT NULL REFERENCES users(id),
  date_ouverture  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  date_resolution TIMESTAMPTZ,
  date_cloture    TIMESTAMPTZ,
  cout_reparation NUMERIC(10,2),
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_resolution_date CHECK (
    date_resolution IS NULL OR date_resolution >= date_ouverture
  )
);

CREATE TYPE incident_priorite AS ENUM ('basse', 'normale', 'haute', 'critique');
CREATE TYPE incident_statut AS ENUM ('ouvert', 'en_cours', 'resolu', 'cloture');

CREATE INDEX idx_incidents_statut ON incidents(statut) WHERE statut NOT IN ('cloture');
CREATE INDEX idx_incidents_priorite ON incidents(priorite, statut);
CREATE INDEX idx_incidents_assigne ON incidents(assigne_a) WHERE statut = 'en_cours';
```

**FSM transitions** (enforced by trigger):
```
ouvert → en_cours (requires: assigne_a IS NOT NULL)
en_cours → resolu (sets: date_resolution = NOW())
resolu → cloture (sets: date_cloture = NOW(), optionally sets cout_reparation)
ouvert → cloture (direct close — syndic only)
```

### 3.7 Table `documents`

```sql
CREATE TABLE public.documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type_document   doc_type NOT NULL,
  serial_id       TEXT NOT NULL UNIQUE,      -- PVA-2025-00001
  storage_path    TEXT,                      -- Supabase Storage path (frozen docs only)
  storage_bucket  TEXT DEFAULT 'legal-documents',
  genere_par      UUID NOT NULL REFERENCES users(id),
  reference_metier UUID,                     -- FK to payments.id, ag_sessions.id, etc.
  reference_table VARCHAR(50),               -- 'payments', 'ag_sessions', 'incidents'
  signe           BOOLEAN NOT NULL DEFAULT false,
  signature_hash  TEXT,                      -- SHA-256 of signed PDF bytes
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata        JSONB DEFAULT '{}'::jsonb  -- flexible extra fields
);

CREATE TYPE doc_type AS ENUM (
  'recu_paiement',
  'relance_amiable',
  'convocation_ag',
  'feuille_presence_ag',
  'proces_verbal_ag',
  'bon_intervention'
);

-- Sequences for serial_id generation
CREATE SEQUENCE seq_recu_paiement START 1;
CREATE SEQUENCE seq_proces_verbal START 1;
CREATE SEQUENCE seq_bon_intervention START 1;
CREATE SEQUENCE seq_convocation_ag START 1;
```

**Serial ID format**: Generated by PostgreSQL functions:
```sql
CREATE OR REPLACE FUNCTION generate_serial_id(type_code TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE seq_val BIGINT;
BEGIN
  seq_val := nextval('seq_' || type_code);
  RETURN type_code || '-' || EXTRACT(YEAR FROM NOW()) || '-' || LPAD(seq_val::TEXT, 5, '0');
END;
$$;
```

### 3.8 Table `ag_sessions`

```sql
CREATE TABLE public.ag_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titre           TEXT NOT NULL,
  date_ag         TIMESTAMPTZ NOT NULL,
  lieu            TEXT NOT NULL,
  type_ag         ag_type NOT NULL DEFAULT 'ordinaire',
  statut          ag_statut NOT NULL DEFAULT 'planifiee',
  quorum_requis   NUMERIC(5,2) NOT NULL DEFAULT 50.0,  -- percentage
  quorum_atteint  NUMERIC(5,2),
  ordre_du_jour   JSONB NOT NULL DEFAULT '[]'::jsonb,   -- array of agenda items
  convocation_doc_id UUID REFERENCES documents(id),
  pv_doc_id       UUID REFERENCES documents(id),
  created_by      UUID NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TYPE ag_type AS ENUM ('ordinaire', 'extraordinaire');
CREATE TYPE ag_statut AS ENUM ('planifiee', 'convoquee', 'en_cours', 'terminee', 'annulee');
```

### 3.9 Table `ag_presences`

```sql
CREATE TABLE public.ag_presences (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES ag_sessions(id) ON DELETE CASCADE,
  resident_id     UUID NOT NULL REFERENCES residents(id),
  appartement_id  UUID NOT NULL REFERENCES apartments(id),
  present         BOOLEAN NOT NULL DEFAULT false,
  pouvoir_donne_a UUID REFERENCES residents(id),
  signature_at    TIMESTAMPTZ,
  CONSTRAINT uq_presence_per_session UNIQUE (session_id, appartement_id)
);
```

### 3.10 Table `audit_log`

```sql
CREATE TABLE public.audit_log (
  id              BIGSERIAL PRIMARY KEY,
  action          VARCHAR(100) NOT NULL,      -- 'payment.validated', 'incident.closed', etc.
  acteur_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  acteur_role     user_role,
  table_cible     VARCHAR(50),
  objet_id        UUID,
  avant           JSONB,                      -- row state before change
  apres           JSONB,                      -- row state after change
  ip_address      INET,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Append-only: prohibit UPDATE and DELETE via trigger
CREATE INDEX idx_audit_action ON audit_log(action);
CREATE INDEX idx_audit_objet ON audit_log(objet_id);
CREATE INDEX idx_audit_created ON audit_log(created_at DESC);
```

### 3.11 Table `residence_settings`

```sql
CREATE TABLE public.residence_settings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom             TEXT NOT NULL DEFAULT 'Résidence L''Amandier B',
  adresse         TEXT NOT NULL DEFAULT 'Bouskoura, Casablanca',
  syndic_nom      TEXT,
  telephone       TEXT,
  cotisation_standard NUMERIC(10,2) NOT NULL DEFAULT 0,
  charges_fixes_mensuelles NUMERIC(10,2) NOT NULL DEFAULT 0,
  seuil_runway_critique NUMERIC(5,2) NOT NULL DEFAULT 3.0,
  seuil_runway_alerte NUMERIC(5,2) NOT NULL DEFAULT 6.0,
  logo_url        TEXT,
  couleur_primaire TEXT DEFAULT '#1e3a2f',
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Single-row table
  CONSTRAINT single_row CHECK (id = id)
);
```

---

## SECTION 4 — VUES SQL ET FONCTIONS RPC

### 4.1 Vue `v_apartment_balance`
```sql
CREATE VIEW v_apartment_balance AS
SELECT
  a.id AS appartement_id,
  a.code,
  a.etage,
  a.numero,
  a.statut AS apt_statut,
  r.id AS resident_id,
  u.nom || ' ' || u.prenom AS resident_nom,
  r.type_residence,
  COALESCE(SUM(p.montant) FILTER (WHERE p.statut = 'valide'), 0) AS total_paye,
  -- Total due: count months since entry × monthly cotisation
  COALESCE(
    EXTRACT(MONTH FROM AGE(CURRENT_DATE, r.date_entree)) *
    a.cotisation_mensuelle, 0
  ) AS total_du,
  COALESCE(SUM(p.montant) FILTER (WHERE p.statut = 'valide'), 0) -
  COALESCE(
    EXTRACT(MONTH FROM AGE(CURRENT_DATE, r.date_entree)) *
    a.cotisation_mensuelle, 0
  ) AS balance,
  CASE
    WHEN r.id IS NULL THEN 'vacant'
    WHEN (COALESCE(SUM(p.montant) FILTER (WHERE p.statut = 'valide'), 0) -
          COALESCE(EXTRACT(MONTH FROM AGE(CURRENT_DATE, r.date_entree)) * a.cotisation_mensuelle, 0)) > 0
      THEN 'credit'
    WHEN (COALESCE(SUM(p.montant) FILTER (WHERE p.statut = 'valide'), 0) -
          COALESCE(EXTRACT(MONTH FROM AGE(CURRENT_DATE, r.date_entree)) * a.cotisation_mensuelle, 0)) = 0
      THEN 'balanced'
    ELSE 'debt'
  END AS balance_state
FROM apartments a
LEFT JOIN residents r ON r.appartement_id = a.id AND r.actif = true
LEFT JOIN users u ON u.id = r.user_id
LEFT JOIN payments p ON p.appartement_id = a.id
GROUP BY a.id, a.code, a.etage, a.numero, a.statut, a.cotisation_mensuelle,
         r.id, r.type_residence, r.date_entree, u.nom, u.prenom;
```

### 4.2 Fonction RPC `get_kpi_dashboard()`
```sql
CREATE OR REPLACE FUNCTION get_kpi_dashboard()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  result JSON;
  solde_total NUMERIC;
  solde_caisse NUMERIC;
  solde_banque NUMERIC;
  charges_fixes NUMERIC;
  runway NUMERIC;
  nb_impayes INTEGER;
  nb_actifs INTEGER;
  nb_payes_ce_mois INTEGER;
BEGIN
  -- Soldes par compte
  SELECT
    COALESCE(SUM(montant) FILTER (WHERE type_flux='entree'), 0) -
    COALESCE(SUM(montant) FILTER (WHERE type_flux='sortie'), 0)
  INTO solde_total FROM flux_tresorerie;

  SELECT
    COALESCE(SUM(montant) FILTER (WHERE type_flux='entree' AND compte='caisse'), 0) -
    COALESCE(SUM(montant) FILTER (WHERE type_flux='sortie' AND compte='caisse'), 0)
  INTO solde_caisse FROM flux_tresorerie;

  solde_banque := solde_total - solde_caisse;

  SELECT charges_fixes_mensuelles INTO charges_fixes FROM residence_settings LIMIT 1;

  -- Runway (avoid division by zero)
  runway := CASE WHEN COALESCE(charges_fixes, 0) = 0 THEN 999
             ELSE solde_total / charges_fixes END;

  -- Impayés: apartments with active resident and no validated payment this month
  SELECT COUNT(*) INTO nb_actifs
  FROM apartments a JOIN residents r ON r.appartement_id = a.id AND r.actif = true;

  SELECT COUNT(DISTINCT appartement_id) INTO nb_payes_ce_mois
  FROM payments
  WHERE statut = 'valide'
    AND date_trunc('month', periode) = date_trunc('month', CURRENT_DATE);

  nb_impayes := nb_actifs - nb_payes_ce_mois;

  SELECT JSON_BUILD_OBJECT(
    'solde_total', solde_total,
    'solde_caisse', solde_caisse,
    'solde_banque', solde_banque,
    'runway', ROUND(runway::NUMERIC, 1),
    'runway_state', CASE
      WHEN runway > 6 THEN 'healthy'
      WHEN runway >= 3 THEN 'warning'
      ELSE 'critical' END,
    'nb_impayes', nb_impayes,
    'nb_actifs', nb_actifs,
    'taux_recouvrement', CASE WHEN nb_actifs = 0 THEN 0
      ELSE ROUND((nb_payes_ce_mois::NUMERIC / nb_actifs) * 100, 1) END,
    'generated_at', NOW()
  ) INTO result;

  RETURN result;
END;
$$;
```

### 4.3 Fonction RPC `get_matrix_data()`
```sql
CREATE OR REPLACE FUNCTION get_matrix_data()
RETURNS TABLE (
  appartement_id UUID, code TEXT, etage SMALLINT, numero SMALLINT,
  resident_nom TEXT, apt_statut apt_statut, balance_state TEXT, balance NUMERIC
) LANGUAGE sql SECURITY DEFINER AS $$
  SELECT appartement_id, code, etage, numero, resident_nom,
         apt_statut, balance_state, balance
  FROM v_apartment_balance
  ORDER BY etage DESC, numero ASC;
$$;
```

---

## SECTION 5 — TRIGGERS CRITIQUES

### 5.1 Trigger: Validation de paiement → Flux trésorerie + Audit
```sql
CREATE OR REPLACE FUNCTION fn_on_payment_validated()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Only fires when statut transitions to 'valide'
  IF NEW.statut = 'valide' AND (OLD.statut IS NULL OR OLD.statut != 'valide') THEN

    -- 1. Create treasury flow entry
    INSERT INTO flux_tresorerie (
      type_flux, categorie, montant, date_flux, compte,
      source_type, source_id, description, saisi_par
    ) VALUES (
      'entree', 'cotisation', NEW.montant, NEW.date_paiement, 'caisse',
      'payment', NEW.id,
      'Cotisation ' || TO_CHAR(NEW.periode, 'MM/YYYY') || ' - Apt ' || (
        SELECT code FROM apartments WHERE id = NEW.appartement_id
      ),
      NEW.valide_par
    );

    -- 2. Set validation timestamp
    NEW.valide_at := NOW();

    -- 3. Generate serial_id if not set
    IF NEW.serial_id IS NULL THEN
      NEW.serial_id := generate_serial_id('recu_paiement');
    END IF;

    -- 4. Audit log entry
    INSERT INTO audit_log (action, acteur_id, acteur_role, table_cible, objet_id, avant, apres)
    VALUES (
      'payment.validated', NEW.valide_par,
      (SELECT role FROM users WHERE id = NEW.valide_par),
      'payments', NEW.id,
      ROW_TO_JSON(OLD)::JSONB, ROW_TO_JSON(NEW)::JSONB
    );

  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tg_payment_validated
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION fn_on_payment_validated();
```

### 5.2 Trigger: Immuabilité du journal de trésorerie
```sql
CREATE OR REPLACE FUNCTION fn_protect_flux_tresorerie()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'flux_tresorerie is append-only. UPDATE and DELETE are forbidden.';
END;
$$;

CREATE TRIGGER tg_protect_flux
  BEFORE UPDATE OR DELETE ON flux_tresorerie
  FOR EACH ROW EXECUTE FUNCTION fn_protect_flux_tresorerie();
```

### 5.3 Trigger: FSM Incidents
```sql
CREATE OR REPLACE FUNCTION fn_incident_fsm()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Validate FSM transitions
  IF OLD.statut = 'en_cours' AND NEW.statut = 'resolu' THEN
    NEW.date_resolution := NOW();
  ELSIF OLD.statut = 'resolu' AND NEW.statut = 'cloture' THEN
    NEW.date_cloture := NOW();
  ELSIF NEW.statut = 'en_cours' AND NEW.assigne_a IS NULL THEN
    RAISE EXCEPTION 'Cannot set incident to en_cours without assigning it.';
  END IF;

  -- Audit
  INSERT INTO audit_log (action, acteur_id, table_cible, objet_id, avant, apres)
  VALUES (
    'incident.' || NEW.statut,
    auth.uid(), 'incidents', NEW.id,
    ROW_TO_JSON(OLD)::JSONB, ROW_TO_JSON(NEW)::JSONB
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER tg_incident_fsm
  BEFORE UPDATE OF statut ON incidents
  FOR EACH ROW EXECUTE FUNCTION fn_incident_fsm();
```

---

## SECTION 6 — RÈGLES MÉTIER CRITIQUES

### 6.1 Cohérence Financière
**Obligation absolue**: Toute entrée financière DOIT produire simultanément:
1. Une ligne dans `flux_tresorerie` (via trigger — jamais manuellement)
2. Une mise à jour du solde visible dans `v_apartment_balance`
3. Une entrée dans `audit_log`

Violation de cette règle = corruption de données = défaut critique.

### 6.2 Unicité des Paiements Mensuels
```sql
-- Index partiel — seul paiement validé par appartement par période
CONSTRAINT uq_validated_payment_period
  EXCLUDE USING btree (appartement_id WITH =, periode WITH =)
  WHERE (statut = 'valide')
```
L'UI doit capturer le code d'erreur PostgreSQL `23505` et afficher une alerte explicite.

### 6.3 Calcul du Runway
```
Runway (mois) = Solde total trésorerie ÷ Charges fixes mensuelles

États:
  > 6 mois  → 'healthy'  → Vert   (#16a34a)
  3–6 mois  → 'warning'  → Jaune  (#d97706)
  < 3 mois  → 'critical' → Rouge  (#dc2626) + animation pulse
```

### 6.4 États Financiers des Appartements
```
balance = total_paye (cotisations validées) − total_du (mois écoulés × cotisation)

balance > 0  → 'credit'   → Doré  (bg-yellow-100, border-yellow-400)
balance = 0  → 'balanced' → Vert  (bg-green-100,  border-green-400)
balance < 0  → 'debt'     → Rouge (bg-red-100,    border-red-400)
Pas résident → 'vacant'   → Gris  (bg-gray-100,   border-gray-300)
```

### 6.5 Taux de Recouvrement
```
Taux = (Nombre d'appartements occupés ayant un paiement validé ce mois) 
        ÷ (Nombre total d'appartements occupés) × 100
```

---

## SECTION 7 — SYSTÈME KPI (DASHBOARD SYNDIC)

### 7.1 KPI Obligatoires
| KPI | Formule | Seuils d'alerte |
|---|---|---|
| Solde Total | SUM(entrees) − SUM(sorties) | < 0 = rouge |
| Solde Caisse | SUM(entrees caisse) − SUM(sorties caisse) | — |
| Solde Banque | Solde Total − Solde Caisse | — |
| Runway | Solde Total ÷ Charges Fixes | < 3 mois = rouge |
| Impayés | Nb apts occupés sans paiement validé ce mois | > 3 = orange |
| Taux Recouvrement | Voir §6.5 | < 70% = rouge |

### 7.2 Source de Données Dashboard
**Obligation**: Un seul appel RPC `get_kpi_dashboard()` charge l'ensemble des KPIs. Interdit de faire N requêtes séparées pour chaque KPI.

---

## SECTION 8 — MATRICE VISUELLE DE LA RÉSIDENCE

### 8.1 Spécification
- Structure: 5 lignes (étages) × 3 colonnes (appartements)
- Orientation: Étage 5 en HAUT, étage 1 en BAS (correspond à la réalité physique)
- Chaque cellule affiche: numéro apt, nom résident (tronqué), indicateur couleur
- Code couleur: conforme §6.4

### 8.2 Implémentation CSS Grid Imposée
```tsx
// INTERDIT: ag-grid, tanstack table, MUI DataGrid, react-window
// OBLIGATOIRE: CSS Grid natif via Tailwind

const MATRIX_GRID_CLASS = "grid grid-cols-3 gap-2 w-full";

// Données triées: ORDER BY etage DESC, numero ASC
// Source: RPC get_matrix_data() — UN SEUL appel au montage

const BALANCE_STATE_CLASSES: Record<string, string> = {
  credit:   'bg-yellow-100 border-yellow-400 text-yellow-900',
  balanced: 'bg-green-100  border-green-400  text-green-900',
  debt:     'bg-red-100    border-red-400    text-red-900',
  vacant:   'bg-gray-100   border-gray-300   text-gray-500 italic',
};
```

### 8.3 Performance
- Données mises en cache dans `useReducer` (React) après le premier fetch
- Invalidation: uniquement sur mutation de paiement ou changement de résident
- Render target: < 100ms après réception des données

---

## SECTION 9 — GÉNÉRATION DOCUMENTAIRE

### 9.1 Documents Dynamiques (Client-side, pdfmake)

| Document | Déclencheur | Stockage | Serial ID |
|---|---|---|---|
| Reçu de paiement | Validation d'un paiement | Non (reconstruit à la volée) | RCP-YYYY-NNNNN |
| Relance amiable | Paiement en retard détecté | Non | RLA-YYYY-NNNNN |

**Propriété critique du reçu**: Le même `payment_id` doit toujours produire un PDF identique. Le reçu est reconstruit à partir des données relationnelles, jamais stocké.

**Champs obligatoires du reçu**:
- Nom Résidence + Adresse + Logo (depuis `residence_settings`)
- IDENTIFIANT_DOCUMENTAIRE_UUID
- Serial ID (ex: RCP-2025-00042)
- QR code encodant l'URL de vérification
- Nom résident, Appartement (code), Période
- Montant numérique + **Montant en lettres (OBLIGATOIRE, en français)**
- Date paiement, Mode paiement
- Nom + signature du validateur
- Horodatage de génération

### 9.2 Documents Figés (Server-side Route Handler, pdf-lib + WebCrypto)

| Document | Déclencheur | Stockage | Signature PKCS#7 |
|---|---|---|---|
| PV Assemblée Générale | Clôture AG | Supabase Storage | ✅ Obligatoire |
| Feuille de présence AG | Validation quorum | Supabase Storage | ✅ Obligatoire |
| Convocation AG | Création AG | Supabase Storage | ✅ |
| Bon d'intervention | Création intervention | Supabase Storage | ✅ |

**Pipeline de signature** (voir AGENTS.md §9 pour le code): SHA-256 → RSA-PKCS1v15 → PKCS#7 → Injection incrémentale pdf-lib → Upload Supabase Storage.

### 9.3 Standard Documentaire Unifié
Tous les documents respectent:
- En-tête: "Résidence L'Amandier B — Bouskoura, Casablanca"
- Police: Helvetica (intégrée pdfmake, zéro dépendance)
- Numérotation pages: "Page X / N"
- Pied de page: Syndic + Date génération + Serial ID + QR code vérification

---

## SECTION 10 — ARCHITECTURE FONCTIONNELLE

### 10.1 Couches Système
```
┌────────────────────────────────────────────────┐
│        Interface mobile PWA (Next.js)          │
│  React Server Components + Client Components   │
├────────────────────────────────────────────────┤
│       API Backend (Next.js Route Handlers)     │
│    /api/documents/sign | /api/notifications    │
├────────────────────────────────────────────────┤
│        Moteur Métier (SQL Triggers + Views)    │
│  Triggers PostgreSQL | RLS | RPC Functions     │
├────────────────────────────────────────────────┤
│        Base de données (Supabase PostgreSQL)   │
│    Tables + Vues + Triggers + Audit Log        │
├────────────────────────────────────────────────┤
│        Service Documents (pdf-lib + pdfmake)   │
├────────────────────────────────────────────────┤
│        Service Stockage (Supabase Storage)     │
└────────────────────────────────────────────────┘
```

### 10.2 Flux Critique: Paiement Complet
```
1. Syndic/Gestionnaire saisit le paiement (formulaire)
2. INSERT payments (statut='en_attente')
3. Syndic valide → UPDATE payments SET statut='valide'
4. [TRIGGER fn_on_payment_validated]:
   a. INSERT flux_tresorerie (entree)
   b. SET serial_id = generate_serial_id('recu_paiement')
   c. INSERT audit_log
5. UI reçoit la confirmation → invalide le cache KPI
6. Syndic clique "Générer reçu" → pdfmake côté client reconstruit le PDF
7. PDF téléchargé — aucun stockage serveur requis
```

---

## SECTION 11 — ÉCRANS OBLIGATOIRES

| Écran | Route | Rôles | Description |
|---|---|---|---|
| Login topographique | `/login` | Tous | Étage → Apt → PIN |
| Login admin | `/admin/login` | Syndic, Gestionnaire | Email + mot de passe |
| Dashboard Syndic | `/syndic/dashboard` | Syndic, Gestionnaire | KPI + Matrice + Incidents |
| Dashboard Résident | `/resident/dashboard` | Résident | Solde + Paiements + Incidents |
| Gestion Résidents | `/syndic/residents` | Syndic, Gestionnaire | CRUD résidents |
| Gestion Appartements | `/syndic/apartments` | Syndic | CRUD appartements + historique |
| Gestion Paiements | `/syndic/payments` | Syndic, Gestionnaire | Liste + Validation + Reçu |
| Incidents | `/syndic/incidents` | Tous (accès filtré) | CRUD + FSM + Assignation |
| Documents | `/syndic/documents` | Syndic, Gestionnaire | Liste + Génération + Vérification |
| Assemblées Générales | `/syndic/ag` | Syndic | Workflow complet AG |
| Paramètres | `/syndic/settings` | Syndic | Résidence + Financiers + KPI |
| À Propos / CGU | `/about` | Tous | Informatif |

---

## SECTION 12 — SÉCURITÉ ET CONTRÔLE D'ACCÈS

### 12.1 Matrice des Permissions

| Fonctionnalité | Syndic | Gestionnaire | Gardien | Résident |
|---|---|---|---|---|
| Dashboard global KPI | ✅ | ✅ | ❌ | ❌ |
| Valider paiement | ✅ | ✅ | ❌ | ❌ |
| Créer résident | ✅ | ✅ | ❌ | ❌ |
| Voir ses propres paiements | ✅ | ✅ | ❌ | ✅ |
| Créer incident | ✅ | ✅ | ✅ | ✅ |
| Assigner incident | ✅ | ✅ | ❌ | ❌ |
| Résoudre incident assigné | ✅ | ✅ | ✅ (si assigné) | ❌ |
| Générer PDF reçu | ✅ | ✅ | ❌ | ❌ |
| Signer document légal | ✅ | ❌ | ❌ | ❌ |
| Modifier paramètres | ✅ | ❌ | ❌ | ❌ |
| Gérer AG | ✅ | ❌ | ❌ | ❌ |

### 12.2 Principes
- **Isolation des données**: RLS enforced at DB engine level — pas de filtrage applicatif pour la sécurité
- **Rôles stricts**: Role embedded in JWT custom claim, validated by every RLS policy
- **Traçabilité complète**: Chaque mutation critique = ligne dans `audit_log`
- **Immuabilité**: `flux_tresorerie` et `audit_log` sont append-only

---

## SECTION 13 — PERFORMANCE ET FIABILITÉ

### 13.1 Objectifs de Performance
| Métrique | Cible |
|---|---|
| Temps de réponse général | < 2 secondes |
| Chargement dashboard KPI | < 500ms (1 RPC) |
| Rendu matrice appartements | < 100ms (CSS Grid) |
| Génération PDF reçu | < 300ms (client-side) |
| Signature PDF légal | < 3 secondes (server-side) |

### 13.2 Fiabilité
- Sauvegarde automatique: Supabase gère les backups PostgreSQL (plan gratuit = 7 jours)
- Journal d'erreurs: Next.js error boundary + Vercel logs
- Reconstruction possible: Tout état financier reconstructible depuis `flux_tresorerie` + `payments`
- Mode hors-ligne: Cache service worker pour consultation de la matrice et des KPIs (Last Known Good)

### 13.3 Évolutivité (Phase 2)
- Architecture multi-résidences: Ajouter `residence_id` FK à toutes les tables + RLS basé sur `residence_id`
- Paiement en ligne: Intégration CMI (Maroc) ou Stripe si budget disponible
- Signature électronique certifiée: Intégration Yousign (si budget)
- Notifications push: Web Push API (gratuit, via service worker)

---

## SECTION 14 — WORKFLOWS CRITIQUES

### 14.1 Workflow Paiement
```
[Saisie] → [Validation] → [Trésorerie auto] → [KPI auto] → [Reçu générable]
  statut='en_attente'    statut='valide'    TRIGGER fires   pdfmake client
```

### 14.2 Workflow Incident (FSM)
```
ouvert → [assignation] → en_cours → [résolution] → resolu → [clôture] → cloture
                                                              ↑
                                               [cout_reparation optionnel]
```

### 14.3 Workflow Assemblée Générale
```
planifiee → [rédaction OJ] → convoquee → [feuille présence] → en_cours
           [convocation PDF]            [quorum calculé]
en_cours → [votes] → terminee → [PV auto-généré + signé] → archivé
```
