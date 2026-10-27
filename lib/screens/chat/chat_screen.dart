// screens/chat/chat_screen.dart
// Chatbot "Tanya Numisma" (K9b, NUMISMA_GUIDE 7.9b). Dua mode:
// - Umum: dibuka dari Beranda, tanya jawab numismatik.
// - Konteks koin: dibuka dari detail koin (`contextCoin` terisi). Data koin
//   dan fotonya (bila ada di perangkat ini) ikut dikirim ke AI, jadi AI
//   melihat gambarnya, bukan hanya percaya teks data.
//
// Riwayat percakapan hanya di memori selama layar terbuka. Chat TIDAK
// mengubah database: bila AI menyarankan data lain, pengguna sendiri yang
// mengubahnya lewat form Ubah (supaya setiap perubahan dikonfirmasi).
// Layar tidak memanggil HTTP langsung, semuanya lewat AiService.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/coin.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import '../../widgets/field_label.dart';
import '../../widgets/soft_card.dart';

class ChatScreen extends StatefulWidget {
  // null = mode umum.
  final Coin? contextCoin;
  const ChatScreen({super.key, this.contextCoin});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ai = AiService();
  final _auth = AuthService();
  final _coinRepo = CoinRepo();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<ChatMsg> _messages = [];
  bool _waiting = false; // menunggu jawaban AI
  String? _error; // gagal pada giliran terakhir

  String? _coinContext; // teks data koin untuk prompt sistem
  Uint8List? _coinPhoto; // foto koin, bila ada di perangkat ini
  bool _contextReady = false;
  int?
  _collectionCount; // mode umum: jumlah item koleksi yang dikirim; null = gagal

  @override
  void initState() {
    super.initState();
    _prepareContext();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Menyiapkan konteks koin (mode konteks saja). Catatan pribadi dan harga
  // beli sengaja TIDAK ikut dikirim ke AI: hanya data identitas koin.
  Future<void> _prepareContext() async {
    final coin = widget.contextCoin;
    if (coin != null) {
      final photoPath = coin.photoPath;
      Uint8List? photo;
      if (photoPath != null) {
        final file = File(photoPath);
        if (await file.exists()) photo = await file.readAsBytes();
      }
      _coinPhoto = photo;
      _coinContext = _buildCoinContext(coin);
    } else {
      await _prepareCollectionContext();
    }
    if (mounted) setState(() => _contextReady = true);
  }

  // Mode umum: daftar koleksi pengguna dikirim sebagai teks di prompt sistem,
  // supaya AI bisa menjawab "koin apa yang paling tua?" atau "ringkas
  // koleksiku". AI tidak membuka database sendiri (tanpa function-calling):
  // aplikasi yang menyusun ringkasannya. Foto, catatan pribadi, dan harga beli
  // TIDAK ikut dikirim. Gagal membaca koleksi tidak fatal: chat umum jalan
  // seperti biasa tanpa konteks.
  Future<void> _prepareCollectionContext() async {
    try {
      final user = await _auth.currentUser();
      if (user == null) return;
      final coins = await _coinRepo.list(user.id!, sort: 'year');
      _collectionCount = coins.length;
      _coinContext = _buildCollectionContext(coins);
    } catch (_) {
      _collectionCount = null;
    }
  }

  // Batas jumlah koin yang dikirim, supaya koleksi besar tidak membengkakkan
  // biaya dan waktu tunggu. Sisanya cukup disebut jumlahnya.
  static const _maxCoinsInContext = 100;

  String _buildCollectionContext(List<Coin> coins) {
    if (coins.isEmpty) {
      return 'Koleksi pengguna di aplikasi masih kosong. Jika ditanya tentang '
          'koleksinya, katakan belum ada koin yang tercatat.';
    }
    final coinCount = coins.where((c) => c.type == 'coin').length;
    final lines = <String>[
      for (final c in coins.take(_maxCoinsInContext))
        '- ${c.type == 'banknote' ? 'uang kertas' : 'koin'}, ${c.country}, '
            '${c.denominationLabel} ${c.currencyCode}'
            '${c.year == null ? ', tahun tidak diketahui' : ', ${c.year}'}'
            '${c.condition == null ? '' : ', kondisi ${c.condition}'}',
    ];
    final more = coins.length > _maxCoinsInContext
        ? '\n(dan ${coins.length - _maxCoinsInContext} item lainnya tidak '
              'ditampilkan)'
        : '';
    return 'Koleksi pengguna di aplikasi: ${coins.length} item '
        '($coinCount koin, ${coins.length - coinCount} uang kertas). '
        'Daftar:\n${lines.join('\n')}$more\n'
        'Jika pengguna bertanya tentang koleksinya, jawab berdasarkan daftar '
        'ini saja dan jangan mengarang item yang tidak ada. Kamu tidak tahu '
        'harga pasarnya.';
  }

  String _buildCoinContext(Coin c) {
    final parts = <String>[
      'jenis: ${c.type == 'banknote' ? 'uang kertas' : 'koin'}',
      'negara: ${c.country}',
      'mata uang: ${c.currencyCode}',
      'nominal: ${c.denominationLabel}',
      if (c.year != null) 'tahun: ${c.year}',
      if (c.condition != null) 'kondisi: ${c.condition}',
      if (c.aiSummary != null)
        'ringkasan analisis AI sebelumnya: ${c.aiSummary}',
    ];
    return 'Koin yang sedang dibahas (data tersimpan di aplikasi): '
        '${parts.join('; ')}. '
        '${_coinPhoto != null ? 'Foto koin dilampirkan pada pesan pertama. ' : 'Tidak ada foto koin, hanya data teks. '}'
        'Jika foto atau pertanyaan menunjukkan data tersimpan keliru atau '
        'berbeda, sebutkan perbedaannya dan sarankan pengguna memeriksa dan '
        'mengubah datanya sendiri. Kamu tidak mengubah data apa pun.';
  }

  // --- Kirim ---------------------------------------------------------

  Future<void> _sendTyped() async {
    final text = _input.text.trim();
    if (text.isEmpty || _waiting) return;
    _input.clear();
    setState(() => _messages.add(ChatMsg(true, text)));
    _scrollToEnd();
    await _ask();
  }

  // Mengirim pesan pengguna TERAKHIR yang belum dijawab. Dipakai juga oleh
  // "Coba lagi": pesan pengguna tetap ada di daftar, tidak diketik ulang.
  Future<void> _ask() async {
    final last = _messages.last;
    final history = _messages.sublist(0, _messages.length - 1);
    setState(() {
      _waiting = true;
      _error = null;
    });
    try {
      final answer = await _ai.chat(
        history,
        last.text,
        coinContext: _coinContext,
        coinPhoto: _coinPhoto,
      );
      if (!mounted) return;
      setState(() => _messages.add(ChatMsg(false, answer)));
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      // Mis. key AI belum diisi di .env.
      if (!mounted) return;
      setState(() => _error = 'Fitur AI belum siap. Coba lagi nanti.');
    } finally {
      if (mounted) {
        setState(() => _waiting = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    // Ditunda satu frame supaya daftar sudah menambah item baru.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _useSuggestion(String text) {
    _input.text = text;
    _sendTyped();
  }

  // --- Tampilan ------------------------------------------------------

  List<String> get _suggestions => widget.contextCoin == null
      ? [
          if (_collectionCount != null && _collectionCount! > 0) ...[
            'Ringkas koleksiku.',
            'Koin mana yang paling tua di koleksiku?',
          ],
          'Apa bedanya nilai nominal dan nilai koleksi?',
          'Apa arti grade UNC, XF, dan VF?',
        ]
      : const [
          'Apakah data koin ini sesuai dengan fotonya?',
          'Ceritakan sejarah singkat koin ini.',
          'Bagaimana cara merawat koin ini?',
        ];

  @override
  Widget build(BuildContext context) {
    final coin = widget.contextCoin;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          coin == null
              ? 'Tanya Numisma'
              : 'Tanya: ${coin.country} ${coin.denominationLabel}',
        ),
      ),
      body: !_contextReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (coin != null || _collectionCount != null) _contextBanner(),
                Expanded(child: _buildMessages()),
                if (_error != null) _errorBar(),
                _inputBar(),
              ],
            ),
    );
  }

  Widget _contextBanner() {
    final hasPhoto = _coinPhoto != null;
    final String text;
    if (widget.contextCoin == null) {
      // Mode umum: pengguna perlu tahu apa saja yang dikirim ke AI.
      text =
          'AI bisa melihat daftar koleksimu ($_collectionCount item: negara, '
          'nominal, tahun, kondisi). Foto dan catatan pribadimu tidak '
          'dikirim.';
    } else if (hasPhoto) {
      text = 'AI melihat foto dan data koin ini. Jawabannya hanya perkiraan.';
    } else {
      text =
          'Koin ini tidak punya foto di perangkat ini, jadi AI hanya '
          'melihat data teksnya.';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tileActive,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.bronze),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.ink.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Daftar pertanyaan cepat di tengah percakapan: lembar bawah berisi
  // pertanyaan yang sama dengan layar awal. Memilih satu langsung
  // mengirimnya; tidak aktif saat AI sedang menjawab.
  Future<void> _showSuggestions() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.creamTop,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pertanyaan cepat',
                style: AppText.serif(size: 22, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final s in _suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    onTap: () => Navigator.of(ctx).pop(s),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.north_east,
                          size: 18,
                          color: AppColors.bronze,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted && !_waiting) _useSuggestion(picked);
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.brown,
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.contextCoin == null
                ? 'Tanyakan apa saja seputar koin dan uang kertas.'
                : 'Tanyakan tentang koin ini.',
            textAlign: TextAlign.center,
            style: AppText.serif(size: 22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Jawaban hanya perkiraan, bukan penilaian ahli.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 20),
          for (final s in _suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                onTap: () => _useSuggestion(s),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(
                  s,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + (_waiting ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _typingBubble();
        return _bubble(_messages[i]);
      },
    );
  }

  Widget _bubble(ChatMsg m) {
    final mine = m.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        // Gelembung pengguna bergradasi cokelat, gelembung AI putih dengan
        // garis krem; sudut ekor yang menghadap pembicara dibuat lancip.
        decoration: BoxDecoration(
          gradient: mine ? AppGradients.brown : null,
          color: mine ? null : AppColors.card,
          border: mine ? null : Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 6),
            bottomRight: Radius.circular(mine ? 6 : 20),
          ),
          boxShadow: AppShadows.soft,
        ),
        child: SelectableText(
          m.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: mine ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _errorBar() {
    return Container(
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _waiting ? null : _ask,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Pertanyaan cepat tetap bisa dibuka di tengah percakapan.
            IconButton(
              tooltip: 'Pertanyaan cepat',
              onPressed: _waiting ? null : _showSuggestions,
              icon: const Icon(
                Icons.lightbulb_outline,
                color: AppColors.bronze,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTyped(),
                decoration: appInput(hint: 'Tulis pertanyaan', radius: 24),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol kirim bulat bergradasi.
            Opacity(
              opacity: _waiting ? 0.5 : 1,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.brown,
                  boxShadow: AppShadows.soft,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _waiting ? null : _sendTyped,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
