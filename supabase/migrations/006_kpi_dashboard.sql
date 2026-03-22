CREATE OR REPLACE FUNCTION public.get_kpi_dashboard()
RETURNS JSON AS $$
DECLARE
  v_total_recettes NUMERIC;
  v_total_depenses NUMERIC;
  v_solde_total NUMERIC;
  v_impayes_total NUMERIC;
  v_incidents_ouverts INT;
  v_charges_mensuelles NUMERIC;
  v_runway NUMERIC;
  v_taux_recouvrement NUMERIC;
  v_paiements_valides_count INT;
  v_total_appartements_actifs INT;
BEGIN
  -- Treasury
  SELECT COALESCE(SUM(montant), 0) INTO v_total_recettes FROM public.flux_tresorerie WHERE type = 'recette';
  SELECT COALESCE(SUM(montant), 0) INTO v_total_depenses FROM public.flux_tresorerie WHERE type = 'depense';
  v_solde_total := v_total_recettes - v_total_depenses;

  -- Impayés (Total expected - Total paid)
  -- For simplicity in KPI, we can sum negative balances from the view
  SELECT COALESCE(SUM(balance), 0) INTO v_impayes_total FROM public.v_apartment_balance WHERE balance < 0;

  -- Incidents
  SELECT COUNT(id) INTO v_incidents_ouverts FROM public.incidents WHERE statut IN ('ouvert', 'en_cours');

  -- Get monthly charges config
  SELECT COALESCE((valeur->>'montant_fixe')::NUMERIC, 200) INTO v_charges_mensuelles FROM public.residence_settings WHERE cle = 'charges_mensuelles';

  -- Calculate Runway
  IF v_charges_mensuelles > 0 THEN
    v_runway := v_solde_total / v_charges_mensuelles;
  ELSE
    v_runway := 999; -- Handled properly in UI per mandate
  END IF;

  -- Calculate Taux de Recouvrement
  SELECT COUNT(DISTINCT appartement_id) INTO v_paiements_valides_count FROM public.payments WHERE statut = 'valide';
  SELECT COUNT(id) INTO v_total_appartements_actifs FROM public.apartments;

  IF v_total_appartements_actifs > 0 THEN
    v_taux_recouvrement := (v_paiements_valides_count::NUMERIC / v_total_appartements_actifs::NUMERIC) * 100;
  ELSE
    v_taux_recouvrement := 0;
  END IF;

  RETURN json_build_object(
    'solde_total', v_solde_total,
    'total_recettes', v_total_recettes,
    'total_depenses', v_total_depenses,
    'impayes_total', ABS(v_impayes_total), -- Make positive for display
    'incidents_ouverts', v_incidents_ouverts,
    'runway', v_runway,
    'taux_recouvrement', v_taux_recouvrement
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
