# Prompt NotebookLM: Verifikasi Voucher Kas Keluar

## Sumber yang perlu dimasukkan

1. Teks resmi PSAK 207 (sebelumnya PSAK 2) dan amendemen/penomoran yang berlaku dari Ikatan Akuntan Indonesia.
2. Kebijakan akuntansi entitas untuk kas, setara kas, dan pengeluaran kas.
3. `Kode SQL/soal-3/schema.sql` serta `Kode SQL/soal-3/app.js`.

Gunakan naskah standar resmi atau materi yang berhak diakses. Jangan mengandalkan ringkasan sekunder sebagai satu-satunya dasar kesimpulan.

## Prompt

> Tinjau sumber yang saya masukkan dan evaluasi prototype Voucher Kas Keluar ini. Gunakan hanya klaim yang didukung sumber; sertakan nama sumber dan nomor paragraf/halaman untuk setiap simpulan. Jika bukti tidak tersedia, tulis "tidak dapat diverifikasi dari sumber yang tersedia".
>
> Periksa secara terpisah:
>
> 1. Definisi kas dan setara kas menurut standar yang berlaku, termasuk sifat jangka pendek, likuiditas tinggi, dapat dikonversi menjadi jumlah kas yang diketahui, dan risiko perubahan nilai yang tidak signifikan. Tunjukkan sumber spesifik.
> 2. Apakah setiap pembayaran kas otomatis merupakan beban. Bedakan pembayaran beban, pembelian aset, pembayaran utang, dan transaksi lain menurut substansi ekonominya.
> 3. Apakah pemeriksaan total debit = total kredit membuktikan kepatuhan PSAK. Pisahkan integritas aritmetika jurnal dari ketepatan klasifikasi, pengakuan, pengukuran, dan periode akuntansi.
> 4. Apakah akun kas dikredit untuk pengeluaran kas dan akun lawannya harus ditentukan dari sifat transaksi, bukan dipilih otomatis sebagai beban.
> 5. Ketidakcukupan atau ambiguitas pada prototype yang perlu diperbaiki sebelum penggunaan produksi.
>
> Akhiri dengan tabel: aturan yang diuji, bukti sumber, status (sesuai/tidak sesuai/tidak cukup bukti), dan tindak lanjut. Jangan mengarang isi PSAK atau mengklaim prototype telah diaudit jika sumber tidak mendukungnya. Ini merupakan pemeriksaan pembelajaran, bukan opini audit atau nasihat akuntansi profesional.

## Ringkasan Hasil NotebookLM

**Status:** Belum dijalankan. Sumber PSAK resmi dan hasil NotebookLM belum tersedia di workspace ini; karena itu tidak ada temuan AI yang diklaim sebagai hasil aktual.

### Isian setelah analisis dilakukan

- Nama notebook dan tanggal analisis:
- Sumber resmi yang dimasukkan:
- Kesimpulan definisi kas/setara kas beserta kutipan/paragraf:
- Kesimpulan klasifikasi pengeluaran kas beserta kutipan/paragraf:
- Apakah validasi debit-kredit cukup untuk menyatakan patuh:
- Celah atau revisi prototype yang disarankan:
- Tautan/screenshot bukti NotebookLM:

## Poin pemeriksaan yang diharapkan (bukan hasil AI)

- Keseimbangan debit-kredit menguji asas berpasangan, bukan dengan sendirinya membuktikan kepatuhan PSAK.
- Akun lawan pengeluaran kas bergantung pada substansi transaksi; pengeluaran dapat berupa beban, perolehan aset, pembayaran liabilitas, atau kategori lain.
- Penilaian dan klasifikasi kas/setara kas harus dirujuk ke teks standar resmi dan kebijakan entitas yang berlaku.
