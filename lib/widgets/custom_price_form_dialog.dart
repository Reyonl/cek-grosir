import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/grocery_item.dart';

class CustomPriceFormData {
  final String normalizedKey;
  final String nama;
  final String kategori;
  final String satuan;
  final int harga;

  const CustomPriceFormData({
    required this.normalizedKey,
    required this.nama,
    required this.kategori,
    required this.satuan,
    required this.harga,
  });
}

class CustomPriceFormDialog extends StatefulWidget {
  final String? existingKey;
  final Map<String, dynamic>? initialData;

  const CustomPriceFormDialog({
    super.key,
    this.existingKey,
    this.initialData,
  });

  @override
  State<CustomPriceFormDialog> createState() => _CustomPriceFormDialogState();
}

class _CustomPriceFormDialogState extends State<CustomPriceFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _keyController;
  late final TextEditingController _priceController;
  late final TextEditingController _satuanController;
  late String _selectedCategory;
  bool _manualKeyEdited = false;
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

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    final initialName = (data?['nama'] ?? '').toString();
    final initialKey = (widget.existingKey ?? '').toString();

    _nameController = TextEditingController(text: initialName);
    _keyController = TextEditingController(text: initialKey);
    _priceController = TextEditingController(
      text: data?['harga'] != null ? data!['harga'].toString() : '',
    );
    _satuanController = TextEditingController(
      text: (data?['satuan'] ?? 'Renteng').toString(),
    );
    _selectedCategory =
        (data?['kategori'] ?? 'Minuman Sachet').toString();

    if (widget.existingKey != null && widget.existingKey!.isNotEmpty) {
      _manualKeyEdited = true;
    }

    _nameController.addListener(() {
      if (!_manualKeyEdited && widget.existingKey == null) {
        final generated = GroceryItem.normalizeKey(_nameController.text);
        _keyController.text = generated;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _priceController.dispose();
    _satuanController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Nama produk wajib diisi.';
      });
      return;
    }

    final cleanPrice =
        _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final price = int.tryParse(cleanPrice);
    if (price == null || price <= 0) {
      setState(() {
        _errorText = 'Masukkan harga satuan yang valid (contoh: 15000)';
      });
      return;
    }

    String key = _keyController.text.trim();
    if (key.isEmpty) {
      key = GroceryItem.normalizeKey(name);
    } else {
      key = GroceryItem.normalizeKey(key);
    }

    final satuan = _satuanController.text.trim().isEmpty
        ? 'Pcs'
        : _satuanController.text.trim();

    Navigator.of(context).pop(
      CustomPriceFormData(
        normalizedKey: key,
        nama: name,
        kategori: _selectedCategory,
        satuan: satuan,
        harga: price,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingKey != null;

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
              isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'Edit Produk Langganan'
                      : 'Tambah Produk Langganan Baru',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  isEditing
                      ? 'Ubah data dan harga toko langganan'
                      : 'Simpan harga pasti agar tidak ditebak AI',
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF64748B)),
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
            if (_errorText != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TextField(
              controller: _nameController,
              autofocus: !isEditing,
              decoration: InputDecoration(
                labelText: 'Nama Produk Lengkap',
                hintText: 'Contoh: Kopi Liong Bulan Merah',
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
                labelText: 'Harga Toko Langganan (Rp)',
                hintText: 'Contoh: 15000',
                prefixText: 'Rp ',
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _satuanController,
                    decoration: InputDecoration(
                      labelText: 'Satuan Grosir',
                      hintText: 'Renteng / Dus',
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
            const SizedBox(height: 14),
            TextField(
              controller: _keyController,
              onChanged: (_) => _manualKeyEdited = true,
              decoration: InputDecoration(
                labelText: 'Kunci / Singkatan Nota (normalized_key)',
                hintText: 'kopi_liong_bulan',
                helperText:
                    'Kata kunci pencocokan otomatis jika Anda mengetik singkatan ini di catatan.',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
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
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(isEditing ? 'Simpan Perubahan' : 'Tambahkan ke Database'),
        ),
      ],
    );
  }
}
