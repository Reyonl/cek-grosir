import 'grocery_item.dart';

class ReceiptScanResult {
  final String namaToko;
  final String tanggalBon;
  final int totalBon;
  final List<GroceryItem> items;

  const ReceiptScanResult({
    this.namaToko = '',
    this.tanggalBon = '',
    this.totalBon = 0,
    required this.items,
  });

  factory ReceiptScanResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<GroceryItem> parsedItems = [];

    if (rawItems is List) {
      for (int i = 0; i < rawItems.length; i++) {
        final itemData = rawItems[i];
        if (itemData is Map) {
          final map = Map<String, dynamic>.from(itemData);
          map['is_custom_price'] = true; // Bon fisik adalah harga pasti riil
          parsedItems.add(GroceryItem.fromJson(map));
        }
      }
    }

    return ReceiptScanResult(
      namaToko: (json['nama_toko'] ?? '').toString(),
      tanggalBon: (json['tanggal_bon'] ?? '').toString(),
      totalBon: int.tryParse(json['total_bon']?.toString() ?? '0') ?? 0,
      items: parsedItems,
    );
  }
}
