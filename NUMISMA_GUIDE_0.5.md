# NUMISMA — Panduan Proyek Final

> Dokumen acuan tunggal (single source of truth) untuk proyek akhir mata kuliah Pemrograman Aplikasi Mobile.
> Menggantikan `numisma-proposal.md` bila ada perbedaan. **Berikan dokumen ini utuh ke setiap asisten AI yang membantu pengerjaan.**

| | |
|---|---|
| Proyek | Numisma — aplikasi kolektor koin dan uang kertas dunia (Flutter, Android) |
| Mata kuliah | Pemrograman Aplikasi Mobile |
| Pengerjaan | Individu |
| Penyusun | [Nama] / [NIM] |
| Versi dokumen | 0.5 (21 Oktober 2026, Hari 3) — lanjutan 0.4, menambal: acara kolektor manual per akun (tanpa seed acara, `events` + `user_id`, DB v2), notifikasi dengan pilihan selisih dan alarm eksak (+ jadwal ulang saat aplikasi dibuka), kurs 44 mata uang + Nilai Koleksi, Jam Dunia satu jam + zona (WIB/WITA/WIT/UTC, London opsional); kolom `events.note` dan `reminders.notif_id` dihapus; LBS digabung dengan acara (satu peta dua lapisan) dengan migrasi v3 `events.lat/lng` direncanakan Hari 5. Bagian yang berubah ditandai **[0.5]** |
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
7. **Nama model Gemini tidak boleh ditulis permanen di kode.** Ambil dari daftar model lewat API, simpan di config (Bagian 6.2).
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

Numisma adalah **buku koleksi digital**: pengguna memfoto koin atau uang kertas, AI mengenali ciri-cirinya, pengguna mengonfirmasi dan menyimpannya, lalu aplikasi menampilkan **nilai nominal setara** dalam beberapa mata uang dan mencatat setiap perubahan pada **Jejak Catatan** (hash chain). Aplikasi juga membantu menemukan spot kolektor terdekat dan menampilkan jadwal acara kolektor dalam beberapa zona waktu.

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
- Supabase Auth, Supabase Storage (foto tidak disinkronkan)
- Dukungan iOS, tablet, mode gelap, multi-bahasa

### 1.6 Keterbatasan yang disengaja (tulis jujur di laporan)

| Area | Keputusan dan alasan |
|---|---|
| Nilai koin | **Nilai nominal setara** berdasarkan kurs hari itu, **bukan harga pasar kolektor**. Label di UI: "nilai nominal setara" |
| Identifikasi AI | Estimasi model AI, bukan penilaian ahli. Pengguna selalu mengonfirmasi sebelum menyimpan |
| Jejak Catatan (blockchain) | Hash chain pada satu perangkat tanpa jaringan terdistribusi. Membuktikan **catatan tidak diubah diam-diam sejak dimasukkan**. **Tidak** membuktikan koin fisiknya ada, asli, atau milik pengguna |
| Spot kolektor | Data kurasi manual yang diverifikasi sendiri |
| Tampilan koin | Animasi 2D (flip dan tilt) |
| Sinkronisasi | Satu arah per tombol (Unggah, Pulihkan), tanpa penyelesaian konflik. Kunci sinkron = username, tanpa autentikasi online. Foto tidak ikut tersinkron |
| Keamanan Supabase | Anon key tertanam di aplikasi dan kebijakan akses dibuat permisif untuk demo |
| Gemini | Key tertanam di aplikasi lewat `.env` yang dibundel sebagai asset APK (bisa diekstrak dengan `unzip` pada APK rilis). Pakai key khusus proyek, hapus setelah penilaian |

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
   > **[0.5] Catatan pemilik proyek:** zona yang disebut dosen adalah **contoh**, bukan daftar wajib. Aplikasi memakai WIB, WITA, WIT, dan UTC sebagai empat zona utama; London ditambahkan sebagai pilihan opsional (lihat 7.7b). Bila dosen menegaskan London wajib, London sudah tersedia.
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
| K2 | Login enkripsi + session, tanpa Firebase | Password di-hash **bcrypt**, data sensitif dienkripsi **AES**, session token di `shared_preferences` | Layar login, isi DB (hash dan ciphertext), T03-T05, T22, T23 | 7.2 |
| K3 | Login biometrik | `local_auth` (sidik jari), aktif dari Profil | Layar login, T06-T07 | 7.3 |
| K4 | DB lokal dan online | SQLite + Supabase (Unggah dan Pulihkan) | Tabel di kedua DB, T18 | 7.4 |
| K5 | Web service/API + LBS | Frankfurter, Gemini, Supabase REST; LBS spot kolektor | Panggilan API di laporan, peta, T19 | 6, 7.5 |
| K6 | Bottom nav: profil (gambar), saran-kesan, logout | 5 ikon (Beranda grid, Profil, Scan tengah, Saran & Kesan, Keluar); foto profil; form saran dan kesan; dialog logout | Screenshot tiap tab, T21 | 7.6 |
| K7 | Konversi uang (min. 3) dan waktu (4 zona), terpadu konsep | Kurs 44 mata uang (pemilih dari JSON) + Nilai Koleksi; Jam Dunia (WIB/WITA/WIT/UTC, London opsional) + acara kolektor buatan pengguna | T10, T11, T25, T26 | 7.7 |
| K8 | Minimal 2 sensor | Accelerometer (goyang = Coin Flip, mini-toy terpisah), gyroscope (tilt pada foto item koleksi asli, koin/uang kertas). GPS dihitung terpisah untuk LBS | T12, T13 | 7.8 |
| K9 | AI dan LLM | Gemini Vision (scan koin) dan chatbot "Tanya Numisma" | T14, T15 | 7.9 |
| K10 | Mini game | "Tebak Asal Koin" (10 soal) + "Coin Flip" (goyang HP, head/tail random) | T16 | 7.10 |
| K11 | Pencarian dan pemilihan | Cari, filter, urut, multi-pilih di Koleksi | T09 | 7.11 |
| K12 | Notifikasi mobile | Notifikasi lokal pengingat acara (pilihan selisih waktu, alarm eksak) + tombol uji | T20, T24, T27, T28 | 7.12 |
| K13 | Blockchain sederhana | Jejak Catatan: hash chain SHA-256 + proof-of-work ringan + verifikasi | T17, T18 | 7.13 |
| L | Laporan | Kerangka di Bagian 11.2 | Dokumen cetak | 11 |
| P | Presentasi | Alur demo di Bagian 11.1 | Demo langsung + video cadangan | 11 |

---

## 3. Tech Stack

Semua paket dipasang dengan `flutter pub add <nama>` (versi terbaru yang kompatibel). **Verifikasi API tiap paket di halaman pub.dev-nya**, karena nama method sering berubah antar versi mayor (terutama `sensors_plus`, `local_auth`, `flutter_local_notifications`, `supabase_flutter`, `flutter_map`).

| Kebutuhan | Paket | Catatan |
|---|---|---|
| Framework | Flutter (channel stable), Dart | Target Android |
| DB lokal | `sqflite`, `path`, `path_provider` | |
| DB online | `supabase_flutter` | Hanya sebagai database. **Tanpa Supabase Auth** |
| Session dan preferensi | `shared_preferences` | |
| Rahasia / key | `flutter_dotenv` | Baca Bagian 3.1. File `.env` di-gitignore |
| Hash password | `bcrypt` (alternatif: PBKDF2 lewat paket `cryptography`) | Verifikasi paket di pub.dev. Jangan memakai SHA-256 polos untuk password |
| Enkripsi data | `encrypt` (AES), `flutter_secure_storage` (simpan kunci AES) | IV acak per enkripsi, disimpan bersama ciphertext |
| Hash chain | `crypto` (SHA-256) | |
| ID unik | `uuid` | ID koin dibuat di aplikasi |
| Biometrik | `local_auth` | Wajib dites di HP asli |
| Sensor | `sensors_plus` | Accelerometer dan gyroscope |
| Lokasi dan peta | `geolocator`, `flutter_map`, `latlong2` | Tile OSM publik, skala kecil |
| HTTP | `http` | Frankfurter dan Gemini (REST). **Bukan** SDK Gemini |
| Foto | `image_picker` | Kecilkan lewat parameter `maxWidth: 1024`, `imageQuality: 85` |
| Notifikasi | `flutter_local_notifications`, `timezone` | Jadwalkan dengan `TZDateTime` dalam UTC agar tidak perlu mendeteksi zona perangkat |
| Format tanggal | `intl` | |
| Izin runtime | `permission_handler` (opsional) | `geolocator` dan `image_picker` sudah meminta izinnya sendiri |
| Potong foto | `crop_your_image` | Layar potong digambar di dalam Flutter sendiri (bukan membuka aktivitas Android terpisah seperti `image_cropper`), supaya proses aplikasi tidak berisiko dimatikan sistem saat kembali dari cropper (lihat Bagian 12) |

**Pengaturan Android yang sering lupa:**
- `AndroidManifest.xml`: izin `INTERNET`, `USE_BIOMETRIC`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `CAMERA`.
- `MainActivity` memakai `FlutterFragmentActivity` (syarat `local_auth`).
- `minSdk` sesuai persyaratan paket (umumnya 21-24); baca pesan error build.
- `flutter_local_notifications` biasanya meminta *core library desugaring*; ikuti README paketnya.
- Notifikasi Android 13+ perlu izin `POST_NOTIFICATIONS` saat runtime.
- **[0.5]** Alarm eksak: Android 13+ umumnya tidak memberi izin alarm eksak otomatis; pengguna mungkin harus mengaktifkannya di Pengaturan ("Alarm & pengingat"). Nama izin, receiver boot, dan versi Android yang terkena **belum diverifikasi**; baca README `flutter_local_notifications` versi terpasang sebelum menulis kode (lihat 7.12 dan 13.2).

### 3.1 Rahasia lewat `.env`

Key dan URL **tidak** ditulis di kode dan **tidak** di-commit.

1. Pasang paket:
   ```
   flutter pub add flutter_dotenv
   ```
2. Buat file `.env` di root proyek (sejajar `pubspec.yaml`):
   ```
   GEMINI_API_KEY=xxxx
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
   final geminiApiKey = dotenv.env['GEMINI_API_KEY']!;
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
│              ->  core/db_helper│ -- HTTPS -->  Gemini REST (scan + chatbot)
│ SQLite (data utama, offline)   │ -- HTTPS -->  Supabase (sinkron + spot kolektor)
│ shared_preferences (session)   │ -- HTTPS -->  Tile OSM (peta)
│ secure storage (kunci AES)     │
└────────────────────────────────┘
```
Semua logika bisnis ada di aplikasi Flutter. Supabase hanya tempat menyimpan data. **Tidak ada server buatan sendiri** (tidak ada FastAPI atau backend terpisah). Proyek hanya **satu folder**.

Aturan alur: **screen → service → db_helper**. Layar tidak boleh memanggil database atau HTTP langsung.

### 4.2 Struktur folder
```
numisma/
  .env                        # TIDAK di-commit (lihat Bagian 3.1)
  .env.example                # Di-commit, nilai kosong
  assets/seed/  coins_seed.json  spots_seed.json  currencies_seed.json   # [0.5] events_seed dihapus
  lib/
    main.dart                  # inisialisasi (dotenv, db, supabase, notifikasi, timezone)
    app.dart                   # tema, rute
    theme.dart                 # warna, font, gaya kartu (satu tempat)
    core/
      config.dart              # baca key dari dotenv.env
      db_helper.dart           # buka SQLite, buat tabel, seed
      session_store.dart       # shared_preferences: user_id, token, expires_at
      crypto_util.dart         # bcrypt, AES, SHA-256
      time_util.dart           # konversi zona waktu
      format_util.dart         # [0.5] format angka dan tanggal bersama
    models/  user.dart  coin.dart  block.dart  event.dart
    services/
      auth_service.dart        biometric_service.dart   coin_repo.dart
      rates_service.dart       event_repo.dart          notif_service.dart
      gemini_service.dart      chain_service.dart       sync_service.dart
      spot_service.dart        game_service.dart
    screens/
      auth/        splash_screen.dart  login_screen.dart  register_screen.dart
      home/        home_shell.dart                # bottom nav custom 5 ikon + grid Beranda
      collection/  collection_screen.dart  coin_form_screen.dart  coin_detail_screen.dart
      scan/        scan_screen.dart
      chain/       chain_screen.dart              # Jejak Catatan
      convert/     convert_screen.dart  (3 tab: Kurs, Nilai Koleksi, Jam Dunia)   # [0.5]
                   collection_value_tab.dart  world_clock_tab.dart  event_form_screen.dart
      explore/     explore_screen.dart
      profile/     profile_screen.dart
      feedback/    feedback_screen.dart
      chat/        chat_screen.dart
      game/        game_screen.dart
    widgets/  coin_face.dart  coin_card.dart
```

### 4.3 Navigasi

> **Keputusan yang menyimpang dari rancangan awal (dicatat sesuai Bagian 0, aturan kejujuran laporan):** panduan versi awal memakai bottom nav 6 tab datar (Koleksi, Konversi, Jelajah, Profil, Saran, Keluar). Setelah didiskusikan ulang Hari 2, desain ini dianggap terlalu padat dan tidak menonjolkan fitur utama (Scan). Diganti dengan **bottom nav 5 ikon bergaya "home-screen smartphone"**: satu tab Beranda berisi grid ikon fitur pendukung, Scan jadi ikon tengah yang menonjol (aksi cepat), dan tiga ketentuan dosen (K6: Profil, Saran & Kesan, Logout) tetap tampil **literal** sebagai ikon bottom nav — tidak hilang, hanya susunannya berubah.

`Splash` (cek session) → `Login` atau `Register` → `HomeShell` dengan **5 ikon bottom nav**:

| Posisi | Ikon | Isi / aksi |
|---|---|---|
| 1 | **Beranda** | Grid ikon fitur pendukung (seperti halaman app launcher HP): Koleksi, Konversi, Jelajah, Jejak Catatan, Tanya Numisma, Game, Sinkron. Tiap ikon membuka halaman masing-masing fitur |
| 2 | **Profil** | Foto, data, switch biometrik |
| 3 | **Scan** (tengah, dibuat lebih besar/menonjol secara visual — bukan `BottomNavigationBar` bawaan, perlu widget custom) | Aksi cepat: langsung membuka `scan_screen.dart` (pilih kamera/galeri → identifikasi AI). Bukan tab dengan halaman riwayat — ditekan, langsung aksi |
| 4 | **Saran** | Saran dan kesan mata kuliah |
| 5 | **Keluar** | Dialog konfirmasi logout (tidak punya halaman; `onTap` memunculkan dialog dan indeks tab aktif tidak berubah) |

**Implementasi bottom nav:** karena ikon ke-3 (Scan) harus tampak menonjol (ukuran lebih besar / bentuk lingkaran terangkat dari garis bottom nav), ini **tidak bisa** dibuat dari `BottomNavigationBar` bawaan Flutter apa adanya. Gunakan `Stack` berisi `Row` 4 ikon biasa (Beranda, Profil, [spasi kosong di tengah], Saran, Keluar) ditumpuk dengan satu `Positioned` tombol bulat (Scan) yang sedikit naik ke atas garis nav — mirip pola tombol kamera di aplikasi Instagram/TikTok. Detail widget dirancang saat implementasi `home_shell.dart` (Hari 2), tidak mengubah kontrak service di Bagian 8.

Grid Beranda cukup `GridView` sederhana (`crossAxisCount: 3` atau `4`), tiap item ikon besar + label singkat di bawahnya, `onTap` membuka halaman fitur terkait lewat `Navigator.push` biasa — bukan tab baru di bottom nav.

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
  username TEXT NOT NULL UNIQUE,
  email_enc TEXT NOT NULL,          -- AES: base64(iv + ciphertext)
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
  location TEXT                     -- nama tempat (teks); lat/lng menyusul di migrasi v3 (Hari 5, lihat 7.5)
);                                  -- [0.5] kolom `note` DIHAPUS (tidak punya isian di form)
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
- `email_enc` dan `notes_enc` terenkripsi, jadi **pencarian tidak mencakup kolom itu**. Login memakai `username` (bukan email).
- Foto disimpan sebagai file di folder aplikasi; tabel hanya menyimpan path.

**[0.5] Versi database naik dari 1 ke 2** (hanya `events` berubah, `reminders` dibuat ulang agar urutannya benar).
- `onUpgrade` 1→2: `DROP TABLE reminders`, `DROP TABLE events`, lalu buat ulang keduanya. Aman karena keduanya hanya berisi data seed atau kosong. Tabel lain tidak disentuh.
- **`onCreate` wajib memakai skema v2 juga** (untuk HP yang bersih, mis. HP penguji). Uji kedua jalur: instal baru dan upgrade dari v1.
- `events` dan `reminders` **tidak ikut sinkron Supabase** (tetap hanya `coins`, `chain_blocks`, `collector_spots`).
- **[0.5] Migrasi v3 (direncanakan Hari 5, saat peta dibuat):** `ALTER TABLE events ADD COLUMN lat REAL` dan `ADD COLUMN lng REAL` (boleh NULL; acara lama tetap valid tanpa titik). Tidak ada tabel yang dibuat ulang, jadi data tidak hilang. `onCreate` pada saat itu juga wajib memakai skema v3.

### 5.2 Supabase (online)
Jalankan di SQL Editor. Anon key harus bisa `select`, `insert`, `update` pada tabel ini. Atur RLS sesuai kebutuhan demo (nonaktif atau policy permisif) dan **catat sebagai keterbatasan keamanan**.

```sql
create table coins (
  id text primary key,
  user_key text not null,            -- = username (tanpa Supabase Auth)
  type text not null,
  country text not null,
  currency_code text not null,
  denomination double precision not null,
  year int,
  condition text,
  buy_price double precision,
  buy_currency text,
  notes_enc text,
  ai_summary text,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table chain_blocks (
  id text primary key,               -- "{user_key}:{idx}"
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

create table collector_spots (
  id bigint generated always as identity primary key,
  name text not null,
  city text,
  lat double precision not null,
  lng double precision not null,
  type text,                         -- museum, bank, toko antik, pasar, komunitas
  note text,
  verified boolean not null default false
);
```

### 5.3 Data seed (aset lokal)
Format di Lampiran C. Isi:
- `coins_seed.json`: 30-50 koin dan uang kertas contoh (dipakai mini game dan data demo). Data contoh, bukan klaim katalog.
- ~~`events_seed.json`~~ **[0.5] dihapus.** Acara dibuat manual oleh pengguna; daftar awalnya kosong (tampilkan keadaan kosong yang jelas).
- `currencies_seed.json`: 44 mata uang (`code`, `name`, `country`), dibaca langsung dari asset lewat `CurrencyService` (bukan dimasukkan ke SQLite).
- `spots_seed.json`: 5-10 spot yang **sudah diverifikasi sendiri**. Bila belum diverifikasi, tandai `verified: false` dan beri label "belum diverifikasi" di UI.

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

### 6.2 Gemini API (REST)
- **Akses:** `http`, header `x-goog-api-key`. Key dari AI Studio, dibaca dari `.env` (Bagian 3.1). Tanpa SDK.
- **Daftar model:** `GET https://generativelanguage.googleapis.com/v1beta/models`. Pilih model varian **Flash atau Flash-Lite** yang mendukung `generateContent`, simpan namanya di `shared_preferences` (kunci `gemini_model`). Bila gagal, pakai nama model terakhir yang tersimpan.
- **Generate:** `POST https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent`. Isi: teks prompt + gambar `inline_data` (mime `image/jpeg`, data base64) dan meminta keluaran JSON.
- **Belum diverifikasi:** penulisan field persis (snake_case atau camelCase, `systemInstruction`, `responseMimeType`). **Cek dokumentasi resmi (ai.google.dev) dan uji dengan satu foto di AI Studio sebelum menulis kode.**
- **Status model (sumber saling bertentangan):** `gemini-1.5-flash` sudah dimatikan. Halaman deprecations Google mencantumkan jadwal shutdown `gemini-2.5-flash` pada 17 Juni 2026 dengan pengganti `gemini-3-flash-preview`, sementara sumber lain masih menyebut 2.5 Flash. **Karena itu nama model diambil dari ListModels, bukan ditulis permanen.**
- **Free tier:** ada untuk Flash dan Flash-Lite. Batas berbeda per model dan bisa berubah, jadi cek di AI Studio. Di free tier Google boleh memakai input dan output untuk meningkatkan modelnya (aman untuk foto koin).
- **Penanganan error:** 429 / `RESOURCE_EXHAUSTED` → pesan ramah "kuota AI habis, coba lagi nanti" + opsi isi manual. Timeout 30 detik.
- **Cadangan demo:** simpan satu respons contoh (JSON) untuk tombol "Gunakan hasil contoh" bila internet atau kuota bermasalah.
- Prompt ada di Lampiran B.

### 6.3 Supabase
- Inisialisasi `supabase_flutter` dengan `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dari `.env` (Bagian 3.1).
- Pola pakai: `supabase.from('coins').upsert(...)`, `supabase.from('collector_spots').select()`.
- Hanya sebagai database. Tanpa Auth dan Storage.

### 6.4 OpenStreetMap (peta)
- Tile: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, isi `userAgentPackageName` dengan nama paket aplikasi.
- Tampilkan atribusi "© OpenStreetMap contributors".
- Tile publik hanya untuk skala kecil (demo), tidak untuk muatan besar.
- Nominatim dan Overpass **tidak dipakai**.

### 6.5 Yang sengaja tidak dipakai
Numista (free plan tanpa pencarian-gambar dan mewajibkan atribusi), Overpass (data toko koin di OSM tidak pasti), Firebase (dilarang), FastAPI atau backend sendiri (tidak perlu).

---

## 7. Spesifikasi Fitur

Format: tujuan, layar, alur, implementasi, aturan, **selesai bila** (acceptance), dan file utama.

### 7.1 K1 — Konsep
Numisma sesuai Bagian 1. Di laporan: tema dan landasan teori numismatik (definisi, nilai nominal vs nilai koleksi, faktor kondisi), lihat Lampiran D.

### 7.2 K2 — Login terenkripsi dan session
- **Layar:** `splash`, `login`, `register`.
- **Registrasi:** username (4-20 karakter, huruf/angka/garis bawah, unik), email valid, password minimal 8 karakter + konfirmasi.
  - `password_hash` = **bcrypt** dari password (bcrypt sudah memuat salt).
  - `email_enc` = **AES** dari email (kunci AES dibuat sekali, disimpan di `flutter_secure_storage`; IV acak disimpan bersama ciphertext).
- **Login:** cari user dari `username`, bandingkan dengan bcrypt. Berhasil → buat session.
- **Session:** `SessionStore` menyimpan `user_id`, `token` acak, `expires_at` (+7 hari). `Splash` mengecek validitas.
- **Penjelasan untuk laporan:** hash untuk password (satu arah, tidak bisa dikembalikan), enkripsi AES untuk data yang perlu dibaca kembali (email, catatan).
- **Selesai bila:** restart aplikasi tetap login; logout menghapus session; di DB tidak ada password asli maupun email asli (T22, T23).
- **File:** `auth_service.dart`, `crypto_util.dart`, `session_store.dart`, `screens/auth/*`.

### 7.3 K3 — Login biometrik
- **Alur:** setelah login password, di Profil pengguna menyalakan "Masuk dengan sidik jari" (meminta autentikasi biometrik dulu). Simpan `biometric_enabled=1` dan `last_biometric_user_id` di `shared_preferences`. Di layar login muncul tombol "Masuk dengan sidik jari". Berhasil → buat session untuk `last_biometric_user_id`.
- **Implementasi:** `local_auth` (`canCheckBiometrics`, lalu `authenticate`). Biometrik gagal, batal, atau tidak tersedia → sembunyikan tombol atau tampilkan pesan, login password tetap bisa.
- **Catatan:** wajib diuji di HP asli dengan sidik jari terdaftar.
- **Selesai bila:** T06, T07.
- **File:** `biometric_service.dart`, `login_screen.dart`, `profile_screen.dart`.

### 7.4 K4 — Database lokal dan online
- **Lokal:** semua data di SQLite; aplikasi tetap bisa dipakai offline.
- **Online:** dua tombol di Koleksi:
  - **Unggah:** kirim koin `is_synced=0` dan blok rantai `is_synced=0` ke Supabase (`upsert`, `user_key` = username), lalu tandai `is_synced=1`.
  - **Pulihkan:** ambil koin dan blok milik username itu dari Supabase, masukkan yang belum ada di lokal. Foto tidak ikut (tampilkan placeholder).
- **Tanpa penyelesaian konflik.** Tulis di laporan sebagai keterbatasan.

> **Perbaikan (ditemukan lewat audit guide + ditemukan ulang secara independen saat implementasi Hari 2, ditambal 21 Okt — kodenya dikerjakan Hari 4-5):**
> - **Koin terhapus tidak boleh "hidup lagi" saat Pulihkan.** Tanpa perbaikan, koin yang sudah dihapus lokal (padahal pernah di-Unggah) akan dianggap "belum ada di lokal" dan masuk lagi saat Pulihkan. **Perbaikan:** sebelum memasukkan satu koin ke lokal, `restore()` cek blok rantai **terakhir** untuk `coin_id` itu (gabungan blok lokal + remote, urut `idx`) — kalau aksi terakhirnya `DELETE`, **jangan** dipulihkan. Syarat: `CoinRepo.delete()` wajib membaca data koin dulu (untuk snapshot hash) **sebelum** menghapus baris, dan wajib menambah blok `DELETE` (bukan cuma hapus baris diam-diam).
> - **Normalisasi format waktu dari Supabase.** Kolom `timestamptz` di Supabase bisa balik dalam format berbeda dari `TEXT ISO-8601 UTC` yang dipakai SQLite. Saat `restore()`, parse dulu nilai `ts`/`created_at`/`updated_at` yang diterima, lalu simpan ulang sebagai `.toUtc().toIso8601String()` supaya format lokal selalu konsisten. **Belum diverifikasi** bentuk string aslinya dari Supabase — cek dengan `curl` ke REST endpoint-nya setelah satu blok terunggah, sebelum menulis parser.
> - **Selesai bila (tambahan):** hapus koin → Unggah → Pulihkan di perangkat lain/setelah hapus data → koin yang terhapus **tidak** muncul kembali.

- **Selesai bila:** tambah koin → Unggah → hapus data aplikasi → daftar ulang dengan username yang sama → Pulihkan → koleksi dan Jejak Catatan kembali (T18).
- **File:** `sync_service.dart`.

### 7.5 K5 — Web service/API dan LBS
- **API dipakai:** Frankfurter, Gemini, Supabase REST (Bagian 6). Di laporan, dokumentasikan endpoint, contoh request, dan contoh respons masing-masing.
- **LBS (tab Jelajah):**
  1. Minta izin lokasi dan ambil posisi (`geolocator`).
  2. Muat `collector_spots` dari Supabase (cadangan: `spots_seed.json`), hitung jarak (`Geolocator.distanceBetween`), urutkan terdekat.
  3. Tampilkan di `flutter_map` (marker pengguna dan spot) dan daftar di bawah peta.
  4. Bila tidak ada spot dalam 50 km, tampilkan yang terdekat beserta jaraknya.
  5. **Lokasi manual:** tekan lama pada peta untuk menetapkan posisi (untuk GPS lemah di dalam ruangan).
  6. Spot `verified=false` diberi label "belum diverifikasi".
  7. **[0.5] Satu peta, dua lapisan:** selain marker spot kolektor, peta menampilkan **marker acara milik pengguna** yang punya titik lokasi (`events.lat`/`lng`, migrasi v3 di 5.1), dengan jarak dari posisi GPS pengguna dan urutan terdekat. Spot kolektor **tidak digantikan** acara: LBS adalah layanan berbasis **posisi pengguna** (GPS, jarak, terdekat), dan spot memberi isi yang bermakna saat demo; memilih titik saja bukan LBS.
  8. **[0.5] Pemilih lokasi di form acara** memakai komponen peta yang sama (tekan lama pada peta menetapkan titik, seperti lokasi manual di poin 5). Nama tempat tetap diketik manual karena geocoding (Nominatim) di luar lingkup (Bagian 1.5).
  9. **[0.5] Opsional, paling akhir bila Hari 5 ada sisa waktu:** tombol "Buka di Google Maps" lewat tautan koordinat (paket `url_launcher`, **tanpa** SDK Google Maps dan tanpa API key). Ini menambah di luar lingkup Bagian 1.5, jadi dicatat sebagai keputusan sengaja.
- **Selesai bila:** T19.
- **File:** `spot_service.dart`, `explore_screen.dart`.

### 7.6 K6 — Profil, Saran dan Kesan, Logout
- **Profil:** foto dari kamera atau galeri (`image_picker`), disalin ke folder aplikasi, path ke `users.photo_path`. Tampilkan username, email (didekripsi), switch biometrik.
- **Saran dan Kesan:** form rating bintang (1-5), saran, kesan, khusus mata kuliah Pemrograman Aplikasi Mobile. Simpan ke `feedback`, riwayat tampil di bawah form.
- **Logout:** dialog konfirmasi → hapus session → ke Login.
- **Selesai bila:** T21 dan screenshot tiap tab.
- **File:** `profile_screen.dart`, `feedback_screen.dart`, `home_shell.dart`.

### 7.7 K7 — Konversi mata uang dan waktu (terpadu konsep)

**a. Kurs dan Nilai Koleksi** (convert_screen.dart punya 3 tab: Kurs, Nilai Koleksi, Jam Dunia)
- Tab **Kurs**: jumlah, mata uang asal dan tujuan (pemilih 44 mata uang, Bagian 6.1), tombol Tukar, hasil langsung, tanggal kurs.
- Tab **Nilai Koleksi**: total `denomination × kurs(currency_code → mata uang tujuan)` seluruh koleksi dalam **IDR** dan satu mata uang pilihan. Kurs diambil sekali per mata uang berbeda. **Label wajib: "nilai nominal setara".** Koin tanpa kurs **tidak dianggap 0**: tampilkan jumlah yang dilewati; tanggal kurs yang ditampilkan adalah yang **terlama**.
- Offline atau akhir pekan → pakai `rates_cache` dan tampilkan tanggal kurs. Tarik-untuk-menyegarkan ada di tab Kurs, Nilai Koleksi, Jam Dunia, dan daftar Koleksi.

**b. Jam Dunia dan Acara** [0.5, menggantikan versi lama]
- **Satu jam** yang berdetak tiap detik (jam:menit:detik, tanggal, singkatan zona). Zona dipilih lewat pilihan: **WIB** (`Asia/Jakarta`), **WITA** (`Asia/Makassar`), **WIT** (`Asia/Jayapura`), **UTC** (`Etc/UTC`; nama `UTC` tidak ada di paket `timezone`), dan **London** (`Europe/London`, **opsional**: bukan wajib, dipertahankan karena membuktikan DST pada T11).
- **UTC ≠ London.** London = UTC+0 (GMT) di musim dingin, tetapi UTC+1 (BST) di musim panas (sampai 25 Okt 2026). Jangan menyamakan keduanya.
- **Kartu acara:** tiap kartu menampilkan **satu zona** (jam, tanggal, singkatan) dengan pilihan zona sendiri. Default WIB.
- **Tambah acara manual** (`event_form_screen.dart`): judul (wajib), lokasi (opsional), tanggal (date picker), jam (time picker). **Jam input dibaca sebagai WIB** (label "Waktu dalam WIB"), lalu disimpan UTC bersama `user_id` akun yang login. Form **tidak punya pilihan zona input** (keputusan 0.5): jam selalu dibaca WIB, dan pengguna melihat waktu acara di zona lain lewat pilihan zona di tiap kartu.
- **Hapus acara** dengan dialog konfirmasi; sekaligus membatalkan pengingatnya. **Edit acara ditunda** (hapus lalu buat ulang).
- Acara yang sudah lewat ditandai "Sudah lewat" dan tidak bisa diberi pengingat. Daftar kosong menampilkan teks "Belum ada acara. Tekan + untuk menambah."
- **Uji DST London (T11)**, otomatis lewat `test/time_util_test.dart`: DST London berakhir Minggu 25 Okt 2026.
  - **20:00 London pada 24 Okt 2026** (BST, UTC+1) = **02:00 WIB 25 Okt 2026** (selisih 6 jam).
  - **20:00 London pada 26 Okt 2026** (GMT, UTC+0) = **03:00 WIB 27 Okt 2026** (selisih 7 jam).
- **File:** `rates_service.dart`, `time_util.dart`, `format_util.dart`, `event_repo.dart`, `convert_screen.dart`, `collection_value_tab.dart`, `world_clock_tab.dart`, `event_form_screen.dart`.

### 7.8 K8 — Dua sensor

> **Keputusan (Hari 2):** dua sensor ini **dipisah perannya** supaya tidak ada masalah "foto sisi satunya dari mana" (koin/uang kertas di koleksi cuma punya satu foto per item, lihat Bagian 5.1 dan 7.9a).

| Sensor | Dipakai di | Objek | Efek |
|---|---|---|---|
| **Gyroscope** | `coin_detail_screen.dart` — item koleksi **asli** milik pengguna (koin **maupun** uang kertas, keduanya sama-sama baris di tabel `coins` dengan `type` berbeda) | Foto asli yang sama (satu-satunya yang tersimpan) | Kemiringan/rotasi HP menggeser tampilan (efek tilt/parallax) — **bukan** mengungkap sisi lain, cuma melihat foto yang sama dari "sudut" berbeda, jadi aman walau cuma satu foto |
| **Accelerometer** | **Coin Flip** — mini-fitur mandiri, **tidak terikat** koin koleksi tertentu (lihat 7.10) | Widget generik `widgets/coin_face.dart` (lingkaran polos, tanpa gambar berlisensi) | Goyang HP → animasi berputar cepat → berhenti random di Head/Tail, seperti lempar koin fisik |

**Catatan — scan juga berlaku untuk uang kertas:** perlu digarisbawahi, fitur Scan AI (7.9a) dan efek gyroscope tilt di atas **sama-sama berlaku untuk kedua jenis item** — koin maupun uang kertas — karena keduanya disimpan di tabel yang sama (`coins`, kolom `type IN ('coin','banknote')`) dan prompt Gemini (Lampiran B.1) sudah meminta AI menentukan `type` sendiri dari foto. Tidak ada jalur terpisah untuk uang kertas; satu alur scan dan satu alur tampilan detail berlaku untuk keduanya.

- Deteksi goyang: besar percepatan melewati ambang (mulai coba sekitar 15 m/s²) dengan jeda 1 detik. Sesuaikan lewat uji di HP.
- Batalkan langganan stream sensor di `dispose`.
- GPS dipakai untuk LBS (7.5) dan dihitung terpisah dari dua sensor ini.
- **Selesai bila:** T12, T13.
- **File:** `coin_detail_screen.dart` (gyroscope), `game_screen.dart` (accelerometer, lihat 7.10), `widgets/coin_face.dart`.

### 7.9 K9 — AI dan LLM
**a. Scan koin (AI Vision)** — `scan_screen.dart`
1. Pilih foto dari kamera atau galeri (diperkecil lewat `image_picker`).
2. Kirim ke Gemini dengan prompt Lampiran B.1 (jawaban JSON).
3. Tampilkan hasil di form yang bisa diedit dengan catatan **"Estimasi AI, bukan penilaian ahli"**.
4. Pengguna konfirmasi → simpan koin + tambah blok rantai (`photo_source` = camera atau gallery).
5. Gagal (kuota, jaringan, JSON tidak valid) → pesan ramah + isi manual + tombol "Gunakan hasil contoh".

**Catatan — tiga jalur menambah koin, foto WAJIB di ketiganya (keputusan Hari 2, revisi dari rancangan awal):** scan bukan satu-satunya cara. Tombol **"Tambah"** di tab Koleksi (beda dari tombol "Scan AI") membuka `coin_form_screen.dart` untuk diisi **manual**: semua field (negara, nominal, tahun, dst) diisi sendiri oleh pengguna, **tanpa** dikirim ke Gemini. Bedanya dengan Scan bukan soal ada-tidaknya foto, tapi soal **siapa yang membaca fotonya**:

| Jalur | Foto dikirim ke Gemini? | Field diisi oleh |
|---|---|---|
| Scan — kamera | Ya | AI (bisa diedit) |
| Scan — galeri | Ya | AI (bisa diedit) |
| Tambah manual | **Tidak** — foto (kamera/galeri) tetap **wajib dilampirkan** lewat `image_picker` saat **menambah**, hanya tidak diproses AI saat itu | Pengguna sepenuhnya |

**Alasan foto diwajibkan (bukan cuma opsional seperti rancangan awal):** supaya **setiap** koin baru — scan maupun manual — bisa dianalisis AI nanti lewat mode konteks koin di Tanya Numisma (7.9b). Kalau data manual ternyata salah atau kurang, AI tetap punya bukti visual untuk mengoreksi, bukan cuma percaya teks yang diketik. Validasi ini **hanya berlaku saat menambah** (`coin_form_screen.dart` mode Tambah) — **tidak** dipaksa saat **mengubah**, karena koin hasil **Pulihkan** dari Supabase (7.4) memang tidak punya foto (foto tidak ikut sinkron) dan harus tetap bisa diedit tanpa dipaksa upload foto baru.

Tidak perlu kolom baru: `photo_path`/`photo_source` tetap menandai **asal foto** (independen dari AI), sedangkan `ai_summary` tetap **null** untuk koin manual (menandai "belum/tidak pernah dianalisis AI"). Jejak Catatan tetap mencatat blok `ADD` identik untuk ketiga jalur ini — hash chain tidak membedakan asal data, hanya menghitung hash dari data koin yang akhirnya tersimpan.

**b. Chatbot "Tanya Numisma" (LLM)** — `chat_screen.dart`
- **Mode umum:** dibuka dari grid Beranda, tanya jawab numismatik umum dengan prompt sistem Lampiran B.2. Riwayat percakapan di memori selama sesi (kirim maksimal 10 pesan terakhir).
- **Mode konteks koin (fitur "Tanya Numisma tentang koin ini"):** tombol di `coin_detail_screen.dart` membuka `chat_screen.dart` dengan parameter opsional `contextCoin`. Saat ada `contextCoin`:
  1. Baca file foto dari `photo_path` koin itu **kalau ada** (apapun asalnya — scan atau dilampirkan manual) dan field data yang tersimpan saat ini (`country`, `currency_code`, `denomination`, `year`, `condition`, `ai_summary` bila terisi).
  2. Kirim foto (bila ada) + ringkasan data itu sebagai bagian pesan pertama ke Gemini, sebelum pertanyaan pengguna. Untuk koin hasil Scan, ini berarti AI **melihat ulang** gambar yang sama (bukan cuma percaya teks hasil scan sebelumnya). Untuk koin manual yang dilampiri foto tapi `ai_summary` masih null, ini justru **kali pertama** AI melihat fotonya — mekanismenya sama, cuma "dulunya belum pernah dianalisis AI", dan karena foto **wajib** saat menambah (lihat 7.9a), ini berlaku untuk hampir semua koin manual.
  3. **Pengecualian tanpa foto sama sekali — hanya koin hasil Pulihkan dari Supabase** (7.4): karena foto tidak ikut sinkron, koin yang dipulihkan bisa punya `photo_path = null` meski aslinya pernah ada foto di perangkat lain. Untuk koin seperti ini, AI cuma punya teks yang tersimpan, tanpa bukti visual untuk dicek ulang.
  4. **Revisi tetap manual:** kalau dari obrolan AI menyarankan data berbeda dari yang tersimpan, pengguna harus membuka sendiri `coin_form_screen.dart` (tombol Edit) untuk mengubahnya. Chat **tidak** menulis balik ke database secara otomatis — supaya pengguna tetap mengonfirmasi setiap perubahan data (konsisten dengan Bagian 1.6) dan implementasinya tetap sederhana (tidak perlu function-calling/tool-use dari Gemini ke database).
  5. Tanda tangan `gemini_service.chat(history, userMessage)` di Bagian 8 **tidak berubah** — koin opsional ini cuma menambah isi pesan pertama di `chat_screen.dart`, bukan mengubah kontrak service.
- **Selesai bila:** T14, T15.
- **File:** `gemini_service.dart`, `chat_screen.dart`, `coin_detail_screen.dart`.

### 7.10 K10 — Mini game "Tebak Asal Koin" + Coin Flip

**a. Tebak Asal Koin**
- 10 soal dari `coins_seed.json`. Tiap soal menampilkan satu koin sebagai widget (`coin_face`: lingkaran dengan nominal dan kode mata uang; **tanpa gambar berlisensi**) dan 4 pilihan negara.
- Skor disimpan ke `game_scores`; tampilkan skor tertinggi.

**b. Coin Flip (pembawa fitur accelerometer, lihat 7.8)**
- Bukan kuis — ini mini-toy lempar koin. Tombol atau goyang HP (accelerometer, ambang ~15 m/s²) memicu animasi `coin_face` berputar cepat lalu berhenti random di **Head** atau **Tail** (50/50, `Random.secure()` seperlunya).
- Sengaja memakai widget generik (bukan foto koin koleksi asli) — karena ini bukan representasi item koleksi tertentu, jadi tidak ada masalah "harus ada dua sisi foto asli" (lihat catatan di 7.8).
- Ditempatkan di tab/halaman yang sama dengan Tebak Asal Koin (`game_screen.dart`), sebagai dua mode berbeda dalam satu screen.
- **Selesai bila:** T16.
- **File:** `game_service.dart`, `game_screen.dart`.

### 7.11 K11 — Pencarian dan pemilihan
- Kolom cari (negara, nominal, tahun) dengan `LIKE`. **Tidak mencakup `notes_enc`.**
- Filter: jenis (koin atau uang kertas), kondisi, rentang tahun. Urut: tahun, nominal, terbaru.
- **Pemilihan:** tekan lama untuk masuk mode multi-pilih; AppBar menampilkan jumlah terpilih, **total nilai nominal setara** dari koin terpilih, dan tombol hapus.
- **Selesai bila:** T09.
- **File:** `coin_repo.dart`, `collection_screen.dart`.

### 7.12 K12 — Notifikasi [0.5, menggantikan versi lama]
- **Pengingat per acara:** tombol **"Ingatkan saya"** dengan pilihan cepat (5 menit, 15 menit, 30 menit, 1 jam, 1 hari) dan **"Atur sendiri"** (angka + menit/jam). Disimpan di `reminders`; satu acara maksimal satu pengingat (pasang baru = ganti baris lama).
- **Cara hitung:** `waktu_pengingat = start_utc − selisih`. Pengguna memilih **selisih**, bukan jam alarm. Di "Atur sendiri": angka (minimal 1) + satuan (menit/jam/hari). Id notifikasi Android = `event_id` (tabel `reminders` tidak punya kolom `notif_id`).
- **Alarm eksak** (`zonedSchedule` dengan mode eksak): jadwal diserahkan ke sistem Android, jadi **hampir tepat waktu dan tetap muncul walau aplikasi ditutup** (digeser dari recents). Syarat: pembatasan baterai HP dimatikan (Bagian 12) dan izin alarm eksak aktif.
  - **Izin alarm eksak:** bila belum aktif, aplikasi **mengarahkan pengguna ke pengaturannya**. Bila tetap ditolak, penjadwalan **turun ke mode tidak eksak** (bisa terlambat beberapa menit) dan memberi tahu pengguna, tidak gagal diam-diam.
  - Nama izin dan receiver persis (alarm eksak, `RECEIVE_BOOT_COMPLETED`, receiver boot plugin, desugaring) **belum diverifikasi**: cek README `flutter_local_notifications` versi terpasang (22.3.2) sebelum menulis kode.
- **Keadaan pengingat di kartu** (diturunkan dari waktu; baris `reminders` tidak dihapus sendiri):
  - `remind_at` di masa depan → "Pengingat: N menit sebelum" + tombol **Batalkan**.
  - `remind_at` sudah lewat, acara belum mulai → "Pengingat sudah lewat" + tombol **Ingatkan lagi**.
  - Acara sudah mulai → "Sudah lewat", tanpa tombol pengingat.
- **Validasi:** pengingat harus di masa depan; bila tidak, pesan jelas (bukan error).
- Baris `reminders` dihapus hanya saat **Batalkan**, **hapus acara**, atau **diganti** pengingat baru.
- **Jadwalkan ulang saat aplikasi dibuka:** setelah `NotifService.init`, semua `reminders` dengan `remind_at` di masa depan dijadwalkan ulang (id sama, tanpa ganda). Perlu karena **force-stop membatalkan semua alarm**; pengingat yang jatuh tempo selama force-stop tidak bisa muncul (perilaku Android).
- **Tombol uji tetap:** **"Kirim notifikasi uji sekarang"** dan **"Uji dalam 10 detik"** (memakai jalur penjadwalan yang sama, jadi membuktikan "jalan saat aplikasi ditutup").
- Android 13+: minta `POST_NOTIFICATIONS` saat runtime.
- **Selesai bila:** T20, T24, T27, T28.
- **File:** `notif_service.dart`, `event_repo.dart`, `convert_screen.dart`.

### 7.13 K13 — Jejak Catatan (blockchain sederhana)
**Tujuan:** setiap penambahan, perubahan, atau penghapusan koin dicatat sebagai blok yang terhubung lewat hash. Perubahan data di luar rantai terdeteksi.

**Blok:** `idx`, `ts`, `coin_id`, `action` (GENESIS/ADD/UPDATE/DELETE), `data_hash`, `photo_hash`, `photo_source`, `prev_hash`, `nonce`, `hash`.

**Aturan hash:**
- `data_hash` = SHA-256 dari **JSON kanonik** (kunci terurut) snapshot koin berisi `id, type, country, currency_code, denomination, year, condition, buy_price, buy_currency`. **Jangan** menyertakan `notes_enc`, `ai_summary`, `photo_path`, atau timestamp (ciphertext AES berubah tiap enkripsi karena IV acak). **Jaga tipe data** tiap field tetap sama (`double` tetap `double`, `int` tetap `int`) saat membuat snapshot — kalau sekali dibuat sebagai `"100"` (string) dan lain kali `100` (angka), hash-nya beda walau nilainya "sama", dan verifikasi akan salah mengira data berubah.
- `photo_hash` = SHA-256 byte foto saat koin ditambahkan atau diubah.
- `hash` = SHA-256 dari gabungan `idx|ts|coin_id|action|data_hash|photo_hash|photo_source|prev_hash|nonce`. **Konvensi nilai `null`:** field manapun yang `null` (misal `coin_id` pada blok genesis, atau `photo_hash`/`photo_source` kalau tidak ada foto) ditulis sebagai **string kosong `""`** saat digabung — bukan `"null"` dan bukan dilewati. Konvensi ini harus persis sama dipakai saat membuat hash maupun saat verifikasi, kalau tidak, hash tidak akan pernah cocok meski datanya benar.
- **Proof-of-work ringan:** cari `nonce` hingga `hash` diawali `"00"`. **Berlaku untuk SEMUA blok tanpa kecuali, termasuk blok genesis** — genesis juga harus melalui pencarian nonce yang sama. Kalau genesis dilewatkan dari PoW, verifikasi akan selalu gagal di blok 0 untuk setiap akun.
- Blok genesis: `idx=0`, `action=GENESIS`, `coin_id=null` (→ `""` saat dihash, lihat konvensi di atas), `prev_hash` = 64 karakter `0`, **tetap dicari nonce-nya sampai hash diawali `"00"`**. Dibuat saat registrasi.

**Verifikasi rantai (tombol "Verifikasi"):**
1. Urutkan blok per `idx`. Tiap blok: hitung ulang `hash` dan cocokkan; cek diawali `"00"`; cek `prev_hash` sama dengan `hash` blok sebelumnya.
2. Untuk tiap koin yang masih ada: ambil blok terakhirnya (ADD/UPDATE), hitung ulang `data_hash` dari baris koin saat ini dan cocokkan. Bila foto ada, hitung ulang `photo_hash` dan cocokkan.
3. Tampilkan per blok "✔ utuh" atau "✘ berubah", dan ringkasan "Catatan utuh" atau "Catatan telah diubah".

**Tombol uji (khusus demo):** "Ubah data diam-diam" menjalankan `UPDATE` langsung ke tabel `coins` tanpa menambah blok, sehingga verifikasi gagal pada koin itu.

**Penamaan di UI:** menu **"Jejak Catatan"**, bukan "Sertifikat". Teks bantuan: "Menjamin catatan tidak diubah diam-diam. Tidak membuktikan keaslian atau kepemilikan koin fisik."

- **Selesai bila:** T16 (valid), T17 (data diubah diam-diam → ✘), T18 (rantai ikut pulih).
- **File:** `chain_service.dart`, `chain_screen.dart`.

---

## 8. Kontrak Antarmuka Service (supaya banyak AI tetap konsisten)

Tanda tangan di bawah adalah pedoman nama dan tipe. Boleh menambah parameter opsional, tidak boleh mengubah nama.

```dart
// auth_service.dart
Future<User> register({required String username, required String email, required String password});
Future<User?> login(String username, String password);
Future<void> logout();
Future<User?> currentUser();

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
                       Uint8List? photoBytes, String photoSource = 'none'});
Future<ChainVerifyResult> verify(int userId);

// gemini_service.dart
Future<String> resolveModel();                              // dari ListModels, disimpan di prefs
Future<CoinGuess> identifyCoin(Uint8List jpegBytes);        // kunci JSON Lampiran B.1
Future<String> chat(List<ChatMsg> history, String userMessage);

// sync_service.dart
Future<SyncResult> upload(User user);
Future<SyncResult> restore(User user);

// event_repo.dart  [0.5 baru]
Future<List<Event>> list(int userId);
Future<Event> add({required int userId, required String title, required DateTime startUtc, String? location});
Future<void> delete(int eventId);

// notif_service.dart  [0.5: parameter selisih]
Future<void> init();
Future<void> scheduleEventReminder(Event event, Duration before);
Future<void> cancelEventReminder(int eventId);
Future<void> rescheduleAll();                               // dipanggil setelah init
Future<void> showTestNow();
Future<void> showTestIn(Duration d);

// rates_service.dart  [0.5 tambahan, parameter opsional]
Future<RateInfo> getRateInfo(String from, String to, {bool forceRefresh = false});
Future<CollectionValue> valueOfCoins(List<Coin> coins, String target, {bool forceRefresh = false});

// time_util.dart
DateTime toZone(DateTime utc, String zoneName);             // Asia/Jakarta, Asia/Makassar, Asia/Jayapura, Etc/UTC, Europe/London
String formatZone(DateTime utc, String zoneName);
String formatZoneTime(DateTime utc, String zoneName);       // [0.5] "02:00"
String formatZoneDate(DateTime utc, String zoneName);       // [0.5] "25 Okt 2026"
String formatClock(DateTime utc, String zoneName);          // [0.5] "14:05:09"
```

---

## 9. Rencana Kerja 7 Hari

Hari ini (19 Okt) tinggal sisa sore dan malam, jadi biometrik digeser ke hari 2.

| Hari | Tanggal | Target | Tanda selesai |
|---|---|---|---|
| 1 | Sen 19 Okt | `flutter doctor` dan tes di HP, akun Supabase dan Gemini, buat proyek dan paket, `theme.dart`, skema SQLite lengkap, register/login (bcrypt) + session. Tes 1 foto koin di AI Studio. Buat kerangka laporan | Daftar, login, tutup lalu buka tetap login |
| 2 | Sel 20 Okt | Biometrik, AES, bottom nav, Profil (foto), Saran dan Kesan, Logout, CRUD koleksi, cari dan filter | Aplikasi utuh dan berguna offline |
| 3 | Rab 21 Okt | Kurs v2 + cache, konversi, Nilai Koleksi, jam dunia, acara manual, notifikasi (alarm eksak), sensor gyroscope | Konversi dan jam benar, notifikasi uji muncul |
| 4 | Kam 22 Okt | Scan Gemini, chatbot, Jejak Catatan (hash chain + PoW), mini game | Alur scan sampai blok baru jalan |
| 5 | Jum 23 Okt | Sinkron Supabase, peta + spot manual, poles, uji penuh di HP, tabel pengujian, build APK. **Fitur beku di akhir hari** | Semua K1-K13 ada |
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
5. Peta hanya dari `spots_seed.json`, tanpa Supabase.

**Percetakan:** hari 7 jatuh pada Minggu. Pastikan ada tempat cetak yang buka, atau selesaikan laporan di hari 6.

---

## 10. Rencana Pengujian (Black Box)

Format lembar evaluasi (kolom "Hasil aktual" dan "Status" diisi saat menguji di HP):

| ID | Fitur | Skenario | Hasil diharapkan | Hasil aktual | Status |
|---|---|---|---|---|---|
| T01 | Register | Data valid | Akun terbuat | | |
| T02 | Register | Email tidak valid atau password < 8 | Pesan error | | |
| T03 | Login | Kredensial benar | Masuk ke Beranda | | |
| T04 | Login | Password salah | Pesan gagal | | |
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
| T17 | Hash chain | Tombol "Ubah data diam-diam", verifikasi | "Catatan telah diubah" (✘) | | |
| T18 | Sinkron | Unggah, hapus data, daftar ulang, Pulihkan | Koleksi dan rantai kembali | | |
| T19 | Peta | Izin lokasi diberikan | Spot terurut jarak; lokasi manual berfungsi | | |
| T20 | Notifikasi | Buat acara 3 menit lagi, "Ingatkan saya" 1 menit sebelum, **tutup aplikasi (geser dari recents)** | Notifikasi muncul hampir tepat waktu | | |
| T21 | Logout | Keluar | Session terhapus, kembali ke Login | | |
| T22 | Enkripsi | Buka DB, lihat kolom `email_enc` dan `notes_enc` | Bukan teks asli (ciphertext) | | |
| T23 | Hash password | Buka DB, lihat `password_hash` | Diawali `$2`, bukan password asli | | |
| T24 | Notifikasi uji | Tombol uji sekarang | Notifikasi muncul segera | | |
| T25 | Nilai Koleksi | Koleksi campur mata uang; cocokkan dengan hitungan manual; pilih beberapa koin | Total dan total koin terpilih benar; koin tanpa kurs dilewati dengan keterangan | | |
| T26 | Acara | Tambah acara, ganti zona tampil, hapus acara | Waktu benar di tiap zona; hapus membatalkan pengingat | | |
| T27 | Pengingat | Pasang pengingat, force-stop, buka aplikasi lagi | Pengingat di masa depan dijadwalkan ulang dan tetap berbunyi | | |
| T28 | Pengingat | Pengingat dengan selisih lebih besar dari sisa waktu ke acara | Pesan jelas, tidak error | | |
| T29 | Migrasi DB | Instal bersih (onCreate) dan upgrade dari v1 | Skema `events` v2 benar di kedua jalur | | |

---

## 11. Demo, Laporan, PPT

### 11.1 Alur demo (sekitar 5 menit, sekaligus checklist dosen)
1. Login password, lalu login sidik jari (K2, K3)
2. Koleksi: cari, filter, pilih beberapa (K11)
3. Scan koin dengan AI, konfirmasi, simpan (K9)
4. Jejak Catatan: verifikasi utuh → "Ubah data diam-diam" → verifikasi gagal (K13)
5. Konversi kurs dan Nilai Koleksi (K7)
6. Jam dunia dan acara; notifikasi uji (K7, K12)
7. Goyang dan miringkan HP (K8)
8. Jelajah: peta dan spot terdekat (K5)
9. Tanya Numisma dan mini game (K9, K10)
10. Unggah ke Supabase (K4)
11. Profil (foto), Saran dan Kesan, Logout (K6)

**Persiapan demo di Jogja:** tes koneksi venue, aktifkan hotspot HP cadangan, siapkan hasil contoh AI, isi data spot yang sudah diverifikasi, siapkan **video rekaman cadangan**, **dan cek H-1 bahwa pembatasan baterai/latar belakang untuk app sudah dinonaktifkan di HP yang dipakai demo** (lihat Bagian 12 — ditemukan di vivo Hari 2, berpotensi muncul lagi di HP manapun kalau settingnya belum diubah).

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
| Nama model Gemini berubah atau dimatikan | AI mati saat demo | Ambil model dari ListModels, simpan di prefs, siapkan hasil contoh |
| Kuota Gemini habis | Scan gagal | Pesan ramah, isi manual, tombol hasil contoh |
| Internet venue tidak stabil | Kurs, sinkron, AI gagal | Cache kurs, mode offline, hotspot, video cadangan |
| GPS lemah di dalam ruangan | Peta kosong | Lokasi manual, tampilkan spot terdekat dengan jarak |
| Biometrik gagal di emulator | Tidak bisa diuji | Uji di HP asli |
| HP mematikan proses app di latar belakang (ditemukan di vivo Hari 2 saat buka kamera/galeri) — berpotensi terjadi lagi di HP demo manapun kalau pembatasan baterainya belum diubah | App "Lost connection"/restart mendadak, isian form hilang, bisa terjadi live saat demo | Nonaktifkan pembatasan baterai/latar belakang untuk app di HP yang dipakai, cek H-1 sebelum demo (lihat Bagian 11.1). Uji alur kamera/galeri di build `--release`, bukan cuma debug |
| Force-stop membatalkan semua alarm **[0.5]** | Pengingat tidak berbunyi | Jadwalkan ulang saat aplikasi dibuka; jelaskan di laporan |
| Pembatasan baterai vivo menunda alarm walau eksak **[0.5]** | Notifikasi terlambat | Nonaktifkan pembatasan baterai app di HP demo (cek H-1); tombol uji sebagai cadangan |
| Izin alarm eksak ditolak atau berbeda per versi Android **[0.5]** | Pengingat tidak tepat waktu | Arahkan ke pengaturan, turun ke mode tidak eksak, verifikasi README plugin dan uji di HP asli |
| Dosen menafsirkan "enkripsi" secara ketat | Poin K2 dipertanyakan | bcrypt + AES, jelaskan bedanya di laporan |
| Dosen mengharapkan API buatan sendiri | Poin K5 dipertanyakan | Tanyakan ke dosen; bila ya, tambah backend kecil (setengah hari), `sync_service` tinggal diganti |
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
- `gemini-1.5-flash` sudah dimatikan. Status model lain saling bertentangan antar sumber (Bagian 6.2).
- Free tier Gemini ada, dengan catatan penggunaan data oleh Google.
- Nominatim dibatasi 1 request per detik; tile OSM publik tidak untuk produksi.
- Numista free plan tidak mencakup pencarian-gambar dan mewajibkan atribusi (tidak dipakai).
- Paket Flutter `geolocator`, `sensors_plus`, `local_auth` ada dan dikenal untuk fungsi masing-masing.

### 13.1b Terverifikasi tambahan (21 Okt 2026) **[0.5]**
- Bentuk JSON `/v2/rate`; ke-44 mata uang seed didukung dan aktif; kurs dibulatkan kasar; nama zona `Etc/UTC` valid, `UTC` tidak; DST London lewat tes otomatis.

### 13.2 Belum diverifikasi (cek sebelum dipakai)
- **[0.5]** Izin dan receiver Android untuk alarm eksak (plugin 22.3.2); perilaku notifikasi dan izin alarm eksak di vivo V2318 saat aplikasi ditutup.
- Batas laju Frankfurter v2 (bentuk JSON sudah terverifikasi, lihat 13.1b).
- Penulisan field persis request Gemini REST dan pemakaian prompt sistem.
- Nama method versi terbaru: `sensors_plus`, `local_auth`, `flutter_local_notifications`, `supabase_flutter`, `flutter_map`, `bcrypt`, `encrypt`, `flutter_dotenv`.
- Kebijakan RLS Supabase untuk anon key.
- Keberadaan dan lokasi spot kolektor (harus diverifikasi sendiri).
- Kebutuhan `minSdk` dan desugaring yang tepat untuk set paket ini.

### 13.3 Hal terbuka untuk pemilik proyek
1. **Tanyakan ke dosen:** (a) apakah Supabase REST dan API publik cukup sebagai web service, atau harus API buatan sendiri; (b) tanggal presentasi; (c) tenggat unggah dan cetak laporan.
2. Kumpulkan dan verifikasi 5-10 spot kolektor.
3. Isi nama dan NIM pada cover dan dokumen ini.
4. Siapkan HP Android asli dengan sidik jari terdaftar, akun Supabase, dan API key Gemini.

---

## 14. Referensi

- Frankfurter: https://frankfurter.dev dan https://api.frankfurter.dev/v2/currencies; daftar v1: https://github.com/lineofflight/frankfurter/issues/144
- Gemini deprecations: https://ai.google.dev/gemini-api/docs/deprecations
- Gemini rate limits: https://ai.google.dev/gemini-api/docs/rate-limits
- Gemini models: https://ai.google.dev/gemini-api/docs/models
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

## Lampiran B — Prompt Gemini

### B.1 Scan koin (jawaban JSON)
```
Kamu adalah asisten numismatik. Analisis foto koin atau uang kertas ini.
Jawab HANYA dengan JSON valid, tanpa teks lain, dengan kunci:
- type: "coin" atau "banknote"
- country: nama negara dalam bahasa Inggris
- currency_code: kode ISO 4217 bila mata uangnya masih berlaku, jika tidak null
- denomination: angka nominal (null bila tidak terbaca)
- year: angka tahun (null bila tidak terbaca)
- features: ciri khas dalam maksimal 2 kalimat bahasa Indonesia
- confidence: "low", "medium", atau "high"
Jika tidak yakin, isi null dan confidence "low". Jangan mengarang.
```

### B.2 Chatbot "Tanya Numisma"
```
Kamu adalah "Tanya Numisma", asisten untuk kolektor koin dan uang kertas.
Jawab dalam bahasa Indonesia, singkat (maksimal 6 kalimat).
Hanya bahas numismatik: sejarah koin atau uang, perawatan, ciri umum keaslian, istilah.
Untuk pertanyaan di luar topik, tolak dengan sopan dan arahkan kembali.
Jangan memberi harga pasti atau menjamin keaslian; sarankan konsultasi ke ahli atau pedagang bereputasi.
```

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
`spots_seed.json` (isi hanya tempat yang sudah kamu cek sendiri)
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
