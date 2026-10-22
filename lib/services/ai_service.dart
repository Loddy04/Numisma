// services/ai_service.dart
// Fitur AI (K9, NUMISMA_GUIDE 7.9): kenali koin/uang kertas dari foto
// (identifyCoin). Memakai REST OpenAI lewat paket `http`, tanpa SDK. Key dan
// nama model dibaca dari .env lewat Config (bukan ditulis di kode). Layar
// tidak memanggil HTTP langsung (aturan Bagian 4.1).
//
// Setiap kegagalan diubah menjadi AiException dengan pesan ramah, yang
// langsung boleh ditampilkan ke pengguna.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config.dart';

// Kesalahan dengan pesan yang sudah ramah untuk pengguna.
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

// Hasil tebakan AI untuk satu foto. Semua field bisa null: AI diminta
// mengisi null bila tidak yakin, dan pengguna selalu mengoreksi di form.
class CoinGuess {
  final String type; // 'coin' atau 'banknote'
  final String? country; // nama negara (bahasa Inggris, sesuai prompt)
  final String?
  currencyCode; // ISO 4217, null bila mata uang sudah tidak berlaku
  final double? denomination;
  final int? year;
  // true = tahun hanya PERKIRAAN AI dari desain/gaya, bukan tahun yang
  // tertera di koin. Pengguna diberi tahu supaya memeriksanya.
  final bool yearEstimated;
  final String features; // ciri khas, maksimal 2 kalimat
  final String confidence; // low / medium / high
  // true = hasil contoh untuk cadangan demo, BUKAN hasil analisis foto.
  final bool isSample;

  const CoinGuess({
    required this.type,
    this.country,
    this.currencyCode,
    this.denomination,
    this.year,
    this.yearEstimated = false,
    required this.features,
    required this.confidence,
    this.isSample = false,
  });

  // Cadangan demo bila internet atau kuota bermasalah (Guide 6.2).
  factory CoinGuess.sample() => const CoinGuess(
    type: 'coin',
    country: 'Japan',
    currencyCode: 'JPY',
    denomination: 100,
    year: 1990,
    features:
        'Hasil contoh (bukan hasil analisis foto ini): koin 100 yen Jepang.',
    confidence: 'low',
    isSample: true,
  );

  // Teks yang disimpan ke coins.ai_summary. Tidak pernah kosong, karena
  // ai_summary yang terisi menandai "koin ini sudah dianalisis AI".
  String get summary {
    final text = features.trim().isEmpty ? 'Dianalisis AI.' : features.trim();
    if (isSample) return text;
    final estimate = yearEstimated ? ' Tahun adalah perkiraan AI.' : '';
    return '$text$estimate (kepercayaan AI: $confidence)';
  }

  // Parser yang toleran: AI kadang mengirim angka sebagai teks ("100") atau
  // kode mata uang berhuruf kecil. Nilai yang tidak masuk akal jadi null,
  // supaya form tidak terisi sampah.
  factory CoinGuess.fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty || t.toLowerCase() == 'null') ? null : t;
    }

    double? number(Object? v) {
      if (v is num) return v.toDouble();
      final t = text(v);
      return t == null ? null : double.tryParse(t.replaceAll(',', '.'));
    }

    final code = text(json['currency_code'])?.toUpperCase();
    final denom = number(json['denomination']);
    final yearRaw = number(json['year'])?.toInt();
    final yearOk =
        yearRaw != null && yearRaw >= 1 && yearRaw <= DateTime.now().year;
    final estimatedRaw = json['year_estimated'];
    final estimated = estimatedRaw == true || estimatedRaw == 'true';
    final confidence = text(json['confidence'])?.toLowerCase();

    return CoinGuess(
      type: text(json['type']) == 'banknote' ? 'banknote' : 'coin',
      country: text(json['country']),
      currencyCode: (code != null && RegExp(r'^[A-Z]{3}$').hasMatch(code))
          ? code
          : null,
      denomination: (denom != null && denom > 0) ? denom : null,
      year: yearOk ? yearRaw : null,
      // Tanda "perkiraan" hanya bermakna bila tahunnya ada.
      yearEstimated: yearOk && estimated,
      features: text(json['features']) ?? '',
      confidence: const ['low', 'medium', 'high'].contains(confidence)
          ? confidence!
          : 'low',
    );
  }
}

// Satu pesan percakapan Tanya Numisma.
class ChatMsg {
  final bool fromUser; // false = jawaban AI
  final String text;
  const ChatMsg(this.fromUser, this.text);
}

class AiService {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _timeout = Duration(seconds: 30);

  // Model GPT-5 adalah model "reasoning". 'minimal' membuat jawaban cepat
  // dan murah, dan pada uji awal lebih berhati-hati (mengisi null, tidak
  // mengarang). Bila bacaan foto koin asli kurang baik, coba 'low'.
  static const _reasoningEffort = 'minimal';

  // Prompt scan (NUMISMA_GUIDE Lampiran B.1).
  static const _scanPrompt =
      'Kamu adalah asisten numismatik. Analisis foto koin atau uang kertas '
      'ini.\n'
      'Jawab HANYA dengan JSON valid, tanpa teks lain, dengan kunci:\n'
      '- type: "coin" atau "banknote"\n'
      '- country: nama negara dalam bahasa Inggris\n'
      '- currency_code: kode ISO 4217 bila mata uangnya masih berlaku, jika '
      'tidak null\n'
      '- denomination: angka nominal (null bila tidak terbaca)\n'
      '- year: angka tahun. Jika tahun tertera dan terbaca, pakai itu. Jika '
      'tidak terbaca, PERKIRAKAN satu tahun pembuatan dari desain, bahan, '
      'gaya, tanda nilai, dan seri uang/koinnya (tebakan terbaik, satu angka). '
      'Isi null hanya bila benar-benar tidak ada petunjuk sama sekali\n'
      '- year_estimated: true bila year adalah perkiraan, false bila tahunnya '
      'tertera dan terbaca\n'
      '- features: ciri khas dalam maksimal 2 kalimat bahasa Indonesia\n'
      '- confidence: "low", "medium", atau "high"\n'
      'Untuk kunci selain year: jika tidak yakin, isi null dan confidence '
      '"low". Jangan mengarang. Turunkan confidence bila year hanya '
      'perkiraan.';

  // Prompt sistem chatbot (NUMISMA_GUIDE Lampiran B.2). Baris terakhir
  // ditambahkan: jawaban ditampilkan sebagai teks biasa, jadi tanda Markdown
  // (**tebal**, # judul) hanya akan tampil sebagai simbol yang mengganggu.
  static const _chatPrompt =
      'Kamu adalah "Tanya Numisma", asisten untuk kolektor koin dan uang '
      'kertas.\n'
      'Jawab dalam bahasa Indonesia, singkat (maksimal 6 kalimat).\n'
      'Hanya bahas numismatik: sejarah koin atau uang, perawatan, ciri umum '
      'keaslian, istilah.\n'
      'Untuk pertanyaan di luar topik, tolak dengan sopan dan arahkan '
      'kembali.\n'
      'Jangan memberi harga pasti atau menjamin keaslian; sarankan konsultasi '
      'ke ahli atau pedagang bereputasi.\n'
      'Tulis teks biasa tanpa format Markdown.';

  // Hanya sekian pesan terakhir yang dikirim: percakapan panjang membuat
  // biaya dan waktu tunggu membengkak (Guide 7.9b).
  static const maxHistory = 10;

  // Mengirim satu giliran percakapan. `history` = pesan sebelumnya (tanpa
  // `userMessage`). Mode konteks koin: `coinContext` (teks data koin) ditaruh
  // di prompt sistem supaya berlaku di SETIAP giliran, dan `coinPhoto`
  // dilampirkan pada pesan pengguna pertama yang ikut terkirim, jadi AI
  // melihat fotonya, bukan hanya percaya teks data. Chat tidak mengubah
  // database; revisi data tetap lewat form oleh pengguna.
  Future<String> chat(
    List<ChatMsg> history,
    String userMessage, {
    String? coinContext,
    Uint8List? coinPhoto,
  }) async {
    final recent = history.length > maxHistory
        ? history.sublist(history.length - maxHistory)
        : history;
    final system = coinContext == null
        ? _chatPrompt
        : '$_chatPrompt\n\n$coinContext';

    var photoAttached = false;
    Object contentOf(ChatMsg m) {
      if (m.fromUser && coinPhoto != null && !photoAttached) {
        photoAttached = true;
        return [
          {'type': 'text', 'text': m.text},
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${_mimeOf(coinPhoto)};base64,'
                  '${base64Encode(coinPhoto)}',
            },
          },
        ];
      }
      return m.text;
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      for (final m in [...recent, ChatMsg(true, userMessage)])
        {'role': m.fromUser ? 'user' : 'assistant', 'content': contentOf(m)},
    ];

    final answer = await _send({
      'model': Config.openaiModel,
      'reasoning_effort': _reasoningEffort,
      'max_completion_tokens': 700,
      'messages': messages,
    });
    return answer.trim();
  }

  // Mengirim satu foto dan mengembalikan tebakan AI. Foto sudah diperkecil
  // oleh image_picker (maxWidth 1024), jadi ukuran kirimnya kecil.
  Future<CoinGuess> identifyCoin(Uint8List imageBytes) async {
    final content = await _send({
      'model': Config.openaiModel,
      'reasoning_effort': _reasoningEffort,
      'max_completion_tokens': 800,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _scanPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${_mimeOf(imageBytes)};base64,'
                    '${base64Encode(imageBytes)}',
              },
            },
          ],
        },
      ],
    });

    try {
      final decoded = jsonDecode(_stripFence(content));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return CoinGuess.fromJson(decoded);
    } on FormatException {
      throw const AiException(
        'Jawaban AI tidak bisa dibaca. Coba lagi atau isi manual.',
      );
    }
  }

  // PNG diawali 89 50 4E 47; selain itu dianggap JPEG (hasil image_picker).
  String _mimeOf(Uint8List b) =>
      (b.length > 4 &&
          b[0] == 0x89 &&
          b[1] == 0x50 &&
          b[2] == 0x4E &&
          b[3] == 0x47)
      ? 'image/png'
      : 'image/jpeg';

  // Jaga-jaga bila model membungkus JSON dengan ```json ... ```.
  String _stripFence(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      t = t.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return t;
  }

  // Satu pintu ke OpenAI: mengirim, memeriksa status, dan mengembalikan
  // teks jawaban. Semua kegagalan jadi AiException ramah.
  Future<String> _send(Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer ${Config.openaiApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException('AI terlalu lama menjawab. Coba lagi.');
    } on SocketException {
      throw const AiException('Tidak bisa terhubung ke AI. Periksa internet.');
    } on http.ClientException {
      throw const AiException('Tidak bisa terhubung ke AI. Periksa internet.');
    }

    if (res.statusCode == 401) {
      throw const AiException(
        'Kunci AI tidak valid. Hubungi pemilik aplikasi.',
      );
    }
    if (res.statusCode == 429) {
      throw const AiException(
        'Kuota AI habis atau terlalu banyak permintaan. Coba lagi nanti.',
      );
    }
    if (res.statusCode != 200) {
      throw AiException('AI sedang bermasalah (kode ${res.statusCode}).');
    }

    try {
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final text = json['choices'][0]['message']['content'] as String?;
      if (text == null || text.trim().isEmpty) throw const FormatException();
      return text;
    } catch (_) {
      throw const AiException('Jawaban AI kosong atau tidak dikenali.');
    }
  }
}
