# Rencana Hari 2 — Numisma
**Selasa, 20 Oktober 2026**
Acuan: `NUMISMA_GUIDE_0.3.md` (Bagian 4.3, 7.2–7.6, 7.11, 8, 9).

**Target:** aplikasi utuh dan berguna offline.
**Selesai bila:** login, tambah, ubah, hapus, dan cari koin berjalan di HP asli tanpa internet.

**Aturan tetap:** tidak ada `git add`, `commit`, atau `push`. State management hanya `setState`. Satu file per fitur, komentar bahasa Indonesia, nama tabel dan tanda tangan fungsi mengikuti kontrak.

---

## Persiapan (tanpa mengubah logika)

- [ ] Baca struktur `lib/` yang ada sekarang.
- [ ] Cek `AndroidManifest.xml`: izin `INTERNET`, `USE_BIOMETRIC`, `CAMERA`, `POST_NOTIFICATIONS`, lokasi. Commit `01cf292` sudah menyebut izin Android, jadi kemungkinan hanya memastikan.
- [ ] Cek `MainActivity` sudah `FlutterFragmentActivity` (syarat `local_auth`).
- [ ] Pasang paket: `flutter pub add local_auth image_picker`.

---

## Langkah kerja

### 1. Bottom nav 5 ikon + grid Beranda
- **File:** `screens/home/home_shell.dart`
- Beranda, Profil, **Scan** (tengah, bulat, menonjol), Saran, Keluar.
- Dibuat dengan `Stack` berisi `Row` 4 ikon dan satu `Positioned` tombol Scan, bukan `BottomNavigationBar` bawaan.
- Grid Beranda (`GridView`, 3 atau 4 kolom): Koleksi, Konversi, Jelajah, Jejak Catatan, Tanya Numisma, Game, Sinkron. Halaman yang belum ada dibuat placeholder.
- **Tes di HP:** semua ikon bisa ditekan dan tidak crash.

### 2. Logout
- **File:** `home_shell.dart`
- Ikon Keluar membuka dialog konfirmasi. Tab aktif tidak berubah. Jika setuju: hapus session lalu ke Login.
- **Tes di HP:** logout lalu buka ulang aplikasi, harus muncul Login.

### 3. Model dan repo koin + AES `notes_enc`
- **File:** `models/coin.dart`, `services/coin_repo.dart`, `core/crypto_util.dart`
- Fungsi sesuai Bagian 8: `insert`, `update`, `delete`, `list`, `getById`.
- `insert` menerima `photoBytes` dan `photoSource` sejak sekarang (pembuatan blok rantai baru di Hari 4).
- Catatan (`notes`) dienkripsi AES sebelum disimpan, didekripsi saat dibaca.
- **Tes:** dicek lewat langkah 4. Isi `notes_enc` di SQLite harus berupa ciphertext.

### 4. Koleksi: daftar, form, detail
- **File:** `collection_screen.dart`, `coin_form_screen.dart`, `coin_detail_screen.dart`
- Tombol **Tambah** membuka form manual. Foto opsional (kamera atau galeri, `maxWidth: 1024`, `imageQuality: 85`), tidak dikirim ke Gemini.
- Edit memakai form yang sama. Hapus lewat detail.
- Hari ini detail belum punya sensor (Hari 3).
- **Tes (T08):** tambah, ubah, hapus koin. Data bertahan setelah aplikasi ditutup.

### 5. Cari, filter, urut, multi-pilih (K11)
- **File:** `coin_repo.dart`, `collection_screen.dart`
- Cari dengan `LIKE` pada negara, nominal, tahun. Tidak mencakup `notes_enc`.
- Filter: jenis, kondisi, rentang tahun. Urut: tahun, nominal, terbaru.
- Tekan lama masuk mode multi-pilih. AppBar menampilkan jumlah terpilih dan tombol hapus. Slot total nilai disiapkan, isinya baru di Hari 3.
- **Tes (T09):** cari "Japan", coba filter, multi-pilih.

### 6. Profil
- **File:** `screens/profile/profile_screen.dart`
- Foto profil (kamera atau galeri) disalin ke folder aplikasi, path masuk ke `users.photo_path`.
- Tampilkan username, email (didekripsi), switch biometrik.
- **Tes:** foto tampil dan tetap ada setelah aplikasi dibuka ulang.

### 7. Biometrik (K3)
- **File:** `services/biometric_service.dart`, `login_screen.dart`, `profile_screen.dart`
- Nyalakan di Profil (minta autentikasi sidik jari dulu). Simpan `biometric_enabled=1` dan `last_biometric_user_id` di `shared_preferences`.
- Layar Login menampilkan tombol "Masuk dengan sidik jari" jika tersedia. Gagal atau batal: login password tetap bisa.
- **Tes di HP asli (T06, T07):** sidik jari terdaftar masuk, yang tidak dikenal ditolak.

### 8. Saran dan Kesan
- **File:** `screens/feedback/feedback_screen.dart`
- Rating bintang 1–5, saran, kesan, khusus mata kuliah Pemrograman Aplikasi Mobile. Simpan ke `feedback`, riwayat tampil di bawah form.
- **Tes:** kirim satu saran, riwayatnya muncul.

---

## Tidak dikerjakan hari ini

- Scan Gemini, chatbot, Jejak Catatan: Hari 4.
- Kurs, jam dunia, notifikasi, sensor: Hari 3.
- Sinkron Supabase, peta: Hari 5.

## Untuk tiap fitur yang selesai

1. Jalan di HP asli.
2. Bisa dijelaskan dalam 30 detik (3 kalimat penjelasan dari Claude).
3. Ada screenshot dan satu baris tabel pengujian.

## Bila waktu mepet

Dari urutan pemangkasan Guide yang relevan: AES hanya pada `email_enc`. Langkah 6, 7, dan 8 saling lepas dan boleh dibalik urutannya.
