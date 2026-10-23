// models/coin.dart
// Model data untuk tabel `coins` (lihat NUMISMA_GUIDE Bagian 5.1).
// Seperti user.dart, file ini hanya bentuk data tanpa logika bisnis.
//
// Catatan pengguna disimpan di sini dalam bentuk teks biasa (`notes`)
// supaya layar mudah memakainya. Enkripsi AES ke kolom `notes_enc`
// dilakukan di coin_repo.dart, bukan di model, supaya model tetap
// sederhana dan tidak bergantung pada kriptografi.

import 'package:uuid/uuid.dart';

class Coin {
  final String id; // UUID v4, dibuat di aplikasi (bukan oleh SQLite)
  final int userId;
  final String type; // 'coin' atau 'banknote'
  final String country;
  final String currencyCode; // ISO 4217, mis. JPY
  final double denomination; // nominal, mis. 100
  final int? year;
  final String? condition; // UNC, XF, VF, F, G
  final double? buyPrice;
  final String? buyCurrency;
  final String? notes; // teks asli; di DB tersimpan terenkripsi
  // true = ada catatan terenkripsi tetapi gagal dibuka (mis. setelah Pulihkan
  // di HP lain: kunci AES hanya ada di HP lama). Tidak disimpan ke DB.
  final bool notesUnreadable;
  final String? photoPath;
  final String? aiSummary; // null = belum/tidak pernah dianalisis AI
  final String createdAt; // ISO-8601 UTC
  final String updatedAt; // ISO-8601 UTC
  final bool isSynced;

  const Coin({
    required this.id,
    required this.userId,
    required this.type,
    required this.country,
    required this.currencyCode,
    required this.denomination,
    this.year,
    this.condition,
    this.buyPrice,
    this.buyCurrency,
    this.notes,
    this.notesUnreadable = false,
    this.photoPath,
    this.aiSummary,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  // Dipanggil layar saat membuat koin baru. Waktu disimpan UTC sesuai
  // aturan skema, dan id dibuat di sini supaya koin sudah punya
  // identitas sebelum menyentuh database.
  factory Coin.create({
    required int userId,
    required String type,
    required String country,
    required String currencyCode,
    required double denomination,
    int? year,
    String? condition,
    double? buyPrice,
    String? buyCurrency,
    String? notes,
    String? aiSummary,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return Coin(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      country: country,
      currencyCode: currencyCode,
      denomination: denomination,
      year: year,
      condition: condition,
      buyPrice: buyPrice,
      buyCurrency: buyCurrency,
      notes: notes,
      aiSummary: aiSummary,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Nominal tanpa ".0" yang tidak perlu: 100.0 tampil "100", 0.5 tetap "0.5".
  String get denominationLabel => denomination == denomination.truncateToDouble()
      ? denomination.toInt().toString()
      : denomination.toString();

  // Ke baris SQLite. `notesEnc` diberikan repo (hasil enkripsi AES),
  // karena model sendiri tidak boleh menulis `notes` sebagai teks biasa.
  Map<String, dynamic> toMap({String? notesEnc}) {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'country': country,
      'currency_code': currencyCode,
      'denomination': denomination,
      'year': year,
      'condition': condition,
      'buy_price': buyPrice,
      'buy_currency': buyCurrency,
      'notes_enc': notesEnc,
      'photo_path': photoPath,
      'ai_summary': aiSummary,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  // Dari baris SQLite. `notes` adalah hasil dekripsi dari repo; null
  // kalau tidak ada catatan, atau kalau repo sengaja tidak mendekripsi
  // (lihat catatan di CoinRepo.list).
  factory Coin.fromMap(
    Map<String, dynamic> map, {
    String? notes,
    bool notesUnreadable = false,
  }) {
    return Coin(
      id: map['id'] as String,
      userId: map['user_id'] as int,
      type: map['type'] as String,
      country: map['country'] as String,
      currencyCode: map['currency_code'] as String,
      denomination: (map['denomination'] as num).toDouble(),
      year: map['year'] as int?,
      condition: map['condition'] as String?,
      buyPrice: (map['buy_price'] as num?)?.toDouble(),
      buyCurrency: map['buy_currency'] as String?,
      notes: notes,
      notesUnreadable: notesUnreadable,
      photoPath: map['photo_path'] as String?,
      aiSummary: map['ai_summary'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  Coin copyWith({
    String? type,
    String? country,
    String? currencyCode,
    double? denomination,
    int? year,
    String? condition,
    double? buyPrice,
    String? buyCurrency,
    String? notes,
    String? photoPath,
    String? aiSummary,
    String? updatedAt,
    bool? isSynced,
  }) {
    return Coin(
      id: id,
      userId: userId,
      type: type ?? this.type,
      country: country ?? this.country,
      currencyCode: currencyCode ?? this.currencyCode,
      denomination: denomination ?? this.denomination,
      year: year ?? this.year,
      condition: condition ?? this.condition,
      buyPrice: buyPrice ?? this.buyPrice,
      buyCurrency: buyCurrency ?? this.buyCurrency,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      aiSummary: aiSummary ?? this.aiSummary,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
