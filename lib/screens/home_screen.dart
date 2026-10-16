import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';
import '../models/receipt_scan_result.dart';
import '../services/ai_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/edit_price_dialog.dart';
import '../widgets/item_card.dart';
import '../widgets/receipt_scan_dialog.dart';
import '../widgets/price_memory_manager_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _noteController = TextEditingController();
  List<GroceryItem> _cartItems = [];
  bool _isLoadingAi = false;
  bool _isInputExpanded = true;

  final NumberFormat _rpFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static const String _sampleNote = '''good day merah 2R
K api mini 2R
susu putih 2
abc susu 1R
minyak 2L 2
royco 2R
ladaku 1R
Lemin besar 1Ds
panther 1Ds''';

  @override
  void initState() {
    super.initState();
    _loadCartFromHive();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _loadCartFromHive() {
    final stored = LocalStorageService.getCartItems();
    setState(() {
      _cartItems = stored
          .map((item) => LocalStorageService.applyLocalPriceMemory(item))
          .toList();
    });
  }

  Future<void> _persistCart() async {
    await LocalStorageService.saveCartItems(_cartItems);
  }

  void _fillSampleText() {
    setState(() {
      _noteController.text = _sampleNote;
      _isInputExpanded = true;
    });
  }

  void _clearNoteInput() {
    setState(() {
      _noteController.clear();
    });
  }

  Future<void> _processGroceryNote({bool forceOffline = false}) async {
    final rawText = _noteController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ketik daftar belanja terlebih dahulu atau klik "Isi Contoh".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final apiKey = LocalStorageService.getApiKey();
    if (!forceOffline && apiKey.isEmpty) {
      final action = await _showMissingApiKeySheet();
      if (action == 'input_key') {
        if (!mounted) return;
        final saved = await showDialog<bool>(
          context: context,
          builder: (_) => const ApiKeyDialog(),
        );
        if (saved != true || LocalStorageService.getApiKey().isEmpty) {
          return;
        }
      } else if (action == 'offline') {
        forceOffline = true;
      } else {
        return;
      }
    }

    setState(() {
      _isLoadingAi = true;
    });

    try {
      List<GroceryItem> newItems;
      if (forceOffline) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        newItems = AiService.analyzeOfflineWithLocalDictionary(rawText);
      } else {
        newItems = await AiService.analyzeGroceryList(rawText);
      }

      setState(() {
        _cartItems = newItems;
        if (_cartItems.isNotEmpty) {
          _isInputExpanded = false;
        }
      });
      await _persistCart();

      if (!mounted) return;
      final langgananCount =
          newItems.where((element) => element.isCustomPrice).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Berhasil memuat ${newItems.length} barang ($langgananCount cocok dengan Harga Langganan Hive).',
          ),
        ),
      );
    } on AiServiceException catch (e) {
      if (!mounted) return;
      _showAiErrorDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      _showAiErrorDialog('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAi = false;
        });
      }
    }
  }

  Future<String?> _showMissingApiKeySheet() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key_off_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'API Key Gemini Belum Diisi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Masukkan Gemini API Key untuk analisis AI penuh, atau gunakan Mode Kamus Grosir Lokal untuk langsung mencoba 11 barang langganan Grosir Batak tanpa API Key.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop('offline'),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Pakai Kamus Lokal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop('input_key'),
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: const Text('Isi API Key'),
          ),
        ],
      ),
    );
  }

  void _showAiErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gagal Memanggil AI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openApiKeyDialog();
            },
            child: const Text('Cek API Key'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processGroceryNote(forceOffline: true);
            },
            child: const Text('Gunakan Kamus Lokal'),
          ),
        ],
      ),
    );
  }

  Future<void> _openApiKeyDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const ApiKeyDialog(),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan API Key & Model Gemini berhasil disimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndScanReceipt() async {
    final ImagePicker picker = ImagePicker();

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner_rounded,
                        color: Color(0xFF047857), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Scan / Upload Bon Belanja Grosir',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Foto bon fisik belanjaan Anda. AI akan membaca harga riil yang dibayar dan otomatis menyimpannya ke memori toko langganan Hive.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Color(0xFF047857)),
                  ),
                  title: const Text('Foto Bon dengan Kamera',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text(
                      'Ambil foto langsung nota/bon fisik di depan Anda',
                      style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(context).pop('camera'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: Color(0xFFB45309)),
                  ),
                  title: const Text('Pilih dari Galeri Foto',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text(
                      'Gunakan foto bon yang tersimpan di HP',
                      style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(context).pop('gallery'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Coba Contoh Bon Grosir (Demo)',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text(
                      'Uji coba sistem pembelajaran memori toko secara instan',
                      style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(context).pop('demo'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    if (source == 'demo') {
      final sample = AiService.getSampleReceiptResult();
      await _displayScanResultDialog(sample);
      return;
    }

    final ImageSource imgSource =
        source == 'camera' ? ImageSource.camera : ImageSource.gallery;

    final XFile? file = await picker.pickImage(
      source: imgSource,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (file == null || !mounted) return;

    final apiKey = LocalStorageService.getApiKey();
    if (apiKey.isEmpty) {
      final action = await _showMissingApiKeySheet();
      if (action == 'input_key') {
        if (!mounted) return;
        final saved = await showDialog<bool>(
          context: context,
          builder: (_) => const ApiKeyDialog(),
        );
        if (saved != true || LocalStorageService.getApiKey().isEmpty) {
          return;
        }
      } else if (action == 'offline') {
        final sample = AiService.getSampleReceiptResult();
        await _displayScanResultDialog(sample);
        return;
      } else {
        return;
      }
    }

    final bytes = await file.readAsBytes();
    final mimeType = file.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    await _processReceiptBytes(bytes, mimeType);
  }

  Future<void> _processReceiptBytes(dynamic bytes, String mimeType) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          elevation: 6,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF047857),
                ),
                SizedBox(height: 16),
                Text(
                  'Membaca & Menganalisis Bon dengan AI...',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                SizedBox(height: 4),
                Text(
                  'Mengekstrak barang, qty, dan harga riil kasir',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await AiService.scanReceiptImage(
        imageBytes: bytes,
        mimeType: mimeType,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Tutup loading dialog
      }

      await _displayScanResultDialog(result);
    } on AiServiceException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showAiErrorDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showAiErrorDialog('Terjadi kesalahan saat memproses OCR: $e');
      }
    }
  }

  Future<void> _displayScanResultDialog(ReceiptScanResult scanResult) async {
    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ReceiptScanDialog(scanResult: scanResult),
    );

    if (dialogResult == null || !mounted) return;

    final List<GroceryItem> newItems =
        dialogResult['items'] as List<GroceryItem>? ?? [];
    final bool savedToMemory = dialogResult['savedToMemory'] == true;
    final int count = dialogResult['itemCount'] as int? ?? 0;

    if (newItems.isNotEmpty) {
      setState(() {
        _cartItems = [..._cartItems, ...newItems];
        _isInputExpanded = false;
      });
      await _persistCart();
    } else if (savedToMemory) {
      _loadCartFromHive();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Sukses mempelajari $count produk dari bon! Harga toko langganan telah disimpan ke Hive.',
        ),
      ),
    );
  }

  Future<void> _handleEditPrice(GroceryItem item) async {
    final result = await showDialog<EditPriceResult>(
      context: context,
      builder: (_) => EditPriceDialog(item: item),
    );

    if (result == null) return;

    if (result.resetToAi) {
      await LocalStorageService.deleteCustomPrice(item.normalizedKey);
      setState(() {
        _cartItems = _cartItems.map((cartItem) {
          if (cartItem.id == item.id ||
              cartItem.normalizedKey == item.normalizedKey) {
            return cartItem.copyWith(
              hargaSatuanMin: cartItem.aiHargaMinOriginal,
              hargaSatuanMax: cartItem.aiHargaMaxOriginal,
              isCustomPrice: false,
            );
          }
          return cartItem;
        }).toList();
      });
      await _persistCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Harga "${item.namaProdukStandar}" dikembalikan ke Estimasi AI.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final updated = result.updatedItem;
      await LocalStorageService.saveCustomPrice(
        normalizedKey: updated.normalizedKey,
        nama: updated.namaProdukStandar,
        kategori: updated.kategori,
        satuan: updated.satuan,
        harga: updated.hargaSatuanMax,
      );

      setState(() {
        _cartItems = _cartItems.map((cartItem) {
          if (cartItem.id == updated.id) {
            return updated;
          }
          if (cartItem.normalizedKey == updated.normalizedKey) {
            return cartItem.copyWith(
              namaProdukStandar: updated.namaProdukStandar,
              kategori: updated.kategori,
              hargaSatuanMin: updated.hargaSatuanMax,
              hargaSatuanMax: updated.hargaSatuanMax,
              satuan: updated.satuan,
              isCustomPrice: true,
            );
          }
          return cartItem;
        }).toList();
      });
      await _persistCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF065F46),
          content: Text(
            'Harga langganan "${updated.namaProdukStandar}" (${_rpFormat.format(updated.hargaSatuanMax)}/${updated.satuan}) disimpan ke Hive!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleItemCheck(String id, bool? checked) {
    setState(() {
      _cartItems = _cartItems.map((item) {
        if (item.id == id) {
          return item.copyWith(isChecked: checked ?? false);
        }
        return item;
      }).toList();
    });
    _persistCart();
  }

  void _changeItemQty(String id, int delta) {
    setState(() {
      _cartItems = _cartItems.map((item) {
        if (item.id == id) {
          final nextQty = (item.qty + delta).clamp(1, 9999);
          return item.copyWith(qty: nextQty);
        }
        return item;
      }).toList();
    });
    _persistCart();
  }

  void _deleteItem(String id) {
    setState(() {
      _cartItems.removeWhere((item) => item.id == id);
    });
    _persistCart();
  }

  Future<void> _clearAllCart() async {
    setState(() {
      _cartItems.clear();
      _isInputExpanded = true;
    });
    await LocalStorageService.clearCart();
  }

  void _openPriceMemorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.50,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return PriceMemoryManagerSheet(
              onDataChanged: () {
                _loadCartFromHive();
              },
            );
          },
        );
      },
    );
  }

  // ==================== KALKULASI RINGKASAN BAWAH ====================

  int get _totalMin =>
      _cartItems.fold(0, (sum, item) => sum + item.subtotalMin);

  int get _totalMax =>
      _cartItems.fold(0, (sum, item) => sum + item.subtotalMax);

  /// Saran Bawa Uang Tunai:
  /// Dibulatkan ke atas ke kelipatan Rp50.000 terdekat dari (total_max + buffer 10%)
  int get _recommendedCash {
    if (_totalMax <= 0) return 0;
    final withBuffer = _totalMax * 1.10;
    final rounded50k = (withBuffer / 50000).ceil() * 50000;
    return rounded50k;
  }

  Map<String, List<GroceryItem>> get _groupedCartItems {
    final Map<String, List<GroceryItem>> grouped = {};
    const categoryOrder = [
      'Minuman Sachet',
      'Minuman Dus & Botol',
      'Sembako & Bumbu',
      'Lainnya',
    ];

    for (final cat in categoryOrder) {
      grouped[cat] = [];
    }

    for (final item in _cartItems) {
      final cat = item.kategori.trim().isEmpty ? 'Lainnya' : item.kategori;
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    grouped.removeWhere((_, list) => list.isEmpty);
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store_mall_directory_rounded, size: 22),
                SizedBox(width: 8),
                Text(
                  'CekGrosir',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            Text(
              'Kalkulator Kulakan Warung',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFFD1FAE5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan Foto Bon Belanja (OCR)',
            onPressed: _pickAndScanReceipt,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          ValueListenableBuilder<Box>(
            valueListenable: LocalStorageService.priceBoxListenable,
            builder: (context, box, _) {
              return IconButton(
                tooltip: 'Database Harga Langganan (${box.length})',
                onPressed: _openPriceMemorySheet,
                icon: Badge(
                  label: Text('${box.length}'),
                  backgroundColor: const Color(0xFFF59E0B),
                  textColor: Colors.black,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
              );
            },
          ),
          ValueListenableBuilder<Box>(
            valueListenable: LocalStorageService.settingsBoxListenable,
            builder: (context, _, __) {
              final hasKey = LocalStorageService.getApiKey().isNotEmpty;
              return IconButton(
                tooltip: 'Pengaturan API Key Gemini',
                onPressed: _openApiKeyDialog,
                icon: Icon(
                  hasKey ? Icons.vpn_key_rounded : Icons.vpn_key_off_outlined,
                  color: hasKey ? const Color(0xFFA7F3D0) : Colors.amberAccent,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildCollapsibleInputSection(),
          Expanded(
            child: _cartItems.isEmpty
                ? _buildEmptyState()
                : _buildCategorizedShoppingList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomSummary(),
    );
  }

  Widget _buildCollapsibleInputSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1.2),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isInputExpanded = !_isInputExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
              bottom: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF047857),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catatan Kulakan (Smart Notepad)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Ketik singkatan nota warung (misal: good day merah 2R, Lemin besar 1Ds)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isInputExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF047857),
                  ),
                ],
              ),
            ),
          ),
          if (_isInputExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 5,
                    minLines: 3,
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                    decoration: InputDecoration(
                      hintText:
                          'Contoh ketikan:\nabc susu 1R\nkapal api mini 2R\nsusu putih 2\nminyak 2L\nLemin besar 1Ds',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF059669),
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoadingAi ? null : _fillSampleText,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF047857),
                          side: const BorderSide(color: Color(0xFF6EE7B7)),
                        ),
                        icon: const Icon(Icons.playlist_add_rounded, size: 17),
                        label: const Text(
                          'Isi Contoh',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isLoadingAi ? null : _pickAndScanReceipt,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFFCD34D)),
                        ),
                        icon: const Icon(Icons.document_scanner_rounded, size: 17),
                        label: const Text(
                          'Scan Bon',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _isLoadingAi ? null : _clearNoteInput,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        icon: const Icon(Icons.clear_all_rounded, size: 17),
                        label: const Text(
                          'Bersihkan',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const Spacer(),
                      if (_cartItems.isNotEmpty)
                        TextButton.icon(
                          onPressed: _isLoadingAi ? null : _clearAllCart,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.redAccent,
                          ),
                          icon: const Icon(
                            Icons.remove_shopping_cart_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Reset Keranjang',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        _isLoadingAi ? null : () => _processGroceryNote(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoadingAi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.calculate_rounded, size: 20),
                    label: Text(
                      _isLoadingAi
                          ? 'Menghitung & Mencocokkan Harga...'
                          : 'Hitung Harga Grosir',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 42,
                color: Color(0xFF065F46),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum Ada Daftar Belanja Aktif',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ketik catatan belanja warung di atas (atau tekan "Isi Contoh"), lalu klik "Hitung Harga Grosir" untuk melihat estimasi harga modal & pencocokan otomatis Harga Langganan Grosir Batak.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedShoppingList() {
    final grouped = _groupedCartItems;
    final categories = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = grouped[category]!;
        final catMaxSubtotal =
            items.fold(0, (sum, item) => sum + item.subtotalMax);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(
                    _iconForCategory(category),
                    size: 17,
                    color: const Color(0xFF047857),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$category (${items.length})',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Text(
                    _rpFormat.format(catMaxSubtotal),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            ...items.map(
              (item) => ItemCard(
                item: item,
                onToggleCheck: (val) => _toggleItemCheck(item.id, val),
                onIncrementQty: () => _changeItemQty(item.id, 1),
                onDecrementQty: () => _changeItemQty(item.id, -1),
                onTapPrice: () => _handleEditPrice(item),
                onDelete: () => _deleteItem(item.id),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('sachet')) return Icons.local_cafe_outlined;
    if (lower.contains('dus') || lower.contains('botol')) {
      return Icons.local_drink_outlined;
    }
    if (lower.contains('sembako') || lower.contains('bumbu')) {
      return Icons.kitchen_outlined;
    }
    return Icons.category_outlined;
  }

  Widget _buildStickyBottomSummary() {
    final bool allExact = _totalMin == _totalMax;
    final String totalEstimateText = allExact
        ? _rpFormat.format(_totalMax)
        : '${_rpFormat.format(_totalMin)} - ${_rpFormat.format(_totalMax)}';

    final int checkedCount = _cartItems.where((e) => e.isChecked).length;
    final int customCount = _cartItems.where((e) => e.isCustomPrice).length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cartItems.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Masuk Keranjang: $checkedCount/${_cartItems.length} item',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Harga Langganan: $customCount/${_cartItems.length} item',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allExact && _cartItems.isNotEmpty
                              ? 'Total Belanja Pasti'
                              : 'Rentang Estimasi Total',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalEstimateText,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065F46),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 13,
                                color: Color(0xFFA7F3D0),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Saran Bawa Tunai (+10%)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _rpFormat.format(_recommendedCash),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
