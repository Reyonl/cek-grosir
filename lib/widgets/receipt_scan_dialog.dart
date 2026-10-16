import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';
import '../models/receipt_scan_result.dart';
import '../services/local_storage_service.dart';

class ReceiptScanDialog extends StatefulWidget {
  final ReceiptScanResult scanResult;

  const ReceiptScanDialog({
    super.key,
    required this.scanResult,
  });

  @override
  State<ReceiptScanDialog> createState() => _ReceiptScanDialogState();
}

class _ReceiptScanDialogState extends State<ReceiptScanDialog> {
  late List<GroceryItem> _scannedItems;
  bool _saveToMemory = true;
  bool _addToCart = true;

  final NumberFormat _rpFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _scannedItems = List.from(widget.scanResult.items);
  }

  int get _totalScanAmount =>
      _scannedItems.fold(0, (sum, item) => sum + item.subtotalMax);

  Future<void> _handleConfirm() async {
    if (_scannedItems.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // 1. Simpan ke database memori lokal Hive agar AI otomatis belajar harga toko ini
    if (_saveToMemory) {
      for (final item in _scannedItems) {
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
    Navigator.of(context).pop({
      'items': _addToCart ? _scannedItems : <GroceryItem>[],
      'savedToMemory': _saveToMemory,
      'itemCount': _scannedItems.length,
    });
  }

  void _removeItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = widget.scanResult.namaToko.isNotEmpty
        ? widget.scanResult.namaToko
        : 'Hasil Scan Bon Belanja (OCR)';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF047857),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.scanResult.tanggalBon.isNotEmpty
                      ? 'Tanggal: ${widget.scanResult.tanggalBon}'
                      : 'AI mengekstrak ${_scannedItems.length} barang dari bon',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
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
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Terbaca:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      _rpFormat.format(_totalScanAmount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Daftar Barang & Harga Riil yang Terbaca:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              if (_scannedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Tidak ada barang yang terdeteksi dari foto bon.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scannedItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _scannedItems[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.namaProdukStandar,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${item.qty} ${item.satuan} • Key: ${item.normalizedKey}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Text(
                              '${_rpFormat.format(item.hargaSatuanMax)}/${item.satuan}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _saveToMemory,
                activeColor: const Color(0xFF047857),
                title: const Text(
                  'Pelajari & Simpan ke Memori Toko Langganan (Hive)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                subtitle: const Text(
                  'Belanja minggu depan otomatis mendeteksi harga riil dari bon ini (bukan estimasi).',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                onChanged: (val) {
                  setState(() {
                    _saveToMemory = val ?? true;
                  });
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _addToCart,
                activeColor: const Color(0xFF047857),
                title: const Text(
                  'Tambahkan ke Keranjang Belanja Aktif',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _addToCart = val ?? true;
                  });
                },
              ),
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
          onPressed: _scannedItems.isEmpty ? null : _handleConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
          ),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Simpan Data Bon'),
        ),
      ],
    );
  }
}
