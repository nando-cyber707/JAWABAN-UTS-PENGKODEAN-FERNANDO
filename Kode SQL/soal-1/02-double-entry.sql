-- Soal 1.2: integritas double-entry dan perlindungan jurnal POSTED.
-- Jalankan setelah 01-schema.sql.

CREATE OR REPLACE FUNCTION guard_journal_header()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.posting_status = 'POSTED' THEN
        RAISE EXCEPTION 'Header jurnal % sudah POSTED dan tidak boleh diubah atau dihapus.', OLD.id
            USING ERRCODE = '55000';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guard_journal_header
BEFORE UPDATE OR DELETE ON journal_headers
FOR EACH ROW
EXECUTE FUNCTION guard_journal_header();

CREATE OR REPLACE FUNCTION guard_journal_line()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_header_ids BIGINT[];
    v_header RECORD;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_header_ids := ARRAY[NEW.header_id];
    ELSIF TG_OP = 'DELETE' THEN
        v_header_ids := ARRAY[OLD.header_id];
    ELSE
        v_header_ids := ARRAY[OLD.header_id, NEW.header_id];
    END IF;

    -- Kunci header dalam urutan konsisten agar posting dan perubahan baris terserialisasi.
    FOR v_header IN
        SELECT id, posting_status
        FROM journal_headers
        WHERE id = ANY (v_header_ids)
        ORDER BY id
        FOR UPDATE
    LOOP
        IF v_header.posting_status = 'POSTED' THEN
            RAISE EXCEPTION 'Baris jurnal pada header % yang sudah POSTED tidak dapat diubah.', v_header.id
                USING ERRCODE = '55000';
        END IF;
    END LOOP;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guard_journal_line
BEFORE INSERT OR UPDATE OR DELETE ON journal_lines
FOR EACH ROW
EXECUTE FUNCTION guard_journal_line();

CREATE OR REPLACE FUNCTION assert_header_balanced_before_posting()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_line_count BIGINT;
    v_total_debit NUMERIC(15, 2);
    v_total_credit NUMERIC(15, 2);
BEGIN
    IF NEW.posting_status = 'POSTED' AND OLD.posting_status <> 'POSTED' THEN
        SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO v_line_count, v_total_debit, v_total_credit
        FROM journal_lines
        WHERE header_id = NEW.id;

        IF v_line_count < 2 OR v_total_debit <= 0 OR v_total_debit <> v_total_credit THEN
            RAISE EXCEPTION
                'Jurnal % tidak seimbang: baris %, debit %, kredit %.',
                NEW.id, v_line_count, v_total_debit, v_total_credit
                USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_assert_header_balanced_before_posting
AFTER UPDATE OF posting_status ON journal_headers
FOR EACH ROW
EXECUTE FUNCTION assert_header_balanced_before_posting();

CREATE OR REPLACE FUNCTION assert_posted_journal_lines_balanced()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_header_ids BIGINT[];
    v_header_id BIGINT;
    v_status VARCHAR(10);
    v_line_count BIGINT;
    v_total_debit NUMERIC(15, 2);
    v_total_credit NUMERIC(15, 2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_header_ids := ARRAY[NEW.header_id];
    ELSIF TG_OP = 'DELETE' THEN
        v_header_ids := ARRAY[OLD.header_id];
    ELSE
        v_header_ids := ARRAY[OLD.header_id, NEW.header_id];
    END IF;

    FOR v_header_id IN
        SELECT DISTINCT ids.header_id
        FROM unnest(v_header_ids) AS ids(header_id)
    LOOP
        SELECT posting_status INTO v_status
        FROM journal_headers
        WHERE id = v_header_id;

        IF v_status = 'POSTED' THEN
            SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
            INTO v_line_count, v_total_debit, v_total_credit
            FROM journal_lines
            WHERE header_id = v_header_id;

            IF v_line_count < 2 OR v_total_debit <= 0 OR v_total_debit <> v_total_credit THEN
                RAISE EXCEPTION
                    'Jurnal POSTED % tidak seimbang: baris %, debit %, kredit %.',
                    v_header_id, v_line_count, v_total_debit, v_total_credit
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_assert_posted_journal_lines_balanced
AFTER INSERT OR UPDATE OR DELETE ON journal_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION assert_posted_journal_lines_balanced();
