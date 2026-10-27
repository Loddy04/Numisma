// Uji pembersih teks AI (tidyAiText): jawaban chat dan ringkasan scan tidak
// boleh memuat Markdown, poin berstrip, atau strip pemisah.

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/services/ai_service.dart';

void main() {
  test('Markdown tebal dan judul dibuang', () {
    expect(tidyAiText('**UNC** artinya belum beredar.'), 'UNC artinya belum beredar.');
    expect(tidyAiText('## Perawatan\nSimpan kering.'), 'Perawatan\nSimpan kering.');
  });

  test('poin berstrip atau bintang menjadi kalimat biasa', () {
    const input = '- Simpan di tempat kering\n* Hindari sentuhan langsung\n• Gunakan sarung tangan.';
    expect(
      tidyAiText(input),
      'Simpan di tempat kering.\nHindari sentuhan langsung.\nGunakan sarung tangan.',
    );
  });

  test('em dash dan strip berspasi diganti koma', () {
    expect(tidyAiText('Koin ini tua — sekitar 1950.'), 'Koin ini tua, sekitar 1950.');
    expect(tidyAiText('Koin ini tua - sekitar 1950.'), 'Koin ini tua, sekitar 1950.');
    expect(tidyAiText('Koin ini tua – sekitar 1950.'), 'Koin ini tua, sekitar 1950.');
  });

  test('strip di dalam kata dan rentang angka tidak disentuh', () {
    expect(tidyAiText('Dicetak 1990-1995 dan 8–64.'), 'Dicetak 1990-1995 dan 8–64.');
    expect(tidyAiText('Pecahan setengah-sen.'), 'Pecahan setengah-sen.');
  });

  test('baris kosong berlebih dirapatkan dan ujung dipangkas', () {
    expect(tidyAiText('  Halo.\n\n\n\nSampai jumpa.  '), 'Halo.\n\nSampai jumpa.');
  });

  test('teks bersih tidak berubah', () {
    const clean = 'Koin ini berasal dari Jepang. Nominalnya 100 yen.';
    expect(tidyAiText(clean), clean);
  });
}
