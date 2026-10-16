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
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;
  late final TextEditingController _satuanController;
  String? _errorText;

  static const List<String> _commonUnits = [
    'Renteng',
    'Dus',
    'Pouch (2L)',
    'Pouch',
    'Pak',
    'Kg',
    'Botol',
  ];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.hargaSatuanMax.toString(),
    );
    _qtyController = TextEditingController(
      text: widget.item.qty.toString(),
    );
    _satuanController = TextEditingController(
      text: widget.item.satuan,
    );
  }

  @override
  void dispose() {
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

    final parsedQty =
        (int.tryParse(_qtyController.text.trim()) ?? widget.item.qty)
            .clamp(1, 9999);
    final newSatuan = _satuanController.text.trim().isEmpty
        ? widget.item.satuan
        : _satuanController.text.trim();

    final updated = widget.item.copyWith(
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
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Koreksi Harga Toko Langganan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.item.namaProdukStandar,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
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
                    Icons.info_outline,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Acuan AI: $aiRangeText / ${widget.item.satuan}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _priceController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Harga Pasti di Grosir (Rp)',
                hintText: 'Contoh: 16000',
                prefixText: 'Rp ',
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            const SizedBox(height: 10),
            const Text(
              'Harga ini akan otomatis disimpan ke Memori Lokal (Hive) untuk belanja minggu depan.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
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
          label: const Text('Simpan Harga Langganan'),
        ),
      ],
    );
  }
}
