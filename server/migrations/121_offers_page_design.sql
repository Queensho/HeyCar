CREATE TABLE IF NOT EXISTS offers_page_design (
 id integer PRIMARY KEY DEFAULT 1 CHECK (id=1),
 published jsonb NOT NULL DEFAULT '{}'::jsonb,
 draft jsonb NOT NULL DEFAULT '{}'::jsonb,
 updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO offers_page_design(id,published,draft) VALUES(1,'{}','{}') ON CONFLICT(id) DO NOTHING;
GRANT SELECT, INSERT, UPDATE ON TABLE public.offers_page_design TO heycar_user;
