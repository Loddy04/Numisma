// core/format_util.dart
// Format tampilan angka dan tanggal yang dipakai beberapa layar (Kurs,
// Nilai Koleksi, multi-pilih Koleksi). Dibuat manual tanpa paket intl
// karena kebutuhannya sederhana.

// Format angka gaya Indonesia: titik pemisah ribuan, koma desimal.
// Jumlah desimal menyesuaikan besar angka supaya kurs kecil (0,008781)
// tidak tampil "0,00".
String formatNumber(double value) {
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
  final fraction = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return '${negative ? '-' : ''}$grouped${fraction.isEmpty ? '' : ',$fraction'}';
}

// "2026-10-20" -> "20 Okt 2026". Dibuat manual (tanpa paket intl) karena
// formatnya sederhana dan hanya dipakai di sini.
String formatRateDate(String isoDate) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return isoDate;
  return '${int.parse(parts[2])} ${months[month - 1]} ${parts[0]}';
}
