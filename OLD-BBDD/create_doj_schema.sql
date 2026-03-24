-- 1. DOJ Cases Table
CREATE TABLE IF NOT EXISTS public.doj_cases (
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
  division TEXT DEFAULT 'DOJ' -- For future consistency
);

-- 2. DOJ Case Assignments
CREATE TABLE IF NOT EXISTS public.doj_case_assignments (
  case_id UUID REFERENCES public.doj_cases(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (case_id, user_id)
);

-- 3. DOJ Case Updates
CREATE TABLE IF NOT EXISTS public.doj_case_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.doj_cases(id) ON DELETE CASCADE,
  author_id UUID REFERENCES public.users(id),
  content TEXT,
  image_url TEXT, -- Or array? Using basic text for now to match main cases
  images TEXT[], -- Supporting multiple images
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. DOJ Sanctions
CREATE TABLE IF NOT EXISTS public.doj_sanctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  author_user_id UUID REFERENCES public.users(id),
  sanction_type TEXT CHECK (sanction_type IN ('Warning', 'Suspension', 'Demotion', 'Termination', 'Fine')),
  amount INT DEFAULT 0, -- For fines
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. DOJ Interrogations
CREATE TABLE IF NOT EXISTS public.doj_interrogations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.doj_cases(id) ON DELETE SET NULL,
  title TEXT,
  summary TEXT,
  subjects TEXT,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Security Policies (RLS)
ALTER TABLE public.doj_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doj_case_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doj_case_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doj_sanctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doj_interrogations ENABLE ROW LEVEL SECURITY;

-- Allow READ to Authenticated (Frontend Filtering handles visibility usually, but strict RLS is better)
-- For now, allowing all authenticated to read, but we will rely on frontend routing and "obscurity".
-- To be stricter, we should check `divisions` column of auth.uid().
CREATE POLICY "Allow All Auth Read IA" ON public.doj_cases FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read DOJ Assign" ON public.doj_case_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read DOJ Updates" ON public.doj_case_updates FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read DOJ Sanctions" ON public.doj_sanctions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow All Auth Read DOJ Interrogations" ON public.doj_interrogations FOR SELECT TO authenticated USING (true);

-- Allow Insert/Update
CREATE POLICY "Allow All Auth Write IA" ON public.doj_cases FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write DOJ Assign" ON public.doj_case_assignments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write DOJ Updates" ON public.doj_case_updates FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write DOJ Sanctions" ON public.doj_sanctions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow All Auth Write DOJ Interrogations" ON public.doj_interrogations FOR ALL TO authenticated USING (true) WITH CHECK (true);
