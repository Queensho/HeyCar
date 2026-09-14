GRANT USAGE ON SCHEMA public TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.users TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicles TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.qr_tags TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_public_themes TO heycar_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO heycar_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO heycar_user;
