// core/format_util.dart
// Format tampilan angka dan tanggal yang dipakai beberapa layar (Kurs,
// Nilai Koleksi, multi-pilih Koleksi). Dibuat manual tanpa paket intl
// karena kebutuhannya sederhana.

// Singkatan bulan bahasa Indonesia (indeks 0 = Januari).
const monthNamesId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

// Format angka gaya Indonesia: titik pemisah ribuan, koma desimal.
// Jumlah desimal menyesuaikan besar angka supaya kurs kecil (0,008781)
// tidak tampil "0,00".
String formatNumber(double value) {
  // Angka sangat besar (atau tak terhingga) tidak boleh tampil berpangkat
  // ("1.0e+21"): toStringAsFixed berganti ke notasi eksponen mulai 1e21.
  if (!value.isFinite || value.abs() >= 1e21) return 'sangat besar';
  final abs = value.abs();
  final decimals = abs >= 100 ? 2 : (abs >= 1 ? 4 : 6);
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final negative = parts[0].startsWith('-');
  final digits = negative ? parts[0].substring(1) : parts[0];

  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  // Buang nol di belakang desimal ("113,8800" -> "113,88").
  final fraction = parts.length > 1
      ? parts[1].replaceFirst(RegExp(r'0+$'), '')
      : '';
  return '${negative ? '-' : ''}$grouped${fraction.isEmpty ? '' : ',$fraction'}';
}

// Selisih waktu yang enak dibaca: "30 menit", "1 jam", "1 jam 30 menit",
// "1 hari". Dipakai untuk "Pengingat: 30 menit sebelum acara".
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  if (minutes <= 0) return '0 menit';
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} hari';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest menit';
  if (rest == 0) return '$hours jam';
  return '$hours jam $rest menit';
}

// Hitung mundur satu satuan saja untuk Beranda: "sebentar lagi", "45 menit
// lagi", "3 jam lagi", "2 hari lagi". Satuan dibulatkan ke bawah.
String formatCountdown(Duration d) {
  if (d.inMinutes < 1) return 'sebentar lagi';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lagi';
  if (d.inHours < 24) return '${d.inHours} jam lagi';
  return '${d.inDays} hari lagi';
}

// "2026-10-20" -> "20 Okt 2026". Dibuat manual (tanpa paket intl) karena
// formatnya sederhana dan hanya dipakai di sini.
String formatRateDate(String isoDate) {
  final months = monthNamesId;
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return isoDate;
  return '${int.parse(parts[2])} ${months[month - 1]} ${parts[0]}';
}
