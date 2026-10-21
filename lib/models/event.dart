// models/event.dart
// Model data untuk tabel `events` (NUMISMA_GUIDE 0.5, Bagian 5.1): acara
// kolektor yang dibuat pengguna sendiri, satu set per akun.

class Event {
  final int id;
  final int userId;
  final String title;
  // Waktu mulai dalam UTC. Konversi ke WIB/WITA/WIT/UTC dilakukan saat
  // ditampilkan (time_util.dart), bukan saat disimpan.
  final DateTime startUtc;
  final String? location; // nama tempat (teks)

  const Event({
    required this.id,
    required this.userId,
    required this.title,
    required this.startUtc,
    this.location,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      // Selalu dijadikan UTC walau teksnya tanpa tanda "Z".
      startUtc: DateTime.parse(map['start_utc'] as String).toUtc(),
      location: map['location'] as String?,
    );
  }
}
