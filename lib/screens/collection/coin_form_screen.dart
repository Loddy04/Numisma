// screens/collection/coin_form_screen.dart
// Form tambah (manual) dan ubah koin. Satu form dipakai untuk dua mode:
// kalau `coin` null = tambah baru, kalau terisi = ubah koin itu.
// Tidak ada pemanggilan Gemini di sini; Scan AI akan mengisi form yang
// sama di Hari 4 (NUMISMA_GUIDE Bagian 7.9).
//
// Foto (kamera atau galeri) WAJIB saat menambah koin, dan hanya disimpan,
// tidak dianalisis AI. Saat mengubah, foto tidak dipaksa. Pop dengan
// nilai true bila data tersimpan.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/coin.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import '../../widgets/currency_picker.dart';

class CoinFormScreen extends StatefulWidget {
  final int userId;
  final Coin? coin; // null = mode tambah
  const CoinFormScreen({super.key, required this.userId, this.coin});

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
  String? _buyCurrencyCode;
  final _country = TextEditingController();
  final _denomination = TextEditingController();
  final _year = TextEditingController();
  final _buyPrice = TextEditingController();
  final _notes = TextEditingController();

  // Foto baru yang dipilih pengguna (belum disimpan). Kalau null,
  // foto lama (mode ubah) dibiarkan apa adanya.
  Uint8List? _newPhotoBytes;
  String _photoSource = 'none';
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
      _buyPrice.text = c.buyPrice?.toString() ?? '';
      _buyCurrencyCode = c.buyCurrency;
      _notes.text = c.notes ?? '';
    }
  }

  @override
  void dispose() {
    _country.dispose();
    _denomination.dispose();
    _year.dispose();
    _buyPrice.dispose();
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

  String? _validateBuyPrice(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null;
    final n = _parseNumber(text);
    return (n == null || n < 0) ? 'Harga beli tidak valid.' : null;
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
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
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
      content = const Icon(Icons.add_a_photo, size: 40);
    }
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          // Garis merah menandai foto yang belum diisi saat disimpan.
          border: _photoError
              ? Border.all(color: AppColors.danger, width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: SizedBox.expand(child: Center(child: content)),
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
      final buyPrice = _parseNumber(_buyPrice.text);
      final buyCurrency = _buyCurrencyCode;
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
          buyPrice: buyPrice,
          buyCurrency: buyCurrency,
          notes: notes,
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
          buyPrice: buyPrice,
          buyCurrency: buyCurrency,
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

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Koin' : 'Tambah Koin')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPhotoPreview(),
            const SizedBox(height: 4),
            Text(
              _photoError
                  ? 'Foto wajib diisi.'
                  : (_isEdit
                      ? 'Tekan foto untuk menggantinya.'
                      : 'Foto wajib. Hanya disimpan, tidak dianalisis AI.'),
              style: TextStyle(
                fontSize: 12,
                color: _photoError ? AppColors.danger : Colors.black54,
              ),
            ),
            gap,
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'coin', label: Text('Koin')),
                ButtonSegment(value: 'banknote', label: Text('Uang kertas')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            gap,
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'Negara'),
              validator: (v) => _validateRequired(v, 'Negara'),
            ),
            gap,
            TextFormField(
              controller: _denomination,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Nominal'),
              validator: _validateDenomination,
            ),
            gap,
            // Nama mata uang cukup panjang ("Dolar Singapura (SGD)"),
            // jadi pemilih diberi satu baris penuh.
            CurrencyPickerField(
              label: 'Mata uang',
              initialCode: _currencyCode,
              required: true,
              onChanged: (code) => _currencyCode = code,
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Tahun (opsional)'),
                    validator: _validateYear,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _condition,
                    decoration:
                        const InputDecoration(labelText: 'Kondisi (opsional)'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('-'),
                      ),
                      for (final c in _conditions)
                        DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _condition = v),
                  ),
                ),
              ],
            ),
            gap,
            TextFormField(
              controller: _buyPrice,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Harga beli (opsional)'),
              validator: _validateBuyPrice,
            ),
            gap,
            CurrencyPickerField(
              label: 'Mata uang beli (opsional)',
              initialCode: _buyCurrencyCode,
              onChanged: (code) => _buyCurrencyCode = code,
            ),
            gap,
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                helperText: 'Disimpan terenkripsi.',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
