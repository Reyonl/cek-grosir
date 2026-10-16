class GroceryItem {
  final String id;
  final String inputAsli;
  final String normalizedKey;
  final String namaProdukStandar;
  final String kategori;
  final int qty;
  final String satuan;
  final int hargaSatuanMin;
  final int hargaSatuanMax;
  final int aiHargaMinOriginal;
  final int aiHargaMaxOriginal;
  final String catatanGrosir;
  final bool isCustomPrice;
  final bool isChecked;

  const GroceryItem({
    required this.id,
    required this.inputAsli,
    required this.normalizedKey,
    required this.namaProdukStandar,
    required this.kategori,
    required this.qty,
    required this.satuan,
    required this.hargaSatuanMin,
    required this.hargaSatuanMax,
    required this.aiHargaMinOriginal,
    required this.aiHargaMaxOriginal,
    required this.catatanGrosir,
    this.isCustomPrice = false,
    this.isChecked = false,
  });

  int get subtotalMin => hargaSatuanMin * qty;
  int get subtotalMax => hargaSatuanMax * qty;
  bool get hasExactPrice => isCustomPrice || hargaSatuanMin == hargaSatuanMax;

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    final int singlePrice = _parseInt(json['harga_satuan'], 0);
    final int minPrice = _parseInt(json['harga_satuan_min'], singlePrice);
    final int maxPrice = _parseInt(json['harga_satuan_max'], minPrice > 0 ? minPrice : singlePrice);
    final int origMin = _parseInt(json['ai_harga_min_original'], minPrice);
    final int origMax = _parseInt(json['ai_harga_max_original'], maxPrice);
    final String rawKey = (json['normalized_key'] ??
            json['nama_produk_standar'] ??
            json['input_asli'] ??
            'item')
        .toString();

    return GroceryItem(
      id: (json['id'] ??
              '${DateTime.now().microsecondsSinceEpoch}_${rawKey.hashCode}')
          .toString(),
      inputAsli: (json['input_asli'] ?? '').toString(),
      normalizedKey: normalizeKey(rawKey),
      namaProdukStandar:
          (json['nama_produk_standar'] ?? json['input_asli'] ?? 'Produk')
              .toString(),
      kategori: (json['kategori'] ?? 'Lainnya').toString(),
      qty: _parseInt(json['qty'], 1).clamp(1, 9999),
      satuan: (json['satuan'] ?? 'Pcs').toString(),
      hargaSatuanMin: minPrice,
      hargaSatuanMax: maxPrice < minPrice ? minPrice : maxPrice,
      aiHargaMinOriginal: origMin,
      aiHargaMaxOriginal: origMax < origMin ? origMin : origMax,
      catatanGrosir: (json['catatan_grosir'] ?? '').toString(),
      isCustomPrice: json['is_custom_price'] == true,
      isChecked: json['is_checked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'input_asli': inputAsli,
      'normalized_key': normalizedKey,
      'nama_produk_standar': namaProdukStandar,
      'kategori': kategori,
      'qty': qty,
      'satuan': satuan,
      'harga_satuan_min': hargaSatuanMin,
      'harga_satuan_max': hargaSatuanMax,
      'ai_harga_min_original': aiHargaMinOriginal,
      'ai_harga_max_original': aiHargaMaxOriginal,
      'catatan_grosir': catatanGrosir,
      'is_custom_price': isCustomPrice,
      'is_checked': isChecked,
    };
  }

  GroceryItem copyWith({
    String? id,
    String? inputAsli,
    String? normalizedKey,
    String? namaProdukStandar,
    String? kategori,
    int? qty,
    String? satuan,
    int? hargaSatuanMin,
    int? hargaSatuanMax,
    int? aiHargaMinOriginal,
    int? aiHargaMaxOriginal,
    String? catatanGrosir,
    bool? isCustomPrice,
    bool? isChecked,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      inputAsli: inputAsli ?? this.inputAsli,
      normalizedKey: normalizedKey ?? this.normalizedKey,
      namaProdukStandar: namaProdukStandar ?? this.namaProdukStandar,
      kategori: kategori ?? this.kategori,
      qty: qty ?? this.qty,
      satuan: satuan ?? this.satuan,
      hargaSatuanMin: hargaSatuanMin ?? this.hargaSatuanMin,
      hargaSatuanMax: hargaSatuanMax ?? this.hargaSatuanMax,
      aiHargaMinOriginal: aiHargaMinOriginal ?? this.aiHargaMinOriginal,
      aiHargaMaxOriginal: aiHargaMaxOriginal ?? this.aiHargaMaxOriginal,
      catatanGrosir: catatanGrosir ?? this.catatanGrosir,
      isCustomPrice: isCustomPrice ?? this.isCustomPrice,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  static String normalizeKey(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }
}
