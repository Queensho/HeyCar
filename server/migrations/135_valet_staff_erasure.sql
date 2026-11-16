BEGIN;
-- Preserve operational records while allowing erasure of a staff identity.
ALTER TABLE valet_guest_invites ALTER COLUMN issued_by_staff_id DROP NOT NULL;
ALTER TABLE valet_guest_invites DROP CONSTRAINT IF EXISTS valet_guest_invites_issued_by_staff_id_fkey;
ALTER TABLE valet_guest_invites ADD CONSTRAINT valet_guest_invites_issued_by_staff_id_fkey
 FOREIGN KEY (issued_by_staff_id) REFERENCES valet_staff(id) ON DELETE SET NULL;
ALTER TABLE valet_shift_history ALTER COLUMN staff_id DROP NOT NULL;
ALTER TABLE valet_shift_history DROP CONSTRAINT IF EXISTS valet_shift_history_staff_id_fkey;
ALTER TABLE valet_shift_history ADD CONSTRAINT valet_shift_history_staff_id_fkey
 FOREIGN KEY (staff_id) REFERENCES valet_staff(id) ON DELETE SET NULL;
ALTER TABLE valet_offline_ops ALTER COLUMN staff_id DROP NOT NULL;
ALTER TABLE valet_offline_ops DROP CONSTRAINT IF EXISTS valet_offline_ops_staff_id_fkey;
ALTER TABLE valet_offline_ops ADD CONSTRAINT valet_offline_ops_staff_id_fkey
 FOREIGN KEY (staff_id) REFERENCES valet_staff(id) ON DELETE SET NULL;
COMMIT;
