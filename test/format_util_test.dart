// Uji format selisih waktu untuk tampilan pengingat ("30 menit sebelum").

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/core/format_util.dart';

void main() {
  test('formatDuration memilih satuan yang enak dibaca', () {
    expect(formatDuration(const Duration(minutes: 5)), '5 menit');
    expect(formatDuration(const Duration(minutes: 30)), '30 menit');
    expect(formatDuration(const Duration(hours: 1)), '1 jam');
    expect(formatDuration(const Duration(minutes: 90)), '1 jam 30 menit');
    expect(formatDuration(const Duration(days: 1)), '1 hari');
    expect(formatDuration(const Duration(days: 2)), '2 hari');
    expect(formatDuration(Duration.zero), '0 menit');
  });

  test('formatCountdown memakai satu satuan dibulatkan ke bawah', () {
    expect(formatCountdown(const Duration(seconds: 30)), 'sebentar lagi');
    expect(formatCountdown(const Duration(minutes: 45)), '45 menit lagi');
    expect(formatCountdown(const Duration(minutes: 150)), '2 jam lagi');
    expect(
      formatCountdown(const Duration(hours: 23, minutes: 59)),
      '23 jam lagi',
    );
    expect(formatCountdown(const Duration(hours: 49)), '2 hari lagi');
  });
}
