# NUMISMA — Panduan Proyek Final

> Dokumen acuan tunggal (single source of truth) untuk proyek akhir mata kuliah Pemrograman Aplikasi Mobile.
> Menggantikan `numisma-proposal.md` bila ada perbedaan. **Berikan dokumen ini utuh ke setiap asisten AI yang membantu pengerjaan.**

| | |
|---|---|
| Proyek | Numisma — aplikasi kolektor koin dan uang kertas dunia (Flutter, Android) |
| Mata kuliah | Pemrograman Aplikasi Mobile |
| Pengerjaan | Individu |
| Penyusun | [Nama] / [NIM] |
| Versi dokumen | 0.7 (23 Oktober 2026, Hari 5 dimulai) — lanjutan 0.6, **hanya merapikan**: teks yang masih menyebut "foto tidak ikut sinkron" (7.9a, 7.9b) disesuaikan dengan sinkron foto 0.6; berkas UI pengingat di 7.12 disesuaikan; prasyarat tes HP Hari 4 ditambahkan di rencana Hari 5. Aturan konflik dua perangkat ditambahkan di 7.4 (dan T34, Bagian 1.6). Isi urutan Hari 5 tidak berubah. Riwayat 0.6: lanjutan 0.5, menambal: AI beralih dari Gemini ke **OpenAI** (`ai_service`, model dari `.env`); login **email + password** dengan username sebagai nama tampilan bebas, akun juga disimpan ke Supabase; sinkron otomatis koin, blok, dan **foto** (Supabase Storage); LBS = peta Jelajah dengan posisi GPS dan acara bertitik (spot kolektor dibuang), rute lewat Google Maps; Acara dipindah ke Jelajah dan Sinkron ke Koleksi; London menggantikan UTC pada pilihan zona; tombol demo Jejak Catatan dihapus; dosen: cukup memakai API; DB v4 (satu migrasi); `applicationId` `com.numisma.app`; Beranda baru. Bagian yang berubah ditandai **[0.6]** |
| Hari 1 | Senin, 19 Oktober 2026 |
| Tenggat | Hari ke-7 = Minggu, 25 Oktober 2026 (konfirmasi ke dosen bila hitungan berbeda) |
| Rencana | Hari 1-5 aplikasi, hari 6-7 laporan dan PPT |
| Demo | Di Jogja, di HP Android asli |

---

## 0. Untuk AI / asisten lain: baca bagian ini dulu

### 0.1 Konteks singkat
- Ini tugas akhir kuliah. Dosen menetapkan **13 fitur wajib** (Bagian 2). Tema aplikasi bebas selama semua fitur wajib itu terpadu dengan tema.
- Tema yang dipilih: **Numisma**, buku koleksi digital untuk koin dan uang kertas.
- **Tujuan keberhasilan:** semua fitur wajib **berjalan di HP asli, bisa dijelaskan dengan lancar, dan terbukti lewat screenshot dan tabel pengujian.** Bukan aplikasi yang paling lengkap, cantik, atau optimal.
- Waktu pengerjaan aplikasi hanya 5 hari. Pilih selalu **versi paling sederhana yang memenuhi ketentuan**.

### 0.2 Aturan wajib (hard rules)
1. **Jangan menambah fitur** di luar Bagian 1.5 dan Bagian 7. Jangan refactor besar atau mengganti arsitektur.
2. **Tanpa Firebase sama sekali** (tidak boleh `firebase_core`, `firebase_auth`, `firebase_messaging`, `firebase_ai`, dan sejenisnya). Dosen melarangnya untuk login; kita menghindarinya seluruhnya.
3. Flutter (Dart), target **Android**. State management: `setState` saja. Tidak ada Provider, Bloc, atau Riverpod.
4. **Satu file per fitur**, fungsi kecil, dan **komentar bahasa Indonesia yang menjelaskan alasan** kode ditulis begitu. Kode harus mudah dijelaskan oleh mahasiswa saat presentasi.
5. **Nama tabel dan kolom di Bagian 5 adalah kontrak.** Jangan diubah tanpa persetujuan pemilik proyek. Tanda tangan fungsi di Bagian 8 juga kontrak.
6. **Rahasia (API key, URL Supabase) lewat file `.env` (paket `flutter_dotenv`)**, tidak ditulis di kode dan tidak di-commit (lihat Bagian 3).
7. **[0.6] Nama model AI tidak ditulis permanen di kode.** Dibaca dari `.env` (`OPENAI_MODEL`), supaya model bisa diganti tanpa membangun ulang (Bagian 6.2).
8. **Jangan mengarang** endpoint, nama field API, atau versi paket. Verifikasi di dokumentasi resmi. Kalau tidak yakin, tulis "belum diverifikasi" dan beri cara mengecek.
9. **Jangan menyalin nomor versi paket dari ingatan.** Pasang dengan `flutter pub add <paket>` agar mendapat versi terbaru yang kompatibel, lalu commit `pubspec.lock`.
10. Setiap fitur yang selesai harus disertai: (a) file lengkap, bukan potongan, (b) langkah tes di HP asli, (c) **penjelasan 3 kalimat** untuk laporan.
11. Pesan error ke pengguna harus ramah (tanpa crash). Semua panggilan jaringan punya penanganan error dan timeout.
12. Jangan membuat klaim yang tidak bisa dibuktikan dalam UI atau laporan. Contoh: hash chain **bukan** sertifikat keaslian atau bukti kepemilikan (lihat Bagian 1.6).

Template prompt untuk meminta bantuan ada di Lampiran A.

---

## 1. Gambaran Proyek (PRD ringkas)

### 1.1 Apa itu Numisma
"Numisma" berasal dari bahasa Yunani *nomisma* (koin, mata uang). Numismatik adalah ilmu dan hobi mengoleksi serta mempelajari koin, uang kertas, dan medali.

Numisma adalah **buku koleksi digital**: pengguna memfoto koin atau uang kertas, AI mengenali ciri-cirinya, pengguna mengonfirmasi dan menyimpannya, lalu aplikasi menampilkan **nilai nominal setara** dalam beberapa mata uang dan mencatat setiap perubahan pada **Jejak Catatan** (hash chain). **[0.6]** Aplikasi juga menampilkan acara kolektor milik pengguna di peta (posisi GPS, jarak, rute) dan jadwalnya dalam beberapa zona waktu.

### 1.2 Masalah dan pengguna
- **Pengguna:** kolektor pemula dan orang yang menemukan koin atau uang lama (atau uang receh asing sisa perjalanan) dan ingin tahu asal-usul serta nilai nominalnya.
- **Masalah:** koleksi dicatat di kertas atau galeri foto tanpa struktur, sulit dicari, tidak tahu nilai nominal setaranya, dan tidak ada riwayat perubahan catatan.

### 1.3 Pembeda dari tema kelompok lain
Dari daftar tema kelompok lain (`Projek_Akhir_PAM_2026.pdf`) tidak ada tema numismatik. Yang paling dekat: "Katalog dan Marketplace Pokémon TCG" (no. 43). Perbedaannya: Numisma **bukan marketplace**, melainkan pencatat koleksi pribadi dengan identifikasi foto AI, nilai multi-mata-uang, dan Jejak Catatan. **Jangan menambah fitur jual-beli.**

### 1.4 Alur inti
Foto koin (kamera atau galeri) → AI membaca gambar → hasil muncul di form yang bisa diedit → pengguna konfirmasi dan simpan → koin masuk koleksi → satu blok baru ditambahkan ke Jejak Catatan.

### 1.5 Lingkup

**Dalam lingkup:** 13 fitur pada Bagian 2 dan 7, ditambah laporan dan PPT.

**Di luar lingkup (jangan dikerjakan):**
- Marketplace atau jual-beli, pembayaran, chat antar pengguna
- Harga pasar kolektor atau penilaian keaslian koin
- Model 3D koin (cukup animasi 2D)
- Katalog koin eksternal (Numista), Overpass, Nominatim
- Push notification berbasis server (butuh Firebase/FCM)
- Supabase Auth (**[0.6]** Supabase Storage dipakai khusus untuk backup foto koin)
- Dukungan iOS, tablet, mode gelap, multi-bahasa

### 1.6 Keterbatasan yang disengaja (tulis jujur di laporan)

| Area | Keputusan dan alasan |
|---|---|
| Nilai koin | **Nilai nominal setara** berdasarkan kurs hari itu, **bukan harga pasar kolektor**. Label di UI: "nilai nominal setara" |
| Identifikasi AI | Estimasi model AI, bukan penilaian ahli. Pengguna selalu mengonfirmasi sebelum menyimpan |
| Jejak Catatan (blockchain) | Hash chain pada satu perangkat tanpa jaringan terdistribusi. Membuktikan **catatan tidak diubah diam-diam sejak dimasukkan**. **Tidak** membuktikan koin fisiknya ada, asli, atau milik pengguna |
| LBS **[0.6]** | Peta Jelajah memakai posisi GPS dan acara milik pengguna yang diberi titik lokasi. Tanpa spot kolektor (dibuang) dan tanpa pencarian alamat. Ubin peta OSM butuh internet |
| Tampilan koin | Animasi 2D (flip dan tilt) |
| Sinkronisasi **[0.6]** | Otomatis tiap perubahan saat online dengan tombol cadangan; Pulihkan satu arah, tanpa penyelesaian konflik (**[0.7]** dua perangkat dengan akun sama bisa menulis blok `idx` sama; Pulihkan penuh hanya di perangkat kosong dan konflik `idx` sama `hash` beda dilaporkan, tidak ditimpa). Kunci sinkron = hash SHA-256 dari email, tanpa Supabase Auth. Foto ikut di-backup (Supabase Storage). Catatan terenkripsi AES tidak bisa dibuka setelah Pulihkan (kunci AES hanya ada di HP lama) |
| Keamanan Supabase **[0.6]** | Anon key tertanam di aplikasi dan kebijakan akses permisif untuk demo (tanpa Supabase Auth): semua tabel dan foto dapat dibaca dan diubah pemegang kunci, termasuk **hash bcrypt password dan hash email** di tabel akun (password lemah bisa ditebak offline, karena itu password wajib kuat). Email dan password polos tidak pernah dikirim. Pemeriksaan password dijalankan oleh aplikasi, bukan server |
| OpenAI **[0.6]** | Key tertanam di aplikasi lewat `.env` yang dibundel sebagai asset APK (bisa diekstrak dengan `unzip` pada APK rilis). Kunci milik teman: pakai project key dengan batas pengeluaran dan hapus setelah penilaian. Edge Function/proxy untuk menyembunyikan kunci tidak dikerjakan (terlalu besar untuk waktu yang ada) |

---

## 2. Ketentuan Dosen dan Requirement Matrix

### 2.1 Ketentuan dari slide dosen (parafrase)
**Umum:** dikerjakan 1-3 orang, tema berbeda tiap projek, bahasa pemrograman yang mendukung mobile, memakai kriteria berikut.

**Kriteria wajib:**
1. Memiliki konsep projek akhir
2. Login dengan enkripsi (tidak boleh Firebase) dan session
3. Login biometric
4. Terkoneksi database/penyimpanan lokal dan online (SQLite/Hive/dll)
5. Ada web service/API (boleh sampai IoT, games, atau multiplatform) serta fasilitas LBS terkait tema
6. Bottom navigation: menu profil (ada gambar), menu saran dan kesan mata kuliah Pemrograman Aplikasi Mobile, menu logout
7. Menu tambahan konversi mata uang (min. 3 mata uang) dan konversi waktu (min. WIB, WIT, WITA, London) yang terpadu dengan konsep
   > **[0.6]** Slide dosen menulis "minimal ada empat: WIB, WIT, WITA, London". Pilihan zona di aplikasi: **WIB, WITA, WIT, London** (`Europe/London`, satu-satunya zona London; GMT/BST). UTC dihapus dari pilihan layar (`zoneUtc` tetap ada di kode untuk tes).
8. Minimal 2 sensor (accelerometer, gyroscope, dll) sesuai konsep
9. Fitur/fasilitas AI dan fitur LLM sesuai tema
10. Fitur mini games sederhana terkait konsep
11. Fasilitas pencarian dan pemilihan terkait konsep dan database
12. Fitur notifikasi berbasis mobile sesuai konsep
13. Fitur blockchain sederhana

**Presentasi dan laporan:**
- Projek dipresentasikan tiap minggu setelah UTS
- Laporan berisi: cover, halaman pengesahan, daftar isi, landasan teori dan tema aplikasi, perancangan (RBPL/RPL), implementasi dan penjelasan source code detail disertai screenshot, lembar evaluasi pengujian perangkat lunak
- Laporan di-upload dan dicetak dengan halaman pengesahan, salah satu syarat mengikuti UAS

Pengguna mengonfirmasi bahwa **semua poin di atas wajib**.

### 2.2 Requirement matrix

| ID | Ketentuan | Realisasi di Numisma | Bukti untuk penilaian | Bagian |
|---|---|---|---|---|
| K1 | Konsep projek | Buku koleksi koin dan uang kertas | Bab landasan teori dan tema | 1, 7.1 |
| K2 | Login enkripsi + session, tanpa Firebase | **[0.6]** Login **email + password**: password di-hash **bcrypt** (wajib huruf besar, huruf kecil, angka, simbol; 8-64 karakter), email disimpan **AES** (`email_enc`) dengan hash SHA-256 (`email_hash`) untuk pencarian dan keunikan, catatan koin **AES**, session token di `shared_preferences` | Layar login, isi DB (hash dan ciphertext), T03-T05, T22, T23 | 7.2 |
| K3 | Login biometrik | `local_auth` (sidik jari), aktif dari Profil | Layar login, T06-T07 | 7.3 |
| K4 | DB lokal dan online | SQLite + Supabase **[0.6]**: akun, koin, blok Jejak Catatan, dan foto (Storage); sinkron otomatis + tombol cadangan + Pulihkan | Tabel di kedua DB, T18 | 7.4 |
| K5 | Web service/API + LBS | Frankfurter, OpenAI, Supabase REST (dosen: cukup memakai API); **[0.6]** LBS = peta Jelajah (GPS + acara bertitik + jarak + rute lewat Google Maps) | Panggilan API di laporan, peta, T19 | 6, 7.5 |
| K6 | Bottom nav: profil (gambar), saran-kesan, logout | 5 ikon (Beranda grid, Profil, Scan tengah, Saran & Kesan, Keluar); foto profil; form saran dan kesan; dialog logout | Screenshot tiap tab, T21 | 7.6 |
| K7 | Konversi uang (min. 3) dan waktu (4 zona), terpadu konsep | Kurs 44 mata uang + Nilai Koleksi; Jam Dunia (**[0.6]** WIB/WITA/WIT/London) di Konversi; acara kolektor di Jelajah dengan pilihan zona | T10, T11, T25, T26 | 7.7 |
| K8 | Minimal 2 sensor | Accelerometer (goyang = Coin Flip, mini-toy terpisah), gyroscope (tilt pada foto item koleksi asli, koin/uang kertas). GPS dihitung terpisah untuk LBS | T12, T13 | 7.8 |
| K9 | AI dan LLM | **[0.6]** OpenAI Vision (scan koin, tahun diperkirakan) dan chatbot "Tanya Numisma" (umum, konteks koleksi, konteks koin) | T14, T15 | 7.9 |
| K10 | Mini game | "Tebak Asal Koin" (10 soal) + "Coin Flip" (goyang HP, head/tail random) | T16 | 7.10 |
| K11 | Pencarian dan pemilihan | Cari, filter, urut, multi-pilih di Koleksi | T09 | 7.11 |
| K12 | Notifikasi mobile | Notifikasi lokal pengingat acara (pilihan selisih waktu, alarm eksak) + tombol uji | T20, T24, T27, T28 | 7.12 |
| K13 | Blockchain sederhana | Jejak Catatan: hash chain SHA-256 + proof-of-work ringan + tombol Verifikasi (**[0.6]** bukti deteksi perubahan lewat tes otomatis, tanpa tombol demo) | T17, T18 | 7.13 |
| L | Laporan | Kerangka di Bagian 11.2 | Dokumen cetak | 11 |
| P | Presentasi | Alur demo di Bagian 11.1 | Demo langsung + video cadangan | 11 |

---

## 3. Tech Stack

Semua paket dipasang dengan `flutter pub add <nama>` (versi terbaru yang kompatibel). **Verifikasi API tiap paket di halaman pub.dev-nya**, karena nama method sering berubah antar versi mayor (terutama `sensors_plus`, `local_auth`, `flutter_local_notifications`, `supabase_flutter`, `flutter_map`).

| Kebutuhan | Paket | Catatan |
|---|---|---|
| Framework | Flutter (channel stable), Dart | Target Android |
| DB lokal | `sqflite`, `path`, `path_provider` | |
| DB online | `supabase_flutter` | Database **dan Storage (foto) [0.6]**. **Tanpa Supabase Auth** |
| Session dan preferensi | `shared_preferences` | |
| Rahasia / key | `flutter_dotenv` | Baca Bagian 3.1. File `.env` di-gitignore |
| Hash password | `bcrypt` (alternatif: PBKDF2 lewat paket `cryptography`) | Verifikasi paket di pub.dev. Jangan memakai SHA-256 polos untuk password |
| Enkripsi data | `encrypt` (AES), `flutter_secure_storage` (simpan kunci AES) | IV acak per enkripsi, disimpan bersama ciphertext |
| Hash chain | `crypto` (SHA-256) | |
| ID unik | `uuid` | ID koin dibuat di aplikasi |
| Biometrik | `local_auth` | Wajib dites di HP asli |
| Sensor | `sensors_plus` | Accelerometer dan gyroscope |
| Lokasi dan peta | `geolocator`, `flutter_map`, `latlong2` | Tile OSM publik, skala kecil |
| Buka aplikasi peta **[0.6]** | `url_launcher` | Tombol "Rute": membuka Google Maps dengan koordinat tujuan; tanpa SDK dan tanpa API key |
| HTTP | `http` | Frankfurter dan **OpenAI [0.6]** (REST). **Bukan** SDK |
| Foto | `image_picker` | Kecilkan lewat parameter `maxWidth: 1024`, `imageQuality: 85` |
| Notifikasi | `flutter_local_notifications`, `timezone` | Jadwalkan dengan `TZDateTime` dalam UTC agar tidak perlu mendeteksi zona perangkat |
| Format tanggal | `intl` | |
| Izin runtime | `permission_handler` (opsional) | `geolocator` dan `image_picker` sudah meminta izinnya sendiri |
| Potong foto | `crop_your_image` | Layar potong digambar di dalam Flutter sendiri (bukan membuka aktivitas Android terpisah seperti `image_cropper`), supaya proses aplikasi tidak berisiko dimatikan sistem saat kembali dari cropper (lihat Bagian 12) |
| Ikon aplikasi **[0.5]** | `flutter_launcher_icons` (**dev dependency**, `flutter pub add --dev`) | Konfigurasi di akhir `pubspec.yaml`; dibuat ulang dengan `dart run flutter_launcher_icons`. Logo ada di `assets/logo/` dan hanya `logo_numisma_1024.png` yang didaftarkan sebagai aset aplikasi |

**Pengaturan Android yang sering lupa:**
- `AndroidManifest.xml`: izin `INTERNET`, `USE_BIOMETRIC`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `CAMERA`.
- `MainActivity` memakai `FlutterFragmentActivity` (syarat `local_auth`).
- `minSdk` sesuai persyaratan paket (umumnya 21-24); baca pesan error build.
- `flutter_local_notifications` **wajib** *core library desugaring*. Tanpanya build gagal dengan pesan `requires core library desugaring to be enabled`, dan itu terjadi begitu paketnya masuk `pubspec.yaml` (bukan hanya saat fiturnya dipakai). **[0.5, terverifikasi, README 22.3.2]** Di `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` di `compileOptions`, `multiDexEnabled = true` di `defaultConfig`, dan `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`. Setelah memasang plugin yang punya syarat konfigurasi Android, atur konfigurasinya lalu jalankan `flutter build apk --debug` sebelum commit.
- Notifikasi Android 13+ perlu izin `POST_NOTIFICATIONS` saat runtime.
- **[0.5, terverifikasi]** Alarm eksak dan notifikasi terjadwal, di `AndroidManifest.xml`: izin `RECEIVE_BOOT_COMPLETED` dan `SCHEDULE_EXACT_ALARM` (Android 14+ butuh pengguna mengaktifkannya di Pengaturan "Alarm & pengingat"; aplikasi meminta lewat `requestExactAlarmsPermission()`), serta di dalam `<application>` receiver `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` dan `ScheduledNotificationBootReceiver` (dengan intent-filter `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`).
- **[0.6]** `applicationId` = `com.numisma.app` (diganti dari `com.example.numisma`: vivo men-cache ikon notifikasi per nama paket, sehingga ikon Flutter lama tetap tampil); `namespace` dan paket Kotlin tetap `com.example.numisma`. Ikon kecil notifikasi harus **monokrom**: `ic_stat_numisma` (koin putih dengan huruf N dilubangi) di `android/app/src/main/res/drawable-*`, dipakai lewat `AndroidInitializationSettings` dan `AndroidNotificationDetails`. **Jangan mengganti `applicationId` atau kunci penandatanganan lagi** (data lokal hilang dan tidak ada cadangan sebelum sinkron).

### 3.1 Rahasia lewat `.env`

Key dan URL **tidak** ditulis di kode dan **tidak** di-commit.

1. Pasang paket:
   ```
   flutter pub add flutter_dotenv
   ```
2. Buat file `.env` di root proyek (sejajar `pubspec.yaml`):
   ```
   OPENAI_API_KEY=xxxx
   OPENAI_MODEL=gpt-5-mini
   SUPABASE_URL=https://xxxx.supabase.co
   SUPABASE_ANON_KEY=xxxx
   ```
3. Daftarkan sebagai asset di `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - .env
   ```
4. Tambahkan ke `.gitignore` **sebelum commit pertama**, dan commit `.env.example` (sama persis tapi nilainya kosong) sebagai contoh untuk yang lain:
   ```
   .env
   ```
5. Muat di awal `main.dart`, sebelum `runApp` dan sebelum inisialisasi Supabase:
   ```dart
   await dotenv.load(fileName: ".env");
   ```
6. Baca di `core/config.dart`:
   ```dart
   final openaiApiKey = dotenv.env['OPENAI_API_KEY']!;
   final openaiModel = dotenv.env['OPENAI_MODEL']!;
   final supabaseUrl = dotenv.env['SUPABASE_URL']!;
   final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
   ```
   Karena nilainya dibaca saat runtime (bukan `const`), `main()` harus `async` dan inisialisasi `main.dart` menunggu `dotenv.load` selesai sebelum memakai nilai-nilai ini.
7. `.env` didaftarkan sebagai asset, jadi **ikut terbundel otomatis** saat `flutter build apk` — tidak perlu flag tambahan saat build rilis untuk demo.

**Catatan keamanan (tulis di laporan, Bagian 1.6):** karena didaftarkan sebagai asset, `.env` ada sebagai file teks biasa di dalam APK dan bisa dibaca langsung dengan `unzip app.apk` tanpa alat khusus. Ini sebabnya dipakai key khusus proyek yang dihapus setelah penilaian, bukan key pribadi/produksi.

---

## 4. Arsitektur

### 4.1 Gambaran
```
HP (aplikasi Flutter)                             Layanan eksternal
┌────────────────────────────────┐
│ screens  ->  services          │ -- HTTPS -->  Frankfurter v2 (kurs)
│              ->  core/db_helper│ -- HTTPS -->  OpenAI REST (scan + chatbot)
│ SQLite (data utama, offline)   │ -- HTTPS -->  Supabase (akun, sinkron koin/blok, foto)
│ shared_preferences (session)   │ -- HTTPS -->  Tile OSM (peta)
│ secure storage (kunci AES)     │
└────────────────────────────────┘
```
Semua logika bisnis ada di aplikasi Flutter. Supabase hanya tempat menyimpan data. **Tidak ada server buatan sendiri** (tidak ada FastAPI atau backend terpisah). Proyek hanya **satu folder**.

Aturan alur: **screen → service → db_helper**. Layar tidak boleh memanggil database atau HTTP langsung.

### 4.2 Struktur folder
**[0.6]** Berkas bertanda *(Hari 5)* belum ada saat Guide ini ditulis.
```
numisma/
  .env                        # TIDAK di-commit (lihat Bagian 3.1)
  .env.example                # Di-commit, nilai kosong
  supabase_schema.sql         # skema Supabase (Bagian 5.2)
  assets/seed/  coins_seed.json  currencies_seed.json   # [0.6] spots_seed dibuang
  assets/logo/  logo_numisma_1024.png (satu-satunya aset logo yang didaftarkan), logo_numisma_2048.png, icon_foreground_1024.png, logo_numisma.svg
  lib/
    main.dart                  # inisialisasi (dotenv, timezone, notifikasi; Supabase di Hari 5)
    theme.dart                 # warna (termasuk AppColors.latte), font, gaya kartu (satu tempat)
    core/
      config.dart              # baca key dari dotenv.env (OPENAI_*, SUPABASE_*)
      db_helper.dart           # buka SQLite, buat tabel, migrasi
      session_store.dart       # shared_preferences: user_id, token, expires_at
      crypto_util.dart         # bcrypt, AES, SHA-256
      time_util.dart           # konversi zona waktu
      format_util.dart         # format angka, tanggal, durasi
    models/  user.dart  coin.dart  block.dart  event.dart
    services/
      auth_service.dart        biometric_service.dart   coin_repo.dart
      rates_service.dart       currency_service.dart    event_repo.dart
      notif_service.dart       feedback_repo.dart       chain_service.dart
      ai_service.dart          # [0.6] scan (identifyCoin) + chat; menggantikan gemini_service
      game_service.dart
      sync_service.dart        # (Hari 5) sinkron otomatis koin, blok, foto + Pulihkan
      account_remote.dart      # (Hari 5) akun online (tabel accounts)
    screens/
      auth/        splash_screen.dart  login_screen.dart  register_screen.dart
      home/        home_shell.dart                # bottom nav custom 5 ikon + Beranda
      collection/  collection_screen.dart  coin_form_screen.dart  coin_detail_screen.dart
                   coin_photo_viewer.dart  collection_filter_sheet.dart
                   (Hari 5: layar/lembar Sinkron, dibuka dari AppBar Koleksi)
      scan/        scan_screen.dart
      chain/       chain_screen.dart              # Jejak Catatan
      chat/        chat_screen.dart
      game/        game_screen.dart  tebak_asal_tab.dart  coin_flip_tab.dart   # [0.6] dipecah jadi tiga berkas
      convert/     convert_screen.dart  (3 tab: Kurs, Nilai Koleksi, Jam Dunia)
                   collection_value_tab.dart  world_clock_tab.dart
      explore/     (Hari 5) explore_screen.dart (2 tab: Peta dan Acara)  map_tab.dart  events_tab.dart
                   location_picker_screen.dart  event_form_screen.dart  event_detail_screen.dart
                   reminder_picker.dart          # [0.6] acara dipindah dari convert/ ke explore/
      profile/     profile_screen.dart
      feedback/    feedback_screen.dart
      crop/        crop_screen.dart
    widgets/  coin_face.dart  app_logo.dart  currency_picker.dart  zone_picker.dart
              confirm_dialog.dart  tilt_photo.dart
  test/  time_util_test.dart  format_util_test.dart  game_service_test.dart
         chain_service_test.dart  ai_service_test.dart
```

### 4.3 Navigasi

> **Keputusan yang menyimpang dari rancangan awal (dicatat sesuai Bagian 0, aturan kejujuran laporan):** panduan versi awal memakai bottom nav 6 tab datar (Koleksi, Konversi, Jelajah, Profil, Saran, Keluar). Setelah didiskusikan ulang Hari 2, desain ini dianggap terlalu padat dan tidak menonjolkan fitur utama (Scan). Diganti dengan **bottom nav 5 ikon bergaya "home-screen smartphone"**: satu tab Beranda berisi grid ikon fitur pendukung, Scan jadi ikon tengah yang menonjol (aksi cepat), dan tiga ketentuan dosen (K6: Profil, Saran & Kesan, Logout) tetap tampil **literal** sebagai ikon bottom nav — tidak hilang, hanya susunannya berubah.

`Splash` (cek session) → `Login` atau `Register` → `HomeShell` dengan **5 ikon bottom nav**:

| Posisi | Ikon | Isi / aksi |
|---|---|---|
| 1 | **Beranda** | **[0.6]** AppBar perunggu (logo + nama), sapaan "Halo, <nama tampilan>" di bidang perunggu bersudut bawah membulat, kartu ringkasan **"Koleksimu: N item"** (jumlah koin dan uang kertas, diketuk membuka Koleksi), lalu ubin fitur: Koleksi, Konversi, Jelajah, Jejak Catatan, Tanya Numisma, Game. Ikon **Sinkron** dipindah ke layar Koleksi saat dibuat (Hari 5); sementara masih ikon di Beranda. Tarik ke bawah untuk menyegarkan (foto profil, pengingat, jumlah koleksi) |
| 2 | **Profil** | Foto, data, switch biometrik |
| 3 | **Scan** (tengah, dibuat lebih besar/menonjol secara visual — bukan `BottomNavigationBar` bawaan, perlu widget custom) | Aksi cepat: langsung membuka `scan_screen.dart` (pilih kamera/galeri → identifikasi AI). Bukan tab dengan halaman riwayat — ditekan, langsung aksi |
| 4 | **Saran** | Saran dan kesan mata kuliah |
| 5 | **Keluar** | Dialog konfirmasi logout (tidak punya halaman; `onTap` memunculkan dialog dan indeks tab aktif tidak berubah) |

**Implementasi bottom nav:** karena ikon ke-3 (Scan) harus tampak menonjol (ukuran lebih besar / bentuk lingkaran terangkat dari garis bottom nav), ini **tidak bisa** dibuat dari `BottomNavigationBar` bawaan Flutter apa adanya. Gunakan `Stack` berisi `Row` 4 ikon biasa (Beranda, Profil, [spasi kosong di tengah], Saran, Keluar) ditumpuk dengan satu `Positioned` tombol bulat (Scan) yang sedikit naik ke atas garis nav — mirip pola tombol kamera di aplikasi Instagram/TikTok. Detail widget dirancang saat implementasi `home_shell.dart` (Hari 2), tidak mengubah kontrak service di Bagian 8.

Ubin Beranda **[0.6]**: `GridView` 3 kolom, ikon besar (40 px) di tengah dengan label di bawahnya, di atas warna cokelat susu lembut `AppColors.latte` (`#EADBC8`), garis tipis perunggu, tanpa bayangan dan tanpa efek kaca. `onTap` membuka halaman fitur lewat `Navigator.push` biasa, bukan tab baru di bottom nav.

### 4.4 State dan session
- State UI: `setState`. Data dimuat ulang dari service saat layar dibuka.
- Pengguna aktif: `SessionStore` menyimpan `user_id`, `token` (acak, dari `Random.secure()`), `expires_at` (7 hari). Splash membaca `SessionStore.isValid()`.

---

## 5. Model Data

### 5.1 SQLite (lokal) — kontrak skema
Waktu disimpan sebagai teks ISO-8601 **UTC**. `PRAGMA foreign_keys = ON`.

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,           -- [0.6] nama tampilan bebas (maks 30), BUKAN unik dan bukan untuk login
  email_enc TEXT NOT NULL,          -- AES: base64(iv + ciphertext); ditampilkan di Profil
  email_hash TEXT NOT NULL UNIQUE,  -- [0.6] SHA-256("numisma:" + email huruf kecil tanpa spasi): pencarian, keunikan, kunci sinkron
  password_hash TEXT NOT NULL,      -- bcrypt (sudah memuat salt), diawali "$2"
  photo_path TEXT,
  biometric_enabled INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE coins (
  id TEXT PRIMARY KEY,              -- UUID v4 dibuat di aplikasi
  user_id INTEGER NOT NULL REFERENCES users(id),
  type TEXT NOT NULL CHECK (type IN ('coin','banknote')),
  country TEXT NOT NULL,
  currency_code TEXT NOT NULL,      -- ISO 4217, mis. JPY
  denomination REAL NOT NULL,       -- nominal, mis. 100
  year INTEGER,
  condition TEXT,                   -- UNC, XF, VF, F, G
  buy_price REAL,
  buy_currency TEXT,
  notes_enc TEXT,                   -- AES (catatan pengguna)
  photo_path TEXT,                  -- ada/tidaknya foto, independen dari apakah AI memprosesnya
  ai_summary TEXT,                  -- NULL = koin ini belum/tidak pernah dianalisis AI (manual, dengan atau tanpa foto)
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_synced INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_coins_user ON coins(user_id);

CREATE TABLE chain_blocks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  idx INTEGER NOT NULL,             -- 0 = genesis
  ts TEXT NOT NULL,
  coin_id TEXT,                     -- null pada genesis
  action TEXT NOT NULL,             -- GENESIS / ADD / UPDATE / DELETE
  data_hash TEXT NOT NULL,          -- SHA-256 snapshot koin (lihat 7.13)
  photo_hash TEXT,                  -- SHA-256 byte foto, bila ada
  photo_source TEXT,                -- camera / gallery / none -- asal foto, independen dari apakah AI memprosesnya
  prev_hash TEXT NOT NULL,
  nonce INTEGER NOT NULL,
  hash TEXT NOT NULL,
  is_synced INTEGER NOT NULL DEFAULT 0,
  UNIQUE (user_id, idx)
);

CREATE TABLE events (               -- [0.5] acara kolektor BUATAN PENGGUNA (tanpa seed)
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  start_utc TEXT NOT NULL,          -- ISO-8601 UTC
  location TEXT,                    -- nama tempat (teks)
  note TEXT,                        -- [0.5] catatan acara; ditambahkan kembali di migrasi v3
  lat REAL,                         -- [0.6] titik lokasi acara (opsional), migrasi v4
  lng REAL
);
CREATE INDEX idx_events_user ON events(user_id);

CREATE TABLE reminders (            -- [0.5] satu acara maksimal satu pengingat (dijaga kode)
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id INTEGER NOT NULL REFERENCES events(id),
  remind_at TEXT NOT NULL           -- selisih "sebelum acara" = start_utc - remind_at, tidak disimpan
);                                  -- [0.5] kolom `notif_id` DIHAPUS: id notifikasi Android = event_id

CREATE TABLE rates_cache (
  base TEXT NOT NULL,
  target TEXT NOT NULL,
  rate REAL NOT NULL,
  rate_date TEXT,                   -- tanggal kurs dari API
  fetched_at TEXT NOT NULL,
  PRIMARY KEY (base, target)
);

CREATE TABLE game_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  score INTEGER NOT NULL,
  total INTEGER NOT NULL,
  played_at TEXT NOT NULL
);

CREATE TABLE feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  saran TEXT,
  kesan TEXT,
  created_at TEXT NOT NULL
);
```

Catatan desain:
- `email_enc` dan `notes_enc` terenkripsi, jadi **pencarian koleksi tidak mencakup `notes_enc`**. **[0.6]** Login memakai **email**: aplikasi menghitung `email_hash` dari email yang diketik lalu mencarinya (enkripsi AES berbeda tiap kali sehingga `email_enc` tidak bisa dicari). `email_hash` bukan enkripsi: ia hash satu arah sebagai "sidik jari" email (*blind index*), dan bisa ditebak dengan daftar email umum (awalan konstan `numisma:` mengurangi kecocokan dengan tabel hash umum).
- Foto disimpan sebagai file di folder aplikasi; tabel hanya menyimpan path.

**[0.5] Versi database naik dari 1 ke 2** (hanya `events` berubah, `reminders` dibuat ulang agar urutannya benar).
- `onUpgrade` 1→2: `DROP TABLE reminders`, `DROP TABLE events`, lalu buat ulang keduanya. Aman karena keduanya hanya berisi data seed atau kosong. Tabel lain tidak disentuh.
- **`onCreate` wajib memakai skema v2 juga** (untuk HP yang bersih, mis. HP penguji). Uji kedua jalur: instal baru dan upgrade dari v1.
- `events` dan `reminders` **tidak ikut sinkron Supabase** (**[0.6]** yang disinkron: `accounts`, `coins`, `chain_blocks`, dan foto koin).
- **[0.5] Migrasi v3 (Hari 3, bersama layar detail acara):** `ALTER TABLE events ADD COLUMN note TEXT` (boleh NULL; acara lama tetap valid tanpa catatan). Tidak ada tabel yang dibuat ulang, jadi data tidak hilang. `onCreate` wajib memakai skema v3 juga.
- **[0.6] Migrasi v4 (Hari 5, SATU migrasi untuk akun dan LBS; DB di kode masih v3):** (a) tabel `users` dibangun ulang dengan `email_hash TEXT NOT NULL UNIQUE` dan `username` tidak lagi `UNIQUE`; (b) `ALTER TABLE events ADD COLUMN lat REAL` dan `ADD COLUMN lng REAL` (boleh NULL; acara tanpa titik tetap valid). Akun lama dihapus (keputusan pemilik proyek), jadi upgrade dari v3 mengosongkan semua tabel data pengguna (`coins`, `chain_blocks`, `events`, `reminders`, `game_scores`, `feedback`) lalu membuat `users` baru, supaya tidak ada baris yatim. `onCreate` wajib memakai skema v4. Uji kedua jalur: instal bersih dan upgrade dari v3.

### 5.2 Supabase (online)
Jalankan di SQL Editor (`supabase_schema.sql` di root proyek memuat skema ini). Anon key harus bisa `select`, `insert`, `update`, dan `delete` pada tabel dan bucket ini. Atur RLS permisif untuk demo dan **catat sebagai keterbatasan keamanan** (Bagian 1.6): tanpa Supabase Auth, aturan akses tidak bisa membedakan pengguna.

```sql
create table accounts (               -- [0.6] akun; TANPA email polos dan TANPA password polos
  email_hash text primary key,        -- SHA-256("numisma:" + email), sama dengan users.email_hash dan kunci sinkron
  username text not null,             -- nama tampilan
  password_hash text not null,        -- bcrypt
  created_at timestamptz not null
);

create table coins (
  id text primary key,
  user_key text not null,             -- [0.6] = email_hash pemilik (bukan username)
  type text not null,
  country text not null,
  currency_code text not null,
  denomination double precision not null,
  year int,
  condition text,
  buy_price double precision,
  buy_currency text,
  notes_enc text,                     -- ciphertext AES; tidak bisa dibuka di perangkat tanpa kunci lama
  ai_summary text,
  has_photo boolean not null default false,   -- [0.6] ada foto di Storage
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table chain_blocks (
  id text primary key,                -- "{user_key}:{idx}"
  user_key text not null,
  idx int not null,
  ts timestamptz not null,
  coin_id text,
  action text not null,
  data_hash text not null,
  photo_hash text,
  photo_source text,
  prev_hash text not null,
  nonce bigint not null,
  hash text not null
);
-- [0.6] tabel collector_spots DIBUANG (spot kolektor tidak dikerjakan).
```
**Storage [0.6]:** bucket `coin-photos` dengan kebijakan permisif untuk demo; objek bernama `{user_key}/{coin_id}.jpg`. Foto yang diunduh dicek dengan `photo_hash` di blok Jejak Catatan.

### 5.3 Data seed (aset lokal)
Format di Lampiran C. Isi:
- `coins_seed.json`: **[0.6]** 43 koin dan uang kertas contoh (dipakai Tebak Asal Koin), negara berbahasa Indonesia, hanya mata uang yang dipakai satu negara (tanpa EUR, supaya jawaban kuis tunggal). Data contoh, bukan klaim katalog.
- ~~`events_seed.json`~~ **[0.5] dihapus.** Acara dibuat manual oleh pengguna; daftar awalnya kosong (tampilkan keadaan kosong yang jelas).
- `currencies_seed.json`: 44 mata uang (`code`, `name`, `country`), dibaca langsung dari asset lewat `CurrencyService` (bukan dimasukkan ke SQLite).
- ~~`spots_seed.json`~~ **[0.6] dihapus.** Spot kolektor dibuang dari rencana; peta Jelajah hanya menampilkan acara pengguna.

---

## 6. API dan Data Eksternal

### 6.1 Frankfurter v2 (kurs)
- **Base URL:** `https://api.frankfurter.dev/v2`. Gratis, tanpa API key.
- **Gunakan v2, bukan alamat lama `frankfurter.app`** (versi lama hanya 31 mata uang ECB).
- **Terverifikasi 19 Okt 2026:** `GET /v2/currencies` mengembalikan **165 kode** mata uang, termasuk IDR, USD, EUR, JPY, GBP, SGD, MYR, KRW, CNY, VND, SAR, AED, EGP, RUB.
- Endpoint yang dirujuk dokumentasi:
  - `GET /v2/currencies`
  - `GET /v2/rates?base=IDR` (semua kurs dari satu mata uang dasar)
  - `GET /v2/rate/IDR/EUR` (satu pasangan)
- Kurs hanya diperbarui **hari kerja**. Akhir pekan memakai kurs terakhir.
- **Belum diverifikasi:** bentuk JSON respons persis dan batas laju. **Panggil dengan `curl` dan lihat bentuk JSON-nya sebelum menulis parser.**
- **Strategi:** panggil per pasangan (`/rate/{dari}/{ke}`), simpan di `rates_cache` (TTL 6 jam). Saat offline atau API gagal, pakai cache dan tampilkan `rate_date`.
- **[0.5] Daftar mata uang di UI: 44** (`assets/seed/currencies_seed.json`; menggantikan "tetap, 8"). Terverifikasi 21 Okt 2026: ke-44 kode didukung Frankfurter v2. Koin dengan kode di luar yang didukung API (atau kode manual "Lainnya…") tampil "nilai tidak tersedia" dan **tidak dijumlahkan** (dihitung sebagai "dilewati").
- **[0.5] Bentuk respons** `GET /v2/rate/{dari}/{ke}` (hasil `curl` 21 Okt 2026): `{"date":"2026-10-20","base":"JPY","quote":"IDR","rate":113.88}`. `rate` bisa bertipe int, jadi parse lewat `num`.
- **[0.5] Ketelitian kurs:** Frankfurter membulatkan kurs kasar (mis. IDR→EUR hanya `4.9e-05`). Aturan: bila kurs langsung < 1, minta arah sebaliknya lalu balik (1/kurs).
- **[0.5]** `getRateInfo(from, to, {forceRefresh})`: cache 6 jam; `forceRefresh` (tarik-untuk-menyegarkan) melewati cache, dan bila API gagal tetap memakai cache lama dengan tanda "dari cache".
- Mata uang lama yang sudah tidak berlaku (mis. mark Jerman, gulden Belanda) tidak ada di daftar. **Opsional:** tabel kecil kurs tetap konversi ke euro (cek angkanya di sumber resmi ECB sebelum dipakai). Versi minimum: tampilkan "nilai tidak tersedia".

### 6.2 OpenAI API (REST) **[0.6, menggantikan Gemini]**
- **Akses:** `http`, header `Authorization: Bearer <OPENAI_API_KEY>` dan `Content-Type: application/json`. Key dan nama model (`OPENAI_MODEL`, bawaan `gpt-5-mini`) dibaca dari `.env` (Bagian 3.1). Tanpa SDK.
- **Endpoint:** `POST https://api.openai.com/v1/chat/completions`. Daftar model: `GET https://api.openai.com/v1/models` (hanya untuk pengecekan manual, tidak dipakai kode).
- **Terverifikasi dengan `curl` 22 Okt 2026:** `gpt-5-mini` tersedia dan menerima peran `system`; pesan `user` berisi teks dan `image_url` (data URL base64, mime `image/jpeg` atau `image/png`); `response_format: {"type":"json_object"}` (kata "JSON" wajib ada di prompt); `reasoning_effort: "minimal"`; dan `max_completion_tokens`. GPT-5 adalah model *reasoning*: jangan memakai `temperature` dan `max_tokens`.
- **Scan:** satu pesan `user` berisi prompt B.1 dan gambar; keluaran JSON dengan kunci B.1 ditambah `year_estimated`. `reasoning_effort` = `minimal` (uji awal: `low` mengarang negara dari gambar tanpa teks; naikkan ke `low` hanya bila bacaan koin asli kurang baik).
- **Chat:** pesan `system` (prompt B.2 ditambah konteks koleksi atau koin), maksimal 10 pesan riwayat, lalu pesan baru. API **tidak punya ingatan**: aplikasi menyimpan riwayat di memori layar dan mengirim ulang tiap giliran. Foto koin dilampirkan pada pesan pengguna pertama yang ikut terkirim.
- **Biaya:** sekitar 1.300 token per foto; riwayat panjang menambah biaya tiap giliran (itu alasan batas 10 pesan).
- **Penanganan error:** 401 (`invalid_api_key`) → "Kunci AI tidak valid"; 404 (`model_not_found`) → pesan umum; 429 → "Kuota AI habis atau terlalu banyak permintaan, coba lagi nanti"; timeout 30 detik; offline → pesan ramah; JSON tak terbaca → pesan ramah + isi manual.
- **Cadangan demo:** `CoinGuess.sample()` (hasil contoh, ditandai jelas sebagai contoh) lewat tombol "Gunakan hasil contoh".
- **Privasi:** foto dan (mode koleksi) daftar koleksi dikirim ke OpenAI; catatan pribadi dan harga beli tidak. Banner di layar memberi tahu pengguna.
- Prompt ada di Lampiran B.

### 6.3 Supabase
- Inisialisasi `supabase_flutter` dengan `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dari `.env` (Bagian 3.1).
- Pola pakai: `supabase.from('accounts')`, `supabase.from('coins').upsert(...)`, `supabase.from('chain_blocks').upsert(...)`, dan **[0.6]** Storage: `supabase.storage.from('coin-photos').uploadBinary(...)` serta `download(...)`.
- Database **dan Storage (foto)**, tanpa Supabase Auth.
- Format `timestamptz` dari Supabase **belum diverifikasi**: cek dengan `curl` setelah satu blok terunggah, sebelum menulis parser (normalisasi ke ISO-8601 UTC).

### 6.4 OpenStreetMap (peta)
- Tile: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, isi `userAgentPackageName` dengan nama paket aplikasi.
- Tampilkan atribusi "© OpenStreetMap contributors".
- Tile publik hanya untuk skala kecil (demo), tidak untuk muatan besar.
- Nominatim dan Overpass **tidak dipakai**.

### 6.5 Yang sengaja tidak dipakai
Numista (free plan tanpa pencarian-gambar dan mewajibkan atribusi), Overpass (data toko koin di OSM tidak pasti), Firebase (dilarang), FastAPI atau backend sendiri (**[0.6]** dosen menjawab: cukup **memakai** API, tidak perlu membuat API sendiri), Supabase Auth, dan Edge Function/proxy untuk menyembunyikan kunci (terlalu besar untuk waktu yang ada).

---

## 7. Spesifikasi Fitur

Format: tujuan, layar, alur, implementasi, aturan, **selesai bila** (acceptance), dan file utama.

### 7.1 K1 — Konsep
Numisma sesuai Bagian 1. Di laporan: tema dan landasan teori numismatik (definisi, nilai nominal vs nilai koleksi, faktor kondisi), lihat Lampiran D.

### 7.2 K2 — Login terenkripsi dan session **[0.6, ditulis ulang]**
- **Layar:** `splash`, `login`, `register`.
- **Registrasi:** **email** (format valid, **unik**), **nama tampilan** (1-30 karakter, bebas, tidak harus unik, hanya untuk Beranda dan Profil), password dan konfirmasi.
  - **Aturan password:** minimal 8 dan maksimal 64 karakter (bcrypt hanya membaca 72 byte pertama, jadi password yang sangat panjang akan terpotong diam-diam), wajib memuat **huruf besar, huruf kecil, angka, dan simbol** (simbol = karakter selain huruf dan angka, spasi tidak dihitung). Pesan error menyebut syarat yang belum terpenuhi.
  - Email dinormalkan (huruf kecil, tanpa spasi di ujung) sebelum diproses.
  - `password_hash` = **bcrypt** dari password (bcrypt sudah memuat salt).
  - `email_enc` = **AES** dari email (kunci AES dibuat sekali, disimpan di `flutter_secure_storage`; IV acak disimpan bersama ciphertext).
  - `email_hash` = **SHA-256** dari `"numisma:" + email` (Bagian 5.1). Dipakai untuk mencari akun dan menjaga keunikan, karena `email_enc` berbeda tiap kali dienkripsi.
  - **Akun juga ditulis ke Supabase** (`accounts`: `email_hash`, `username`, `password_hash`, `created_at`; **tidak pernah** email polos atau password polos). **Daftar wajib internet** (keunikan diperiksa online); tanpa internet, pendaftaran ditolak dengan pesan ramah. Genesis Jejak Catatan dibuat di akun baru.
- **Login:** email + password. Aplikasi menghitung `email_hash`, mencari akun di SQLite, lalu mencocokkan password dengan bcrypt. Bila akun tidak ada di HP (mis. setelah aplikasi dihapus), aplikasi memeriksa `accounts` di Supabase (butuh internet), mencocokkan bcrypt, lalu membuat akun lokal (email yang baru diketik dienkripsi dan disimpan). Setelah itu **Pulihkan dulu** sebelum membuat genesis (7.4). Pesan error digabung ("email atau password salah") supaya tidak membocorkan email mana yang terdaftar.
- **Session:** `SessionStore` menyimpan `user_id`, `token` acak, `expires_at` (+7 hari). `Splash` mengecek validitas.
- **Profil:** nama tampilan bisa diubah (diperbarui di lokal dan di `accounts`); email tidak bisa diubah.
- **Penjelasan untuk laporan:** **bcrypt** = hash satu arah khusus password (lambat dan bergaram, tidak bisa dikembalikan); **AES** = enkripsi dua arah untuk data yang perlu dibaca kembali (email, catatan); **SHA-256** pada `email_hash` = sidik jari satu arah untuk mencocokkan. Hash **bukan** enkripsi: hash tidak bisa dibalik tetapi bisa ditebak bila isinya mudah ditebak. Karena tabel Supabase terbuka bagi pemegang anon key (Bagian 1.6), hash password terbaca publik dan password lemah bisa ditebak offline; aturan password kuat adalah mitigasinya.
- **Selesai bila:** restart aplikasi tetap login; logout menghapus session; di DB tidak ada password asli; email hanya tersimpan sebagai ciphertext dan hash; setelah hapus aplikasi, login dengan email dan password yang sama berhasil tanpa daftar ulang (T01-T05, T22, T23, T30).
- **File:** `auth_service.dart`, `account_remote.dart`, `crypto_util.dart`, `session_store.dart`, `screens/auth/*`, `profile_screen.dart`.

### 7.3 K3 — Login biometrik
- **Alur:** setelah login password, di Profil pengguna menyalakan "Masuk dengan sidik jari" (meminta autentikasi biometrik dulu). Simpan `biometric_enabled=1` dan `last_biometric_user_id` di `shared_preferences`. Di layar login muncul tombol "Masuk dengan sidik jari". Berhasil → buat session untuk `last_biometric_user_id`.
- **Implementasi:** `local_auth` (`canCheckBiometrics`, lalu `authenticate`). Biometrik gagal, batal, atau tidak tersedia → sembunyikan tombol atau tampilkan pesan, login password tetap bisa.
- **Catatan:** wajib diuji di HP asli dengan sidik jari terdaftar.
- **Selesai bila:** T06, T07.
- **File:** `biometric_service.dart`, `login_screen.dart`, `profile_screen.dart`.

### 7.4 K4 — Database lokal dan online **[0.6, ditulis ulang]**
- **Lokal:** semua data di SQLite; aplikasi tetap bisa dipakai offline.
- **Online (Supabase):** `accounts`, `coins`, `chain_blocks`, dan foto koin (Storage). Kunci pemilik data = `user_key` = `email_hash` (bukan username, karena nama tampilan bisa diubah dan tidak unik).
- **Sinkron otomatis:** setiap tambah, ubah, atau hapus koin saat online, aplikasi mengunggah **semua** koin `is_synced=0` dan blok `is_synced=0` (`upsert`) beserta fotonya, lalu menandai `is_synced=1`. Pengguna tidak memilih item satu per satu (menghindari kesalahan manusia). Bila offline atau gagal, baris tetap `is_synced=0` dan dicoba lagi saat aplikasi dibuka, saat online kembali, dan lewat tombol cadangan **"Sinkronkan sekarang"**. Layar Sinkron (dibuka dari AppBar Koleksi) menampilkan status **"N belum diunggah"**. Kegagalan di latar belakang tidak boleh mengganggu pengguna.
- **Pulihkan:** berjalan otomatis setelah login di HP yang belum punya data bila online punya data, dan tersedia sebagai tombol. Mengambil koin, blok, dan foto milik `user_key` itu, lalu memasukkan yang belum ada di lokal. Foto diunduh ke folder aplikasi dan dicek dengan `photo_hash` di blok Jejak Catatan; foto yang gagal diunduh tidak menggagalkan Pulihkan (koin tetap masuk tanpa foto).
- **Tanpa penyelesaian konflik.** Tulis di laporan sebagai keterbatasan.
- **[0.7] Dua perangkat, satu akun.** Kunci tidak bisa mencegah dua HP dengan akun yang sama menulis blok dengan `idx` sama (mis. HP A dan HP B sama-sama menulis blok `#5`: id `{user_key}:5` sama tetapi isi beda, sehingga `upsert` kedua menimpa yang pertama dan rantai online bisa rusak). Untuk demo satu HP per akun hal ini tidak muncul. Dua aturan untuk mengurangi risikonya:
  1. **Pulihkan penuh hanya bila data lokal akun itu masih kosong** (HP baru atau setelah aplikasi dihapus). Bila lokal sudah punya data, Pulihkan **tidak menggabungkan** dua rantai yang berbeda; tampilkan pesan bahwa pemulihan hanya untuk perangkat kosong.
  2. **Konflik dilaporkan, bukan ditimpa.** Bila saat Pulihkan atau unggah ditemukan blok dengan `idx` sama tetapi `hash` berbeda (lokal vs online), hentikan untuk blok itu, laporkan "konflik rantai" ke pengguna, dan jangan menimpa diam-diam. `upload` juga tidak boleh menimpa blok online yang `hash`-nya berbeda.
  Batas ini dicatat sebagai keterbatasan di laporan (Bagian 1.6).

> **Aturan penting (ditemukan lewat audit Guide dan implementasi):**
> - **Koin terhapus tidak boleh "hidup lagi" saat Pulihkan.** Sebelum memasukkan satu koin ke lokal, `restore()` cek blok rantai **terakhir** untuk `coin_id` itu (gabungan blok lokal dan remote, urut `idx`); bila aksi terakhirnya `DELETE`, **jangan** dipulihkan. Karena itu `CoinRepo.delete()` membaca data koin dulu sebelum menghapus baris dan menambah blok `DELETE` (sudah dikerjakan Hari 4).
> - **Normalisasi format waktu dari Supabase.** Kolom `timestamptz` bisa kembali dalam format berbeda dari `TEXT` ISO-8601 UTC di SQLite. Saat `restore()`, parse nilai `ts`, `created_at`, `updated_at`, lalu simpan ulang sebagai `.toUtc().toIso8601String()`. **Belum diverifikasi** bentuk aslinya: cek dengan `curl` setelah satu blok terunggah, sebelum menulis parser.
> - **Genesis dan Pulihkan.** Rantai baru di HP baru akan punya blok `#0` berbeda dari blok `#0` online. Aturan: setelah login dari Supabase, **Pulihkan dulu**; genesis baru dibuat hanya bila online belum punya blok sama sekali.
> - **Catatan terenkripsi (`notes_enc`) tidak bisa dibuka setelah Pulihkan di perangkat tanpa kunci AES lama.** Catatan tetap disinkronkan, tetapi bila dekripsi gagal, layar detail menampilkan "catatan tidak bisa dibuka" dan **tidak boleh crash**.
- **Selesai bila:** tambah koin (dengan foto) → tersinkron otomatis → hapus aplikasi → login dengan email dan password yang sama → koleksi, foto, dan Jejak Catatan kembali dan Verifikasi tetap utuh (T18); koin yang dihapus lalu Pulihkan **tidak** muncul kembali; mematikan internet lalu menambah koin menampilkan "1 belum diunggah" dan terunggah saat online (T31).
- **File:** `sync_service.dart`, `account_remote.dart`.

### 7.5 K5 — Web service/API dan LBS **[0.6, ditulis ulang]**
- **API dipakai:** Frankfurter, OpenAI, Supabase REST (Bagian 6). Dosen menjawab: cukup **memakai** API, tidak perlu membuat API sendiri. Di laporan, dokumentasikan endpoint, contoh request, dan contoh respons masing-masing.
- **LBS = layar Jelajah** dengan dua tab: **Peta** dan **Acara** (daftar, detail, form, dan pengingat acara dipindah dari Konversi ke sini; Jam Dunia tetap di Konversi). Spot kolektor **dibuang** dari rencana.
  1. Minta izin lokasi dan ambil posisi (`geolocator`).
  2. Peta `flutter_map` (ubin OSM, `userAgentPackageName` = `com.numisma.app`, atribusi "© OpenStreetMap contributors") menampilkan **posisi pengguna** dan **penanda acara milik pengguna yang punya titik lokasi** (`events.lat/lng`).
  3. Hitung **jarak** dari posisi pengguna ke tiap acara (`Geolocator.distanceBetween`) dan urutkan **terdekat**. Daftar di bawah peta; mengetuk penanda atau baris membuka detail acara.
  4. **Tombol "Rute"** di detail acara membuka Google Maps dengan koordinat tujuan lewat `url_launcher` (Maps URLs: `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>`; **belum diverifikasi di HP**, cek saat uji). Tanpa SDK Google Maps dan tanpa API key. Garis rute di dalam aplikasi (OSRM) tidak dikerjakan.
  5. **Lokasi manual:** tekan lama pada peta untuk menetapkan posisi (GPS lemah di dalam ruangan).
  6. **Pemilih lokasi di form acara:** layar terpisah (`location_picker_screen.dart`) dengan komponen peta yang sama. Pengguna mengetuk satu titik. Acara lain yang sudah punya titik tampil sebagai **penanda kecil abu-abu** (hanya tampilan, tidak bisa diketuk di mode pemilihan) dan titik yang sedang dipilih tampil mencolok. Nama tempat tetap diketik manual (tanpa pencarian alamat).
  7. **Titik lokasi opsional.** Acara tanpa titik tetap valid, tampil di tab Acara, tetapi tidak di peta.
  8. LBS dihitung dari **posisi pengguna** (GPS, jarak, terdekat, rute); memilih titik saja bukan LBS.
- **Penyimpanan:** titik acara disimpan lokal di SQLite (migrasi v4, Bagian 5.1); acara tidak ikut sinkron.
- **Persiapan demo:** ubin OSM butuh internet (siapkan hotspot) dan buat 3-4 acara bertitik di Jogja agar peta tidak kosong.
- **Selesai bila:** T19.
- **File:** `explore_screen.dart`, `map_tab.dart`, `events_tab.dart`, `location_picker_screen.dart`, `event_form_screen.dart`, `event_detail_screen.dart`.

### 7.6 K6 — Profil, Saran dan Kesan, Logout
- **Profil:** foto dari kamera atau galeri (`image_picker`), disalin ke folder aplikasi, path ke `users.photo_path`. **[0.6]** Tampilkan **nama tampilan** (bisa diubah lewat dialog: 1-30 karakter, bebas; diperbarui di lokal dan online), email (didekripsi, tidak bisa diubah), dan switch biometrik.
- **Saran dan Kesan:** form rating bintang (1-5), saran, kesan, khusus mata kuliah Pemrograman Aplikasi Mobile. Simpan ke `feedback`, riwayat tampil di bawah form.
- **Logout:** dialog konfirmasi → hapus session → ke Login.
- **Selesai bila:** T21 dan screenshot tiap tab.
- **File:** `profile_screen.dart`, `feedback_screen.dart`, `home_shell.dart`.

### 7.7 K7 — Konversi mata uang dan waktu (terpadu konsep)

**a. Kurs dan Nilai Koleksi** (convert_screen.dart punya 3 tab: Kurs, Nilai Koleksi, Jam Dunia)
- Tab **Kurs**: jumlah, mata uang asal dan tujuan (pemilih 44 mata uang, Bagian 6.1), tombol Tukar, hasil langsung, tanggal kurs.
- Tab **Nilai Koleksi**: total `denomination × kurs(currency_code → mata uang tujuan)` seluruh koleksi dalam **IDR** dan satu mata uang pilihan. Kurs diambil sekali per mata uang berbeda. **Label wajib: "nilai nominal setara".** Koin tanpa kurs **tidak dianggap 0**: tampilkan jumlah yang dilewati; tanggal kurs yang ditampilkan adalah yang **terlama**.
- Offline atau akhir pekan → pakai `rates_cache` dan tampilkan tanggal kurs. Tarik-untuk-menyegarkan ada di tab Kurs, Nilai Koleksi, Jam Dunia, dan daftar Koleksi.

**b. Jam Dunia dan Acara** [0.5, menggantikan versi lama; **[0.6]** Jam Dunia tetap di Konversi, tetapi daftar, detail, form, dan pengingat **Acara dipindah ke Jelajah (tab Acara)**, lihat 7.5]
- **Satu jam** yang berdetak tiap detik (jam:menit:detik, tanggal, singkatan zona). Zona dipilih lewat pilihan **[0.6]**: **WIB** (`Asia/Jakarta`), **WITA** (`Asia/Makassar`), **WIT** (`Asia/Jayapura`), dan **London** (`Europe/London`, satu-satunya zona London; sesuai slide dosen "WIB, WIT, WITA, London"). UTC dihapus dari pilihan layar; `zoneUtc` (`Etc/UTC`, nama `UTC` tidak ada di paket `timezone`) tetap ada di `time_util.dart` untuk tes. Menambah zona cukup menambah satu baris di `zoneOptions` (`zone_picker.dart`).
- London = UTC+0 (GMT) di musim dingin dan UTC+1 (BST) di musim panas (sampai 25 Okt 2026). DST dibawa paket `timezone`, tidak dihitung manual.
- **Kartu acara (daftar):** tiap kartu menampilkan nama, lokasi, dan **satu zona** (jam, tanggal, singkatan) dengan pilihan zona sendiri. Default WIB. Bila acara punya pengingat, kartu menampilkan **info pengingat** (ikon lonceng + "N menit sebelum"); tanpa pengingat, bagian itu kosong. **Kartu tidak punya tombol hapus** (hapus ada di layar detail dan ubah, agar tidak terpencet tanpa sengaja). Mengetuk kartu membuka layar **detail**.
- **Layar detail** (`event_detail_screen.dart`): nama, lokasi, waktu di **satu zona pilihan** (pilihan zona seperti kartu, bukan keempat zona sekaligus), **catatan**, bagian **pengingat** (tambah, ganti, batalkan; lihat 7.12), tombol **Ubah**, dan tombol **Hapus** (dengan dialog konfirmasi; sekaligus membatalkan pengingatnya).
- **Tambah dan ubah acara** (`event_form_screen.dart`, satu form dipakai untuk dua mode): judul (wajib), lokasi (opsional), tanggal (date picker), jam (time picker), **catatan (opsional)**. **Jam input dibaca sebagai WIB** (label "Waktu dalam WIB"), lalu disimpan UTC bersama `user_id` akun yang login. Form **tidak punya pilihan zona input** (keputusan 0.5): jam selalu dibaca WIB, dan pengguna melihat waktu acara di zona lain lewat pilihan zona di kartu dan detail. Layar **Ubah juga punya tombol Hapus**.
- **[0.6] Titik lokasi (opsional):** form punya tombol "Pilih lokasi di peta" yang membuka layar pemilih (Bagian 7.5); titik disimpan di `events.lat/lng`. Mengubah titik atau nama tempat tidak menyentuh pengingat.
- **Mengubah tanggal atau jam acara membatalkan pengingatnya** (alarm dan baris `reminders`), dan pengguna diberi tahu agar memasang ulang pengingat sesuai waktu baru. Mengubah nama, lokasi, atau catatan tidak menyentuh pengingat.
- Acara yang sudah lewat ditandai "Sudah lewat" dan tidak bisa diberi pengingat. Daftar kosong menampilkan teks "Belum ada acara. Tekan + untuk menambah."
- **Uji DST London (T11)**, otomatis lewat `test/time_util_test.dart`: DST London berakhir Minggu 25 Okt 2026.
  - **20:00 London pada 24 Okt 2026** (BST, UTC+1) = **02:00 WIB 25 Okt 2026** (selisih 6 jam).
  - **20:00 London pada 26 Okt 2026** (GMT, UTC+0) = **03:00 WIB 27 Okt 2026** (selisih 7 jam).
- **File:** `rates_service.dart`, `time_util.dart`, `format_util.dart`, `convert_screen.dart`, `collection_value_tab.dart`, `world_clock_tab.dart`, `zone_picker.dart`. **[0.6]** File acara (`event_repo.dart`, `event_form_screen.dart`, `event_detail_screen.dart`, `reminder_picker.dart`) berada di Jelajah (7.5).

### 7.8 K8 — Dua sensor

> **Keputusan (Hari 2):** dua sensor ini **dipisah perannya** supaya tidak ada masalah "foto sisi satunya dari mana" (koin/uang kertas di koleksi cuma punya satu foto per item, lihat Bagian 5.1 dan 7.9a).

| Sensor | Dipakai di | Objek | Efek |
|---|---|---|---|
| **Gyroscope** | `coin_detail_screen.dart` — item koleksi **asli** milik pengguna (koin **maupun** uang kertas, keduanya sama-sama baris di tabel `coins` dengan `type` berbeda) | Foto asli yang sama (satu-satunya yang tersimpan) | Kemiringan/rotasi HP menggeser tampilan (efek tilt/parallax) — **bukan** mengungkap sisi lain, cuma melihat foto yang sama dari "sudut" berbeda, jadi aman walau cuma satu foto |
| **Accelerometer** | **Coin Flip** — mini-fitur mandiri, **tidak terikat** koin koleksi tertentu (lihat 7.10) | Widget generik `widgets/coin_face.dart` (lingkaran polos, tanpa gambar berlisensi) | Goyang HP → animasi berputar cepat → berhenti random di Head/Tail, seperti lempar koin fisik |

**Catatan — scan juga berlaku untuk uang kertas:** perlu digarisbawahi, fitur Scan AI (7.9a) dan efek gyroscope tilt di atas **sama-sama berlaku untuk kedua jenis item** — koin maupun uang kertas — karena keduanya disimpan di tabel yang sama (`coins`, kolom `type IN ('coin','banknote')`) dan prompt OpenAI (Lampiran B.1) sudah meminta AI menentukan `type` sendiri dari foto. Tidak ada jalur terpisah untuk uang kertas; satu alur scan dan satu alur tampilan detail berlaku untuk keduanya.

- **[0.5] Efek tilt dan layar penuh:** `widgets/tilt_photo.dart` mengintegrasikan kecepatan putar gyroscope (rad/detik) menjadi sudut miring, yang "bocor" kembali ke tengah saat HP diam; foto bergeser maksimum beberapa piksel dan kartunya miring tipis. Di `coin_detail_screen.dart` efeknya halus (foto dipotong bingkai dan diperbesar 12%). **Mengetuk foto membuka `coin_photo_viewer.dart`**: foto layar penuh seperti foto profil WhatsApp (transisi Hero) di atas latar cokelat tua, dengan tilt lebih dinamis (foto utuh, geser dan miring lebih besar). **Tanpa zoom cubit** karena bertabrakan dengan gerakan tilt. HP tanpa gyroscope: foto diam, tidak crash.
- Deteksi goyang: besar percepatan melewati ambang (mulai coba sekitar 15 m/s²) dengan jeda 1 detik. Sesuaikan lewat uji di HP.
- Batalkan langganan stream sensor di `dispose`.
- GPS dipakai untuk LBS (7.5) dan dihitung terpisah dari dua sensor ini.
- **Selesai bila:** T12, T13.
- **File:** `coin_detail_screen.dart` (gyroscope), `game_screen.dart` (accelerometer, lihat 7.10), `widgets/coin_face.dart`.

### 7.9 K9 — AI dan LLM
**a. Scan koin (AI Vision)** — `scan_screen.dart`
1. Pilih foto dari kamera atau galeri (diperkecil lewat `image_picker`).
2. Kirim ke OpenAI (Bagian 6.2) dengan prompt Lampiran B.1 (jawaban JSON). **[0.6]** Bila tahun tidak tertera, AI **memperkirakan** satu tahun dari desain, bahan, dan gaya, lalu menandai `year_estimated`; penandanya muncul di banner, kolom Tahun ("Perkiraan AI", hilang begitu pengguna mengetik), dan `ai_summary`.
3. Tampilkan hasil di form yang bisa diedit dengan catatan **"Estimasi AI, bukan penilaian ahli"**.
4. Pengguna konfirmasi → simpan koin + tambah blok rantai (`photo_source` = camera atau gallery).
5. Gagal (kuota, jaringan, JSON tidak valid) → pesan ramah + isi manual + tombol "Gunakan hasil contoh".

**Catatan — tiga jalur menambah koin, foto WAJIB di ketiganya (keputusan Hari 2, revisi dari rancangan awal):** scan bukan satu-satunya cara. Tombol **"Tambah"** di tab Koleksi (beda dari tombol "Scan AI") membuka `coin_form_screen.dart` untuk diisi **manual**: semua field (negara, nominal, tahun, dst) diisi sendiri oleh pengguna, **tanpa** dikirim ke OpenAI. Bedanya dengan Scan bukan soal ada-tidaknya foto, tapi soal **siapa yang membaca fotonya**:

| Jalur | Foto dikirim ke OpenAI? | Field diisi oleh |
|---|---|---|
| Scan — kamera | Ya | AI (bisa diedit) |
| Scan — galeri | Ya | AI (bisa diedit) |
| Tambah manual | **Tidak** — foto (kamera/galeri) tetap **wajib dilampirkan** lewat `image_picker` saat **menambah**, hanya tidak diproses AI saat itu | Pengguna sepenuhnya |

**Alasan foto diwajibkan (bukan cuma opsional seperti rancangan awal):** supaya **setiap** koin baru — scan maupun manual — bisa dianalisis AI nanti lewat mode konteks koin di Tanya Numisma (7.9b). Kalau data manual ternyata salah atau kurang, AI tetap punya bukti visual untuk mengoreksi, bukan cuma percaya teks yang diketik. Validasi ini **hanya berlaku saat menambah** (`coin_form_screen.dart` mode Tambah) — **tidak** dipaksa saat **mengubah**, karena koin hasil **Pulihkan** dari Supabase (7.4) bisa tidak punya foto (**[0.7]** foto kini ikut di-backup ke Storage, tetapi unduhan bisa gagal dan koin tetap masuk tanpa foto) dan harus tetap bisa diedit tanpa dipaksa upload foto baru.

Tidak perlu kolom baru: `photo_path`/`photo_source` tetap menandai **asal foto** (independen dari AI), sedangkan `ai_summary` tetap **null** untuk koin manual (menandai "belum/tidak pernah dianalisis AI"). Jejak Catatan tetap mencatat blok `ADD` identik untuk ketiga jalur ini — hash chain tidak membedakan asal data, hanya menghitung hash dari data koin yang akhirnya tersimpan.

**b. Chatbot "Tanya Numisma" (LLM)** — `chat_screen.dart`
- **Mode umum [0.6]:** dibuka dari grid Beranda, tanya jawab numismatik dengan prompt sistem Lampiran B.2 (ditambah baris "teks biasa tanpa Markdown"). Ditambah **konteks koleksi**: daftar koleksi pengguna (jenis, negara, nominal, tahun, kondisi; maksimal 100 item) disusun aplikasi dan dikirim di prompt sistem, **tanpa foto, catatan pribadi, dan harga beli**; banner memberi tahu pengguna apa yang dikirim. AI tidak membuka database sendiri (tanpa function-calling). Riwayat di memori selama sesi (maksimal 10 pesan terakhir dikirim). Layar kosong menampilkan saran pertanyaan; gagal kirim menampilkan bar pesan dengan tombol "Coba lagi" tanpa mengetik ulang.
- **Mode konteks koin (fitur "Tanya Numisma tentang koin ini"):** tombol di `coin_detail_screen.dart` membuka `chat_screen.dart` dengan parameter opsional `contextCoin`. Saat ada `contextCoin`:
  1. Baca file foto dari `photo_path` koin itu **kalau ada** (apapun asalnya — scan atau dilampirkan manual) dan field data yang tersimpan saat ini (`country`, `currency_code`, `denomination`, `year`, `condition`, `ai_summary` bila terisi).
  2. Kirim foto (bila ada) + ringkasan data itu sebagai bagian pesan pertama ke OpenAI, sebelum pertanyaan pengguna. Untuk koin hasil Scan, ini berarti AI **melihat ulang** gambar yang sama (bukan cuma percaya teks hasil scan sebelumnya). Untuk koin manual yang dilampiri foto tapi `ai_summary` masih null, ini justru **kali pertama** AI melihat fotonya — mekanismenya sama, cuma "dulunya belum pernah dianalisis AI", dan karena foto **wajib** saat menambah (lihat 7.9a), ini berlaku untuk hampir semua koin manual.
  3. **Pengecualian tanpa foto — koin hasil Pulihkan yang fotonya gagal diunduh** (7.4; **[0.7]** foto normalnya ikut dipulihkan dari Storage): koin seperti ini bisa punya `photo_path = null` meski aslinya pernah ada foto di perangkat lain. Untuk koin seperti ini, AI cuma punya teks yang tersimpan, tanpa bukti visual untuk dicek ulang.
  4. **Revisi tetap manual:** kalau dari obrolan AI menyarankan data berbeda dari yang tersimpan, pengguna harus membuka sendiri `coin_form_screen.dart` (tombol Edit) untuk mengubahnya. Chat **tidak** menulis balik ke database secara otomatis — supaya pengguna tetap mengonfirmasi setiap perubahan data (konsisten dengan Bagian 1.6) dan implementasinya tetap sederhana (tidak perlu function-calling/tool-use dari OpenAI ke database).
  5. Tanda tangan `ai_service.chat(history, userMessage)` di Bagian 8 **tidak berubah** — koin opsional ini cuma menambah isi pesan pertama di `chat_screen.dart`, bukan mengubah kontrak service.
- **Selesai bila:** T14, T15.
- **File:** `ai_service.dart`, `chat_screen.dart`, `coin_detail_screen.dart`.

### 7.10 K10 — Mini game "Tebak Asal Koin" + Coin Flip

**a. Tebak Asal Koin**
- 10 soal dari `coins_seed.json`. Tiap soal menampilkan satu koin sebagai widget (`coin_face`: lingkaran dengan nominal dan kode mata uang; **tanpa gambar berlisensi**) dan 4 pilihan negara.
- Skor disimpan ke `game_scores`; tampilkan skor tertinggi.

**b. Coin Flip (pembawa fitur accelerometer, lihat 7.8)**
- Bukan kuis — ini mini-toy lempar koin. Tombol atau goyang HP (accelerometer, ambang ~15 m/s²) memicu animasi `coin_face` berputar cepat lalu berhenti random di **Head** atau **Tail** (50/50, `Random.secure()` seperlunya).
- Sengaja memakai widget generik (bukan foto koin koleksi asli) — karena ini bukan representasi item koleksi tertentu, jadi tidak ada masalah "harus ada dua sisi foto asli" (lihat catatan di 7.8).
- Ditempatkan di tab/halaman yang sama dengan Tebak Asal Koin (`game_screen.dart`), sebagai dua mode berbeda dalam satu screen.
- **Selesai bila:** T16.
- **File [0.6]:** `game_service.dart`, `game_screen.dart` (dua tab), `tebak_asal_tab.dart`, `coin_flip_tab.dart`, `widgets/coin_face.dart`. Soal dari `coins_seed.json` (43 koin), skor di `game_scores`, tab Tebak Asal dijaga hidup saat berpindah tab.

### 7.11 K11 — Pencarian dan pemilihan
- Kolom cari (negara, nominal, tahun) dengan `LIKE`. **Tidak mencakup `notes_enc`.**
- Filter: jenis (koin atau uang kertas), kondisi, rentang tahun. Urut: tahun, nominal, terbaru.
- **Pemilihan:** tekan lama untuk masuk mode multi-pilih; AppBar menampilkan jumlah terpilih, **total nilai nominal setara** dari koin terpilih, dan tombol hapus.
- **Selesai bila:** T09.
- **File:** `coin_repo.dart`, `collection_screen.dart`.

### 7.12 K12 — Notifikasi [0.5, menggantikan versi lama]
- **Akses pengingat ada di layar detail acara** (bukan di kartu daftar). Kartu daftar hanya **menampilkan** info pengingat bila ada (ikon lonceng + "N menit sebelum").
- **Pengingat per acara:** tombol **"Ingatkan saya"** dengan pilihan cepat (5 menit, 15 menit, 30 menit, 1 jam, 1 hari) dan **"Atur sendiri"** (angka + menit/jam). Disimpan di `reminders`; satu acara maksimal satu pengingat (pasang baru = ganti baris lama).
- **Cara hitung:** `waktu_pengingat = start_utc − selisih`. Pengguna memilih **selisih**, bukan jam alarm. Di "Atur sendiri": angka (minimal 1) + satuan (menit/jam/hari). Id notifikasi Android = `event_id` (tabel `reminders` tidak punya kolom `notif_id`).
- **Alarm eksak** (`zonedSchedule` dengan mode eksak): jadwal diserahkan ke sistem Android, jadi **hampir tepat waktu dan tetap muncul walau aplikasi ditutup** (digeser dari recents). Syarat: pembatasan baterai HP dimatikan (Bagian 12) dan izin alarm eksak aktif.
  - **Izin alarm eksak:** bila belum aktif, aplikasi **mengarahkan pengguna ke pengaturannya**. Bila tetap ditolak, penjadwalan **turun ke mode tidak eksak** (bisa terlambat beberapa menit) dan memberi tahu pengguna, tidak gagal diam-diam.
  - Nama izin dan receiver sudah **terverifikasi** dari README `flutter_local_notifications` 22.3.2 (lihat Bagian 3, pengaturan Android).
- **Keadaan pengingat di layar detail** (diturunkan dari waktu; baris `reminders` tidak dihapus sendiri; kartu daftar hanya menampilkan ringkasannya):
  - `remind_at` di masa depan → "Pengingat: N menit sebelum" + tombol **Batalkan**.
  - `remind_at` sudah lewat, acara belum mulai → "Pengingat sudah lewat" + tombol **Ingatkan lagi**.
  - Acara sudah mulai → "Sudah lewat", tanpa tombol pengingat.
- **Validasi:** pengingat harus di masa depan; bila tidak, pesan jelas (bukan error).
- Baris `reminders` dihapus hanya saat **Batalkan**, **hapus acara**, **mengubah tanggal/jam acara**, atau **diganti** pengingat baru.
- **Jadwalkan ulang saat aplikasi dibuka:** `rescheduleAll(userId)` dipanggil dari `HomeShell` (akun yang login baru diketahui di sana, bukan di `main()`), dan menjadwalkan ulang `reminders` **akun itu** dengan `remind_at` di masa depan (id sama, tanpa ganda). Perlu karena **force-stop membatalkan semua alarm**; pengingat yang jatuh tempo selama force-stop tidak bisa muncul (perilaku Android).
- **[0.5] Alarm Android per perangkat, acara per akun:** `logout()` memanggil `cancelAllForUser(userId)` (alarm akun itu dibatalkan, baris `reminders` dibiarkan agar pulih saat login lagi), dan `rescheduleAll(userId)` juga **membatalkan alarm milik akun lain** (menutup kasus session habis tanpa logout atau alarm yang dipulihkan sistem setelah restart). Tanpa ini, alarm akun A tetap berbunyi dan menampilkan nama acaranya saat akun B login di HP yang sama.
- **[0.5] Teks "Berbunyi …" di layar detail** memakai zona pratinjau yang sedang dipilih (keputusan: dibiarkan); waktu bunyi sebenarnya selalu momen mutlak.
- **Tombol uji tetap:** **"Kirim notifikasi uji sekarang"** dan **"Uji dalam 10 detik"** (memakai jalur penjadwalan yang sama, jadi membuktikan "jalan saat aplikasi ditutup").
- **[0.6] Ikon notifikasi:** ikon kecil di bilah status harus monokrom, jadi dipakai `ic_stat_numisma` (koin putih dengan huruf N dilubangi) dengan aksen perunggu; tanpa ikon besar. Berkas di `android/app/src/main/res/drawable-*` (Bagian 3). Di vivo, ikon kiri kartu notifikasi sempat tetap logo Flutter karena cache sistem per nama paket; teratasi dengan mengganti `applicationId` menjadi `com.numisma.app`.
- Android 13+: minta `POST_NOTIFICATIONS` saat runtime.
- **Selesai bila:** T20, T24, T27, T28.
- **File:** `notif_service.dart`, `event_repo.dart`. **[0.7]** UI pengingat ada di `explore/event_detail_screen.dart` dan `explore/reminder_picker.dart` (acara sudah dipindah dari `convert/`).

### 7.13 K13 — Jejak Catatan (blockchain sederhana)
**Tujuan:** setiap penambahan, perubahan, atau penghapusan koin dicatat sebagai blok yang terhubung lewat hash. Perubahan data di luar rantai terdeteksi.

**Blok:** `idx`, `ts`, `coin_id`, `action` (GENESIS/ADD/UPDATE/DELETE), `data_hash`, `photo_hash`, `photo_source`, `prev_hash`, `nonce`, `hash`.

**Aturan hash:**
- `data_hash` = SHA-256 dari **JSON kanonik** (kunci terurut) snapshot koin berisi `id, type, country, currency_code, denomination, year, condition, buy_price, buy_currency`. **Jangan** menyertakan `notes_enc`, `ai_summary`, `photo_path`, atau timestamp (ciphertext AES berubah tiap enkripsi karena IV acak). **Jaga tipe data** tiap field tetap sama (`double` tetap `double`, `int` tetap `int`) saat membuat snapshot — kalau sekali dibuat sebagai `"100"` (string) dan lain kali `100` (angka), hash-nya beda walau nilainya "sama", dan verifikasi akan salah mengira data berubah.
- `photo_hash` = SHA-256 byte foto saat koin ditambahkan atau diubah.
- `hash` = SHA-256 dari gabungan `idx|ts|coin_id|action|data_hash|photo_hash|photo_source|prev_hash|nonce`. **Konvensi nilai `null`:** field manapun yang `null` (misal `coin_id` pada blok genesis, atau `photo_hash`/`photo_source` kalau tidak ada foto) ditulis sebagai **string kosong `""`** saat digabung — bukan `"null"` dan bukan dilewati. Konvensi ini harus persis sama dipakai saat membuat hash maupun saat verifikasi, kalau tidak, hash tidak akan pernah cocok meski datanya benar.
- **Proof-of-work ringan:** cari `nonce` hingga `hash` diawali `"00"`. **Berlaku untuk SEMUA blok tanpa kecuali, termasuk blok genesis** — genesis juga harus melalui pencarian nonce yang sama. Kalau genesis dilewatkan dari PoW, verifikasi akan selalu gagal di blok 0 untuk setiap akun.
- Blok genesis: `idx=0`, `action=GENESIS`, `coin_id=null` (→ `""` saat dihash, lihat konvensi di atas), `prev_hash` = 64 karakter `0`, **tetap dicari nonce-nya sampai hash diawali `"00"`**. Dibuat saat registrasi.
- **[0.6]** `ensureChain`: akun yang dibuat sebelum fitur ini ada (belum punya rantai sama sekali) dibuatkan genesis lalu satu blok `ADD` per koin saat Jejak Catatan pertama dibuka (waktu blok = waktu pencatatan; asal foto `unknown`). Hanya berjalan sekali; setelah punya rantai, koin tanpa catatan dianggap masalah. Koin dan bloknya ditulis dalam **satu transaksi**, dan snapshot hash diambil dari baris yang benar-benar tersimpan.

**Verifikasi rantai (tombol "Verifikasi"):**
1. Urutkan blok per `idx`. Tiap blok: hitung ulang `hash` dan cocokkan; cek diawali `"00"`; cek `prev_hash` sama dengan `hash` blok sebelumnya.
2. Untuk tiap koin yang masih ada: ambil blok terakhirnya (ADD/UPDATE), hitung ulang `data_hash` dari baris koin saat ini dan cocokkan. Bila foto ada, hitung ulang `photo_hash` dan cocokkan.
3. **[0.6]** Koin tanpa catatan di rantai, atau koin yang hilang tanpa blok `DELETE`, dilaporkan sebagai masalah tersendiri. Foto dicocokkan hanya bila file-nya ada di perangkat ini (koin hasil Pulihkan tanpa foto tidak dianggap berubah).
4. Tampilkan per blok "✔ utuh" atau "✘ berubah" beserta alasannya, dan ringkasan "Catatan utuh" atau "Catatan telah diubah".

**[0.6] Tidak ada tombol demo.** Tombol "Ubah data diam-diam" dihapus atas keputusan pemilik proyek (mengubah data langsung di database di luar aplikasi bukan kasus pengguna biasa). Bukti bahwa perubahan terdeteksi adalah **tes otomatis** `test/chain_service_test.dart` (isi blok diubah, sambungan putus, blok dihapus dari tengah rantai, semuanya terdeteksi), dilampirkan sebagai hasil `flutter test` di laporan.

**Penamaan di UI:** menu **"Jejak Catatan"**, bukan "Sertifikat". Teks bantuan: "Menjamin catatan tidak diubah diam-diam. Tidak membuktikan keaslian atau kepemilikan koin fisik."

- **Selesai bila:** T16 (valid), T17 (deteksi perubahan, dibuktikan lewat tes otomatis), T18 (rantai ikut pulih).
- **File:** `chain_service.dart`, `chain_screen.dart`.

---

## 8. Kontrak Antarmuka Service (supaya banyak AI tetap konsisten)

Tanda tangan di bawah adalah pedoman nama dan tipe. Boleh menambah parameter opsional, tidak boleh mengubah nama.

```dart
// auth_service.dart
Future<User> register({required String username, required String email, required String password});  // [0.6] username = nama tampilan (1-30); email unik; password kuat; wajib internet
Future<User?> login(String email, String password);        // [0.6] email + password; akun tak ada di HP -> cek Supabase
Future<void> logout();
Future<User?> currentUser();
Future<User> updateDisplayName(User user, String name);   // [0.6] ganti nama tampilan (lokal + online)

// biometric_service.dart
Future<bool> isAvailable();
Future<bool> authenticate();
Future<User?> loginWithBiometric();      // memakai last_biometric_user_id

// coin_repo.dart
Future<void> insert(Coin coin, {Uint8List? photoBytes, String photoSource = 'none'});
Future<void> update(Coin coin);
Future<void> delete(String coinId);
Future<List<Coin>> list(int userId, {String? query, String? type, String? condition,
                                     int? yearFrom, int? yearTo, String sort = 'newest'});
Future<Coin?> getById(String id);

// rates_service.dart
Future<double> getRate(String from, String to);            // cache + fallback
Future<double?> convert(double amount, String from, String to);  // null bila tidak tersedia
Future<double> collectionValue(int userId, String targetCurrency);

// chain_service.dart
Future<void> createGenesis(int userId);
Future<void> addBlock({required int userId, required String coinId, required String action,
                       required Map<String, dynamic> coinSnapshot,
                       Uint8List? photoBytes, String photoSource = 'none',
                       DatabaseExecutor? executor});    // [0.6] executor = transaksi CoinRepo
Future<ChainVerifyResult> verify(int userId);
Future<void> ensureChain(int userId);                      // [0.6] akun lama: genesis + ADD per koin, sekali
Future<List<ChainBlock>> blocksOf(int userId);
// static: snapshotOf(Coin), dataHashOf(snapshot), computeHash(...), mine(...), checkBlocks(blocks)

// ai_service.dart  [0.6: menggantikan gemini_service; resolveModel dihapus, model dari .env]
Future<CoinGuess> identifyCoin(Uint8List imageBytes);       // kunci JSON Lampiran B.1 + year_estimated
Future<String> chat(List<ChatMsg> history, String userMessage,
                    {String? coinContext, Uint8List? coinPhoto});   // 10 pesan terakhir; konteks koleksi/koin di prompt sistem
// AiException(message): pesan ramah, langsung ditampilkan UI. CoinGuess.sample() = hasil contoh.

// game_service.dart  [0.6 baru]
Future<List<QuizQuestion>> buildQuiz({Random? random});     // 10 soal, 4 pilihan, tanpa koin ganda
Future<void> saveScore({required int userId, required int score, required int total});
Future<BestScore?> bestScore(int userId);
bool flipIsHead();                                          // Random.secure()

// account_remote.dart  [0.6 baru, Hari 5]
Future<bool> emailExists(String emailHash);
Future<void> createAccount({required String emailHash, required String username, required String passwordHash});
Future<RemoteAccount?> fetchAccount(String emailHash);      // untuk login di HP yang belum punya akun
Future<void> updateUsername(String emailHash, String username);

// sync_service.dart
Future<SyncResult> upload(User user);                      // [0.6] mengunggah SEMUA koin, blok, foto yang is_synced=0; dipanggil otomatis tiap perubahan saat online
Future<SyncResult> restore(User user);                     // [0.6] Pulihkan: koin, blok, foto; koin yang aksi terakhirnya DELETE tidak dipulihkan
Future<int> pendingCount(User user);                        // [0.6] "N belum diunggah"

// event_repo.dart  [0.5 baru]
Future<List<Event>> list(int userId);
Future<Event> add({required int userId, required String title, required DateTime startUtc, String? location, String? note, double? lat, double? lng});   // [0.6] lat/lng opsional
Future<Event?> getById(int eventId);
Future<Event> update(Event event);                          // mengubah waktu = pengingat dibatalkan oleh pemanggil
Future<void> delete(int eventId);

// notif_service.dart  [0.5: parameter selisih, nilai kembali, per akun]
Future<void> init();                                        // sekali di main(); izin TIDAK diminta di sini
Future<bool> scheduleEventReminder(Event event, Duration before);  // true = dijadwalkan eksak; melempar NotifException bila waktu lewat/izin ditolak
Future<void> cancelEventReminder(int eventId);              // batalkan alarm + hapus baris reminders
Future<void> cancelAllForUser(int userId);                  // saat logout: batalkan alarm akun itu, baris dibiarkan
Future<void> rescheduleAll(int userId);                     // dari HomeShell: jadwal ulang pengingat AKUN INI, batalkan alarm akun lain
Future<Map<int, DateTime>> reminderMap();                   // id acara -> remind_at (UTC)
Future<bool> canScheduleExact();
Future<void> showTestNow();
Future<bool> showTestIn(Duration d);                        // true = eksak
// NotifException(message): kesalahan dengan pesan ramah, langsung ditampilkan UI.

// rates_service.dart  [0.5 tambahan, parameter opsional]
Future<RateInfo> getRateInfo(String from, String to, {bool forceRefresh = false});
Future<CollectionValue> valueOfCoins(List<Coin> coins, String target, {bool forceRefresh = false});

// time_util.dart
DateTime toZone(DateTime utc, String zoneName);             // Asia/Jakarta, Asia/Makassar, Asia/Jayapura, Etc/UTC, Europe/London
String formatZone(DateTime utc, String zoneName);
String formatZoneTime(DateTime utc, String zoneName);       // [0.5] "02:00"
String formatZoneDate(DateTime utc, String zoneName);       // [0.5] "25 Okt 2026"
String formatClock(DateTime utc, String zoneName);          // [0.5] "14:05:09"
String zoneAbbreviation(DateTime utc, String zoneName);     // [0.5] WIB, WITA, WIT, UTC, BST/GMT
DateTime utcFromZone(String zoneName, int y, int m, int d, int h, int min);  // [0.5] jam dinding di zona -> UTC
// Konstanta zona: zoneWib, zoneWita, zoneWit, zoneUtc ('Etc/UTC'), zoneLondon. initTimeZones() dipanggil di main().
```

---

## 9. Rencana Kerja 7 Hari

Hari ini (19 Okt) tinggal sisa sore dan malam, jadi biometrik digeser ke hari 2.

| Hari | Tanggal | Target | Tanda selesai |
|---|---|---|---|
| 1 | Sen 19 Okt | `flutter doctor` dan tes di HP, akun Supabase dan OpenAI, buat proyek dan paket, `theme.dart`, skema SQLite lengkap, register/login (bcrypt) + session. Tes 1 foto koin di AI Studio. Buat kerangka laporan | Daftar, login, tutup lalu buka tetap login |
| 2 | Sel 20 Okt | Biometrik, AES, bottom nav, Profil (foto), Saran dan Kesan, Logout, CRUD koleksi, cari dan filter | Aplikasi utuh dan berguna offline |
| 3 | Rab 21 Okt | Kurs v2 + cache, konversi, Nilai Koleksi, jam dunia, acara manual, notifikasi (alarm eksak), sensor gyroscope | Konversi dan jam benar, notifikasi uji muncul |
| 4 | Kam 22 Okt | **[0.6] Selesai di kode:** Scan OpenAI (+ estimasi tahun), chatbot (umum, koleksi, koin), Jejak Catatan (hash chain + PoW + Verifikasi), mini game + Coin Flip (accelerometer), Beranda baru, ikon notifikasi, `applicationId`, London | Alur scan sampai blok baru jalan; tes HP Coin Flip, Jejak Catatan, Scan koin asli menyusul |
| 5 | Jum 23 Okt | **[0.7]** Prasyarat (sebelum fitur baru, di HP asli): tes Coin Flip (T12), Verifikasi Jejak Catatan (T16), Scan dengan koin dan uang kertas asli (T14; bila tebakan buruk naikkan `_reasoningEffort` ke `low`), lalu commit. **[0.6]** Urutan: (1) login email + akun online + migrasi v4; (2) sinkron otomatis koin dan blok (+ tombol dipindah ke Koleksi); (3) foto ke Supabase Storage; (4) Jelajah (tab Peta dan Acara, GPS, jarak, Rute, pemilih titik); (5) uji penuh, tabel pengujian, build final. **Fitur beku di akhir hari** | Semua K1-K13 ada |
| 6 | Sab 24 Okt | Laporan lengkap, cetak bila perlu | Laporan selesai |
| 7 | Min 25 Okt | PPT, cek akhir, unggah dan cetak, video demo cadangan | Semua terkumpul |

**Kebiasaan harian:**
- `git commit` setiap fitur selesai.
- Setelah tiap fitur: simpan screenshot, tulis 3 kalimat penjelasan kode (bahan laporan), isi baris tabel pengujian. Sekitar 20-30 menit per fitur. Ini yang membuat hari 6 hanya merapikan.
- Aturan selesai per fitur: (1) jalan di HP asli, (2) bisa dijelaskan 30 detik, (3) ada screenshot dan satu baris pengujian.

**Urutan pemangkasan bila tertinggal** (versi disederhanakan tetap memenuhi ketentuan):
1. Game jadi 5 soal, tanpa Coin Flip.
2. Chatbot jadi satu putaran tanya-jawab.
3. Hapus proof-of-work (kesulitan 0), rantai tetap ada.
4. AES hanya pada `email_enc`.
5. **[0.6]** Foto kembali tidak ikut tersinkron (keterbatasan lama), lalu lokasi manual dan pemilih titik disederhanakan. **Sinkron data inti dan Jelajah tidak boleh dipangkas** (poin wajib dosen).

**Percetakan:** hari 7 jatuh pada Minggu. Pastikan ada tempat cetak yang buka, atau selesaikan laporan di hari 6.

---

## 10. Rencana Pengujian (Black Box)

Format lembar evaluasi (kolom "Hasil aktual" dan "Status" diisi saat menguji di HP):

| ID | Fitur | Skenario | Hasil diharapkan | Hasil aktual | Status |
|---|---|---|---|---|---|
| T01 | Register | Data valid | Akun terbuat | | |
| T02 | Register | **[0.6]** Email tidak valid, email sudah terdaftar, password < 8 atau > 64, password tanpa huruf besar, huruf kecil, angka, atau simbol, tanpa internet | Pesan error yang menyebut syaratnya | | |
| T03 | Login | **[0.6]** Email dan password benar | Masuk ke Beranda | | |
| T04 | Login | Password salah atau email tidak terdaftar | Pesan gagal yang sama | | |
| T05 | Session | Tutup dan buka aplikasi | Tetap login | | |
| T06 | Biometrik | Sidik jari terdaftar | Masuk | | |
| T07 | Biometrik | Sidik jari tidak dikenal | Ditolak | | |
| T08 | CRUD koleksi | Tambah, ubah, hapus koin | Data tersimpan dan terbarui | | |
| T09 | Cari/pilih | Cari "Japan", filter, multi-pilih | Hasil sesuai, total nilai benar | | |
| T10 | Kurs | 1.000 JPY ke IDR | Sesuai kurs hari itu, tanggal kurs tampil | | |
| T11 | Jam dunia | Acara 20:00 London, 24 vs 26 Okt 2026 (lewat `time_util_test.dart`; di layar bila London dipilih) | WIB 02:00 (25 Okt) vs 03:00 (27 Okt) | | |
| T12 | Sensor | Goyang HP | Koin berputar | | |
| T13 | Sensor | Miringkan HP | Kartu bergeser | | |
| T14 | AI scan | Foto koin | Form terisi dan bisa diedit | | |
| T15 | Chatbot | Pertanyaan sejarah koin | Jawaban relevan; pertanyaan di luar topik ditolak sopan | | |
| T16 | Game + rantai | Main 10 soal; verifikasi rantai normal | Skor tersimpan; "Catatan utuh" | | |
| T17 | Hash chain | **[0.6]** Jalankan `flutter test` (`chain_service_test.dart`): isi blok diubah, sambungan putus, blok dihapus | Semua terdeteksi; lampirkan hasil tes | | |
| T18 | Sinkron | **[0.6]** Tambah koin dengan foto (tersinkron otomatis), hapus aplikasi, login dengan email dan password yang sama, Pulihkan | Koleksi, foto, dan rantai kembali; Verifikasi utuh; koin yang dihapus tidak muncul lagi | | |
| T19 | Peta | **[0.6]** Izin lokasi diberikan; ada acara bertitik | Posisi tampil; acara terurut jarak; tombol Rute membuka Google Maps; lokasi manual berfungsi; acara tanpa titik hanya di tab Acara | | |
| T20 | Notifikasi | Buat acara 3 menit lagi, "Ingatkan saya" 1 menit sebelum, **tutup aplikasi (geser dari recents)** | Notifikasi muncul hampir tepat waktu | | |
| T21 | Logout | Keluar | Session terhapus, kembali ke Login | | |
| T22 | Enkripsi | **[0.6]** Buka DB, lihat kolom `email_enc` dan `notes_enc` | Bukan teks asli (ciphertext); `email_hash` berupa 64 karakter heksadesimal | | |
| T23 | Hash password | Buka DB, lihat `password_hash` | Diawali `$2`, bukan password asli | | |
| T24 | Notifikasi uji | Tombol uji sekarang | Notifikasi muncul segera | | |
| T25 | Nilai Koleksi | Koleksi campur mata uang; cocokkan dengan hitungan manual; pilih beberapa koin | Total dan total koin terpilih benar; koin tanpa kurs dilewati dengan keterangan | | |
| T26 | Acara | Tambah acara, ganti zona tampil, hapus acara | Waktu benar di tiap zona; hapus membatalkan pengingat | | |
| T27 | Pengingat | Pasang pengingat, force-stop, buka aplikasi lagi | Pengingat di masa depan dijadwalkan ulang dan tetap berbunyi | | |
| T28 | Pengingat | Pengingat dengan selisih lebih besar dari sisa waktu ke acara | Pesan jelas, tidak error | | |
| T29 | Pengingat per akun | Akun A pasang pengingat (acara 10 menit lagi), logout, login akun B, tunggu; lalu login A lagi | Notifikasi A tidak muncul saat B login; pengingat A pulih saat A login lagi | | |
| T29b | Migrasi DB | **[0.6]** Instal bersih (onCreate) dan upgrade dari v3 ke v4 | Skema `users` (`email_hash` unik, `username` tidak unik) dan `events.lat/lng` benar di kedua jalur; tabel data pengguna kosong setelah upgrade | | |
| T30 | Akun online | Daftar, hapus aplikasi, login dengan email dan password yang sama; daftar dengan email yang sama | Login berhasil tanpa daftar ulang; pendaftaran ganda ditolak | | |
| T31 | Sinkron otomatis | Matikan internet, tambah koin, nyalakan internet | Status "1 belum diunggah", lalu terunggah otomatis | | |
| T32 | Nama tampilan | Ubah nama tampilan di Profil (1-30 karakter bebas, termasuk spasi dan simbol) | Sapaan Beranda dan Profil berubah; tersimpan di lokal dan online | | |
| T34 | Konflik rantai | **[0.7]** Pulihkan di HP yang lokalnya sudah berisi data; blok online dengan `idx` sama tetapi `hash` beda (disimulasikan) | Pulihkan penuh ditolak untuk perangkat tidak kosong; konflik dilaporkan, blok tidak ditimpa | | |
| T33 | Zona waktu | Pilihan zona di Jam Dunia dan acara | Tepat empat zona: WIB, WITA, WIT, London | | |

---

## 11. Demo, Laporan, PPT

### 11.1 Alur demo (sekitar 5 menit, sekaligus checklist dosen)
1. Login email dan password, lalu login sidik jari (K2, K3)
2. Koleksi: cari, filter, pilih beberapa (K11)
3. Scan koin dengan AI, konfirmasi, simpan (K9)
4. Jejak Catatan: daftar blok, tekan Verifikasi → "Catatan utuh"; jelaskan logikanya (hash dihitung ulang, sambungan prev_hash, proof-of-work) dan tunjukkan hasil `flutter test` sebagai bukti deteksi perubahan (K13)
5. Konversi kurs dan Nilai Koleksi (K7)
6. Jam Dunia (WIB, WITA, WIT, London); buat acara dengan pengingat, notifikasi muncul (K7, K12)
7. Goyang dan miringkan HP (K8)
8. Jelajah: posisi saya, acara bertitik, jarak dan urutan terdekat, tombol Rute (K5)
9. Tanya Numisma dan mini game (K9, K10)
10. Sinkron: tunjukkan status tersinkron, lalu skenario hapus data dan Pulihkan bila waktu cukup (K4)
11. Profil (foto), Saran dan Kesan, Logout (K6)

**Persiapan demo di Jogja:** tes koneksi venue, aktifkan hotspot HP cadangan (ubin peta, sinkron, dan AI butuh internet), siapkan hasil contoh AI, **buat 3-4 acara bertitik di Jogja agar peta tidak kosong**, siapkan **video rekaman cadangan**, **dan cek H-1 bahwa pembatasan baterai/latar belakang untuk app sudah dinonaktifkan di HP yang dipakai demo** (lihat Bagian 12). **Pasang satu build release final di HP demo** (`applicationId` `com.numisma.app`), uji semua fitur dari layar utama tanpa kabel, dan jangan mengganti `applicationId` atau kunci penandatanganan lagi (data lokal hilang).

### 11.2 Kerangka laporan (sesuai syarat dosen)
1. **Cover**
2. **Halaman pengesahan**
3. **Daftar isi**
4. **Landasan teori dan tema aplikasi:** numismatik; nilai nominal vs nilai koleksi; hash vs enkripsi (bcrypt, AES, SHA-256); hash chain; biometrik; sensor ponsel; REST API; LBS; zona waktu dan DST; AI Vision dan LLM
5. **Perancangan (RBPL/RPL):** kebutuhan fungsional dan non-fungsional, use case diagram, activity diagram (login, scan, verifikasi rantai), ERD (dari Bagian 5), arsitektur (Bagian 4), rancangan antarmuka
6. **Implementasi:** per fitur K1-K13: tujuan, file, potongan kode inti, **penjelasan source code detail**, screenshot
7. **Lembar evaluasi pengujian perangkat lunak:** tabel Bagian 10
8. **Penutup:** kesimpulan, keterbatasan (Bagian 1.6), saran pengembangan

Tips: minta AI membuat diagram dalam Mermaid atau PlantUML lalu render menjadi gambar.

### 11.3 Kerangka PPT (±12 slide)
Judul dan identitas · Masalah dan tema · Fitur ringkas · Arsitektur · Tech stack dan API · Keamanan (bcrypt, AES, hash chain, biometrik) · Demo (video/live) · Checklist K1-K13 · Pengujian · Keterbatasan · Kesimpulan · Tanya jawab.

---

## 12. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Model OpenAI diganti atau dimatikan **[0.6]** | AI mati saat demo | Nama model ada di `.env` (`OPENAI_MODEL`) sehingga bisa diganti; siapkan hasil contoh |
| Kredit OpenAI habis atau kunci dicabut **[0.6]** | Scan dan chat gagal | Pesan ramah, isi manual, tombol hasil contoh; pakai project key dengan batas pengeluaran |
| Internet venue tidak stabil | Kurs, sinkron, AI gagal | Cache kurs, mode offline, hotspot, video cadangan |
| GPS lemah di dalam ruangan | Posisi tidak muncul atau meleset | Lokasi manual (tekan lama di peta); jarak dihitung dari lokasi manual |
| Biometrik gagal di emulator | Tidak bisa diuji | Uji di HP asli |
| HP mematikan proses app di latar belakang (ditemukan di vivo Hari 2 saat buka kamera/galeri) — berpotensi terjadi lagi di HP demo manapun kalau pembatasan baterainya belum diubah | App "Lost connection"/restart mendadak, isian form hilang, bisa terjadi live saat demo | Nonaktifkan pembatasan baterai/latar belakang untuk app di HP yang dipakai, cek H-1 sebelum demo (lihat Bagian 11.1). Uji alur kamera/galeri di build `--release`, bukan cuma debug |
| Force-stop membatalkan semua alarm **[0.5]** | Pengingat tidak berbunyi | Jadwalkan ulang saat aplikasi dibuka; jelaskan di laporan |
| Pembatasan baterai vivo menunda alarm walau eksak **[0.5]** | Notifikasi terlambat | Nonaktifkan pembatasan baterai app di HP demo (cek H-1); tombol uji sebagai cadangan |
| Izin alarm eksak ditolak atau berbeda per versi Android **[0.5]** | Pengingat tidak tepat waktu | Arahkan ke pengaturan, turun ke mode tidak eksak, verifikasi README plugin dan uji di HP asli |
| Dosen menafsirkan "enkripsi" secara ketat | Poin K2 dipertanyakan | bcrypt + AES, jelaskan bedanya di laporan |
| Hash password dan hash email terbaca pemegang anon key **[0.6]** | Password lemah bisa ditebak offline; tabel koleksi dan foto terbuka | Aturan password kuat (besar, kecil, angka, simbol, 8-64), tanpa email dan password polos online, tulis jujur di keterbatasan |
| Kunci OpenAI/Supabase terbundel di APK **[0.6]** | Kredit teman bisa dihabiskan pihak lain | Project key dengan batas pengeluaran, jangan sebar APK, hapus kunci setelah penilaian |
| Vivo men-cache ikon notifikasi per nama paket **[0.6]** | Ikon Flutter lama tetap tampil | `applicationId` `com.numisma.app` (sudah diganti) |
| Mengganti `applicationId` atau kunci penandatanganan | Data lokal hilang (tanpa cadangan sebelum sinkron) | Jangan diganti lagi menjelang demo |
| ~~Dosen mengharapkan API buatan sendiri~~ **[0.6] tertutup** | — | Dosen menjawab: cukup **memakai** API (22 Okt 2026) |
| Build error atau konflik versi paket | Waktu habis | Commit `pubspec.lock`, commit per fitur, jangan upgrade paket di tengah jalan |
| `.env` ter-commit atau ikut terunggah tanpa sengaja | Key bocor/disalahgunakan | `.gitignore` sebelum commit pertama, commit `.env.example` kosong, key khusus proyek, hapus setelah penilaian |
| Waktu laporan kurang | Terlambat | Catat bahan laporan tiap fitur, kerangka sejak hari 1 |
| Tenggat percetakan | Tidak bisa cetak | Selesaikan laporan hari 6 |

---

## 13. Status Verifikasi dan Hal Terbuka

### 13.1 Terverifikasi (dicek 19 Okt 2026)
- Frankfurter v2 `/v2/currencies`: 165 kode, termasuk semua mata uang pada daftar UI.
- Frankfurter v1 / `frankfurter.app`: 31 mata uang ECB, jangan dipakai.
- Frankfurter gratis, tanpa key, diperbarui hari kerja (sumber dokumentasi pihak ketiga).
- ~~Status model Gemini~~ **[0.6]** AI beralih ke OpenAI; nama model dibaca dari `.env`.
- **[0.6, terverifikasi `curl` 22 Okt 2026]** OpenAI `gpt-5-mini`: `/v1/models` 200 dan model tersedia; chat teks, vision (data URL base64), `response_format: json_object`, peran `system`, dan `reasoning_effort: minimal` diterima; key salah → 401, model salah → 404. Hasil lengkap di Bagian 6.2.
- Nominatim dibatasi 1 request per detik; tile OSM publik tidak untuk produksi.
- Numista free plan tidak mencakup pencarian-gambar dan mewajibkan atribusi (tidak dipakai).
- Paket Flutter `geolocator`, `sensors_plus`, `local_auth` ada dan dikenal untuk fungsi masing-masing.

### 13.1b Terverifikasi tambahan (21 Okt 2026) **[0.5]**
- **[0.6, 22 Okt 2026]** Dosen menjawab: untuk poin web service/API cukup **memakai** API (tidak perlu membuat sendiri). Ikon notifikasi Numisma tampil dengan `applicationId` `com.numisma.app` (dites pemilik proyek di vivo V2318).
- Bentuk JSON `/v2/rate`; ke-44 mata uang seed didukung dan aktif; kurs dibulatkan kasar; nama zona `Etc/UTC` valid, `UTC` tidak; DST London lewat tes otomatis.

### 13.2 Belum diverifikasi (cek sebelum dipakai)
- **[0.5]** Izin dan receiver Android untuk alarm eksak (plugin 22.3.2) **sudah terverifikasi** dari README dan build berhasil; notifikasi uji tetap muncul saat aplikasi ditutup di vivo V2318 (dites pengguna). **Belum terbukti:** pengingat setelah **force-stop** lalu aplikasi dibuka lagi, setelah **restart HP** tanpa membuka aplikasi (T27), dan **dua akun** di HP yang sama (T29).
- Batas laju Frankfurter v2 (bentuk JSON sudah terverifikasi, lihat 13.1b).
- **[0.6]** Bentuk string `timestamptz` dari Supabase; URL Maps untuk tombol Rute (`https://www.google.com/maps/dir/?api=1&destination=...`) di HP; perilaku Storage Supabase dengan anon key; ambang goyang Coin Flip (15 m/s²) di HP; akurasi scan dan perkiraan tahun pada koin asli (belum dites oleh pemilik proyek).
- Nama method versi terbaru: `sensors_plus`, `local_auth`, `flutter_local_notifications`, `supabase_flutter`, `flutter_map`, `bcrypt`, `encrypt`, `flutter_dotenv`.
- Kebijakan RLS Supabase untuk anon key.
- ~~Keberadaan dan lokasi spot kolektor~~ **[0.6]** spot kolektor dibuang dari rencana.
- Kebutuhan `minSdk` dan desugaring yang tepat untuk set paket ini.

### 13.3 Hal terbuka untuk pemilik proyek
1. **Tanyakan ke dosen:** ~~(a) API buatan sendiri~~ **[0.6] terjawab: cukup memakai API**; (b) tanggal presentasi; (c) tenggat unggah dan cetak laporan.
2. **[0.6]** Buat 3-4 acara bertitik di Jogja sebelum demo (pengganti spot kolektor).
3. Isi nama dan NIM pada cover dan dokumen ini.
4. Siapkan HP Android asli dengan sidik jari terdaftar, akun Supabase (tabel dan bucket `coin-photos`), dan kunci OpenAI dengan batas pengeluaran. **[0.6]** Hapus atau ganti kunci setelah penilaian.

---

## 14. Referensi

- Frankfurter: https://frankfurter.dev dan https://api.frankfurter.dev/v2/currencies; daftar v1: https://github.com/lineofflight/frankfurter/issues/144
- OpenAI API (chat completions): https://platform.openai.com/docs/api-reference/chat
- OpenAI models: https://platform.openai.com/docs/models
- Google Maps URLs (tombol Rute): https://developers.google.com/maps/documentation/urls/get-started
- Kebijakan tile OSM: https://operations.osmfoundation.org/policies/tiles/
- Kebijakan Nominatim (tidak dipakai, sebagai catatan): https://operations.osmfoundation.org/policies/nominatim/
- Numista API (tidak dipakai): https://en.numista.com/api/index.php
- Landasan teori numismatik (DJKN): https://www.djkn.kemenkeu.go.id/artikel/baca/13914/Numismatik-Hobi-Sekaligus-Belajar-Sejarah-dan-Berinvestasi.html
- Paket Flutter: https://pub.dev (cari nama paket pada Bagian 3)
- `flutter_dotenv`: https://pub.dev/packages/flutter_dotenv

---

## Lampiran A — Template prompt untuk AI lain

```
Konteks: proyek Numisma (Flutter). Panduan lengkap terlampir (NUMISMA_GUIDE.md).
Tugas: implementasikan fitur [K7a: konversi kurs] sesuai Bagian 7.7 dan kontrak service Bagian 8.
Batasan:
- Ikuti aturan wajib Bagian 0.2 (tanpa Firebase, setState saja, komentar Indonesia, rahasia lewat .env).
- Jangan ubah skema Bagian 5 atau nama fungsi Bagian 8.
- Hanya buat atau ubah file: services/rates_service.dart, screens/convert/convert_screen.dart.
Output yang diminta:
1. File lengkap (bukan potongan).
2. Langkah tes di HP asli.
3. Penjelasan 3 kalimat untuk laporan.
Jika ada API atau paket yang tidak kamu yakini, katakan "belum diverifikasi" dan jangan mengarang.
```

## Lampiran B — Prompt OpenAI **[0.6]**

### B.1 Scan koin (jawaban JSON)
```
Kamu adalah asisten numismatik. Analisis foto koin atau uang kertas ini.
Jawab HANYA dengan JSON valid, tanpa teks lain, dengan kunci:
- type: "coin" atau "banknote"
- country: nama negara dalam bahasa Inggris
- currency_code: kode ISO 4217 bila mata uangnya masih berlaku, jika tidak null
- denomination: angka nominal (null bila tidak terbaca)
- year: angka tahun. Jika tahun tertera dan terbaca, pakai itu. Jika tidak terbaca, PERKIRAKAN satu tahun pembuatan dari desain, bahan, gaya, tanda nilai, dan seri uang/koinnya (tebakan terbaik, satu angka). Isi null hanya bila benar-benar tidak ada petunjuk sama sekali
- year_estimated: true bila year adalah perkiraan, false bila tahunnya tertera dan terbaca
- features: ciri khas dalam maksimal 2 kalimat bahasa Indonesia
- confidence: "low", "medium", atau "high"
Untuk kunci selain year: jika tidak yakin, isi null dan confidence "low". Jangan mengarang. Turunkan confidence bila year hanya perkiraan.
```
**[0.6]** Prompt ini sama dengan `_scanPrompt` di `ai_service.dart`. Kata "JSON" harus tetap ada (syarat `response_format: json_object`), dan nama kunci tidak boleh diubah (dibaca `CoinGuess.fromJson`).

### B.2 Chatbot "Tanya Numisma"
```
Kamu adalah "Tanya Numisma", asisten untuk kolektor koin dan uang kertas.
Jawab dalam bahasa Indonesia, singkat (maksimal 6 kalimat).
Hanya bahas numismatik: sejarah koin atau uang, perawatan, ciri umum keaslian, istilah.
Untuk pertanyaan di luar topik, tolak dengan sopan dan arahkan kembali.
Jangan memberi harga pasti atau menjamin keaslian; sarankan konsultasi ke ahli atau pedagang bereputasi.
Tulis teks biasa tanpa format Markdown.
```
**[0.6]** Baris terakhir ditambahkan karena jawaban tampil sebagai teks biasa. Konteks koleksi atau koin ditambahkan ke prompt sistem ini oleh `chat_screen.dart` (Bagian 7.9b).

## Lampiran C — Format data seed

`coins_seed.json`
```json
[
  {"id": "seed-001", "type": "coin", "country": "Japan", "currency_code": "JPY",
   "denomination": 100, "year": 1990, "note": "contoh"}
]
```
`currencies_seed.json` **[0.5]** (events_seed dihapus)
```json
[
  {"code": "IDR", "name": "Rupiah", "country": "Indonesia"}
]
```
~~`spots_seed.json`~~ **[0.6] dihapus** (spot kolektor tidak dikerjakan).
```json
[
  {"name": "[isi nama tempat]", "city": "[kota]", "lat": 0.0, "lng": 0.0,
   "type": "museum", "note": "", "verified": true}
]
```

## Lampiran D — Glosarium singkat
- **Numismatik / numismatis:** ilmu atau hobi mengoleksi koin, uang kertas, medali; pelakunya disebut numismatis.
- **Nilai nominal:** angka yang tertera pada koin atau uang. Berbeda dari **nilai koleksi** (harga pasar), yang dipengaruhi kelangkaan, kondisi fisik, dan permintaan.
- **Kondisi (grade):** tingkat keawetan fisik, mis. UNC (belum beredar), XF, VF, F, G.
- **Hash:** fungsi satu arah yang mengubah data jadi sidik jari tetap. Dipakai untuk password dan rantai blok.
- **Enkripsi:** pengacakan data dengan kunci sehingga bisa dikembalikan (didekripsi). Dipakai untuk email dan catatan.
- **Hash chain:** daftar blok yang masing-masing memuat hash blok sebelumnya, sehingga perubahan di tengah terdeteksi.
- **Proof-of-work:** syarat tambahan agar blok sah, di sini hash harus diawali "00".
- **LBS:** *Location-Based Service*, layanan berbasis lokasi.
- **DST:** *Daylight Saving Time*; London memakai BST (UTC+1) di musim panas dan GMT (UTC+0) di musim dingin.
