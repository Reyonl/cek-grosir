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
    final int singlePrice = _parseInt(
      json['harga_satuan'] ?? json['harga'] ?? json['price'],
      0,
    );
    final int minPrice = _parseInt(json['harga_satuan_min'], singlePrice);
    final int maxPrice = _parseInt(
      json['harga_satuan_max'],
      minPrice > 0 ? minPrice : singlePrice,
    );
    final int origMin = _parseInt(json['ai_harga_min_original'], minPrice);
    final int origMax = _parseInt(json['ai_harga_max_original'], maxPrice);

    final String nama = (json['nama_produk_standar'] ??
            json['nama'] ??
            json['nama_produk'] ??
            json['item'] ??
            json['input_asli'] ??
            'Produk')
        .toString()
        .trim();

    final String rawKey = (json['normalized_key'] ??
            (nama.isNotEmpty ? nama : null) ??
            json['input_asli'] ??
            'item')
        .toString();

    final int rawQty = _parseInt(
      json['qty'] ?? json['jumlah'] ?? json['kuantitas'] ?? json['quantity'],
      1,
    );

    String rawSatuan = (json['satuan'] ?? json['unit'] ?? '').toString().trim();
    if (rawSatuan.isEmpty) {
      final lowerNama = nama.toLowerCase();
      if (lowerNama.contains(' kg') ||
          lowerNama.startsWith('kg ') ||
          lowerNama.contains('kilo')) {
        rawSatuan = 'Kg';
      } else if (lowerNama.contains('renteng') || lowerNama.contains('rtg')) {
        rawSatuan = 'Renteng';
      } else if (lowerNama.contains('dus') ||
          lowerNama.contains('box') ||
          lowerNama.contains('karton')) {
        rawSatuan = 'Dus';
      } else if (lowerNama.contains('pouch') ||
          lowerNama.contains('2l') ||
          lowerNama.contains('1l')) {
        rawSatuan = 'Pouch';
      } else if (lowerNama.contains('botol') || lowerNama.contains('btl')) {
        rawSatuan = 'Botol';
      } else if (lowerNama.contains('pak') || lowerNama.contains('pack')) {
        rawSatuan = 'Pak';
      } else {
        rawSatuan = 'Pcs';
      }
    }

    String rawKategori =
        (json['kategori'] ?? json['category'] ?? '').toString().trim();
    if (rawKategori.isEmpty) {
      final lowerNama = nama.toLowerCase();
      if (lowerNama.contains('kopi') ||
          lowerNama.contains('susu') ||
          lowerNama.contains('teh') ||
          lowerNama.contains('sachet') ||
          lowerNama.contains('cocolatos') ||
          lowerNama.contains('chocolatos')) {
        rawKategori = 'Minuman Sachet';
      } else if (lowerNama.contains('dus') ||
          lowerNama.contains('cup') ||
          lowerNama.contains('gelas') ||
          lowerNama.contains('botol') ||
          lowerNama.contains('minerale') ||
          lowerNama.contains('aqua') ||
          lowerNama.contains('panther')) {
        rawKategori = 'Minuman Dus & Botol';
      } else if (lowerNama.contains('gula') ||
          lowerNama.contains('beras') ||
          lowerNama.contains('minyak') ||
          lowerNama.contains('royco') ||
          lowerNama.contains('garam') ||
          lowerNama.contains('terigu') ||
          lowerNama.contains('bumbu') ||
          lowerNama.contains('telur')) {
        rawKategori = 'Sembako & Bumbu';
      } else {
        rawKategori = 'Lainnya';
      }
    }

    final bool isFixedPrice = json['is_custom_price'] == true ||
        (singlePrice > 0 && json['harga_satuan_min'] == null);

    return GroceryItem(
      id: (json['id'] ??
              '${DateTime.now().microsecondsSinceEpoch}_${rawKey.hashCode}')
          .toString(),
      inputAsli: (json['input_asli'] ?? nama).toString(),
      normalizedKey: normalizeKey(rawKey),
      namaProdukStandar: nama.isNotEmpty ? nama : 'Produk',
      kategori: rawKategori,
      qty: rawQty.clamp(1, 9999),
      satuan: rawSatuan,
      hargaSatuanMin: minPrice,
      hargaSatuanMax: maxPrice < minPrice ? minPrice : maxPrice,
      aiHargaMinOriginal: origMin,
      aiHargaMaxOriginal: origMax < origMin ? origMin : origMax,
      catatanGrosir: (json['catatan_grosir'] ?? '').toString(),
      isCustomPrice: isFixedPrice,
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
