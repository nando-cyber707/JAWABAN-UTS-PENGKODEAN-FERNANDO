-- Soal 3.2: voucher kas keluar, audit trail, hash, dan immutability.
-- Target: Supabase PostgreSQL. Jalankan sebagai migration/admin role.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS chart_of_accounts (
    account_id TEXT PRIMARY KEY,
    account_name TEXT NOT NULL,
    normal_balance TEXT NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    report_classification TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Kompatibel dengan chart_of_accounts soal 1 jika tabel tersebut sudah ada.
ALTER TABLE chart_of_accounts
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS cash_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_number TEXT NOT NULL UNIQUE,
    trx_date DATE NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'POSTED')),
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    posted_at TIMESTAMPTZ,
    hash_checksum TEXT,
    reverses_voucher_id UUID UNIQUE REFERENCES cash_vouchers(id) ON DELETE RESTRICT,
    CONSTRAINT chk_posted_voucher_metadata CHECK (
        status <> 'POSTED' OR (posted_at IS NOT NULL AND hash_checksum IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS cash_voucher_lines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    voucher_id UUID NOT NULL REFERENCES cash_vouchers(id) ON DELETE RESTRICT,
    line_no INT NOT NULL CHECK (line_no > 0),
    account_id TEXT NOT NULL REFERENCES chart_of_accounts(account_id) ON DELETE RESTRICT,
    memo TEXT NOT NULL DEFAULT '',
    debit NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    CONSTRAINT uq_cash_voucher_line_no UNIQUE (voucher_id, line_no),
    CONSTRAINT chk_cash_voucher_one_sided CHECK (
        (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)
    )
);

CREATE TABLE IF NOT EXISTS cash_voucher_audit (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_name TEXT NOT NULL,
    entity_id UUID NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    actor_user_id UUID,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    snapshot JSONB NOT NULL,
    hash_checksum TEXT
);

CREATE INDEX IF NOT EXISTS idx_cash_vouchers_created_by ON cash_vouchers(created_by);
CREATE INDEX IF NOT EXISTS idx_cash_voucher_lines_voucher_id ON cash_voucher_lines(voucher_id);
CREATE INDEX IF NOT EXISTS idx_cash_voucher_audit_entity ON cash_voucher_audit(entity_name, entity_id, occurred_at);

CREATE OR REPLACE FUNCTION guard_posted_cash_voucher()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        RAISE EXCEPTION 'Voucher % sudah POSTED; koreksi harus menggunakan reversing entry.', OLD.voucher_number
            USING ERRCODE = '55000';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_posted_cash_voucher ON cash_vouchers;
CREATE TRIGGER trg_guard_posted_cash_voucher
BEFORE UPDATE OR DELETE ON cash_vouchers
FOR EACH ROW
EXECUTE FUNCTION guard_posted_cash_voucher();

CREATE OR REPLACE FUNCTION guard_cash_voucher_line()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_voucher_id UUID;
    v_status TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_voucher_id := OLD.voucher_id;
    ELSE
        v_voucher_id := NEW.voucher_id;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.voucher_id <> NEW.voucher_id THEN
        RAISE EXCEPTION 'Baris tidak dapat dipindahkan ke voucher lain.' USING ERRCODE = '55000';
    END IF;

    SELECT status INTO v_status
    FROM cash_vouchers
    WHERE id = v_voucher_id
    FOR UPDATE;

    IF v_status IS DISTINCT FROM 'DRAFT' THEN
        RAISE EXCEPTION 'Baris voucher hanya dapat diubah saat status DRAFT.'
            USING ERRCODE = '55000';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_cash_voucher_line ON cash_voucher_lines;
CREATE TRIGGER trg_guard_cash_voucher_line
BEFORE INSERT OR UPDATE OR DELETE ON cash_voucher_lines
FOR EACH ROW
EXECUTE FUNCTION guard_cash_voucher_line();

CREATE OR REPLACE FUNCTION post_cash_voucher_and_hash()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_line_count BIGINT;
    v_total_debit NUMERIC(15, 2);
    v_total_credit NUMERIC(15, 2);
    v_lines JSONB;
    v_payload JSONB;
BEGIN
    IF NEW.status = 'POSTED' AND OLD.status = 'DRAFT' THEN
        SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0),
               COALESCE(jsonb_agg(
                   jsonb_build_object(
                       'line_no', line_no,
                       'account_id', account_id,
                       'memo', memo,
                       'debit', debit,
                       'credit', credit
                   ) ORDER BY line_no
               ), '[]'::JSONB)
        INTO v_line_count, v_total_debit, v_total_credit, v_lines
        FROM cash_voucher_lines
        WHERE voucher_id = NEW.id;

        IF v_line_count < 2 OR v_total_debit <= 0 OR v_total_debit <> v_total_credit THEN
            RAISE EXCEPTION 'Voucher % tidak seimbang: debit %, kredit %, baris %.',
                NEW.voucher_number, v_total_debit, v_total_credit, v_line_count
                USING ERRCODE = '23514';
        END IF;

        NEW.posted_at := clock_timestamp();
        v_payload := jsonb_build_object(
            'id', NEW.id,
            'voucher_number', NEW.voucher_number,
            'trx_date', NEW.trx_date,
            'description', NEW.description,
            'created_by', NEW.created_by,
            'created_at', NEW.created_at,
            'reverses_voucher_id', NEW.reverses_voucher_id,
            'lines', v_lines
        );
        NEW.hash_checksum := encode(
            digest(convert_to(v_payload::TEXT, 'UTF8'), 'sha256'),
            'hex'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_cash_voucher_and_hash ON cash_vouchers;
CREATE TRIGGER trg_post_cash_voucher_and_hash
BEFORE UPDATE OF status ON cash_vouchers
FOR EACH ROW
EXECUTE FUNCTION post_cash_voucher_and_hash();

CREATE OR REPLACE FUNCTION write_cash_voucher_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_row JSONB;
    v_entity_id UUID;
    v_actor UUID;
    v_checksum TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_row := to_jsonb(OLD);
        v_entity_id := OLD.id;
        v_actor := OLD.created_by;
        v_checksum := OLD.hash_checksum;
    ELSE
        v_row := to_jsonb(NEW);
        v_entity_id := NEW.id;
        v_actor := NEW.created_by;
        v_checksum := NEW.hash_checksum;
    END IF;

    INSERT INTO cash_voucher_audit (entity_name, entity_id, action, actor_user_id, snapshot, hash_checksum)
    VALUES ('cash_vouchers', v_entity_id, TG_OP, COALESCE(auth.uid(), v_actor), v_row, v_checksum);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_write_cash_voucher_audit ON cash_vouchers;
CREATE TRIGGER trg_write_cash_voucher_audit
AFTER INSERT OR UPDATE OR DELETE ON cash_vouchers
FOR EACH ROW
EXECUTE FUNCTION write_cash_voucher_audit();

CREATE OR REPLACE FUNCTION reject_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Audit log bersifat append-only.' USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS trg_reject_audit_mutation ON cash_voucher_audit;
CREATE TRIGGER trg_reject_audit_mutation
BEFORE UPDATE OR DELETE ON cash_voucher_audit
FOR EACH ROW
EXECUTE FUNCTION reject_audit_mutation();

CREATE OR REPLACE FUNCTION submit_cash_voucher(
    p_voucher_number TEXT,
    p_trx_date DATE,
    p_description TEXT,
    p_lines JSONB,
    p_reverses_voucher_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_actor UUID := auth.uid();
    v_voucher_id UUID;
    v_original_id UUID;
BEGIN
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Autentikasi diperlukan untuk memposting voucher.' USING ERRCODE = '28000';
    END IF;
    IF jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) < 2 THEN
        RAISE EXCEPTION 'Voucher harus memiliki minimal dua baris.' USING ERRCODE = '23514';
    END IF;

    INSERT INTO cash_vouchers (voucher_number, trx_date, description, created_by, reverses_voucher_id)
    VALUES (p_voucher_number, p_trx_date, p_description, v_actor, p_reverses_voucher_id)
    RETURNING id INTO v_voucher_id;

    INSERT INTO cash_voucher_lines (voucher_id, line_no, account_id, memo, debit, credit)
    SELECT v_voucher_id, input.line_no, input.account_id, COALESCE(input.memo, ''),
           COALESCE(input.debit, 0), COALESCE(input.credit, 0)
    FROM jsonb_to_recordset(p_lines) AS input(
        line_no INT,
        account_id TEXT,
        memo TEXT,
        debit NUMERIC(15, 2),
        credit NUMERIC(15, 2)
    );

    IF p_reverses_voucher_id IS NOT NULL THEN
        SELECT id INTO v_original_id
        FROM cash_vouchers
        WHERE id = p_reverses_voucher_id AND status = 'POSTED'
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Voucher asal tidak ditemukan atau belum POSTED.' USING ERRCODE = '23514';
        END IF;

        IF EXISTS (
            SELECT 1 FROM (
                SELECT line_no, account_id, memo, debit, credit
                FROM cash_voucher_lines WHERE voucher_id = v_original_id
                EXCEPT
                SELECT line_no, account_id, memo, credit, debit
                FROM cash_voucher_lines WHERE voucher_id = v_voucher_id
            ) AS missing_reverse_lines
        ) OR EXISTS (
            SELECT 1 FROM (
                SELECT line_no, account_id, memo, credit, debit
                FROM cash_voucher_lines WHERE voucher_id = v_voucher_id
                EXCEPT
                SELECT line_no, account_id, memo, debit, credit
                FROM cash_voucher_lines WHERE voucher_id = v_original_id
            ) AS unexpected_reverse_lines
        ) THEN
            RAISE EXCEPTION 'Baris reversing entry harus membalik akun dan nilai voucher asal.'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    UPDATE cash_vouchers
    SET status = 'POSTED'
    WHERE id = v_voucher_id;

    RETURN v_voucher_id;
END;
$$;

ALTER TABLE cash_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_voucher_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_voucher_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coa_read_authenticated ON chart_of_accounts;
CREATE POLICY coa_read_authenticated ON chart_of_accounts
FOR SELECT TO authenticated USING (is_active);

DROP POLICY IF EXISTS vouchers_read_own ON cash_vouchers;
CREATE POLICY vouchers_read_own ON cash_vouchers
FOR SELECT TO authenticated USING (created_by = auth.uid());

DROP POLICY IF EXISTS voucher_lines_read_own ON cash_voucher_lines;
CREATE POLICY voucher_lines_read_own ON cash_voucher_lines
FOR SELECT TO authenticated USING (
    EXISTS (
        SELECT 1 FROM cash_vouchers
        WHERE cash_vouchers.id = cash_voucher_lines.voucher_id
          AND cash_vouchers.created_by = auth.uid()
    )
);

DROP POLICY IF EXISTS voucher_audit_read_own ON cash_voucher_audit;
CREATE POLICY voucher_audit_read_own ON cash_voucher_audit
FOR SELECT TO authenticated USING (actor_user_id = auth.uid());

REVOKE INSERT, UPDATE, DELETE ON cash_vouchers, cash_voucher_lines, cash_voucher_audit FROM anon, authenticated;
REVOKE ALL ON FUNCTION submit_cash_voucher(TEXT, DATE, TEXT, JSONB, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION submit_cash_voucher(TEXT, DATE, TEXT, JSONB, UUID) TO authenticated;

INSERT INTO chart_of_accounts (account_id, account_name, normal_balance, report_classification)
VALUES
    ('1000', 'Kas', 'DEBIT', 'ASSET'),
    ('5100', 'Beban Perlengkapan', 'DEBIT', 'EXPENSE'),
    ('5200', 'Beban Utilitas', 'DEBIT', 'EXPENSE'),
    ('5300', 'Beban Transportasi', 'DEBIT', 'EXPENSE')
ON CONFLICT (account_id) DO NOTHING;
