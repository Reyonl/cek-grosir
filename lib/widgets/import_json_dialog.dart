import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';
import '../services/local_storage_service.dart';

class ImportJsonResult {
  final List<GroceryItem> items;
  final bool addToCart;
  final bool saveToMemory;

  const ImportJsonResult({
    required this.items,
    this.addToCart = true,
    this.saveToMemory = true,
  });
}

class ImportJsonDialog extends StatefulWidget {
  const ImportJsonDialog({super.key});

  @override
  State<ImportJsonDialog> createState() => _ImportJsonDialogState();
}

class _ImportJsonDialogState extends State<ImportJsonDialog> {
  final TextEditingController _jsonController = TextEditingController();
  List<GroceryItem> _parsedItems = [];
  String? _parseError;
  bool _addToCart = true;
  bool _saveToMemory = true;

  final NumberFormat _rpFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static const String _sampleJson = '''[
  {
    "nama": "Lantiza",
    "jumlah": 6,
    "harga": 38900
  },
  {
    "nama": "Gingku",
    "jumlah": 3,
    "harga": 20000
  },
  {
    "nama": "Nabati",
    "jumlah": 10,
    "harga": 18000
  },
  {
    "nama": "Cocolatos 1000",
    "jumlah": 1,
    "harga": 21000
  },
  {
    "nama": "1 kg gula",
    "jumlah": 1,
    "harga": 18500
  }
]''';

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _parseJsonInput(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      setState(() {
        _parsedItems = [];
        _parseError = null;
      });
      return;
    }

    try {
      // Bersihkan markdown code fence jika ada
      String cleaned = raw;
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim();
      }

      final decoded = jsonDecode(cleaned);
      List<dynamic> rawList = [];

      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map) {
        if (decoded['items'] is List) {
          rawList = decoded['items'] as List<dynamic>;
        } else if (decoded['data'] is List) {
          rawList = decoded['data'] as List<dynamic>;
        } else {
          // Coba ambil list pertama yang ada di dalam map
          for (final value in decoded.values) {
            if (value is List) {
              rawList = value;
              break;
            }
          }
        }
      }

      if (rawList.isEmpty) {
        setState(() {
          _parsedItems = [];
          _parseError = 'Format JSON valid tetapi tidak menemukan daftar produk.';
        });
        return;
      }

      final List<GroceryItem> items = [];
      for (int i = 0; i < rawList.length; i++) {
        final el = rawList[i];
        if (el is Map) {
          final map = Map<String, dynamic>.from(el);
          map['id'] =
              '${DateTime.now().microsecondsSinceEpoch}_json_${i}_${map['nama'] ?? map['nama_produk'] ?? ''}';
          final item = GroceryItem.fromJson(map);
          items.add(LocalStorageService.applyLocalPriceMemory(item));
        }
      }

      setState(() {
        _parsedItems = items;
        _parseError = items.isEmpty ? 'Tidak ada item yang dapat diurai.' : null;
      });
    } catch (e) {
      setState(() {
        _parsedItems = [];
        _parseError = 'JSON belum valid: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _jsonController.text = data.text!.trim();
      _parseJsonInput(_jsonController.text);
    }
  }

  void _fillSample() {
    _jsonController.text = _sampleJson;
    _parseJsonInput(_sampleJson);
  }

  void _clear() {
    _jsonController.clear();
    _parseJsonInput('');
  }

  Future<void> _handleImport() async {
    if (_parsedItems.isEmpty) return;

    if (_saveToMemory) {
      for (final item in _parsedItems) {
        await LocalStorageService.saveCustomPrice(
          normalizedKey: item.normalizedKey,
          nama: item.namaProdukStandar,
          kategori: item.kategori,
          satuan: item.satuan,
          harga: item.hargaSatuanMax,
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      ImportJsonResult(
        items: _parsedItems,
        addToCart: _addToCart,
        saveToMemory: _saveToMemory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.data_object_rounded,
              color: Color(0xFF047857),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impor Data JSON',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Tempel hasil JSON dari Gemini Chat / AI lain',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFF047857),
                      side: const BorderSide(color: Color(0xFF6EE7B7)),
                    ),
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: const Text('Tempel', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _fillSample,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFF2563EB),
                    ),
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Contoh JSON',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const Spacer(),
                  if (_jsonController.text.isNotEmpty)
                    TextButton(
                      onPressed: _clear,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Hapus',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _jsonController,
                maxLines: 7,
                minLines: 4,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText:
                      '[\n  {\n    "nama": "Nabati",\n    "jumlah": 10,\n    "harga": 18000\n  }\n]',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF047857), width: 1.6),
                  ),
                ),
                onChanged: _parseJsonInput,
              ),
              if (_parseError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _parseError!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_parsedItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: Color(0xFF047857)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Berhasil mengenali ${_parsedItems.length} produk dari JSON!',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _parsedItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _parsedItems[index];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        title: Text(
                          item.namaProdukStandar,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${item.qty} ${item.satuan} • ${item.kategori}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          _rpFormat.format(item.hargaSatuanMax),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _addToCart,
                  activeColor: const Color(0xFF047857),
                  title: const Text(
                    'Masukkan ke Keranjang Belanja Aktif',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _addToCart = val ?? true;
                    });
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _saveToMemory,
                  activeColor: const Color(0xFF047857),
                  title: const Text(
                    'Simpan juga ke Database Harga Langganan (Hive)',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Harga ini akan dipelajari untuk belanja berikutnya.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _saveToMemory = val ?? true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _parsedItems.isEmpty ? null : _handleImport,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
          ),
          icon: const Icon(Icons.file_download_done_rounded, size: 18),
          label: Text('Impor ${_parsedItems.length} Barang'),
        ),
      ],
    );
  }
}
