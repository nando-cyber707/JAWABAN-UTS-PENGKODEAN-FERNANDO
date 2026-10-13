# Prompt Gemini Canvas: Voucher Kas Keluar

## Prompt

> Buat purwarupa web satu halaman untuk modul akuntansi "Voucher Kas Keluar" berbahasa Indonesia. Gunakan HTML, CSS, dan JavaScript yang dapat berjalan mandiri di browser. Antarmuka ditujukan untuk staf akuntansi yang berulang kali mencatat transaksi, bukan halaman promosi.
>
> Tampilkan nomor voucher, tanggal transaksi, deskripsi, serta tabel baris jurnal dengan akun, keterangan, debit, dan kredit. Sediakan kontrol tambah/hapus baris dengan minimal dua baris. Hitung total debit dan kredit secara langsung saat pengguna mengubah nilai. Tampilkan indikator seimbang dan nilai selisih. Tombol Posting harus nonaktif jika tanggal/deskripsi/nomor belum terisi, baris tidak valid, total nol, atau total debit tidak sama dengan total kredit. Gunakan pembulatan dua desimal secara konsisten.
>
> Buat tampilan responsif desktop dan ponsel, label input yang dapat diakses, fokus keyboard yang terlihat, pesan status yang dibaca screen reader, serta konfirmasi kesalahan yang tidak menghapus input. Gunakan gaya operasional yang rapi dan padat, bukan landing page. Jangan menaruh credential atau service-role key di frontend.
>
> Pisahkan komponen antarmuka, stylesheet, dan logika JavaScript. Berikan kode lengkap, petunjuk menjalankan lokal, dan daftar uji manual: jurnal seimbang, jurnal tidak seimbang, baris kosong, tambah/hapus baris, serta ukuran layar ponsel.

## Hubungan dengan Artefak

Implementasi prototype pada `Kode SQL/soal-3/index.html`, `style.css`, dan `app.js` memenuhi spesifikasi di atas. Berkas ini mendokumentasikan prompt instruksi; tidak menyatakan bahwa Gemini Canvas telah mengeksekusi atau menghasilkan kode tersebut.
