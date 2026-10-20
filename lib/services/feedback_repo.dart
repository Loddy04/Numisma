// services/feedback_repo.dart
// Membaca/menulis tabel `feedback` (saran dan kesan mata kuliah,
// NUMISMA_GUIDE Bagian 7.6). Seperti service lain, layar tidak
// menyentuh database langsung: screen -> feedback_repo -> db_helper.
//
// Bentuk data satu baris (FeedbackEntry) ditaruh di file yang sama
// karena kecil dan hanya dipakai di sini dan di feedback_screen.dart.

import '../core/db_helper.dart';

class FeedbackEntry {
  final int id;
  final int rating; // 1-5 (dijaga juga oleh CHECK di tabel)
  final String? saran;
  final String? kesan;
  final String createdAt; // ISO-8601 UTC

  const FeedbackEntry({
    required this.id,
    required this.rating,
    this.saran,
    this.kesan,
    required this.createdAt,
  });

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id'] as int,
      rating: map['rating'] as int,
      saran: map['saran'] as String?,
      kesan: map['kesan'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class FeedbackRepo {
  // Teks kosong disimpan sebagai NULL, supaya kolom jelas menandai
  // "tidak diisi" dan riwayat tidak menampilkan baris kosong.
  Future<void> add({
    required int userId,
    required int rating,
    String? saran,
    String? kesan,
  }) async {
    final db = await DbHelper.instance.database;
    await db.insert('feedback', {
      'user_id': userId,
      'rating': rating,
      'saran': _nullIfBlank(saran),
      'kesan': _nullIfBlank(kesan),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // Riwayat milik satu pengguna, yang terbaru di atas.
  Future<List<FeedbackEntry>> list(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'feedback',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(FeedbackEntry.fromMap).toList();
  }

  String? _nullIfBlank(String? text) {
    final t = text?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
