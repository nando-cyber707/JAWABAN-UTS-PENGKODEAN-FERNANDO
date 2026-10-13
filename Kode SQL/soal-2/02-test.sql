-- Soal 2: smoke test stok dan anti-negative inventory.
-- Jalankan setelah 01-trigger.sql pada database uji.
-- Semua perubahan dibatalkan pada akhir skrip.

BEGIN;

INSERT INTO inventory_items (item_id, item_name, stock_qty, unit_cost)
VALUES ('UTS-ITEM-1', 'Item uji UTS', 1, 100.00)
ON CONFLICT (item_id) DO UPDATE
SET stock_qty = EXCLUDED.stock_qty,
    unit_cost = EXCLUDED.unit_cost;

DO $$
DECLARE
    v_stock INT;
BEGIN
    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES ('UTS-ITEM-1', 'SALE', 1);

    SELECT stock_qty INTO v_stock
    FROM inventory_items
    WHERE item_id = 'UTS-ITEM-1';
    IF v_stock <> 0 THEN
        RAISE EXCEPTION 'Uji gagal: penjualan seharusnya menyisakan stok 0, aktual %.', v_stock;
    END IF;

    BEGIN
        INSERT INTO inventory_transactions (item_id, trx_type, qty)
        VALUES ('UTS-ITEM-1', 'SALE', 1);
        RAISE EXCEPTION 'Uji gagal: penjualan melebihi stok berhasil.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Lulus: penjualan melebihi stok ditolak.';
    END;

    SELECT stock_qty INTO v_stock
    FROM inventory_items
    WHERE item_id = 'UTS-ITEM-1';
    IF v_stock <> 0 THEN
        RAISE EXCEPTION 'Uji gagal: stok berubah setelah penjualan ditolak.';
    END IF;

    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES ('UTS-ITEM-1', 'PURCHASE', 3);
    INSERT INTO inventory_transactions (item_id, trx_type, qty)
    VALUES ('UTS-ITEM-1', 'ADJUSTMENT', -1);

    SELECT stock_qty INTO v_stock
    FROM inventory_items
    WHERE item_id = 'UTS-ITEM-1';
    IF v_stock <> 2 THEN
        RAISE EXCEPTION 'Uji gagal: stok akhir seharusnya 2, aktual %.', v_stock;
    END IF;

    RAISE NOTICE 'Lulus: purchase dan adjustment menghasilkan stok akhir %.', v_stock;
END;
$$;

ROLLBACK;

-- Uji konkurensi manual pada dua sesi PostgreSQL, dengan item ber-stok 1:
-- Sesi A: BEGIN; INSERT INTO inventory_transactions(item_id, trx_type, qty)
--         VALUES ('SKU-1', 'SALE', 1); -- trigger mengunci baris inventory_items
-- Sesi B: BEGIN; INSERT INTO inventory_transactions(item_id, trx_type, qty)
--         VALUES ('SKU-1', 'SALE', 1); -- menunggu kunci sesi A
-- Sesi A: COMMIT;
-- Sesi B: INSERT gagal karena setelah menunggu stok terbaru adalah 0; ROLLBACK.
