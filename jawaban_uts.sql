-- 1. Tabel Chart of Accounts (Bagan Akun)
CREATE TABLE chart_of_accounts (
    account_id VARCHAR(20) PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    normal_balance VARCHAR(6) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    report_classification VARCHAR(50) NOT NULL
);

-- 2. Tabel Journal Headers (Header Transaksi Jurnal)
CREATE TABLE journal_headers (
    id SERIAL PRIMARY KEY,
    trx_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ref_number VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    posting_status VARCHAR(10) NOT NULL DEFAULT 'DRAFT' CHECK (posting_status IN ('DRAFT', 'POSTED'))
);

-- 3. Tabel Journal Lines (Detail Baris Jurnal)
CREATE TABLE journal_lines (
    id SERIAL PRIMARY KEY,
    header_id INT NOT NULL REFERENCES journal_headers(id) ON DELETE RESTRICT,
    account_id VARCHAR(20) NOT NULL REFERENCES chart_of_accounts(account_id) ON DELETE RESTRICT,
    debit NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (debit >= 0),
    credit NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (credit >= 0),
    
    -- CHECK constraint: debit dan credit tidak boleh sama-sama 0
    CONSTRAINT chk_debit_credit_not_both_zero CHECK (
        (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0) OR (debit > 0 AND credit > 0)
    )
);

-- Indeks Tambahan untuk Mengoptimalkan Performa Query Join & Audit
CREATE INDEX idx_journal_lines_header_id ON journal_lines(header_id);
CREATE INDEX idx_journal_lines_account_id ON journal_lines(account_id);
