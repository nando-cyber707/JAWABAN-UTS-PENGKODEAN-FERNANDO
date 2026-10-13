const DEFAULT_ACCOUNTS = [
  { account_id: '1000', account_name: 'Kas' },
  { account_id: '5100', account_name: 'Beban Perlengkapan' },
  { account_id: '5200', account_name: 'Beban Utilitas' },
  { account_id: '5300', account_name: 'Beban Transportasi' }
];

const STORAGE_KEY = 'diponegoro-cash-vouchers-v1';
const state = { accounts: DEFAULT_ACCOUNTS, supabase: null, session: null, online: false, busy: false, connectionError: null };
const elements = {
  userLabel: document.querySelector('#user-label'),
  connectionDot: document.querySelector('#connection-dot'),
  connectionLabel: document.querySelector('#connection-label'),
  voucherForm: document.querySelector('#voucher-form'),
  voucherNumber: document.querySelector('#voucher-number'),
  trxDate: document.querySelector('#trx-date'),
  description: document.querySelector('#description'),
  linesBody: document.querySelector('#lines-body'),
  lineCount: document.querySelector('#line-count'),
  balanceIndicator: document.querySelector('#balance-indicator'),
  balanceSymbol: document.querySelector('#balance-symbol'),
  balanceTitle: document.querySelector('#balance-title'),
  balanceDetail: document.querySelector('#balance-detail'),
  totalDebit: document.querySelector('#total-debit'),
  totalCredit: document.querySelector('#total-credit'),
  difference: document.querySelector('#difference'),
  submitButton: document.querySelector('#submit-voucher'),
  submitLabel: document.querySelector('#submit-label'),
  recentList: document.querySelector('#recent-list'),
  recentCount: document.querySelector('#recent-count'),
  documentNumber: document.querySelector('#document-number'),
  todayLabel: document.querySelector('#today-label'),
  toast: document.querySelector('#feedback-toast')
};

const currency = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 2, maximumFractionDigits: 2 });
const localDate = new Date().toLocaleDateString('sv-SE');
elements.trxDate.value = localDate;
elements.todayLabel.textContent = new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium' }).format(new Date());

function makeVoucherNumber() {
  const stamp = new Date().toISOString().replaceAll('-', '').replaceAll(':', '').slice(0, 13);
  const suffix = Math.random().toString(36).slice(2, 5).toUpperCase();
  return `KK-${stamp}-${suffix}`;
}

function newLine(values = {}) {
  const row = document.createElement('tr');
  row.innerHTML = `
    <td><span class="line-number"></span></td>
    <td><label class="sr-only">Akun</label><select class="account-select" required></select></td>
    <td><label class="sr-only">Keterangan baris</label><input class="line-input memo-input" type="text" maxlength="120" placeholder="Keterangan"></td>
    <td><label class="sr-only">Debit rupiah</label><input class="line-input amount-input debit-input" type="number" min="0" step="0.01" inputmode="decimal" placeholder="0,00"></td>
    <td><label class="sr-only">Kredit rupiah</label><input class="line-input amount-input credit-input" type="number" min="0" step="0.01" inputmode="decimal" placeholder="0,00"></td>
    <td><button class="remove-line" type="button" aria-label="Hapus baris">&times;</button></td>`;
  const select = row.querySelector('.account-select');
  for (const account of state.accounts) {
    const option = document.createElement('option');
    option.value = account.account_id;
    option.textContent = `${account.account_id} - ${account.account_name}`;
    select.append(option);
  }
  if (values.account_id) select.value = values.account_id;
  row.querySelector('.memo-input').value = values.memo ?? '';
  row.querySelector('.debit-input').value = values.debit ?? '';
  row.querySelector('.credit-input').value = values.credit ?? '';
  elements.linesBody.append(row);
  renumberLines();
  recalculate();
  return row;
}

function renumberLines() {
  const rows = [...elements.linesBody.querySelectorAll('tr')];
  rows.forEach((row, index) => {
    row.querySelector('.line-number').textContent = String(index + 1).padStart(2, '0');
    row.querySelector('.remove-line').disabled = rows.length <= 2;
  });
  elements.lineCount.textContent = `${rows.length} baris`;
}

function amountInCents(input) {
  const value = Number(input.value);
  if (!Number.isFinite(value) || value < 0) return 0;
  return Math.round(value * 100);
}

function formatCents(value) {
  return currency.format(value / 100);
}

function readLines() {
  return [...elements.linesBody.querySelectorAll('tr')].map((row, index) => ({
    line_no: index + 1,
    account_id: row.querySelector('.account-select').value,
    memo: row.querySelector('.memo-input').value.trim(),
    debit: amountInCents(row.querySelector('.debit-input')) / 100,
    credit: amountInCents(row.querySelector('.credit-input')) / 100,
    debitCents: amountInCents(row.querySelector('.debit-input')),
    creditCents: amountInCents(row.querySelector('.credit-input'))
  }));
}

function recalculate() {
  const lines = readLines();
  const debit = lines.reduce((sum, line) => sum + line.debitCents, 0);
  const credit = lines.reduce((sum, line) => sum + line.creditCents, 0);
  const difference = Math.abs(debit - credit);
  const linesValid = lines.length >= 2 && lines.every(line =>
    line.account_id && ((line.debitCents > 0 && line.creditCents === 0) || (line.creditCents > 0 && line.debitCents === 0))
  );
  const headerValid = elements.trxDate.value && elements.voucherNumber.value.trim() && elements.description.value.trim();
  const balanced = linesValid && debit > 0 && debit === credit;

  elements.totalDebit.textContent = formatCents(debit);
  elements.totalCredit.textContent = formatCents(credit);
  elements.difference.textContent = formatCents(difference);
  elements.balanceIndicator.classList.toggle('is-balanced', balanced);
  elements.balanceSymbol.textContent = balanced ? '\u2713' : '!';
  elements.balanceTitle.textContent = balanced ? 'Seimbang' : 'Belum seimbang';
  elements.balanceDetail.textContent = balanced ? 'Debit sama dengan kredit' : 'Total debit dan kredit harus sama';
  const sessionReady = !state.online || Boolean(state.session && !state.connectionError);
  elements.submitButton.disabled = !balanced || !headerValid || state.busy || !sessionReady;
  return { lines, debit, credit, balanced };
}

let toastTimer;
function showToast(message, isError = false) {
  elements.toast.textContent = message;
  elements.toast.classList.toggle('error', isError);
  elements.toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { elements.toast.hidden = true; }, 4200);
}

function setConnection(mode, text) {
  elements.connectionDot.classList.toggle('connected', mode === 'connected');
  elements.connectionDot.classList.toggle('offline', mode === 'offline');
  elements.connectionLabel.textContent = text;
}

function storedVouchers() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]'); }
  catch { return []; }
}

function renderRecent(vouchers) {
  elements.recentList.replaceChildren();
  elements.recentCount.textContent = `${vouchers.length} TERSIMPAN`;
  if (!vouchers.length) {
    const empty = document.createElement('p');
    empty.className = 'recent-empty';
    empty.textContent = 'Belum ada voucher.';
    elements.recentList.append(empty);
    return;
  }
  for (const voucher of vouchers.slice(0, 6)) {
    const row = document.createElement('div');
    row.className = 'recent-row';
    const number = document.createElement('span');
    number.className = 'recent-number';
    number.textContent = voucher.voucher_number;
    const description = document.createElement('span');
    description.className = 'recent-description';
    description.textContent = voucher.description;
    const amount = document.createElement('span');
    amount.className = 'recent-amount';
    amount.textContent = formatCents(Math.round(Number(voucher.total_debit || 0) * 100));
    const status = document.createElement('span');
    status.className = 'posted-tag';
    status.textContent = 'POSTED';
    row.append(number, description, amount, status);
    elements.recentList.append(row);
  }
}

function currentPayload() {
  const { lines } = recalculate();
  return {
    p_voucher_number: elements.voucherNumber.value.trim(),
    p_trx_date: elements.trxDate.value,
    p_description: elements.description.value.trim(),
    p_lines: lines.map(({ line_no, account_id, memo, debit, credit }) => ({ line_no, account_id, memo, debit, credit })),
    p_reverses_voucher_id: null
  };
}

async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
}

async function submitLocal(payload, totals) {
  const createdAt = new Date().toISOString();
  const canonical = JSON.stringify({ ...payload, created_by: 'demo-local', created_at: createdAt });
  const voucher = {
    id: crypto.randomUUID(),
    voucher_number: payload.p_voucher_number,
    trx_date: payload.p_trx_date,
    description: payload.p_description,
    created_by: 'demo-local',
    created_at: createdAt,
    status: 'POSTED',
    total_debit: totals.debit / 100,
    hash_checksum: await sha256(canonical)
  };
  const vouchers = [voucher, ...storedVouchers()].slice(0, 20);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(vouchers));
  renderRecent(vouchers);
  return voucher;
}

async function submitOnline(payload) {
  if (!state.session?.user) throw new Error('Masuk ke akun Supabase sebelum memposting voucher.');
  const { data, error } = await state.supabase.rpc('submit_cash_voucher', payload);
  if (error) throw error;
  await loadOnlineVouchers();
  return data;
}

async function loadOnlineVouchers() {
  if (!state.session?.user) return;
  const { data, error } = await state.supabase
    .from('cash_vouchers')
    .select('id,voucher_number,description,created_at,cash_voucher_lines(debit)')
    .order('created_at', { ascending: false })
    .limit(6);
  if (error) throw error;
  renderRecent((data || []).map(voucher => ({
    ...voucher,
    total_debit: (voucher.cash_voucher_lines || []).reduce((sum, line) => sum + Number(line.debit || 0), 0)
  })));
}

function refreshAuthUi() {
  const signedIn = Boolean(state.session?.user);
  elements.userLabel.textContent = signedIn
    ? (state.session.user.is_anonymous ? 'Sesi tugas' : (state.session.user.email || 'Sesi aktif'))
    : (state.online ? 'Menghubungkan sesi' : 'Demo lokal');
  setConnection(
    state.online ? (signedIn && !state.connectionError ? 'connected' : 'offline') : 'demo',
    state.online
      ? (state.connectionError ? 'Sesi anonim gagal' : (signedIn ? 'Supabase terhubung · sesi tanpa password' : 'Membuat sesi tanpa password'))
      : 'Mode demo lokal'
  );
  if (!state.online) renderRecent(storedVouchers());
  else if (!signedIn) renderRecent([]);
}

async function initializeSupabase() {
  const config = window.SUPABASE_CONFIG || {};
  if (!config.url || !config.anonKey) {
    refreshAuthUi();
    return;
  }
  state.online = true;
  setConnection('offline', 'Membuat sesi tanpa password');
  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    state.supabase = createClient(config.url, config.anonKey);
    const { data, error } = await state.supabase.auth.getSession();
    if (error) throw error;
    state.session = data.session;
    if (!state.session) {
      const { data: anonymousData, error: anonymousError } = await state.supabase.auth.signInAnonymously();
      if (anonymousError) throw anonymousError;
      state.session = anonymousData.session;
    }
    state.supabase.auth.onAuthStateChange((_event, session) => {
      state.session = session;
      refreshAuthUi();
      if (session) loadOnlineVouchers().catch(error => showToast(error.message, true));
    });
    refreshAuthUi();
    if (state.session) {
      const { data: accounts, error: accountError } = await state.supabase
        .from('chart_of_accounts')
        .select('account_id,account_name')
        .eq('is_active', true)
        .order('account_id');
      if (accountError) throw accountError;
      if (accounts?.length) state.accounts = accounts;
      for (const row of elements.linesBody.querySelectorAll('tr')) {
        const selected = row.querySelector('.account-select').value;
        row.querySelector('.account-select').replaceChildren();
        for (const account of state.accounts) {
          const option = document.createElement('option');
          option.value = account.account_id;
          option.textContent = `${account.account_id} - ${account.account_name}`;
          row.querySelector('.account-select').append(option);
        }
        if (state.accounts.some(account => account.account_id === selected)) row.querySelector('.account-select').value = selected;
      }
      recalculate();
      await loadOnlineVouchers();
    }
  } catch (error) {
    state.connectionError = error.message;
    refreshAuthUi();
    setConnection('offline', 'Aktifkan anonymous sign-ins di Supabase Auth');
    elements.submitButton.disabled = true;
    showToast(`Sesi tanpa password belum aktif: ${error.message}`, true);
  }
}

document.querySelector('#add-line').addEventListener('click', () => newLine());
elements.linesBody.addEventListener('input', recalculate);
elements.linesBody.addEventListener('change', recalculate);
elements.linesBody.addEventListener('click', event => {
  const button = event.target.closest('.remove-line');
  if (!button || elements.linesBody.rows.length <= 2) return;
  button.closest('tr').remove();
  renumberLines();
  recalculate();
});
for (const input of [elements.trxDate, elements.voucherNumber, elements.description]) {
  input.addEventListener('input', recalculate);
  input.addEventListener('change', recalculate);
}
elements.voucherForm.addEventListener('submit', async event => {
  event.preventDefault();
  const totals = recalculate();
  if (!totals.balanced || elements.submitButton.disabled) return;
  state.busy = true;
  elements.submitButton.disabled = true;
  elements.submitLabel.textContent = 'Memposting...';
  try {
    const payload = currentPayload();
    if (state.online) {
      const id = await submitOnline(payload);
      showToast(`Voucher berhasil diposting ke Supabase. ID: ${id}`);
    } else {
      const voucher = await submitLocal(payload, totals);
      showToast(`Voucher tersimpan dalam mode demo. Hash: ${voucher.hash_checksum.slice(0, 12)}...`);
    }
    elements.description.value = '';
    elements.voucherNumber.value = makeVoucherNumber();
    elements.documentNumber.textContent = elements.voucherNumber.value;
    elements.trxDate.value = new Date().toLocaleDateString('sv-SE');
    elements.linesBody.replaceChildren();
    newLine({ account_id: '5100', memo: 'Beban perlengkapan', debit: '250000' });
    newLine({ account_id: '1000', memo: 'Kas keluar', credit: '250000' });
  } catch (error) {
    showToast(error.message || 'Voucher gagal diposting.', true);
  } finally {
    state.busy = false;
    elements.submitLabel.textContent = 'Posting voucher';
    recalculate();
  }
});

elements.voucherNumber.value = makeVoucherNumber();
elements.documentNumber.textContent = elements.voucherNumber.value;
newLine({ account_id: '5100', memo: 'Beban perlengkapan', debit: '250000' });
newLine({ account_id: '1000', memo: 'Kas keluar', credit: '250000' });
initializeSupabase();
