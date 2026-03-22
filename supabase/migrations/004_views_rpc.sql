-- View: v_apartment_balance
CREATE OR REPLACE VIEW public.v_apartment_balance AS
WITH total_charges AS (
  SELECT a.id, a.code, (SELECT COALESCE(SUM((valeur->>'montant_fixe')::NUMERIC), 200) FROM public.residence_settings WHERE cle = 'charges_mensuelles') *
    ((EXTRACT(YEAR FROM CURRENT_DATE) - 2024) * 12 + EXTRACT(MONTH FROM CURRENT_DATE) - 1) as charge_totale
  FROM public.apartments a
),
total_paiements AS (
  SELECT appartement_id, SUM(montant) as total_paye
  FROM public.payments
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
CREATE OR REPLACE FUNCTION public.get_matrix_data()
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
    (SELECT u.nom || ' ' || u.prenom FROM public.residents r JOIN public.users u ON r.user_id = u.id WHERE r.appartement_id = a.id AND r.date_sortie IS NULL LIMIT 1) as resident_nom,
    vb.balance,
    vb.statut_financier
  FROM public.apartments a
  LEFT JOIN public.v_apartment_balance vb ON a.id = vb.id
  ORDER BY a.etage DESC, a.numero ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: get_kpi_dashboard (replaces get_dashboard_metrics to match prompt)
CREATE OR REPLACE FUNCTION public.get_kpi_dashboard()
RETURNS JSON AS $$
DECLARE
  v_total_tresorerie NUMERIC;
  v_charges_mensuelles NUMERIC := 200; -- Default if not found in settings
  v_runway NUMERIC;
  v_taux_recouvrement NUMERIC;
  v_paiements_valides_count INT;
  v_total_appartements_actifs INT;
BEGIN
  SELECT COALESCE(SUM(montant), 0) INTO v_total_tresorerie FROM public.flux_tresorerie WHERE type = 'recette';
  SELECT COALESCE(SUM(montant), 0) INTO v_total_tresorerie FROM public.flux_tresorerie WHERE type = 'depense' AND v_total_tresorerie > 0;

  -- Calculate Runway
  IF v_charges_mensuelles > 0 THEN
    v_runway := v_total_tresorerie / v_charges_mensuelles;
  ELSE
    v_runway := 0;
  END IF;

  SELECT COUNT(DISTINCT appartement_id) INTO v_paiements_valides_count FROM public.payments WHERE statut = 'valide';
  SELECT COUNT(id) INTO v_total_appartements_actifs FROM public.apartments;

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

-- Ensure get_server_time is also there
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ AS $$
BEGIN
  RETURN NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
