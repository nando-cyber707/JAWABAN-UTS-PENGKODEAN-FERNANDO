-- Soal 1: smoke test untuk jurnal seimbang dan penolakan jurnal tidak seimbang.
-- Jalankan setelah 01-schema.sql dan 02-double-entry.sql pada database uji.

INSERT INTO chart_of_accounts (account_id, account_name, normal_balance, report_classification)
VALUES
    ('UTS-CASH', 'Kas - akun uji UTS', 'DEBIT', 'ASSET'),
    ('UTS-EXP', 'Beban - akun uji UTS', 'DEBIT', 'EXPENSE')
ON CONFLICT (account_id) DO NOTHING;

DO $$
DECLARE
    v_good_header BIGINT;
    v_bad_header BIGINT;
BEGIN
    INSERT INTO journal_headers (ref_number, description)
    VALUES ('UTS-GOOD-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS'), 'Uji jurnal seimbang')
    RETURNING id INTO v_good_header;

    INSERT INTO journal_lines (header_id, account_id, debit, credit)
    VALUES
        (v_good_header, 'UTS-EXP', 125.00, 0.00),
        (v_good_header, 'UTS-CASH', 0.00, 125.00);

    UPDATE journal_headers
    SET posting_status = 'POSTED'
    WHERE id = v_good_header;

    INSERT INTO journal_headers (ref_number, description)
    VALUES ('UTS-BAD-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS'), 'Uji jurnal tidak seimbang')
    RETURNING id INTO v_bad_header;

    INSERT INTO journal_lines (header_id, account_id, debit, credit)
    VALUES (v_bad_header, 'UTS-EXP', 125.00, 0.00);

    BEGIN
        UPDATE journal_headers
        SET posting_status = 'POSTED'
        WHERE id = v_bad_header;
        RAISE EXCEPTION 'Uji gagal: jurnal tidak seimbang berhasil diposting.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Lulus: jurnal tidak seimbang ditolak saat posting.';
    END;

    DELETE FROM journal_lines WHERE header_id = v_bad_header;
    DELETE FROM journal_headers WHERE id = v_bad_header;
    RAISE NOTICE 'Lulus: jurnal seimbang % berhasil diposting.', v_good_header;
END;
$$;
