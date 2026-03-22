-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.residents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flux_tresorerie ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ag_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ag_presences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.residence_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to get resident's apartment_id from JWT
CREATE OR REPLACE FUNCTION public.jwt_resident_apartment_id()
RETURNS UUID AS $$
  SELECT (NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'resident_apartment_id', ''))::UUID;
$$ LANGUAGE SQL STABLE;

-- Helper function to get role from JWT
CREATE OR REPLACE FUNCTION public.jwt_user_role()
RETURNS TEXT AS $$
  SELECT current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'role';
$$ LANGUAGE SQL STABLE;

-- RLS: users
CREATE POLICY "Users can read all users"
ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile"
ON public.users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "Syndic can manage users"
ON public.users FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: apartments
CREATE POLICY "Everyone can view apartments"
ON public.apartments FOR SELECT USING (true);
CREATE POLICY "Syndic can manage apartments"
ON public.apartments FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: residents
CREATE POLICY "Everyone can view residents"
ON public.residents FOR SELECT USING (true);
CREATE POLICY "Syndic can manage residents"
ON public.residents FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: payments
CREATE POLICY "Residents can view their own apartment payments"
ON public.payments FOR SELECT USING (
  appartement_id = public.jwt_resident_apartment_id()
  OR public.jwt_user_role() = 'syndic'
);
CREATE POLICY "Syndic can manage payments"
ON public.payments FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: flux_tresorerie
CREATE POLICY "Syndic can view flux_tresorerie"
ON public.flux_tresorerie FOR SELECT USING (public.jwt_user_role() = 'syndic');

-- RLS: incidents
CREATE POLICY "Residents and others can view incidents"
ON public.incidents FOR SELECT USING (
  public.jwt_user_role() IN ('resident', 'syndic', 'gardien')
);
CREATE POLICY "Residents and others can insert incidents"
ON public.incidents FOR INSERT WITH CHECK (
  public.jwt_user_role() IN ('resident', 'syndic', 'gardien')
);
CREATE POLICY "Syndic can manage incidents"
ON public.incidents FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: documents
CREATE POLICY "Everyone can view documents"
ON public.documents FOR SELECT USING (
  public.jwt_user_role() IN ('resident', 'syndic')
);
CREATE POLICY "Syndic can manage documents"
ON public.documents FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: ag_sessions
CREATE POLICY "Everyone can view ag_sessions"
ON public.ag_sessions FOR SELECT USING (
  public.jwt_user_role() IN ('resident', 'syndic')
);
CREATE POLICY "Syndic can manage ag_sessions"
ON public.ag_sessions FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: ag_presences
CREATE POLICY "Everyone can view ag_presences"
ON public.ag_presences FOR SELECT USING (
  public.jwt_user_role() IN ('resident', 'syndic')
);
CREATE POLICY "Residents can update their own presence"
ON public.ag_presences FOR UPDATE USING (
  resident_id IN (SELECT id FROM public.residents WHERE user_id = auth.uid())
);
CREATE POLICY "Syndic can manage ag_presences"
ON public.ag_presences FOR ALL USING (public.jwt_user_role() = 'syndic');

-- RLS: audit_log
CREATE POLICY "Syndic can view audit_log"
ON public.audit_log FOR SELECT USING (public.jwt_user_role() = 'syndic');

-- RLS: residence_settings
CREATE POLICY "Everyone can view residence_settings"
ON public.residence_settings FOR SELECT USING (true);
CREATE POLICY "Syndic can manage residence_settings"
ON public.residence_settings FOR ALL USING (public.jwt_user_role() = 'syndic');
