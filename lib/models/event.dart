// models/event.dart
// Model data untuk tabel `events` (NUMISMA_GUIDE Bagian 5.1): acara
// kolektor. Isinya data CONTOH untuk demo, bukan acara nyata.

class Event {
  final int id;
  final String title;
  // Waktu mulai dalam UTC. Konversi ke WIB/WITA/WIT/London dilakukan
  // saat ditampilkan (time_util.dart), bukan saat disimpan.
  final DateTime startUtc;
  final String? location;
  final String? note;

  const Event({
    required this.id,
    required this.title,
    required this.startUtc,
    this.location,
    this.note,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as int,
      title: map['title'] as String,
      // Selalu dijadikan UTC walau teksnya tanpa tanda "Z".
      startUtc: DateTime.parse(map['start_utc'] as String).toUtc(),
      location: map['location'] as String?,
      note: map['note'] as String?,
    );
  }
}
