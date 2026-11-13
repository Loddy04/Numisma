// warna_widget.dart
// DAFTAR WARNA PER ELEMEN. Satu tempat untuk mengganti warna widget di Beranda,
// Profil, Saran, Navbar, AppBar, Background, serta Login dan Daftar.
//
// Cara pakai (tantangan ubah warna):
//  1. Cari barisnya di bawah (dikelompokkan per layar).
//  2. Ganti nilainya, mis. `Color(0xFFFFFFFF)` menjadi `Colors.yellow`
//     atau `Color(0xFFFFEB3B)`.
//  3. Simpan, lalu tekan `R` (hot restart) di terminal `flutter run`.
//     Nilai ini `const`, jadi hot reload `r` biasa kadang tidak cukup.
//
// Nilai awal di sini sama persis dengan tampilan semula, jadi tidak ada yang
// berubah sebelum kamu mengeditnya. Warna di luar daftar ini tetap diatur di
// theme.dart. Berkas ini sengaja tidak mengimpor theme.dart supaya berdiri
// sendiri.
//
// Format warna: Color(0xAARRGGBB). AA = keburaman (FF penuh, 80 setengah,
// 00 transparan), lalu RR GG BB. Warna bernama: Colors.red, Colors.blue, dst.

import 'package:flutter/material.dart';

class WarnaWidget {
  WarnaWidget._();

  // ===================================================================
  // BACKGROUND (latar semua halaman; gradasi dari atas ke bawah)
  // ===================================================================
  static const backgroundAtas = Color(0xFFFBF5EA); // krem muda
  static const backgroundBawah = Color(0xFFF2E6D2); // krem lebih tua

  // ===================================================================
  // APP BAR (bilah judul layar seperti Koleksi)
  // ===================================================================
  static const appBarLatar = Color(0xFFFBF5EA);
  static const appBarJudul = Color(0xFF1E1A14);
  static const appBarIkon = Color(0xFF8C6239); // panah kembali dan aksi

  // ===================================================================
  // NAVBAR (bilah bawah)
  // ===================================================================
  static const navbarLatar = Color(0xFFFFFFFF); // kapsul putih
  static const navbarAreaSekitar = Color(0xFFF2E6D2); // di sekeliling kapsul
  static const navbarBayangan = Color(0x2445301F);
  static const navbarIkonAktif = Color(0xFF8C6239);
  static const navbarIkonAktifLatar = Color(0xFFEDE0CB);
  static const navbarIkonPasif = Color(0x991E1A14);
  static const navbarScanGradasiAtas = Color(0xFF9A6B3A); // tombol Scan
  static const navbarScanGradasiBawah = Color(0xFF45301F);
  static const navbarScanIkon = Color(0xFFFFFFFF);
  static const navbarScanCincin = Color(0xFFFBF5EA); // cincin di sekitar Scan

  // ===================================================================
  // BERANDA
  // ===================================================================
  // Bilah atas
  static const berandaNamaApp = Color(0xFF1E1A14); // tulisan "Numisma"
  static const berandaFotoBingkai = Color(0xFFFFFFFF);
  static const berandaFotoLatar = Color(0x80C9A66B); // bila belum ada foto
  static const berandaFotoIkon = Color(0xFF8C6239);

  // Kartu hero (nama, jumlah item)
  static const berandaHeroGradasiAtas = Color(0xFF45301F);
  static const berandaHeroGradasiBawah = Color(0xFF9A6B3A);
  static const berandaHeroBayangan = Color(0x6145301F);
  static const berandaHeroNama = Color(0xFFFFFFFF);
  static const berandaHeroLabel = Color(0xFFE6CFA3); // tulisan KOLEKSIMU
  static const berandaHeroAngka = Color(0xFFFFFFFF);
  static const berandaHeroChipLatar = Color(0x2EFFFFFF);
  static const berandaHeroChipTeks = Color(0xFFFFFFFF);

  // Judul seksi
  static const berandaJudulAcaraTerdekat = Color(0xFF1E1A14);
  static const berandaJudulMenu = Color(0xFF1E1A14);

  // Kartu "Acara terdekat"
  static const berandaAcaraKartu = Color(0xFFFFFFFF);
  static const berandaAcaraGaris = Color(0xFFEADBC4);
  static const berandaAcaraBayangan = Color(0x338C6239);
  static const berandaAcaraTanggalAtas = Color(0xFFEBD8AE);
  static const berandaAcaraTanggalBawah = Color(0xFFC9A66B);
  static const berandaAcaraTanggalTeks = Color(0xFF45301F);
  static const berandaAcaraJudul = Color(0xFF1E1A14);
  static const berandaAcaraWaktu = Color(0xA61E1A14);
  static const berandaAcaraChipLatar = Color(0xFFEDE0CB); // "2 hari lagi"
  static const berandaAcaraChipTeks = Color(0xFF8C6239);
  static const berandaAcaraPanah = Color(0xFF1E1A14);
  static const berandaAcaraKosongLatarIkon = Color(0xFFEDE0CB);
  static const berandaAcaraKosongIkon = Color(0xFF8C6239);
  static const berandaAcaraKosongTeks = Color(0xB31E1A14);

  // Ubin menu (Koleksi, Konversi, dst.)
  static const berandaMenuGradasiAtas = Color(0xFFFFFFFF);
  static const berandaMenuGradasiBawah = Color(0xFFFAF1E2);
  static const berandaMenuGaris = Color(0xFFEADBC4);
  static const berandaMenuBayangan = Color(0x338C6239);
  static const berandaMenuIkon = Color(0xFF8C6239);
  static const berandaMenuTeks = Color(0xFF1E1A14);

  // ===================================================================
  // PROFIL
  // ===================================================================
  static const profilHeaderGradasiAtas = Color(0xFF9A6B3A);
  static const profilHeaderGradasiBawah = Color(0xFF45301F);
  static const profilHeaderLabel = Color(0xD9FBF5EA); // tulisan PROFIL
  static const profilHeaderNama = Color(0xFFFBF5EA);
  static const profilFotoCincin = Color(0xFFC9A66B);
  static const profilFotoLatar = Color(0xFFF2E6D2);
  static const profilFotoIkon = Color(0xFF9A6B3A);
  static const profilKameraLatar = Color(0xFFC9A66B); // tombol kamera
  static const profilKameraGaris = Color(0xFFFBF5EA);
  static const profilKameraIkon = Color(0xFF45301F);
  static const profilKartu = Color(0xFFFFFFFF); // kartu Nama, Email, dst.
  static const profilLabel = Color(0xFF8C6239); // NAMA TAMPILAN, EMAIL
  static const profilNilai = Color(0xFF1E1A14);
  static const profilAksi = Color(0xFF8C6239); // tulisan "Ubah"
  static const profilKeterangan = Color(0x8C1E1A14);
  static const profilIkonKartu = Color(0xFF8C6239); // ikon sidik jari, sinkron
  static const profilJudulKartu = Color(0xFF1E1A14);
  static const profilSubjudulKartu = Color(0x991E1A14);
  static const profilSaklarAktif = Color(0xFF8C6239);

  // ===================================================================
  // SARAN DAN KESAN
  // ===================================================================
  static const saranJudul = Color(0xFF1E1A14); // "Saran & Kesan"
  static const saranSubjudul = Color(0x991E1A14);
  static const saranKartu = Color(0xFFFFFFFF); // kartu rating dan riwayat
  static const saranLabel = Color(0xFF8C6239);
  static const saranBintangAktif = Color(0xFFC9A66B);
  static const saranBintangKosong = Color(0xFFE6DCCD);
  static const saranKolomIsi = Color(0xFFFFFFFF);
  static const saranKolomGaris = Color(0xFFEADBC4);
  static const saranKolomGarisFokus = Color(0xFF8C6239);
  static const saranTombolGradasiAtas = Color(0xFF9A6B3A); // tombol Kirim
  static const saranTombolGradasiBawah = Color(0xFF45301F);
  static const saranJudulRiwayat = Color(0xFF1E1A14);
  static const saranTeksRiwayat = Color(0xFF1E1A14);
  static const saranTanggalRiwayat = Color(0x8C1E1A14);
  static const saranKosong = Color(0x991E1A14); // "Belum ada kiriman."
  static const saranGalat = Color(0xFFB3261E);

  // ===================================================================
  // LOGIN DAN DAFTAR
  // ===================================================================
  // Kepala bergradasi di Login
  static const authHeaderGradasiAtas = Color(0xFF45301F);
  static const authHeaderGradasiBawah = Color(0xFF9A6B3A);
  static const authHeaderJudul = Color(0xFFFBF5EA); // tulisan "Numisma"
  static const authHeaderTagline = Color(0xD9FBF5EA);

  // Lembar di bawah kepala (Login) dan latar halaman Daftar
  static const authLembarAtas = Color(0xFFFBF5EA);
  static const authLembarBawah = Color(0xFFF2E6D2);
  static const authLatarBelakang = Color(0xFFF2E6D2); // di balik lembar Login

  // Teks
  static const authJudul = Color(0xFF1E1A14); // "Masuk" dan "Daftar"
  static const authKeterangan = Color(0xA61E1A14);
  static const authLabel = Color(0xFF8C6239); // EMAIL, PASSWORD
  static const authCatatan = Color(0x8C1E1A14); // catatan di bawah tombol Daftar

  // Kolom isian
  static const authKolomIsi = Color(0xFFFFFFFF);
  static const authKolomGaris = Color(0xFFEADBC4);
  static const authKolomGarisFokus = Color(0xFF8C6239);
  static const authKolomGarisGalat = Color(0xFFB3261E);
  static const authKolomIkon = Color(0xFF8C6239);
  static const authKolomHint = Color(0x661E1A14);

  // Tombol
  static const authTombolGradasiAtas = Color(0xFF9A6B3A); // Masuk, Daftar
  static const authTombolGradasiBawah = Color(0xFF45301F);
  static const authSidikJariLatar = Color(0xFFFFFFFF);
  static const authSidikJariTeks = Color(0xFF8C6239);
  static const authSidikJariGaris = Color(0xFFEADBC4);
  static const authPemisah = Color(0x801E1A14); // tulisan "atau"
  static const authTautanTeks = Color(0xA61E1A14); // "Belum punya akun?"
  static const authTautanAksen = Color(0xFF8C6239); // "Daftar"

  // Halaman Daftar
  static const authTombolKembaliLatar = Color(0xFFFFFFFF);
  static const authTombolKembaliGaris = Color(0xFFEADBC4);
  static const authTombolKembaliIkon = Color(0xFF8C6239);
  static const authSyaratOkLatar = Color(0xFFE1E8D0); // chip syarat terpenuhi
  static const authSyaratOkTeks = Color(0xFF2E6B2E);
  static const authSyaratBelumLatar = Color(0xFFEADFCE);
  static const authSyaratBelumTeks = Color(0xFF6B5A44);
}
