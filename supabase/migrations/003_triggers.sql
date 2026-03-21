-- fn_on_payment_validated trigger
CREATE OR REPLACE FUNCTION public.fn_on_payment_validated()
RETURNS TRIGGER AS $$
DECLARE
  v_serial_id VARCHAR(50);
BEGIN
  -- Only fire when status changes to 'valide'
  IF NEW.statut = 'valide' AND (OLD.statut IS NULL OR OLD.statut != 'valide') THEN
    NEW.valide_at = NOW();

    -- Generate serial ID
    v_serial_id := public.generate_serial_id('REC');

    INSERT INTO public.flux_tresorerie (
      serial_id, type, montant, date_flux, description, source_id
    ) VALUES (
      v_serial_id, 'recette', NEW.montant, NEW.date_paiement,
      'Paiement validé pour appartement ' || (SELECT code FROM public.apartments WHERE id = NEW.appartement_id) || ' - Période ' || NEW.periode,
      NEW.id
    );

    INSERT INTO public.audit_log (
      table_name, objet_id, action, new_data, changed_by
    ) VALUES (
      'payments', NEW.id, 'payment.validated', row_to_json(NEW)::jsonb, NEW.valide_par
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_payment_validated
BEFORE UPDATE ON public.payments
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_payment_validated();


-- fn_protect_flux_tresorerie trigger
CREATE OR REPLACE FUNCTION public.fn_protect_flux_tresorerie()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Les modifications ou suppressions dans flux_tresorerie sont strictement interdites.';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_protect_flux
BEFORE UPDATE OR DELETE ON public.flux_tresorerie
FOR EACH ROW
EXECUTE FUNCTION public.fn_protect_flux_tresorerie();


-- fn_protect_audit_log trigger
CREATE OR REPLACE FUNCTION public.fn_protect_audit_log()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Les modifications ou suppressions dans audit_log sont strictement interdites.';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_protect_audit
BEFORE UPDATE OR DELETE ON public.audit_log
FOR EACH ROW
EXECUTE FUNCTION public.fn_protect_audit_log();


-- fn_incident_fsm trigger
CREATE OR REPLACE FUNCTION public.fn_incident_fsm()
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

CREATE TRIGGER tg_incident_fsm
BEFORE UPDATE OF statut ON public.incidents
FOR EACH ROW
EXECUTE FUNCTION public.fn_incident_fsm();
