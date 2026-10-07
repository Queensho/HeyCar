BEGIN;
ALTER TABLE store_orders ALTER COLUMN owner_id DROP NOT NULL;
ALTER TABLE store_orders DROP CONSTRAINT IF EXISTS store_orders_owner_id_fkey;
ALTER TABLE store_orders
  ADD CONSTRAINT store_orders_owner_id_fkey
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE SET NULL;
COMMIT;
