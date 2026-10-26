# Progres Numisma — Hari 5
**Jumat 23 sampai Senin 26 Oktober 2026 — status: login email, sinkron (teks dan foto), Jelajah, redesain Beranda, BLOCKCHAIN Sepolia (penjangkaran blok terakhir; transaksi pertama terbukti di jaringan), dan KONVERSI GABUNGAN (Jam Dunia dipindah ke Jelajah) selesai. Belum: perbaikan kecil catatan terenkripsi, rombak UI global (Beranda berwarna sedang berjalan, belum di-commit), uji formal T01–T38, build release, laporan, PPT (rencananya di bagian 11). TENGGAT DIPERPANJANG sampai Selasa 27 Oktober 2026.**

> Dokumen ini merekam apa yang dikerjakan di Hari 5, keputusan, temuan, dan **rencana rinci blockchain** supaya (a) sesi Claude berikutnya paham konteks tanpa tanya ulang, dan (b) materinya siap dipakai untuk Bagian 6 "Implementasi" laporan. Format sama dengan `progres-hari-4.md`. Acuan: `NUMISMA_GUIDE_0.7.md` (Guide belum diperbarui untuk perubahan Hari 5; lihat bagian 9).

**Perangkat uji:** vivo V2318, Android 16, HP asli. **Tes otomatis:** `flutter test` 42 lulus. `flutter analyze` bersih (satu peringatan `anonKey` deprecated di `main.dart`, sengaja dibiarkan).
**Aturan kerja (berlaku seterusnya):** Claude tidak pernah `git add`/`commit`/`push` (pemilik proyek yang menjalankan; Claude memberi pesan commit), dan **setiap menjalankan kode, perintah, atau langkah harus dengan izin pemilik proyek**, satu izin per langkah.

---

## 1. Audit tabel dan kolom (sebelum migrasi)

Semua tabel dan kolom SQLite terpakai kode (tidak ada yang dibuang). Di Supabase, tabel **`collector_spots` tidak terpakai** sama sekali (spot kolektor sudah dibuang dari rencana), jadi dibuang dari `supabase_schema.sql`. `supabase_schema.sql` ditulis ulang: tabel `accounts` ditambah, `coins.has_photo` ditambah (`alter table ... add column if not exists`), dua indeks `user_key`, policy permisif untuk `accounts`, bucket privat `coin-photos` beserta policy `storage.objects`. **Tidak ada foreign key di Supabase, disengaja:** tanpa Supabase Auth tidak ada tabel pengguna untuk dirujuk, dan koin/blok boleh tiba dalam urutan apa pun (blok `DELETE` tetap ada walau koinnya sudah dihapus). Relasinya logis: `accounts.email_hash = coins.user_key = chain_blocks.user_key`, dan `chain_blocks.coin_id = coins.id`.

## 2. Migrasi DB v4, login email, akun online (K2)

- `CryptoUtil.emailHash(email)` = SHA-256 dari `"numisma:" + email` (huruf kecil, tanpa spasi di ujung). 5 tes.
- **DB v4** (`db_helper.dart`): satu jalur upgrade dari versi lama mana pun (v1, v2, v3): `reminders` dan `events` dibuang, `chain_blocks`, `coins`, `game_scores`, `feedback` dikosongkan, `users` dibuang lalu dibuat ulang (`email_hash` unik, `username` tidak lagi unik), `events` dapat `lat` dan `lng`. `rates_cache` tidak disentuh. `onCreate` dan `onUpgrade` memakai fungsi pembuat tabel yang sama.
- `models/user.dart` (+`emailHash`), `models/event.dart` (+`lat`, `lng`, `hasPoint`).
- `services/account_remote.dart` (baru): `emailExists`, `createAccount`, `fetchAccount`, `updateUsername`; penerjemah error bersama `AccountRemote.guard` (batas waktu bisa diatur, kode `23505` diterjemahkan sesuai konteks pemanggil lewat `onDuplicate`).
- `auth_service.dart` ditulis ulang: **daftar** wajib internet (cek email lokal lalu online, akun ditulis ke Supabase LEBIH DULU baru ke HP, lalu genesis); **login** dengan email + password (cari lokal lewat `email_hash`; bila tidak ada, ambil dari Supabase, cocokkan bcrypt, buat akun lokal, **panggil `restore` sebelum sesi dibuat**; bila pemulihan gagal, akun lokal dibatalkan dan login gagal dengan pesan ramah); `updateDisplayName` (online lebih dulu). Pesan gagal login digabung ("Email atau password salah").
- Aturan: password 8–64 karakter dengan huruf besar, huruf kecil, angka, simbol (spasi tidak dihitung); nama tampilan 1–30 karakter bebas. 8 tes.
- Layar register dan login memakai email; Profil punya tile "Nama tampilan" dengan dialog ganti nama; sapaan Beranda ikut berubah.
- Diuji pemilik proyek di HP: **aman**.

## 3. Sinkron koin dan blok (K4)

`services/sync_service.dart` (baru):
- **`upload(user)`:** koin `is_synced = 0` di-upsert (ditandai terunggah hanya bila `updated_at` masih sama dengan yang dikirim). Blok dicek dulu terhadap yang ada online: hash sama = hanya ditandai, **hash beda = konflik rantai** (dilaporkan, blok itu dan sesudahnya tidak diunggah, tidak ada yang ditimpa), selebihnya `insert` (bukan upsert). Koin yang sudah dihapus ikut dihapus dari cloud (beserta fotonya).
- **`restore(user)`:** hanya menulis ke HP yang MASIH KOSONG (HP berisi: tidak ada yang ditulis, hanya konflik dilaporkan). Rantai online diperiksa dulu dengan `ChainService.checkBlocks`; rantai rusak = pemulihan dibatalkan. Koin yang blok terakhirnya `DELETE` tidak dihidupkan lagi. Online belum punya blok = baru dibuat genesis. Semua penulisan dalam satu transaksi.
- **`pendingCount`**, **`syncQuietly(userId)`** (pintu otomatis: tidak ada dua sinkron bersamaan, semua kegagalan ditelan).
- Waktu dari Supabase dinormalkan `DateTime.parse(...).toUtc().toIso8601String()` karena `ts` ikut dalam hash blok.
- **Otomatis:** setelah tambah/ubah/hapus koin (`CoinRepo`), saat Beranda dibuka atau ditarik, dan timer 1 menit di `HomeShell` (tanpa paket pemantau koneksi: yang gagal offline terkirim paling lambat semenit setelah internet kembali).
- **Layar Sinkron** (`screens/collection/sync_screen.dart`, dibuka dari ikon awan di AppBar Koleksi, ada lencana jumlah yang belum diunggah): status, tombol "Sinkronkan sekarang", tombol "Pulihkan dari cloud", daftar konflik. Ubin Sinkron di Beranda dihapus.
- **Catatan terenkripsi yang tidak bisa dibuka** (kunci AES hanya ada di HP lama): `CoinRepo.getById` tidak lagi crash, `Coin.notesUnreadable`, detail menampilkan "Catatan tidak bisa dibuka di perangkat ini".
- **Keterbatasan terbuka:** koin yang catatannya tak terbaca lalu diubah di form menyimpan catatan kosong sehingga **ciphertext lama di cloud tertimpa `NULL`**. Perbaikan kecil diusulkan (pertahankan ciphertext bila kolom Catatan tidak diisi pengguna) tetapi belum diputuskan.

## 4. Foto ke Supabase Storage (K4)

- **Unggah:** foto koin ke bucket `coin-photos`, objek `{email_hash}/{id_koin}.jpg` (`upsert`), `has_photo = true` hanya bila unggahan berhasil. Foto yang gagal tidak menghalangi sinkron teks: koinnya diunggah tetapi tidak ditandai tersinkron, jadi dicoba lagi. Langkah sekali jalan per akun (`shared_preferences`, kunci `photo_resync_v1_{userId}`) menandai koin yang sudah terunggah sebelum fitur foto agar fotonya ikut.
- **Pulihkan:** setiap foto diunduh, **dicek dengan `photo_hash` di blok terakhir koin itu (SHA-256 byte foto)**, lalu disimpan ke folder aplikasi. Foto gagal atau hash beda dilewati tanpa menggagalkan apa pun (setelah transaksi selesai; tiap foto dibungkus try/catch supaya `restore` tidak pernah melempar di tahap itu).
- Batas waktu unggah/unduh foto 60 detik (teks tetap 15 detik).
- **Pulihkan otomatis saat login**: bila akun tidak ada di HP (aplikasi dihapus lalu dipasang ulang), login memulihkan koleksi, foto, dan Jejak Catatan sebelum masuk Beranda. T18 diuji pemilik proyek: **aman**.

## 5. Jelajah (LBS, K5)

- Paket baru: `geolocator ^14.0.1`, `flutter_map ^8.3.2`, `latlong2 ^0.10.1`, `url_launcher ^6.3.3` (API diverifikasi di kode paket yang terpasang).
- `core/geo_util.dart` (jarak Haversine milik geolocator, `formatDistance`, `sortByDistance`; 9 tes), `services/location_service.dart` (izin, posisi dengan batas waktu 10 detik, cadangan posisi terakhir, pesan ramah), `EventRepo.add/update` menulis `lat`/`lng`.
- `screens/explore/`: `explore_screen` (tab Peta dan Acara), `map_tab` (peta OSM, posisi GPS, pin acara, daftar terurut terdekat dengan jarak, tekan lama = lokasi manual, tombol Lokasi saya dan Segarkan, tarik-untuk-menyegarkan, muat ulang otomatis saat kembali ke tab Peta karena tab dipertahankan hidup), `events_tab` (daftar acara, kartu jam, uji notifikasi), `location_picker_screen`, `event_form_screen` (tombol "Pilih titik di peta"), `event_detail_screen` (koordinat, jarak, tombol **Rute** ke Google Maps lewat `https://www.google.com/maps/dir/?api=1&destination=lat,lng`), `reminder_picker`. Berkas form/detail/reminder dipindah dari `convert/` ke `explore/`.
- `widgets/event_map.dart` (peta + penanda; atribusi OSM dan `userAgentPackageName` `com.numisma.app`), `widgets/world_clock_card.dart` (jam dunia bersama, dipakai di tab Acara dan, untuk sementara, tab Jam Dunia).
- Menu "Jelajah" di Beranda membuka layar asli; `_PlaceholderPage` dihapus. T19 diuji pemilik proyek: **aman**.

## 6. Redesain Beranda dan bottom nav (gaya buku koleksi)

Kertas krem (`AppColors.paper`), tinta, merah marun, garis ganda (`widgets/double_rule.dart`), kotak ringkasan tiga kolom (Koin, Uang Kertas, Jumlah; tanpa nilai uang), "Daftar Isi" 1–6 (Koleksi, Konversi, Tanya Numisma, Jelajah, Permainan, Jejak Catatan), foto profil di kiri header (tidak bisa diketuk) dan "Halo, nama" di kanan, ikon Profil biasa di bottom nav, tombol Scan merah marun. Font bawaan Android (`serif`, `monospace`) lewat `AppText` di `theme.dart`; tidak ada font yang diunduh. Berkas: `screens/home/beranda_view.dart`, `theme.dart` (hanya menambah). Hanya Beranda dan bottom nav yang bertema baru; layar lain masih tema perunggu. Cara kembali ke tampilan lama: titik kembali commit `925cfbb` (lihat memori `ui-beranda-lama-cara-kembali`).
Bug yang ditemukan dan diperbaiki: `DoubleRule` awalnya tidak tampil (garis berlebar nol di dalam `Column`; perlu `crossAxisAlignment: stretch`).

**Pembaruan 26 Okt (belum di-commit):** `screens/home/beranda_view.dart` terdeteksi sudah diubah lagi ke versi **berwarna** (spanduk gradasi dengan foto profil dan nama besar, tiga kartu ringkasan berwarna, "Daftar Isi" berupa kartu menu dua kolom dengan warna tiap fitur: Koleksi, Konversi, Tanya Numisma, Jelajah, Permainan, Jejak Catatan; `DoubleRule` tidak dipakai lagi di berkas itu). Perubahan ini bukan dari sesi dokumen ini dan merupakan bagian dari rombak UI (9.3); perlu diperiksa di HP dan di-commit oleh pemilik proyek. Titik kembali ke gaya buku bernuansa krem: commit `06c89a9`.

## 7. Masalah teknis yang ditemukan dan solusinya

- **Bentrok nama `User`** antara model kita dan Supabase Auth: `import 'package:supabase_flutter/supabase_flutter.dart' hide User;` di `sync_service.dart`.
- **`addBlock` juga membuat genesis otomatis**, bukan hanya `ensureChain`: sebab login dari cloud harus memulihkan dulu sebelum sesi dibuat.
- **Tab Peta tidak melihat acara baru** (keep-alive): dimuat ulang saat tab dibuka.
- **`flutter run` ke vivo kadang putus** ("log reader stopped unexpectedly") walau APK terpasang; aplikasi tetap bisa dibuka manual.
- **Windows meminta Developer Mode** (symlink plugin) setiap `flutter pub add`; tidak menghalangi build.
- **Patch skrip saya menghapus `_PlaceholderPage`** (ketahuan analyze, dikembalikan dari commit sebelumnya).
- `anonKey` ditandai deprecated (pakai `publishableKey`); belum diverifikasi apakah menerima kunci lama, dibiarkan.

## 8. Daftar commit Hari 5 (urut lama ke baru)

`340589a` Guide 0.7 + skema Supabase · `dedc378` login email + akun online + DB v4 · `0ba4147` sync_service · `925cfbb` sinkron otomatis + layar Sinkron · `06c89a9` redesain Beranda · `0eedf07` dasar LBS · `214d2f8` layar Jelajah · `ac9c2a3` LBS lengkap · `2eb0e49` sinkron foto ke Storage · `bed6baf` persiapan blockchain (web3dart, konfigurasi `ETH_*`) · `971f247` jangkarkan Jejak Catatan ke blockchain Sepolia (penjangkaran, DB v5, kartu di Jejak Catatan) · `c5bd56e` Konversi gabungan dan hapus Jam Dunia dari Konversi. Belum di-commit saat ini: `beranda_view.dart` versi berwarna. `progres-hari-5.md` sengaja tidak di-commit.

---

## 9. PERUBAHAN PERMINTAAN SETELAH FITUR LENGKAP (blockchain 9.5, Konversi 9.1, dan Jam Dunia 9.2 SUDAH dikerjakan; rombak UI 9.3 sedang berjalan)

Urutan prioritas yang disepakati: **blockchain > Konversi gabungan > hapus Jam Dunia dari Konversi > rombak UI (paling akhir, bila ada waktu)**. Lalu uji penuh dan build final. **Tenggat awalnya Minggu 25 Oktober, kini diperpanjang sampai Selasa 27 Oktober 2026**; hari ini (25 Oktober) tetap dianggap batas aplikasi selesai secara santai, lalu sisa waktu untuk uji penuh, laporan, dan PPT.

### 9.1 Konversi digabung (menggantikan Kurs + Nilai Koleksi) — SELESAI (`c5bd56e`, belum diuji di HP)
Menu Konversi jadi **satu layar tanpa tab** (`screens/convert/convert_screen.dart`). Rancangan awal punya kartu "Total nilai koleksi" di atas; atas keputusan pemilik proyek kartu itu **dihapus** (jumlah seluruh koleksi didapat lewat "Pilih semua", dan permintaan kurs berkurang). Hasil akhir: satu pemilih "Konversi ke" (default IDR), kartu "Total terpilih (N item) ≈ X" (dengan peringatan item tanpa kurs dan tanggal kurs tertua, ditandai bila dari cache), tombol "Pilih semua / Hapus pilihan", dan daftar koleksi dengan kotak centang, nominal asli, negara, tahun, jenis, dan hasil konversi per koin. Kurs diminta **sekali per mata uang koin** (`RatesService.getRateInfo`), bukan per koin; tarik-untuk-menyegarkan memaksa kurs baru. Tab Kurs bebas (1.000 JPY ke IDR) dan tab Nilai Koleksi lama dihapus, begitu pula berkas `collection_value_tab.dart`. Syarat dosen "minimal 3 mata uang" tetap lewat pemilih (44 mata uang dari Frankfurter). Tes yang berubah: **T10** (sekarang lewat daftar koleksi), **T25** (Pilih semua dibandingkan hitungan manual).

### 9.2 Jam Dunia dihapus dari Konversi — SELESAI (`c5bd56e`)
`world_clock_tab.dart` dihapus. Jam dunia ada di Jelajah, tab Acara, lewat `widgets/world_clock_card.dart` (empat zona: WIB, WITA, WIT, London), dan kartu acara tetap punya pemilih zona. Dampak dokumen: Guide 7.7, matriks K7, T11, T33 (kini diuji di Jelajah); di laporan, "konversi waktu" dijelaskan lewat Jelajah (jam dunia dan zona waktu acara), bukan menu Konversi.

### 9.3 Rombak UI
Tetap diinginkan, dikerjakan paling akhir. Beranda sudah bertema baru; layar lain (Profil, Saran, Koleksi, Scan, Konversi, Game, Chat, Jejak Catatan, Jelajah) masih tema perunggu. Rencana: ganti tema global bertahap memakai `AppColors.paper/ink/maroon` dan `AppText`.

### 9.4 BLOCKCHAIN DI JARINGAN SUNGGUHAN (K13) — rancangan awal dan penjelasan konsep

> **Pembaruan:** keputusan akhir adalah **Cara 1 (tanpa smart contract)** dengan **kebijakan penjangkaran A (tiap sinkron yang membawa perubahan)**, dan sudah diimplementasikan; lihat 9.5. Draf kontrak di bawah TIDAK dipakai (tetap disimpan sebagai alternatif bila dosen meminta kontrak buatan sendiri). Tingkat penyimpanan yang dipakai adalah **tingkat 1** (hanya hash blok terakhir yang ditulis ke jaringan, rantai tetap di database); tingkat 2 (setiap blok) dan tingkat 3 (rantai hanya di jaringan, `chain_blocks` Supabase dibuang) dibahas tetapi tidak dikerjakan, dan hanya naik bila dosen mengharuskan semua blok di jaringan.

**Situasi.** Dosen menjelaskan blockchain harus "dipasang di jaringan sebenarnya", dengan dua pilihan: (a) pakai layanan blockchain yang sudah ada, atau (b) membuat blockchain sederhana sendiri lalu mengunggahnya ke jaringan. Jejak Catatan saat ini adalah rantai hash di SQLite/Supabase pada satu perangkat (Guide 1.6 menyebut keterbatasan "tanpa jaringan terdistribusi"); Supabase hanya database biasa. **Belum ada konfirmasi dosen** soal bentuk yang cukup; pertanyaan yang disarankan ke dosen: *"Apakah cukup mencatat hash Jejak Catatan ke testnet Sepolia lewat smart contract buatan sendiri, dengan rantainya tetap di aplikasi?"*

**Penjelasan konsep (untuk landasan teori laporan dan untuk memahami rancangannya).**
- **Blockchain publik** = buku besar yang disalin ribuan komputer (node). Menambah catatan = mengirim **transaksi** yang harus **ditandatangani** dengan kunci privat; node memeriksa tanda tangan dan memasukkannya ke blok; setelah dikonfirmasi, catatan tidak bisa diubah siapa pun.
- **Testnet** (di sini **Ethereum Sepolia**, chain ID 11155111) = jaringan latihan dengan koin tanpa nilai uang (Sepolia ETH), mekanismenya sama dengan jaringan utama.
- **Kunci privat** = rahasia untuk menandatangani; **alamat** (`0x...`) = identitas akun yang diturunkan dari kunci itu. Siapa pun yang memegang kunci privat bisa mengirim transaksi dari alamat itu.
- **Gas** = biaya mengirim transaksi, dibayar dengan ETH (di testnet gratis lewat faucet atau kiriman dari dompet lain). Biaya per transaksi kecil (perkiraan di bawah 0,001 ETH testnet; **belum diverifikasi**).
- **Smart contract** = program kecil yang disimpan di blockchain dengan alamatnya sendiri. "Mengunggah ke jaringan" = **deploy** = satu transaksi khusus berisi kode kontrak. Setelah itu fungsinya bisa dipanggil lewat transaksi (menulis, bayar gas) atau lewat pembacaan gratis (`eth_call`).
- **Node dan RPC** = pintu masuk ke jaringan lewat HTTP (JSON-RPC). Aplikasi tidak menjalankan node; ia memakai penyedia (publik gratis seperti PublicNode, atau Alchemy/Infura dengan akun dan kunci).
- **Block explorer** (Etherscan Sepolia: `sepolia.etherscan.io`) = situs untuk melihat transaksi dan kontrak secara publik: bukti untuk dosen dan screenshot laporan.
- **MetaMask itu apa hubungannya?** MetaMask hanyalah **dompet (wallet)**: aplikasi/ekstensi browser yang **menyimpan kunci privat dan menandatangani transaksi atas nama pengguna**, dengan tampilan yang ramah. MetaMask **bukan bagian dari blockchain** dan **tidak wajib**. Temanmu memakainya karena (1) alat deploy kontrak populer, Remix (`remix.ethereum.org`), meminta transaksi ditandatangani lewat MetaMask ("Injected Provider"), dan (2) MetaMask menampung saldo testnet serta memudahkan melihat transaksi. Aplikasi Numisma **tidak perlu MetaMask**: aplikasi bisa menyimpan kunci sendiri dan menandatangani sendiri lewat paket `web3dart`. Kita memakai MetaMask hanya sebagai **alat bantu** membuat dompet, menerima saldo faucet, dan men-deploy kontrak.
- **Tidak bergantung pada teman:** semua langkah bisa dikerjakan sendiri. Teman hanya satu sumber saldo opsional (bisa mengirim sedikit Sepolia ETH); faucet publik adalah jalur lain.

**Pilihan rancangan.**
- **Opsi A, pakai jaringan tanpa kontrak:** kirim transaksi biasa ke Sepolia dengan kolom `data` berisi hash. Paling sederhana (tanpa Solidity), tetapi bukan "membuat sendiri".
- **Opsi B (disarankan), smart contract buatan sendiri:** "membuat sendiri" (kontrak) + "diunggah ke jaringan" (Sepolia), jadi memenuhi kedua pilihan dosen. Rantai Jejak Catatan lokal tetap ada sebagai desain kita; jaringan berperan sebagai **notaris** (penjangkaran/anchoring): hash kepala rantai dicatat di jaringan, dan Verifikasi membandingkan.
- Membuat jaringan P2P sendiri dengan banyak node ditolak: butuh server (di luar rencana "tanpa backend sendiri") dan terlalu besar untuk waktu yang ada.

**Draf kontrak (BELUM dikompilasi atau diuji; kompilasi dan uji di Remix dulu).** Disimpan per pengirim supaya orang lain tidak bisa menimpa catatan akun kita:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract JejakCatatan {
    struct Catatan { uint256 idx; bytes32 hash; uint256 waktu; }
    // pengirim (dompet aplikasi) -> kunci akun (email_hash) -> catatan terakhir
    mapping(address => mapping(bytes32 => Catatan)) public terakhir;
    event Dicatat(address indexed pengirim, bytes32 indexed kunci, uint256 idx, bytes32 hash);

    function catat(bytes32 kunci, uint256 idx, bytes32 hash) external {
        Catatan storage c = terakhir[msg.sender][kunci];
        require(c.waktu == 0 || idx > c.idx, "idx harus lebih besar");
        terakhir[msg.sender][kunci] = Catatan(idx, hash, block.timestamp);
        emit Dicatat(msg.sender, kunci, idx, hash);
    }
}
```
`email_hash` (64 heks) dan hash blok (64 heks) masing-masing tepat 32 byte, jadi cocok dengan `bytes32`.

**Rancangan aplikasi (belum dikerjakan).**
- **`.env` baru:** `ETH_RPC_URL`, `ETH_PRIVATE_KEY` (dompet testnet khusus proyek, **jangan pernah** kunci dompet berisi uang asli), `ETH_CONTRACT_ADDRESS`, `ETH_CHAIN_ID=11155111`. Perbarui `.env.example` dan `core/config.dart`. Catatan keamanan untuk laporan: `.env` ikut di APK dan bisa diekstrak (sama seperti kunci OpenAI); aman karena testnet tanpa nilai.
- **Paket:** `web3dart ^3.0.3` (aktif di pub.dev, mendukung Android, bergantung `http >=0.13.1 <2.0.0`; tidak ditandai discontinued pada halaman resminya, walau satu pencarian pihak ketiga sempat menyebut sebaliknya, itu keliru). Pasang dengan `flutter pub add web3dart`. API pemanggilan kontrak (`DeployedContract`, `ContractAbi.fromJson`, `Transaction.callContract`, `client.call`) **belum diverifikasi**: baca contoh `example/contracts.dart` di repositori web3dart sebelum menulis kode.
- **`services/chain_anchor_service.dart` (baru):** `anchorHead(user)` mengirim `catat(kunci = email_hash, idx = idx blok terakhir, hash = hash blok terakhir)` bila `idx` kepala lebih besar dari yang terakhir dijangkarkan; `readAnchor(user)` memanggil `terakhir(alamat, kunci)` (pembacaan gratis); `verifyOnChain(user)` membandingkan blok lokal ber-`idx` itu dengan hash di jaringan. Sengaja **satu transaksi untuk kepala rantai** (bukan satu per blok): blok sebelumnya terikat lewat `prev_hash`, jadi mengunci kepala sudah mengunci seluruh riwayat.
- **Pemicu:** setelah `SyncService.upload` berhasil (di latar belakang, kegagalan ditelan seperti sinkron, antre bila offline). Jangan menunggu konfirmasi (`sendTransaction` mengembalikan hash transaksi segera); status "menunggu konfirmasi" bila catatan di jaringan masih tertinggal dari yang dikirim.
- **Migrasi DB v5:** `ALTER TABLE chain_blocks ADD COLUMN tx_hash TEXT` (hanya menambah kolom; `tx_hash` **tidak** masuk rumus hash blok, jadi verifikasi lama tidak terganggu); `onCreate` ikut skema v5; Guide Bagian 5.1 diperbarui. Menyinkronkan `tx_hash` ke Supabase opsional (cukup sebelah lokal; keadaan jaringan selalu bisa dibaca ulang dari kontrak).
- **UI Jejak Catatan:** banner "Terjangkar di Sepolia: blok #N" dengan tanggal, tx hash, dan tombol membuka `https://sepolia.etherscan.io/tx/<hash>` (`url_launcher`); tombol "Catat ke jaringan" manual; Verifikasi menambah pemeriksaan on-chain dengan tiga hasil: **cocok**, **HP berbeda dari jaringan** (bukti perubahan), **HP tertinggal** (sarankan Pulihkan).
- **Penanganan galat ramah:** saldo ETH habis, RPC publik menolak (HTTP 429), offline, konfirmasi lambat.

**Langkah kerja yang disarankan (satu izin per langkah, spike dulu).**
1. **Persiapan pemilik proyek (di luar kode):** buat dompet **baru khusus proyek** (MetaMask atau lainnya; jangan dompet berisi uang asli), pilih jaringan Sepolia, dapatkan sedikit Sepolia ETH (faucet; beberapa faucet meminta saldo mainnet dan ada yang tidak, mis. berbasis kerja browser; atau kirim dari dompet teman; 0,05 ETH testnet sudah sangat cukup), deploy kontrak lewat Remix dengan "Injected Provider", catat **alamat kontrak** dan salin **ABI** dari Remix, lalu ekspor kunci privat dompet itu ke `.env` (`ETH_PRIVATE_KEY`). Jangan pernah mengirim kunci privat ke chat; isi langsung ke `.env`.
2. **Spike:** `flutter pub add web3dart`; tulis skrip atau tombol uji kecil yang mengirim satu `catat(...)` dan membacanya kembali. Pastikan transaksi EIP-1559 di Sepolia berhasil dan tampil di Etherscan. Bila gagal di tahap ini, putuskan beralih ke Opsi A atau perbaiki sebelum membangun apa pun.
3. `chain_anchor_service.dart` + tes murni (pembandingan hash on-chain vs lokal, konversi heks ke `bytes32`).
4. Migrasi v5 + `tx_hash`.
5. Penyambungan: pemicu setelah upload, banner dan tombol di `chain_screen.dart`, pemeriksaan on-chain di Verifikasi.
6. Uji di HP: T35 (kepala rantai tercatat, tx hash terlihat di Etherscan), T36 (Verifikasi "cocok"), T37 (ubah satu blok lokal lewat `adb run-as` pada build debug, Verifikasi melaporkan perbedaan), T38 (offline lalu online, tercatat otomatis).
7. Dokumentasi: Guide (K13, Bagian 3, 5, 6, 8, 10, 13), laporan (landasan teori blockchain, perancangan, implementasi, keterbatasan: testnet, kunci di APK, "bukan sertifikat keaslian koin" tetap berlaku).

**Perkiraan waktu:** sekitar 4–5 jam termasuk persiapan dan uji, dengan ketidakpastian pada faucet, batas laju RPC publik, dan format transaksi di web3dart.

**Sumber riset (diakses 23 Okt 2026):** daftar faucet Sepolia (`github.com/dallaspu/sepolia-faucets-2026`, pihak ketiga), panduan RPC Sepolia (OnFinality), panduan deploy Remix (docs.base.org, docs.lisk.com), pengumuman penutupan Holesky (blog.ethereum.org; Sepolia tetap testnet yang direkomendasikan, tidak ditemukan tanggal penghentian), halaman `pub.dev/packages/web3dart`.

### 9.5 BLOCKCHAIN YANG SUDAH DIKERJAKAN (penjangkaran ke Ethereum Sepolia)

**Keputusan:** Cara 1 (tanpa smart contract; memenuhi pilihan dosen "pakai service blockchain yang sudah ada"), kebijakan A (tiap sinkron yang membawa perubahan = satu transaksi), tingkat 1 (hanya blok terakhir). Rantai Jejak Catatan tetap di SQLite dan Supabase; Sepolia berperan sebagai notaris publik. **Belum ada konfirmasi dosen** soal bentuk yang cukup.

**Yang dibuat:**
- Paket `web3dart 2.7.3` (versi 3.0.3 bentrok dengan paket lain di proyek; tidak masalah karena memakai transaksi biasa dengan `gasPrice`). API diverifikasi di kode paket: `Transaction` (kolom `data`), `sendTransaction`, `getTransactionByHash` (`input`), `getTransactionReceipt` (`status`).
- `.env`: `ETH_PRIVATE_KEY` (dompet testnet khusus proyek, dibuat di MetaMask HP, diisi sendiri oleh pemilik proyek, tidak pernah lewat chat), `ETH_CHAIN_ID=11155111`, `ETH_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com` (diuji: `eth_chainId` = `0xaa36a7`, saldo terbaca benar). `core/config.dart`: `ethPrivateKey`, `ethChainId`, `ethRpcUrl`, `ethConfigured` (bila belum lengkap, penjangkaran mati diam-diam). `.env.example` diperbarui.
- `services/chain_anchor_service.dart`: `anchorHead(user)` mengirim transaksi bernilai 0 **ke alamat dompet sendiri** dengan `data` = teks `numisma:v1:<idx>:<hash blok>` (hanya bila blok terakhir lebih baru dari yang sudah dijangkarkan; harga gas dinaikkan 25%, `maxGas` 40000); `checkOnChain(user)` membaca transaksi blok terjangkar terakhir dan membandingkannya dengan blok di HP (hasil: cocok, berbeda, menunggu konfirmasi, gagal, jaringan tidak terjangkau; transaksi harus berasal dari dompet aplikasi); `anchorQuietly` (otomatis, menelan semua kegagalan, jeda 5 menit setelah gagal); bagian murni `payloadOf`, `parsePayload`, `payloadMatches`, `explorerUrl`. Pesan galat ramah: offline, timeout, saldo habis, batas laju RPC.
- **DB v5:** `chain_blocks.tx_hash TEXT` (hanya menambah kolom; tidak masuk rumus hash blok). `ChainBlock.txHash`. Nomor transaksi disalin ke Supabase secara opsional lewat `update` (gagal diabaikan); kolom Supabase: `alter table chain_blocks add column if not exists tx_hash text;`. `restore` membaca `tx_hash` bila ada.
- **Pemicu:** di `SyncService.syncQuietly`, sesudah `upload` berhasil dan tanpa konflik rantai.
- **UI** (`screens/chain/chain_screen.dart`): kartu "Blockchain Sepolia" (blok terakhir yang tercatat dan tx), tombol "Catat sekarang" (kirim blok terakhir sekarang, melewati jeda), "Periksa di jaringan", dan "Etherscan"; tanda "⛓ tercatat di jaringan Sepolia" pada tiap blok yang sudah tercatat. Kartu hanya tampil bila `.env` lengkap.
- Tes: `test/chain_anchor_test.dart` (9 tes murni). Total `flutter test` 51 lulus.

**Bukti dari jaringan (diverifikasi lewat RPC, 25 Okt 2026):** blok #12 (aksi `DELETE`, nonce 242, hash `0014512f2d381df96c8212bebb7218c4900a61b80a7c95e410e830f2520356a9`, waktu `2026-10-24 17:50:15 UTC` = 25 Okt 00:50 WIB) tercatat di transaksi `0xfa4e8345afa24c36fe31d32e8f1b88d6fedf5c6245e64cb74735783cbcf4b749`: dikirim dan diterima oleh dompet `0x7f7e7F0324465904E9115b4cC2B5414dbe12C1fB`, status berhasil, masuk blok Sepolia `0xb6e1da`, `input` terbaca `numisma:v1:12:0014512f...56a9`, **persis sama dengan kolom `hash` di Supabase**. Dompet didanai 0,05 SepoliaETH (dikirim teman lewat MetaMask).

**Keterbatasan untuk laporan (jujur):** hanya blok yang sudah dijangkarkan yang terlindungi (ada celah beberapa detik sampai konfirmasi); jaringan tidak membuktikan koin asli atau milik pengguna; kunci dompet ada di `.env` yang ikut di APK (aman karena testnet tanpa nilai uang); RPC publik dibatasi laju; testnet tidak permanen (Holesky sudah dipensiunkan, Sepolia saat ini direkomendasikan); data yang tercatat publik (hash, nomor blok, dan alamat dompet; email dan data koin tidak).

**Belum diuji di HP:** tombol "Periksa di jaringan" (harus "Cocok dengan catatan di jaringan"), "Catat sekarang" (blok yang sudah tercatat harus menjawab "sudah tercatat"), skenario ubah blok lokal (T37), offline lalu online (T38).

---

## 10. Status pengujian formal (T01–T38)

Diuji pemilik proyek di Hari 5 dan dinyatakan aman (**hasil dan screenshot belum dicatat**): T01–T05 (daftar, login, sesi), T18 (sinkron dan pulihkan dengan foto), T19 (Jelajah), T30 dan T32 (akun online, nama tampilan), T31 (sinkron otomatis offline lalu online), **T35 (blok tercatat di Sepolia; terbukti lewat RPC, lihat 9.5)**. **Belum dites atau perlu diulang:** T06–T07 (biometrik, alur login berubah), T08–T09, T10–T11 dan T25 (akan berubah karena Konversi digabung), T12–T13 (Coin Flip dan tilt), T14–T15 (Scan koin asli, chatbot), T16–T17 (Verifikasi, `flutter test`), T20, T22–T24, **T27 dan T29 (belum pernah dites sejak Hari 3)**, T28, T21, T26, T29b, T33 (empat zona, kini di Jelajah), T34 (konflik rantai, disimulasikan dengan mengubah satu `hash` blok di Table Editor Supabase), dan T35–T38 baru untuk blockchain. Untuk T22 dan T23 cukup screenshot tabel `accounts` di Supabase dan database lokal (`adb run-as` pada build debug).

## Catatan proyek (berlaku seterusnya)

- **Sebelum demo:** build `--release` dan uji ulang alur utama (ada bug R8/vivo khusus release di Hari 2), jangan ganti `applicationId` (`com.numisma.app`) atau kunci penandatanganan, nonaktifkan pembatasan baterai app di HP demo, aktifkan izin "Alarm & pengingat", siapkan hotspot, 3–4 acara bertitik di Jogja, video rekaman cadangan, dan hapus atau ganti kunci OpenAI setelah penilaian (kunci dompet testnet juga).
- **Keputusan kecil yang masih terbuka:** perbaikan catatan terenkripsi yang tertimpa `NULL` (bagian 3), dan `anonKey` vs `publishableKey`.
- **Dokumen yang harus diperbarui:** Guide 0.8 (redesain Beranda, Jelajah, foto Storage, Konversi gabungan, Jam Dunia, blockchain on-chain, DB v5), tabel pengujian, kerangka laporan (Bagian 6 per fitur), bahan PPT.
- **Pertanyaan ke dosen yang masih terbuka:** bentuk blockchain yang cukup (lihat 9.4 dan 9.5; pertanyaan yang disarankan: *"Apakah cukup mencatat hash blok terakhir Jejak Catatan ke testnet Sepolia, dengan rantainya tetap di aplikasi, atau semua blok harus ada di jaringan?"*), tanggal presentasi, dan tenggat unggah/cetak laporan.
- **Tenggat diperpanjang** sampai Selasa 27 Oktober 2026 (dikonfirmasi pemilik proyek).

---

## 11. RENCANA LANJUTAN (disusun Minggu 25 Oktober 2026, diperbarui Senin 26 Oktober)

> **Status 26 Okt:** poin 1 (Konversi gabungan) **SELESAI** (rancangan akhirnya di 9.1: tanpa kartu total). Poin 2 (perbaikan kecil) belum. Poin 3 (rombak UI) sedang berjalan: Beranda versi berwarna sudah ada di berkas tetapi belum di-commit dan belum diperiksa di HP. Poin 4 (uji cepat di HP: Konversi, Beranda, blockchain) belum. Tenggat Selasa 27 Okt, jadi uji formal T01–T38, build release, dan laporan harus dimulai hari ini.

### 11.1 Rencana awal hari kerja aplikasi (disusun Minggu 25 Okt; poin 1 sudah selesai)
| # | Pekerjaan | Perkiraan | Catatan |
|---|---|---|---|
| 1 | **[SELESAI, lihat 9.1]** **Konversi gabungan** (9.1): satu layar tanpa tab. Atas: total nilai koleksi dengan pilihan mata uang. Bawah: daftar koleksi yang bisa dipilih (multi-pilih) dan dikonversi ke mata uang pilihan. Hapus tab Kurs bebas dan tab Jam Dunia dari `ConvertScreen` (9.2; `WorldClockCard` tetap dipakai di tab Acara Jelajah). Baca dulu `convert_screen.dart`, `collection_value_tab.dart`, `rates_service.dart`, `widgets/currency_picker.dart`, tampilkan rancangan layar, baru tulis kode. | 1,5–2 jam | Menyentuh syarat dosen K7; perbarui T10, T11, T25, T33 |
| 2 | **Perbaikan kecil:** catatan terenkripsi yang tertimpa `NULL` bila koin diubah di HP hasil pulihan (pertahankan ciphertext lama bila kolom Catatan tidak diisi pengguna; `coin_repo.update` dan form), dan kekurangan lain yang ditemukan | 0,5 jam | Keputusan kecil masih terbuka (bagian 3) |
| 3 | **Rombak UI** (9.3): tema global dulu (warna `AppColors.paper/ink/maroon`, AppBar, kartu, tombol, input, `AppText`) supaya semua layar ikut berubah, lalu poles layar demi layar (Koleksi, Konversi baru, Profil, Saran, Scan, Jejak Catatan, Jelajah, Game, Chat) | 2–3 jam | Paling akhir; bila waktu habis, cukup sebagian |
| 4 | **Uji cepat di HP:** Konversi baru, tema baru, dan blockchain (Periksa di jaringan, Catat sekarang) | 0,5–1 jam | Pasang lewat `flutter run`; koneksi debug vivo sering putus walau APK terpasang |

**Bila masih ada tenaga malam ini:** buat `progres-hari-6.md` (progres hari ini dan rencana lanjutan), dan cicil laporan: kerangka lengkap (Guide 11.2), bab landasan teori (numismatik, hash vs enkripsi, bcrypt/AES/SHA-256, hash chain, **blockchain publik, testnet, transaksi, kunci privat dan alamat, MetaMask hanya dompet**, biometrik, sensor, REST API, LBS, zona waktu, AI Vision dan LLM), dan bab perancangan (ERD dari Guide 5 plus DB v5, arsitektur, use case).

### 11.2 Senin 26 Okt
- **Uji penuh T01–T38** dengan tabel pengujian (hasil aktual dan status) dan screenshot tiap fitur; T34 (konflik rantai) dan T37 (ubah blok lokal lewat `adb run-as` pada build debug, lalu "Periksa di jaringan" harus melaporkan perbedaan) disimulasikan; T22 dan T23 lewat screenshot tabel `accounts` dan database lokal.
- **Build release** (`flutter build apk --release`) dan uji ulang alur utama di HP demo (bug R8/vivo hanya muncul di release); jangan ganti `applicationId` atau kunci penandatanganan; matikan pembatasan baterai app; izin "Alarm & pengingat".
- Perbarui Guide ke 0.8 (redesain Beranda, Jelajah, foto Storage, Konversi gabungan, Jam Dunia, blockchain, DB v5), mulai bab implementasi laporan (penjelasan source code per fitur K1–K13 disertai screenshot).

### 11.3 Selasa 27 Okt (tenggat)
- Finalisasi laporan (cover, halaman pengesahan, daftar isi, evaluasi pengujian, penutup dengan keterbatasan Guide 1.6 dan 9.5), PPT (±12 slide, Guide 11.3), video demo cadangan (alur Guide 11.1 ditambah penjangkaran blockchain dan Etherscan), cetak dan unggah.
- Persiapan demo: hotspot, 3–4 acara bertitik di Jogja, saldo Sepolia cukup (0,05 ETH sudah ratusan transaksi), buka Etherscan alamat dompet dan satu transaksi sebagai bukti.

### 11.4 Bila waktu mepet (urutan pemangkasan)
Rombak UI dipotong ke tema global saja → perbaikan kecil catatan terenkripsi dicatat sebagai keterbatasan → polesan layar dilewati. **Tidak boleh dipangkas:** Konversi gabungan (K7), blockchain (K13), uji penuh, build release, dan laporan.
