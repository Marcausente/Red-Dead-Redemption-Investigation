-- 1. IA Cases Table
CREATE TABLE IF NOT EXISTS public.ia_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_number SERIAL,
  title TEXT NOT NULL,
  status TEXT DEFAULT 'Open' CHECK (status IN ('Open', 'Closed', 'Archived')),
  location TEXT,
  occurred_at TIMESTAMP WITH TIME ZONE,
  description TEXT,
  initial_image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id),
  division TEXT DEFAULT 'Internal Affairs' -- For future consistency
);

-- 2. IA Case Assignments
CREATE TABLE IF NOT EXISTS public.ia_case_assignments (
  case_id UUID REFERENCES public.ia_cases(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (case_id, user_id)
);

-- 3. IA Case Updates
CREATE TABLE IF NOT EXISTS public.ia_case_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.ia_cases(id) ON DELETE CASCADE,
  author_id UUID REFERENCES public.users(id),
  content TEXT,
  image_url TEXT, -- Or array? Using basic text for now to match main cases
  images TEXT[], -- Supporting multiple images
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. IA Sanctions
CREATE TABLE IF NOT EXISTS public.ia_sanctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  author_user_id UUID REFERENCES public.users(id),
  sanction_type TEXT CHECK (sanction_type IN ('Warning', 'Suspension', 'Demotion', 'Termination', 'Fine')),
  amount INT DEFAULT 0, -- For fines
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. IA Interrogations
CREATE TABLE IF NOT EXISTS public.ia_interrogations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.ia_cases(id) ON DELETE SET NULL,
  title TEXT,
  summary TEXT,
  subjects TEXT,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Security Policies (RLS)
ALTER TABLE public.ia_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ia_case_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ia_case_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ia_sanctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ia_interrogations ENABLE ROW LEVEL SECURITY;

-- Allow READ to Authenticated (Frontend Filtering handles visibility usually, but strict RLS is better)
-- For now, allowing all authenticated to read, but we will rely on frontend routing and "obscurity".
-- To be stricter, we should check `divisions` column of auth.uid().
CREATE POLICY "Allow All Auth Read IA" ON public.ia_cases FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read IA Assign" ON public.ia_case_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read IA Updates" ON public.ia_case_updates FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read IA Sanctions" ON public.ia_sanctions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read IA Interrogations" ON public.ia_interrogations FOR SELECT TO authenticated USING (true);

-- Allow Insert/Update
CREATE POLICY "Allow All Auth Write IA" ON public.ia_cases FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write IA Assign" ON public.ia_case_assignments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write IA Updates" ON public.ia_case_updates FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write IA Sanctions" ON public.ia_sanctions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write IA Interrogations" ON public.ia_interrogations FOR ALL TO authenticated USING (true) WITH CHECK (true);
