-- Soal 2.1: mutasi stok perpetual dan pencegahan stok negatif.
-- File ini menyertakan struktur tabel yang diberikan pada naskah.

CREATE TABLE IF NOT EXISTS inventory_items (
    item_id VARCHAR(10) PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    stock_qty INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    unit_cost NUMERIC(15, 2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE IF NOT EXISTS inventory_transactions (
    trx_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id VARCHAR(10) NOT NULL
        REFERENCES inventory_items(item_id) ON DELETE RESTRICT,
    trx_type VARCHAR(10) NOT NULL
        CHECK (trx_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT')),
    qty INT NOT NULL CHECK (qty <> 0),
    trx_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION trg_update_stock_and_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock INT;
BEGIN
    -- Lock baris item sampai transaksi selesai untuk mencegah overselling.
    SELECT stock_qty
    INTO v_current_stock
    FROM inventory_items
    WHERE item_id = NEW.item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item dengan ID % tidak ditemukan dalam master persediaan.', NEW.item_id
            USING ERRCODE = '23503';
    END IF;

    IF NEW.trx_type IN ('PURCHASE', 'SALE') AND NEW.qty <= 0 THEN
        RAISE EXCEPTION 'Qty untuk % harus lebih besar dari nol.', NEW.trx_type
            USING ERRCODE = '23514';
    END IF;

    IF NEW.trx_type = 'PURCHASE' THEN
        UPDATE inventory_items
        SET stock_qty = stock_qty + NEW.qty
        WHERE item_id = NEW.item_id;

    ELSIF NEW.trx_type = 'SALE' THEN
        IF v_current_stock < NEW.qty THEN
            RAISE EXCEPTION
                'Transaksi dibatalkan: stok barang % tidak mencukupi. (Sisa stok: %, permintaan: %)',
                NEW.item_id, v_current_stock, NEW.qty
                USING ERRCODE = '23514';
        END IF;

        UPDATE inventory_items
        SET stock_qty = stock_qty - NEW.qty
        WHERE item_id = NEW.item_id;

    ELSIF NEW.trx_type = 'ADJUSTMENT' THEN
        IF v_current_stock + NEW.qty < 0 THEN
            RAISE EXCEPTION
                'Transaksi dibatalkan: penyesuaian stok mengakibatkan nilai minus untuk item %.',
                NEW.item_id
                USING ERRCODE = '23514';
        END IF;

        UPDATE inventory_items
        SET stock_qty = stock_qty + NEW.qty
        WHERE item_id = NEW.item_id;
    ELSE
        RAISE EXCEPTION 'Jenis transaksi % tidak didukung.', NEW.trx_type
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_stock_and_journal ON inventory_transactions;
CREATE TRIGGER trigger_update_stock_and_journal
BEFORE INSERT ON inventory_transactions
FOR EACH ROW
EXECUTE FUNCTION trg_update_stock_and_journal();

-- Catatan: tabel jurnal dan mapping akun tidak disediakan dalam Soal 2.
-- Karena itu, trigger ini memperbarui kuantitas stok saja; pencatatan nominal
-- pembelian/HPP memerlukan aturan akun, harga jual, dan tabel jurnal yang jelas.
