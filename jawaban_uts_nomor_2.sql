-- 1. Membuat Trigger Function
CREATE OR REPLACE FUNCTION trg_update_stock_and_journal()
RETURNS TRIGGER AS $$
DECLARE
    v_current_stock INT;
BEGIN
    -- Ambil stok fisik saat ini dari tabel inventory_items
    SELECT stock_qty INTO v_current_stock
    FROM inventory_items
    WHERE item_id = NEW.item_id;

    -- Jika barang tidak ditemukan di tabel master
    IF v_current_stock IS NULL THEN
        RAISE EXCEPTION 'Item dengan ID % tidak ditemukan dalam master persediaan.', NEW.item_id;
    END IF;

    -- a & b. Logika Pembaruan Stok dan Pencegahan Negative Inventory
    IF NEW.trx_type = 'PURCHASE' THEN
        -- Penambahan stok akibat Pembelian
        UPDATE inventory_items
        SET stock_qty = stock_qty + NEW.qty
        WHERE item_id = NEW.item_id;

    ELSIF NEW.trx_type = 'SALE' THEN
        -- Anti-Negative Inventory Prevention: Cek apakah stok mencukupi
        IF v_current_stock < NEW.qty THEN
            RAISE EXCEPTION 'Transaksi dibatalkan: Stok barang % tidak mencukupi. (Sisa Stok: %, Permintaan: %)',
                NEW.item_id, v_current_stock, NEW.qty;
        END IF;

        -- Pengurangan stok akibat Penjualan
        UPDATE inventory_items
        SET stock_qty = stock_qty - NEW.qty
        WHERE item_id = NEW.item_id;

    ELSIF NEW.trx_type = 'ADJUSTMENT' THEN
        -- Penyesuaian stok langsung (Stock Opname)
        -- Jika NEW.qty berupa penyesuaian mutlak atau perubahan selisih
        IF NEW.qty < 0 AND (v_current_stock + NEW.qty) < 0 THEN
            RAISE EXCEPTION 'Transaksi dibatalkan: Penyesuaian stok mengakibatkan nilai minus.';
        END IF;

        UPDATE inventory_items
        SET stock_qty = stock_qty + NEW.qty
        WHERE item_id = NEW.item_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Membuat Trigger yang Menjalankan Function Setiap Ada INSERT
CREATE TRIGGER trigger_update_stock_and_journal
BEFORE INSERT ON inventory_transactions
FOR EACH ROW
EXECUTE FUNCTION trg_update_stock_and_journal();
