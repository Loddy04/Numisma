# Progres Numisma — Hari 3
**Rabu, 21 Oktober 2026 — status: SELESAI untuk fitur, dites manual oleh pengguna di HP asli dan dinyatakan aman**

> Dokumen ini merekam apa yang dikerjakan dan hasilnya per task, supaya (a) sesi Claude berikutnya paham konteks tanpa tanya ulang, dan (b) materinya siap dipakai untuk Bagian 6 "Implementasi" laporan. Format sama dengan `progres-hari-2.md`. Acuan: `NUMISMA_GUIDE_0.5.md` (lanjutan 0.4, disusun selama Hari 3).

**Target Hari 3:** konversi dan jam benar, notifikasi uji muncul, dan sensor ada. **Tercapai**, ditambah acara kolektor manual, pengingat per acara, logo dan ikon aplikasi.
**Perangkat uji:** vivo V2318, Android 16, HP asli. **Status pengujian:** dites manual oleh pengguna dan dinyatakan aman secara keseluruhan; baris tabel pengujian formal (T10, T11, T13, T20, T24–T28) belum diisi di lembar evaluasi, dan skenario force-stop serta restart HP belum dicatat hasilnya. Tes otomatis (`flutter test`): 6 lulus, mencakup konversi zona waktu dan format durasi.

---

## 1. Verifikasi API Frankfurter v2 (curl) sebelum menulis parser

**Dilakukan**: memanggil `/v2/rate/{dari}/{ke}`, `/v2/rates?base=IDR`, dan `/v2/currencies` dengan `curl`, lalu mencocokkan hasilnya dengan daftar 44 mata uang di `currencies_seed.json`.

**Hasil**:
- Bentuk respons satu pasangan: `{"date":"2026-10-20","base":"JPY","quote":"IDR","rate":113.88}`. Nilai `rate` bisa bertipe int (mis. `18025`), jadi diparse lewat `num`.
- **Ke-44 mata uang seed semuanya didukung dan aktif.** Keputusan: konversi dan Nilai Koleksi memakai 44, bukan 8 seperti Guide 6.1 versi lama.
- **Ketelitian kurs rendah:** API membulatkan kurs ke beberapa angka penting saja (IDR→EUR hanya `4.9e-05`, IDR→JPY `0.00878`), sedangkan JPY→IDR (`113.88`) jauh lebih teliti.

**Penjelasan teknis**: bila kurs langsung < 1, `rates_service.dart` meminta arah sebaliknya lalu membaliknya (1/kurs), karena angka besar kehilangan lebih sedikit ketelitian relatif. Ini penting untuk Nilai Koleksi karena banyak koin (JPY, KRW, dan sebagainya) dikonversi ke IDR.

---

## 2. Kurs, cache, dan layar Konversi (tab Kurs)

**Dilakukan**: `services/rates_service.dart` (`getRate`, `getRateInfo`, `convert`), `screens/convert/convert_screen.dart` (tiga tab), `core/format_util.dart` (format angka dan tanggal gaya Indonesia, tanpa paket `intl`), ikon **Konversi** di grid Beranda tersambung. Paket `http` dipasang lewat `flutter pub add`. Tab Kurs: jumlah, mata uang Dari dan Ke (pemilih 44 yang sudah ada), tombol Tukar, hasil langsung (tertunda 400 ms), tanggal kurs.

**Hasil**: dites di HP (T10: 1.000 JPY ke IDR sesuai kurs dan tanggal kurs tampil). Cache di `rates_cache` dengan TTL 6 jam; saat API gagal, cache lama dipakai dan layar menandai "dari cache". Pasangan yang belum pernah dipakai saat offline menampilkan pesan error ramah, bukan crash.

**Penjelasan teknis**: tarik-untuk-menyegarkan (`forceRefresh`) melewati cache segar dan bertanya ke API; bila gagal tetap jatuh ke cache. Nomor permintaan membuang hasil lama yang datang terlambat. Tarik-untuk-menyegarkan juga ditambahkan di tab Nilai Koleksi, Jam Dunia, dan daftar Koleksi.

---

## 3. Nilai Koleksi dan total di multi-pilih

**Dilakukan**: `RatesService.valueOfCoins` dan `collectionValue`, `screens/convert/collection_value_tab.dart` (tab Nilai Koleksi), dan slot "total nilai nominal setara" di AppBar mode multi-pilih Koleksi (slot yang sengaja dikosongkan di Hari 2).

**Hasil**: total koleksi dalam IDR dan satu mata uang pilihan, dengan label wajib **"nilai nominal setara"** (bukan harga pasar kolektor). Total koin terpilih di multi-pilih dihitung ulang tiap pilihan berubah.

**Penjelasan teknis**: nominal dijumlah per mata uang dulu, lalu dikali kurs sekali per mata uang (30 koin JPY = satu kali minta kurs). Koin yang kursnya tidak tersedia **tidak dianggap 0**: dihitung sebagai "dilewati" dan jumlahnya ditampilkan, supaya total jujur. Tanggal kurs yang ditampilkan adalah yang **terlama**. Ini yang membuat konversi kurs terpadu dengan konsep koleksi (syarat "terpadukan dengan konsep" pada slide dosen), bukan sekadar kalkulator umum.

---

## 4. Jam Dunia

**Dilakukan**: `core/time_util.dart` (`toZone`, `formatZone`, `formatZoneTime`, `formatZoneDate`, `formatClock`, `zoneAbbreviation`, `utcFromZone`) memakai paket `timezone`, dipanggil dari `main.dart` lewat `initTimeZones()`; `screens/convert/world_clock_tab.dart`; widget bersama `widgets/zone_picker.dart`.

**Hasil**: **satu jam** yang berdetak tiap detik dengan pilihan zona WIB, WITA, WIT, UTC (bukan empat kartu sekaligus, atas permintaan pengguna). Tiap kartu acara juga menampilkan satu zona dengan pilihan zonanya sendiri. Uji DST London (T11) **otomatis lewat `test/time_util_test.dart`**: 20:00 London 24 Okt 2026 (BST) = 02:00 WIB 25 Okt; 20:00 London 26 Okt (GMT) = 03:00 WIB 27 Okt.

**Penjelasan teknis**: semua waktu disimpan UTC; data DST dibawa paket `timezone`, tidak dihitung manual. Zona perangkat sengaja tidak dibaca. **Nama zona UTC di paket ini adalah `Etc/UTC`**: nama `UTC` saja tidak ada dan membuat aplikasi error (ditemukan lewat tes otomatis, bukan lewat HP). **UTC ≠ London** (London UTC+1 saat BST); keputusan pengguna: zona di slide dosen hanya contoh, London opsional, dan tidak ada di pilihan layar (menambahnya satu baris di `zoneOptions`).

---

## 5. Acara kolektor manual, per akun

**Dilakukan**:
- **Database v2** (`core/db_helper.dart`): `events` mendapat `user_id`, `reminders` kehilangan `notif_id`. Migrasi `onUpgrade` membuang lalu membuat ulang kedua tabel (hanya berisi data seed/kosong); tabel lain tidak disentuh. `onCreate` memakai skema yang sama.
- **Seed acara dihapus** (`events_seed.json` dan kodenya). Daftar awal kosong.
- **Database v3**: `ALTER TABLE events ADD COLUMN note TEXT` (catatan acara).
- `models/event.dart`, `services/event_repo.dart` (`list`, `getById`, `add`, `update`, `delete`).
- `screens/convert/event_form_screen.dart` (satu form untuk tambah dan ubah, dengan catatan), `event_detail_screen.dart`, widget bersama `widgets/confirm_dialog.dart`.

**Hasil**: acara bisa ditambah, dilihat, diubah, dan dihapus; data bertahan setelah aplikasi ditutup; satu set per akun. Koleksi aman setelah migrasi.

**Penjelasan teknis**: jam yang diisi **selalu dibaca WIB** (label "Jam (WIB)"), lalu disimpan UTC lewat `utcFromZone`. Kartu daftar tidak punya tombol hapus; mengetuk kartu membuka detail (catatan, pengingat, tombol Ubah dan Hapus), dan Ubah juga punya Hapus. `EventRepo.update` menghapus baris pengingat bila waktu mulai berubah (dalam satu transaksi). Waktu hanya dipaksa di masa depan bila tanggal atau jam diubah, jadi mengubah catatan acara lama tetap boleh.

---

## 6. Notifikasi lokal dan pengingat per acara

**Dilakukan**:
- **Android:** `isCoreLibraryDesugaringEnabled`, `multiDexEnabled`, dan dependensi `desugar_jdk_libs:2.1.4` di `build.gradle.kts`; izin `RECEIVE_BOOT_COMPLETED` dan `SCHEDULE_EXACT_ALARM`, serta receiver plugin di `AndroidManifest.xml`. Semuanya dari README `flutter_local_notifications` 22.3.2 (API diperiksa dari kode sumber paket).
- `services/notif_service.dart`: `init`, `showTestNow`, `showTestIn`, `scheduleEventReminder`, `cancelEventReminder`, `reminderMap`, `rescheduleAll`, `canScheduleExact`. Dipanggil di `main.dart` (init, lalu jadwal ulang).
- Kartu "Uji notifikasi" di tab Jam Dunia (tombol "Kirim sekarang" dan "Uji dalam 10 detik").
- `screens/convert/reminder_picker.dart`: pilihan cepat (5 menit, 15 menit, 30 menit, 1 jam, 1 hari) dan "Atur sendiri" (angka + menit/jam/hari).
- Bagian **Pengingat** di layar detail (Ingatkan saya, Ganti, Batalkan, Ingatkan lagi), info lonceng di kartu daftar, `formatDuration` di `format_util.dart`.

**Hasil**: **notifikasi uji muncul, termasuk saat aplikasi dimatikan** (T20, T24). Pengingat per acara dipasang, diganti, dan dibatalkan dari detail; mengubah tanggal atau jam acara membatalkan pengingatnya (dengan pesan); menghapus acara membatalkan alarmnya.

**Penjelasan teknis**: pengingat dihitung `momen acara − selisih` dan diserahkan ke sistem Android lewat `zonedSchedule` (alarm eksak bila izinnya aktif; bila tidak, turun ke mode tidak eksak dan pengguna diberi tahu), jadi tetap muncul walau aplikasi ditutup dan tidak bergantung pada zona HP. Id notifikasi = `events.id` (satu acara satu pengingat). Baris `reminders` tidak dihapus sendiri setelah berbunyi; keadaan kartu diturunkan dari waktu ("Pengingat sudah lewat" + tombol Ingatkan lagi). **Force-stop membatalkan semua alarm Android**, tetapi tabel `reminders` tetap ada, jadi `rescheduleAll` menjadwalkan ulang pengingat yang masih di masa depan saat aplikasi dibuka lagi. Pengingat yang jatuh tempo saat aplikasi force-stop tidak bisa muncul (perilaku Android).

---

## 7. Logo dan ikon aplikasi

**Dilakukan**: logo dari `assets/logo/` (koin emas dengan huruf N perunggu). `widgets/app_logo.dart` dipakai di splash, login, dan judul AppBar Beranda. Ikon launcher adaptif dibuat dengan `flutter_launcher_icons` (dev dependency; konfigurasi di `pubspec.yaml`, latar `#8C6239`, foreground `icon_foreground_1024.png`, inset 0).

**Hasil**: ikon aplikasi dan logo di layar awal sudah berganti. Hanya `logo_numisma_1024.png` yang masuk aset aplikasi (file 2048 dan SVG tidak ikut, supaya APK tidak membengkak).

---

## 8. Gyroscope (K8) dan foto koin layar penuh

**Dilakukan**: paket `sensors_plus` (memakai `gyroscopeEventStream`; README masih menyebut `gyroscopeEvents` yang di kode sudah ditandai usang). `widgets/tilt_photo.dart` dipakai di `coin_detail_screen.dart`; `screens/collection/coin_photo_viewer.dart` membuka foto layar penuh (transisi Hero, latar cokelat tua `AppColors.textDark`) saat foto diketuk, dengan tilt lebih dinamis. **Tanpa zoom cubit.**

**Hasil**: foto koin dan uang kertas bergeser halus mengikuti kemiringan HP, dan di layar penuh lebih dinamis (geser 32 piksel dan miring sekitar 11 derajat, dibanding 14 piksel dan sekitar 6 derajat di detail). Dinyatakan aman oleh pengguna.

**Penjelasan teknis**: gyroscope melaporkan **kecepatan putar** (rad/detik), bukan sudut, jadi kecepatan dijumlahkan terhadap waktu menjadi sudut, lalu "bocor" kembali ke tengah saat HP diam (supaya tidak melayang). Foto yang sama dipakai untuk koin dan uang kertas, jadi tidak ada masalah "sisi lain". HP tanpa gyroscope: foto diam, tidak crash. Langganan sensor dibatalkan di `dispose`. Bila arah geser terasa terbalik, ubah `_direction` di `tilt_photo.dart` dari `1.0` ke `-1.0`.

---

## 9. Masalah teknis yang ditemukan dan solusinya

**a. Build gagal setelah plugin notifikasi masuk (`requires core library desugaring`).** Plugin `flutter_local_notifications` sudah ada di `pubspec.yaml` (ikut commit sebelumnya) tetapi konfigurasi Android-nya belum diatur, sehingga Gradle menolak membangun aplikasi dan tes HP terhenti. Solusi: nyalakan desugaring di `build.gradle.kts` sesuai README (lihat bagian 6). Pelajaran: setelah memasang plugin yang punya syarat konfigurasi Android, atur konfigurasinya dan jalankan `flutter build apk --debug` sebelum commit.

**b. Nama zona `UTC` tidak ada di paket `timezone`.** Tertangkap oleh tes otomatis yang ditambahkan bersamaan dengan pilihan UTC. Solusi: `Etc/UTC`.

**c. `dart format` pada seluruh folder ikut mengubah file lain.** Perintah format yang saya jalankan pada `lib/core` dan `lib/widgets` merapikan `crypto_util.dart` dan `currency_picker.dart` (hanya tata letak, bukan logika), dan sudah ikut ter-commit. Ke depan format hanya dijalankan pada file yang sedang diubah.

**e. Alarm Android per perangkat, acara per akun (ditemukan lewat tinjauan dokumen ini, diperbaiki malam yang sama).** `logout()` hanya menghapus session dan `rescheduleAll()` menjadwalkan ulang pengingat semua akun, sehingga alarm akun A bisa tetap berbunyi (dengan nama acaranya) saat akun B login di HP yang sama. Perbaikan: `NotifService.cancelAllForUser(userId)` dipanggil saat logout (baris `reminders` dibiarkan agar pulih saat login lagi), dan `rescheduleAll(userId)` kini dipanggil dari `HomeShell` (bukan `main()`, karena akun belum diketahui di sana), menjadwalkan ulang pengingat akun itu **dan membatalkan alarm akun lain**. **Belum diuji di HP dengan dua akun (T29).**

**d. Pesan "Please enable Developer Mode" saat `flutter pub add` plugin.** Muncul untuk plugin yang butuh symlink di Windows, tetapi paket tetap terpasang dan build berhasil.

---

## 10. Keputusan dan perubahan dari Guide 0.4 (sudah tercatat di Guide 0.5)

- Acara kolektor **buatan pengguna, per akun** (`events` + `user_id`), tanpa seed; migrasi DB v2 (drop dan buat ulang `events` dan `reminders`).
- Kolom **`events.note` dihapus lalu ditambahkan kembali** lewat migrasi **v3** (karena detail acara menampilkan catatan). `reminders.notif_id` dihapus (id notifikasi = `event_id`). Rencana `lat`/`lng` bergeser menjadi migrasi **v4** (Hari 5, saat peta).
- Notifikasi memakai **alarm eksak** (menggantikan "tanpa izin alarm eksak" di 7.12) dengan fallback tidak eksak; pengguna **memilih selisih**, bukan jam alarm.
- **Alur UI acara:** kartu tanpa hapus, ketuk ke detail; hapus ada di detail dan Ubah; mengubah tanggal atau jam membatalkan pengingat (dipasang ulang manual).
- Daftar mata uang konversi = **44** (bukan 8). Jam Dunia = **satu jam + pilihan zona** (WIB/WITA/WIT/UTC, London opsional).
- **LBS digabung dengan acara** (satu peta, dua lapisan: spot kolektor + acara pengguna; spot kolektor tidak digantikan). "Buka di Google Maps" opsional paling akhir (`url_launcher`).
- AI/LLM tetap **Gemini** (Vision untuk scan, chat untuk Tanya Numisma, dua fitur terpisah). **9router/Hermes ditunda** sebagai cadangan setelah K1–K13 selesai. Pertanyaan ke dosen soal "API buatan sendiri" **masih terbuka** (Guide 13.3).
- Foto koin layar penuh dengan tilt dan tanpa zoom cubit (Guide 7.8 sudah diperbarui).

---

## 11. Perbedaan kode dengan Guide 0.5 (SUDAH disinkronkan malam yang sama)

Daftar berikut ditemukan setelah dokumen ini ditinjau; semuanya **sudah dimasukkan ke `NUMISMA_GUIDE_0.5.md`** (Bagian 3, 4.2, 7.12, 8, 10 T29, 13). Dicatat di sini sebagai bahan laporan:
- **Kontrak Bagian 8 (`notif_service`):** `scheduleEventReminder` dan `showTestIn` mengembalikan `Future<bool>` (true bila dijadwalkan eksak), bukan `Future<void>`. Ada tambahan `canScheduleExact()`, `reminderMap()`, dan kelas `NotifException` (pesan ramah). Guide menulis `Future<void>`.
- **Kontrak Bagian 8 (`time_util`):** tambahan `utcFromZone`, `zoneAbbreviation`, dan konstanta zona (`zoneWib`, `zoneWita`, `zoneWit`, `zoneUtc`, `zoneLondon`).
- **Struktur folder 4.2:** file baru `widgets/zone_picker.dart`, `widgets/confirm_dialog.dart`, `widgets/app_logo.dart`, `widgets/tilt_photo.dart`, `screens/convert/reminder_picker.dart`, `screens/collection/coin_photo_viewer.dart`, `test/time_util_test.dart`, `test/format_util_test.dart`.
- **Paket (Bagian 3):** `flutter_launcher_icons` (dev dependency) belum tercantum; `sensors_plus`, `http`, `timezone`, `flutter_local_notifications` sudah.
- **Konfigurasi Android (Bagian 3):** desugaring, `multiDexEnabled`, izin `SCHEDULE_EXACT_ALARM` dan `RECEIVE_BOOT_COMPLETED`, serta receiver notifikasi belum dijelaskan sebagai langkah tetap.
- **Detail pengingat:** teks "Berbunyi …" di layar detail memakai **zona pratinjau yang sedang dipilih**, bukan zona HP; di zona UTC angkanya benar tetapi terasa janggal. Pengguna menilainya dapat diterima.

---

## 12. Ide dan saran lanjutan yang didiskusikan tetapi belum dikerjakan

Dicatat agar tidak hilang; tidak ada yang wajib untuk K1–K13.
- **Simpan zona asli acara** (kolom `events.zone`, migrasi baru) supaya kartu menampilkan **jam resmi tetap** ("21:30 WITA") dan pratinjau zona lain hanya di detail. Keluhan awalnya: tanpa zona tersimpan, kartu menampilkan waktu di zona yang bisa diganti-ganti sehingga bisa terasa membingungkan. Setelah dicek ulang, tampilan sekarang dinilai konsisten (setiap angka disertai zona) dan **dikunci apa adanya**; ini dicatat sebagai keterbatasan: acara dicatat dalam WIB dan dapat dilihat di zona lain.
- **Tampilan pengingat mengikuti jam HP** (`toLocal()`, berlabel "jam HP"), tidak ikut pratinjau zona.
- **Zona awal form mengikuti zona HP** (dipetakan dari selisih UTC, cadangan WIB) dan **pratinjau konversi** satu baris di form.
- **Time picker** memakai `TimeOfDay.now()` (jam HP) sebagai saran awal, sedikit tidak konsisten dengan tanggal yang memakai WIB; hanya saran awal, nilai yang disimpan tetap dibaca WIB.
- **Ikon notifikasi monokrom** (ikon berwarna tampil sebagai siluet di bilah status), nama aplikasi di launcher masih huruf kecil ("numisma"), dan layar Daftar belum berlogo.
- **Zoom cubit** di foto layar penuh (ditunda karena bertabrakan dengan tilt).
- **Isi Excel baris 44** (API: Frankfurter, Gemini, Supabase REST, OSM; Sensor: Accelerometer, Gyroscope, GPS, Biometric; AI: Gemini Vision + LLM; Database: SQLite dan Supabase). Disarankan diisi setelah fiturnya benar-benar jadi; diisi sendiri oleh pengguna.

---

## Catatan proyek (berlaku seterusnya)

- **Kerangka laporan tetap ditunda**; screenshot Hari 2 dan Hari 3 dan baris tabel pengujian **belum diambil** (ditunda atas keputusan pengguna). Screenshot Hari 3 yang perlu diambil: tab Kurs, Nilai Koleksi, multi-pilih dengan total, Jam Dunia (jam + kartu acara), form tambah acara, pilihan pengingat, detail acara dengan pengingat, notifikasi muncul, foto layar penuh, ikon dan logo.
- **Aturan git:** tidak pernah `git add`/`commit`/`push` otomatis oleh Claude; pengguna yang mengeksekusi (biasanya `git add .`), Claude memberi saran pesan commit dan memeriksa `git status` lebih dulu. `.env` dan `build/` sudah di `.gitignore`.
- **Ingatkan di Hari 4–5 (dari Hari 2):** `CoinRepo.insert/update/delete` belum menambah blok rantai; `delete` wajib membaca data koin dulu dan menulis blok `DELETE`. Konvensi hash: null jadi `""`, tipe snapshot dijaga tetap, genesis wajib PoW. Sinkron: koin terhapus tidak boleh hidup lagi saat Pulihkan; normalisasi format `ts` Supabase (cek bentuk aslinya dengan `curl` setelah satu blok terunggah).
- **Wajib diuji dan dicatat sebelum demo (T27, T29):** (1) pasang pengingat, force-stop aplikasi, buka lagi, pengingat tetap dijadwalkan ulang; (2) pasang pengingat, restart HP **tanpa** membuka aplikasi, notifikasi tetap muncul; (3) dua akun di HP yang sama: alarm akun A tidak muncul saat akun B login.
- **Hari 4:** pakai key Gemini **khusus proyek ini** dan hapus setelah penilaian (`.env` terbundel di APK dan bisa diekstrak, Guide 1.6).
- **Sebelum demo:** nonaktifkan pembatasan baterai app di HP demo (vivo), pastikan izin "Alarm & pengingat" aktif, uji di build `--release`, ganti `applicationId` `com.example.numisma`, dan `adb` belum ada di PATH.

## Rencana Hari 4
Scan Gemini (verifikasi bentuk request/respons REST lebih dulu dan pastikan `GEMINI_API_KEY` terisi di `.env`), chatbot Tanya Numisma (mode umum dan mode konteks koin), Jejak Catatan (hash chain SHA-256 + proof-of-work + verifikasi, termasuk menyambungkan `CoinRepo`), mini game Tebak Asal Koin + **Coin Flip (accelerometer, sensor kedua yang membuat syarat 2 sensor terpenuhi)** dengan `widgets/coin_face.dart`. Hari 4 paling padat: pakai urutan pemangkasan di Guide Bagian 9 bila tertinggal.
