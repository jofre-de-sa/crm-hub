-- ============================================================
--  CRM HUB – Supabase Database Schema
--  By Plotting Engage
--  Run this in Supabase SQL Editor (Settings > SQL Editor)
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────
-- 1. COMPANIES
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  nif         TEXT UNIQUE NOT NULL,
  email       TEXT,
  phone       TEXT,
  country     TEXT DEFAULT 'Angola',
  logo_url    TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 2. USER PROFILES (extends Supabase auth.users)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name    TEXT NOT NULL,
  email        TEXT NOT NULL,
  phone        TEXT,
  role         TEXT NOT NULL CHECK (role IN ('master','admin','collaborator')) DEFAULT 'collaborator',
  company_id   UUID REFERENCES companies(id) ON DELETE SET NULL,
  avatar_url   TEXT,
  active       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'role', 'collaborator')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- ─────────────────────────────────────────────
-- 3. PROJECTS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  description TEXT,
  date        DATE,
  company_id  UUID REFERENCES companies(id) ON DELETE CASCADE,
  created_by  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  image_url   TEXT,
  active      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 4. PROJECT MEMBERS (many-to-many)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS project_members (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('admin','collaborator')) DEFAULT 'collaborator',
  added_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (project_id, user_id)
);

-- ─────────────────────────────────────────────
-- 5. FLOOR PLANS (Plantas)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS floor_plans (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  width_m     INTEGER NOT NULL DEFAULT 10,   -- metros largura
  length_m    INTEGER NOT NULL DEFAULT 20,   -- metros comprimento
  grid_data   JSONB DEFAULT '[]'::jsonb,     -- array of {row,col,type:'corridor'|'stand'|'empty'}
  stands_data JSONB DEFAULT '[]'::jsonb,     -- array of {number, cells:[{row,col}]}
  confirmed   BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 6. STANDS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stands (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  floor_plan_id UUID NOT NULL REFERENCES floor_plans(id) ON DELETE CASCADE,
  number       TEXT NOT NULL,               -- '01','02', etc.
  cells        JSONB NOT NULL DEFAULT '[]', -- [{row,col}]
  status       TEXT NOT NULL CHECK (status IN ('available','rented','reserved')) DEFAULT 'available',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(floor_plan_id, number)
);

-- ─────────────────────────────────────────────
-- 7. RENTALS (Aluguéis)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rentals (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  stand_id        UUID NOT NULL REFERENCES stands(id) ON DELETE CASCADE,
  company_name    TEXT NOT NULL,
  nif             TEXT NOT NULL,
  email           TEXT NOT NULL,
  phone           TEXT NOT NULL,
  country         TEXT DEFAULT 'Angola',
  status          TEXT NOT NULL CHECK (status IN ('active','cancelled')) DEFAULT 'active',
  notes           TEXT,
  created_by      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  cancelled_by    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  cancelled_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 8. RENTAL DOCUMENTS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rental_documents (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rental_id   UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
  file_name   TEXT NOT NULL,
  file_url    TEXT NOT NULL,
  file_type   TEXT,
  uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 9. NOTIFICATIONS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  message     TEXT NOT NULL,
  type        TEXT DEFAULT 'info' CHECK (type IN ('info','success','warning','error')),
  read        BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 10. MESSAGES (Internal)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  to_user_id   UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- NULL = broadcast
  subject      TEXT,
  body         TEXT NOT NULL,
  read         BOOLEAN DEFAULT FALSE,
  parent_id    UUID REFERENCES messages(id) ON DELETE SET NULL,  -- for replies
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 11. ACTIVITY LOG
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  project_id  UUID REFERENCES projects(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  entity_type TEXT,   -- 'stand','rental','floor_plan','project','user'
  entity_id   UUID,
  details     JSONB DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 12. STORAGE BUCKETS (run separately in Supabase dashboard)
-- ─────────────────────────────────────────────
-- Create these buckets in Supabase Storage:
--   • avatars       (public)
--   • logos         (public)
--   • documents     (private)
--   • project-images (public)

-- ─────────────────────────────────────────────
-- 13. ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────

ALTER TABLE companies        ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects         ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE floor_plans      ENABLE ROW LEVEL SECURITY;
ALTER TABLE stands           ENABLE ROW LEVEL SECURITY;
ALTER TABLE rentals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log     ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all, update own
CREATE POLICY "profiles_read_all"   ON profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Companies: authenticated users read all; master/admin can insert/update
CREATE POLICY "companies_read_all"  ON companies FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "companies_manage"    ON companies FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('master','admin'))
);

-- Projects: members and admins
CREATE POLICY "projects_read"    ON projects FOR SELECT USING (
  auth.role() = 'authenticated'
);
CREATE POLICY "projects_manage"  ON projects FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('master','admin'))
);

-- Project members
CREATE POLICY "pm_read"   ON project_members FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "pm_manage" ON project_members FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('master','admin'))
);

-- Floor plans
CREATE POLICY "fp_read"   ON floor_plans FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "fp_manage" ON floor_plans FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('master','admin'))
);

-- Stands
CREATE POLICY "stands_read"   ON stands FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "stands_manage" ON stands FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('master','admin'))
);

-- Rentals: all authenticated can read; admin can manage
CREATE POLICY "rentals_read"   ON rentals FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "rentals_manage" ON rentals FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('master','admin'))
);

-- Rental documents
CREATE POLICY "docs_read"   ON rental_documents FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "docs_manage" ON rental_documents FOR ALL USING (auth.role() = 'authenticated');

-- Notifications: own only
CREATE POLICY "notif_own" ON notifications FOR ALL USING (user_id = auth.uid());

-- Messages
CREATE POLICY "msg_read" ON messages FOR SELECT USING (
  from_user_id = auth.uid() OR to_user_id = auth.uid() OR to_user_id IS NULL
);
CREATE POLICY "msg_insert" ON messages FOR INSERT WITH CHECK (from_user_id = auth.uid());
CREATE POLICY "msg_update" ON messages FOR UPDATE USING (to_user_id = auth.uid());

-- Activity log
CREATE POLICY "log_read"   ON activity_log FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "log_insert" ON activity_log FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────
-- 14. HELPER FUNCTION – log activity
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION log_activity(
  p_action      TEXT,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id   UUID DEFAULT NULL,
  p_project_id  UUID DEFAULT NULL,
  p_details     JSONB DEFAULT '{}'::jsonb
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO activity_log (user_id, project_id, action, entity_type, entity_id, details)
  VALUES (auth.uid(), p_project_id, p_action, p_entity_type, p_entity_id, p_details);
END;
$$;

-- ─────────────────────────────────────────────
-- 15. INDEXES
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_company      ON profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_projects_company      ON projects(company_id);
CREATE INDEX IF NOT EXISTS idx_project_members_proj  ON project_members(project_id);
CREATE INDEX IF NOT EXISTS idx_project_members_user  ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_floor_plans_project   ON floor_plans(project_id);
CREATE INDEX IF NOT EXISTS idx_stands_floor_plan     ON stands(floor_plan_id);
CREATE INDEX IF NOT EXISTS idx_rentals_stand         ON rentals(stand_id);
CREATE INDEX IF NOT EXISTS idx_rental_docs_rental    ON rental_documents(rental_id);
CREATE INDEX IF NOT EXISTS idx_notif_user            ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_to           ON messages(to_user_id);
CREATE INDEX IF NOT EXISTS idx_messages_from         ON messages(from_user_id);
CREATE INDEX IF NOT EXISTS idx_activity_user         ON activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_project      ON activity_log(project_id);

-- ─────────────────────────────────────────────
-- 16. SAMPLE SEED DATA (optional – comment out for production)
-- ─────────────────────────────────────────────
/*
-- Create a test company
INSERT INTO companies (id, name, nif, email, phone, country)
VALUES ('00000000-0000-0000-0000-000000000001', 'Plotting Engage', '5000000001', 'admin@plottingengage.com', '923000001', 'Angola');

-- After creating a user via Supabase Auth UI or signup form,
-- update their profile role to 'master':
-- UPDATE profiles SET role='master', company_id='00000000-0000-0000-0000-000000000001'
-- WHERE email='admin@plottingengage.com';
*/

-- ─────────────────────────────────────────────
-- DONE ✓
-- ─────────────────────────────────────────────
