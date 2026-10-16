import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';

class EditPriceResult {
  final GroceryItem updatedItem;
  final bool resetToAi;

  const EditPriceResult({
    required this.updatedItem,
    this.resetToAi = false,
  });
}

class EditPriceDialog extends StatefulWidget {
  final GroceryItem item;

  const EditPriceDialog({
    super.key,
    required this.item,
  });

  @override
  State<EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<EditPriceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;
  late final TextEditingController _satuanController;
  late String _selectedCategory;
  String? _errorText;

  static const List<String> _categories = [
    'Minuman Sachet',
    'Minuman Dus & Botol',
    'Sembako & Bumbu',
    'Rokok & Korek',
    'Sabun & Kebersihan',
    'Lainnya',
  ];

  static const List<String> _commonUnits = [
    'Renteng',
    'Dus',
    'Pouch (2L)',
    'Pouch',
    'Pak',
    'Kg',
    'Botol',
    'Bal',
    'Sak',
    'Pcs',
  ];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.item.namaProdukStandar,
    );
    _priceController = TextEditingController(
      text: widget.item.hargaSatuanMax.toString(),
    );
    _qtyController = TextEditingController(
      text: widget.item.qty.toString(),
    );
    _satuanController = TextEditingController(
      text: widget.item.satuan,
    );
    _selectedCategory = _categories.contains(widget.item.kategori)
        ? widget.item.kategori
        : 'Lainnya';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _satuanController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final cleanPrice =
        _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsedPrice = int.tryParse(cleanPrice);

    if (parsedPrice == null || parsedPrice <= 0) {
      setState(() {
        _errorText = 'Masukkan harga satuan yang valid (contoh: 16000)';
      });
      return;
    }

    final newName = _nameController.text.trim().isEmpty
        ? widget.item.namaProdukStandar
        : _nameController.text.trim();
    final parsedQty =
        (int.tryParse(_qtyController.text.trim()) ?? widget.item.qty)
            .clamp(1, 9999);
    final newSatuan = _satuanController.text.trim().isEmpty
        ? widget.item.satuan
        : _satuanController.text.trim();

    final updated = widget.item.copyWith(
      namaProdukStandar: newName,
      kategori: _selectedCategory,
      hargaSatuanMin: parsedPrice,
      hargaSatuanMax: parsedPrice,
      qty: parsedQty,
      satuan: newSatuan,
      isCustomPrice: true,
    );

    Navigator.of(context).pop(
      EditPriceResult(updatedItem: updated, resetToAi: false),
    );
  }

  void _handleResetToAi() {
    final resetItem = widget.item.copyWith(
      hargaSatuanMin: widget.item.aiHargaMinOriginal,
      hargaSatuanMax: widget.item.aiHargaMaxOriginal,
      isCustomPrice: false,
    );

    Navigator.of(context).pop(
      EditPriceResult(updatedItem: resetItem, resetToAi: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiRangeText =
        widget.item.aiHargaMinOriginal == widget.item.aiHargaMaxOriginal
            ? _currencyFormat.format(widget.item.aiHargaMinOriginal)
            : '${_currencyFormat.format(widget.item.aiHargaMinOriginal)} - ${_currencyFormat.format(widget.item.aiHargaMaxOriginal)}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: Icon(
              Icons.edit_note_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koreksi Produk & Harga',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Ubah nama hasil AI atau simpan harga toko langganan',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Taksiran AI: $aiRangeText / ${widget.item.satuan}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Produk (Bisa Diedit)',
                hintText: 'Contoh: Kopi Liong Bulan',
                prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Harga Pasti di Toko Langganan (Rp)',
                hintText: 'Contoh: 16000',
                prefixText: 'Rp ',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (_) => _handleSave(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _satuanController,
                    decoration: InputDecoration(
                      labelText: 'Satuan Grosir',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _commonUnits.map((unit) {
                final selected =
                    _satuanController.text.trim().toLowerCase() ==
                        unit.toLowerCase();
                return ChoiceChip(
                  label: Text(unit, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() {
                      _satuanController.text = unit;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kategori Produk:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  selectedColor: const Color(0xFFD1FAE5),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nama & harga ini akan otomatis disimpan ke Memori Lokal (Hive) agar belanja berikutnya memakai data pasti ini.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (widget.item.isCustomPrice) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleResetToAi,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange.shade700,
                    side: BorderSide(color: Colors.deepOrange.shade300),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text(
                    'Reset ke Estimasi AI',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _handleSave,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Simpan Perubahan'),
        ),
      ],
    );
  }
}
