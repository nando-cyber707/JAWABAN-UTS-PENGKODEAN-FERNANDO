-- Soal 1.1-1.2: skema inti General Ledger PostgreSQL
-- Jalankan sekali pada database/schema kosong sebelum 02-double-entry.sql.

CREATE TABLE chart_of_accounts (
    account_id VARCHAR(20) PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    normal_balance VARCHAR(6) NOT NULL
        CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    report_classification VARCHAR(50) NOT NULL
);

CREATE TABLE journal_headers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trx_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ref_number VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    posting_status VARCHAR(10) NOT NULL DEFAULT 'DRAFT'
        CHECK (posting_status IN ('DRAFT', 'POSTED'))
);

CREATE TABLE journal_lines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    header_id BIGINT NOT NULL
        REFERENCES journal_headers(id) ON DELETE RESTRICT,
    account_id VARCHAR(20) NOT NULL
        REFERENCES chart_of_accounts(account_id) ON DELETE RESTRICT,
    debit NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (debit >= 0),
    credit NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (credit >= 0),
    CONSTRAINT chk_journal_line_one_sided CHECK (
        (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)
    )
);

CREATE INDEX idx_journal_lines_header_id ON journal_lines(header_id);
CREATE INDEX idx_journal_lines_account_id ON journal_lines(account_id);

-- ERD ringkas:
-- chart_of_accounts (1) ---- (N) journal_lines (N) ---- (1) journal_headers
