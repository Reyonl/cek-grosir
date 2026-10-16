import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/local_storage_service.dart';
import 'custom_price_form_dialog.dart';

class PriceMemoryManagerSheet extends StatefulWidget {
  final VoidCallback onDataChanged;

  const PriceMemoryManagerSheet({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<PriceMemoryManagerSheet> createState() =>
      _PriceMemoryManagerSheetState();
}

class _PriceMemoryManagerSheetState extends State<PriceMemoryManagerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  static const List<String> _categories = [
    'Semua',
    'Minuman Sachet',
    'Minuman Dus & Botol',
    'Sembako & Bumbu',
    'Rokok & Korek',
    'Sabun & Kebersihan',
    'Lainnya',
  ];

  final NumberFormat _rpFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddProductDialog() async {
    final result = await showDialog<CustomPriceFormData>(
      context: context,
      builder: (_) => const CustomPriceFormDialog(),
    );

    if (result == null || !mounted) return;

    await LocalStorageService.saveCustomPrice(
      normalizedKey: result.normalizedKey,
      nama: result.nama,
      kategori: result.kategori,
      satuan: result.satuan,
      harga: result.harga,
    );

    widget.onDataChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Produk "${result.nama}" (${_rpFormat.format(result.harga)}/${result.satuan}) ditambahkan ke database toko langganan!',
        ),
      ),
    );
  }

  Future<void> _openEditProductDialog(
    String key,
    Map<String, dynamic> data,
  ) async {
    final result = await showDialog<CustomPriceFormData>(
      context: context,
      builder: (_) => CustomPriceFormDialog(
        existingKey: key,
        initialData: data,
      ),
    );

    if (result == null || !mounted) return;

    // Jika key berubah, hapus key lama
    if (result.normalizedKey != key) {
      await LocalStorageService.deleteCustomPrice(key);
    }

    await LocalStorageService.saveCustomPrice(
      normalizedKey: result.normalizedKey,
      nama: result.nama,
      kategori: result.kategori,
      satuan: result.satuan,
      harga: result.harga,
    );

    widget.onDataChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Produk "${result.nama}" berhasil diperbarui!',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String key, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Produk Langganan?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$nama" dari database harga toko langganan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalStorageService.deleteCustomPrice(key);
      widget.onDataChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produk "$nama" telah dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: LocalStorageService.priceBoxListenable,
      builder: (context, box, _) {
        final allPrices = LocalStorageService.getAllSavedPrices();

        final filteredEntries = allPrices.entries.where((entry) {
          final data = entry.value;
          final key = entry.key.toLowerCase();
          final nama = (data['nama'] ?? '').toString().toLowerCase();
          final kategori = (data['kategori'] ?? '').toString();

          final matchesQuery = _searchQuery.isEmpty ||
              nama.contains(_searchQuery) ||
              key.contains(_searchQuery);

          final matchesCategory = _selectedCategory == 'Semua' ||
              kategori.toLowerCase() == _selectedCategory.toLowerCase();

          return matchesQuery && matchesCategory;
        }).toList()
          ..sort((a, b) => (a.value['nama'] ?? '')
              .toString()
              .compareTo((b.value['nama'] ?? '').toString()));

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF065F46),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar Harga Toko Langganan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${allPrices.length} produk tersimpan di memori lokal Hive',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openAddProductDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Tambah',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama produk atau kata kunci...',
                  prefixIcon:
                      const Icon(Icons.search, size: 20, color: Colors.black45),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFD1FAE5),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 44,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada produk cocok dengan "$_searchQuery"'
                                  : 'Belum ada produk di kategori ini.',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 13),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _openAddProductDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Tambah Produk Baru'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: filteredEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final key = entry.key;
                        final data = entry.value;
                        final nama = (data['nama'] ?? key).toString();
                        final kategori =
                            (data['kategori'] ?? 'Lainnya').toString();
                        final satuan = (data['satuan'] ?? 'Pcs').toString();
                        final harga = data['harga'] is int
                            ? data['harga'] as int
                            : int.tryParse(data['harga']?.toString() ?? '0') ??
                                0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          title: Text(
                            nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$kategori • Key: $key',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Text(
                                  '${_rpFormat.format(harga)} / $satuan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Edit Produk',
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Color(0xFF047857),
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _openEditProductDialog(key, data),
                              ),
                              IconButton(
                                tooltip: 'Hapus dari database',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _confirmDelete(key, nama),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Produk: ${allPrices.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await LocalStorageService.seedInitialPrices();
                      widget.onDataChanged();
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Harga default 11 produk Grosir Batak dipulihkan!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text(
                      'Pulihkan Default 11 Produk',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
