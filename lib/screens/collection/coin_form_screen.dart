// screens/collection/coin_form_screen.dart
// Form tambah (manual) dan ubah koin. Satu form dipakai untuk dua mode:
// kalau `coin` null = tambah baru, kalau terisi = ubah koin itu.
// Form ini tidak memanggil AI sendiri. Jalur Scan (scan_screen.dart) memanggil
// AI lebih dulu, lalu membuka form ini dengan `guess` (tebakan AI) dan foto
// yang sudah dipilih: kolom terisi dari tebakan, tetap bisa diedit, dan
// ringkasan AI ikut tersimpan di coins.ai_summary (NUMISMA_GUIDE Bagian 7.9).
//
// Foto (kamera atau galeri) WAJIB saat menambah koin. Di jalur manual foto
// hanya disimpan, tidak dianalisis AI. Saat mengubah, foto tidak dipaksa.
// Pop dengan nilai true bila data tersimpan.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/coin.dart';
import '../../services/ai_service.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import '../../widgets/currency_picker.dart';
import '../../widgets/field_label.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/soft_card.dart';
import '../crop/crop_screen.dart';

class CoinFormScreen extends StatefulWidget {
  final int userId;
  final Coin? coin; // null = mode tambah
  // Hanya dari jalur Scan: tebakan AI, foto yang dikirim ke AI, dan asalnya
  // (camera/gallery). Tanpa ketiganya form berjalan seperti biasa (manual).
  final CoinGuess? guess;
  final Uint8List? initialPhoto;
  final String initialPhotoSource;
  const CoinFormScreen({
    super.key,
    required this.userId,
    this.coin,
    this.guess,
    this.initialPhoto,
    this.initialPhotoSource = 'none',
  });

  @override
  State<CoinFormScreen> createState() => _CoinFormScreenState();
}

class _CoinFormScreenState extends State<CoinFormScreen> {
  static const _conditions = ['UNC', 'XF', 'VF', 'F', 'G'];

  final _formKey = GlobalKey<FormState>();
  final _repo = CoinRepo();
  final _picker = ImagePicker();

  late String _type;
  String? _condition;
  // Kode mata uang dipilih lewat CurrencyPickerField, jadi disimpan
  // sebagai String? (kode 3 huruf), bukan controller teks.
  String? _currencyCode;
  final _country = TextEditingController();
  final _denomination = TextEditingController();
  final _year = TextEditingController();
  final _notes = TextEditingController();

  // Foto baru yang dipilih pengguna (belum disimpan). Kalau null,
  // foto lama (mode ubah) dibiarkan apa adanya.
  Uint8List? _newPhotoBytes;
  String _photoSource = 'none';
  // true = tahun di form masih perkiraan AI (hilang begitu pengguna mengetik).
  bool _yearEstimated = false;
  bool _photoError = false; // true = tampilkan pesan "foto wajib"
  bool _saving = false;

  bool get _isEdit => widget.coin != null;

  @override
  void initState() {
    super.initState();
    final c = widget.coin;
    _type = c?.type ?? 'coin';
    if (c != null) {
      _condition = c.condition;
      _country.text = c.country;
      _currencyCode = c.currencyCode;
      _denomination.text = c.denominationLabel;
      _year.text = c.year?.toString() ?? '';
      _notes.text = c.notes ?? '';
    }

    // Jalur Scan: isi kolom dari tebakan AI (null dibiarkan kosong supaya
    // pengguna yang melengkapi) dan pakai foto yang sudah dikirim ke AI.
    final g = widget.guess;
    if (g != null && c == null) {
      _type = g.type;
      _country.text = g.country ?? '';
      _currencyCode = g.currencyCode;
      if (g.denomination != null) {
        final d = g.denomination!;
        _denomination.text = d == d.truncateToDouble()
            ? d.toInt().toString()
            : d.toString();
      }
      _year.text = g.year?.toString() ?? '';
      _yearEstimated = g.yearEstimated;
    }

    // Foto dari jalur Scan dipakai juga saat AI gagal dan pengguna memilih
    // "Isi manual" (guess null): fotonya sudah dipilih, tidak perlu diulang.
    if (c == null && widget.initialPhoto != null) {
      _newPhotoBytes = widget.initialPhoto;
      _photoSource = widget.initialPhotoSource;
    }
  }

  @override
  void dispose() {
    _country.dispose();
    _denomination.dispose();
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  // --- Validasi: pesan ramah dalam bahasa Indonesia -------------------

  double? _parseNumber(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateRequired(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label wajib diisi.' : null;

  String? _validateDenomination(String? v) {
    final n = _parseNumber(v ?? '');
    if (n == null || n <= 0) return 'Nominal harus berupa angka lebih dari 0.';
    return null;
  }

  String? _validateYear(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null; // tahun boleh kosong
    final n = int.tryParse(text);
    if (n == null || n < 1 || n > DateTime.now().year + 1) {
      return 'Tahun tidak valid.';
    }
    return null;
  }

  // --- Foto ----------------------------------------------------------

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      // Diperkecil di sumbernya (Bagian 3): foto asli HP bisa berukuran
      // beberapa MB, padahal 1024 px sudah cukup untuk koleksi.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final original = await picked.readAsBytes();
      if (!mounted) return;

      // Pengguna mengatur area foto dulu; batal = foto tidak dipakai.
      // Rasio bebas karena uang kertas berbentuk persegi panjang.
      final bytes = await CropScreen.open(
        context,
        original,
        allowRatioChoice: true,
      );
      if (bytes == null || !mounted) return;

      setState(() {
        _newPhotoBytes = bytes;
        _photoError = false;
        _photoSource = source == ImageSource.camera ? 'camera' : 'gallery';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tidak bisa diambil, coba lagi.')),
      );
    }
  }

  // Pratinjau foto dalam kartu bersudut bulat dengan bayangan lembut. Garis
  // merah menandai foto yang belum diisi saat disimpan.
  Widget _buildPhotoPreview() {
    Widget content;
    if (_newPhotoBytes != null) {
      content = Image.memory(_newPhotoBytes!, fit: BoxFit.cover);
    } else if (widget.coin?.photoPath != null) {
      content = Image.file(
        File(widget.coin!.photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
      );
    } else {
      content = const Icon(
        Icons.add_a_photo_outlined,
        size: 40,
        color: AppColors.bronze,
      );
    }
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _photoError ? AppColors.danger : AppColors.cardBorder,
          width: _photoError ? 2 : 1,
        ),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _pickPhoto,
          child: SizedBox.expand(child: Center(child: content)),
        ),
      ),
    );
  }

  // --- Simpan --------------------------------------------------------

  String? _nullIfEmpty(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();

    // Foto wajib saat MENAMBAH koin (aturan proyek: koleksi tanpa foto
    // tidak bisa dianalisis ulang AI dan tidak berarti bagi Jejak
    // Catatan). Saat mengubah, tidak dipaksa: koin hasil Pulihkan tidak
    // punya foto (foto tidak ikut sinkron), dan pengguna tetap harus
    // bisa memperbaiki datanya.
    final photoMissing = !_isEdit && _newPhotoBytes == null;
    if (photoMissing) setState(() => _photoError = true);

    if (!formValid || photoMissing) return;
    setState(() => _saving = true);

    try {
      final country = _country.text.trim();
      final currency = _currencyCode!; // sudah divalidasi wajib dipilih
      final denomination = _parseNumber(_denomination.text)!;
      final year = int.tryParse(_year.text.trim());
      final notes = _nullIfEmpty(_notes.text);

      final old = widget.coin;
      if (old == null) {
        final coin = Coin.create(
          userId: widget.userId,
          type: _type,
          country: country,
          currencyCode: currency,
          denomination: denomination,
          year: year,
          condition: _condition,
          notes: notes,
          aiSummary: widget.guess?.summary,
        );
        await _repo.insert(
          coin,
          photoBytes: _newPhotoBytes,
          photoSource: _photoSource,
        );
      } else {
        // Dibuat lewat konstruktor (bukan copyWith) supaya field yang
        // dikosongkan pengguna, mis. tahun, benar-benar jadi null.
        final coin = Coin(
          id: old.id,
          userId: old.userId,
          type: _type,
          country: country,
          currencyCode: currency,
          denomination: denomination,
          year: year,
          condition: _condition,
          notes: notes,
          photoPath: old.photoPath,
          aiSummary: old.aiSummary,
          createdAt: old.createdAt,
          updatedAt: old.updatedAt,
          isSynced: old.isSynced,
        );
        await _repo.update(
          coin,
          photoBytes: _newPhotoBytes,
          photoSource: _photoSource,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan, coba lagi.')),
      );
    }
  }

  // --- Tampilan ------------------------------------------------------

  // Kartu peringatan di atas form hasil Scan. Wajib ada: hasil AI hanyalah
  // estimasi dan pengguna harus memeriksanya sebelum menyimpan (Bagian 1.6).
  Widget _buildAiBanner() {
    final g = widget.guess!;
    final small = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: AppColors.ink.withValues(alpha: 0.7),
    );
    return SoftCard(
      color: AppColors.tileActive,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.bronze,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.isSample
                      ? 'Hasil contoh, bukan hasil dari foto ini'
                      : 'Perkiraan dari foto, bukan penilaian ahli',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            g.isSample
                ? 'Periksa dan ubah semua kolom sebelum menyimpan.'
                : 'Periksa dan koreksi kolom di bawah sebelum menyimpan. '
                      'Kolom yang kosong berarti belum bisa dipastikan dari foto.',
            style: small,
          ),
          if (g.features.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(g.features, style: small),
          ],
          if (g.yearEstimated) ...[
            const SizedBox(height: 8),
            Text(
              'Tahun ${g.year} adalah perkiraan dari desain dan gaya, bukan '
              'tahun yang tertera. Mohon diperiksa.',
              style: small.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
          if (!g.isSample) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Keyakinan: ${g.confidence}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bronze,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Koin' : 'Tambah Koin')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            if (widget.guess != null && !_isEdit) _buildAiBanner(),
            _buildPhotoPreview(),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _photoError
                    ? 'Foto wajib diisi.'
                    : (_isEdit
                          ? 'Tekan foto untuk menggantinya.'
                          : (widget.guess != null
                                ? 'Tekan foto untuk menggantinya.'
                                : 'Foto wajib. Hanya disimpan, tidak dianalisis AI.')),
                style: TextStyle(
                  fontSize: 12,
                  color: _photoError
                      ? AppColors.danger
                      : AppColors.ink.withValues(alpha: 0.55),
                ),
              ),
            ),
            gap,
            const FieldLabel('Jenis'),
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.bronze,
                selectedForegroundColor: Colors.white,
                foregroundColor: AppColors.bronze,
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'coin', label: Text('Koin')),
                ButtonSegment(value: 'banknote', label: Text('Uang kertas')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            gap,
            const FieldLabel('Negara'),
            TextFormField(
              controller: _country,
              decoration: appInput(hint: 'mis. Jepang'),
              validator: (v) => _validateRequired(v, 'Negara'),
            ),
            gap,
            const FieldLabel('Nominal'),
            TextFormField(
              controller: _denomination,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: appInput(hint: 'mis. 100'),
              validator: _validateDenomination,
            ),
            gap,
            // Nama mata uang cukup panjang ("Dolar Singapura (SGD)"),
            // jadi pemilih diberi satu baris penuh.
            const FieldLabel('Mata uang'),
            CurrencyPickerField(
              label: 'Pilih mata uang',
              initialCode: _currencyCode,
              required: true,
              onChanged: (code) => _currencyCode = code,
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Tahun'),
                      TextFormField(
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: appInput(
                          hint: 'Opsional',
                          helper: _yearEstimated ? 'Perkiraan' : null,
                        ),
                        onChanged: (_) {
                          if (_yearEstimated) {
                            setState(() => _yearEstimated = false);
                          }
                        },
                        validator: _validateYear,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Kondisi'),
                      DropdownButtonFormField<String?>(
                        initialValue: _condition,
                        decoration: appInput(hint: 'Opsional'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('-'),
                          ),
                          for (final c in _conditions)
                            DropdownMenuItem<String?>(
                              value: c,
                              child: Text(c),
                            ),
                        ],
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            gap,
            const FieldLabel('Catatan'),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: appInput(
                hint: 'Opsional',
                helper: 'Disimpan terenkripsi.',
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: _isEdit ? 'Simpan Perubahan' : 'Simpan',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
