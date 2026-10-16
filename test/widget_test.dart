import 'package:cek_grosir/models/grocery_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GroceryItem fromJson, toJson, and copyWith work accurately', () {
    final item = GroceryItem.fromJson({
      'input_asli': 'good day merah 2R',
      'normalized_key': 'good_day_mocacinno_renteng',
      'nama_produk_standar': 'Good Day Merah (Mocacinno)',
      'kategori': 'Minuman Sachet',
      'qty': 2,
      'satuan': 'Renteng',
      'harga_satuan_min': 15000,
      'harga_satuan_max': 15000,
      'catatan_grosir': '1 Renteng isi 10 sachet',
      'is_custom_price': true,
    });

    expect(item.normalizedKey, 'good_day_mocacinno_renteng');
    expect(item.subtotalMin, 30000);
    expect(item.subtotalMax, 30000);
    expect(item.isCustomPrice, isTrue);

    final updated = item.copyWith(qty: 3);
    expect(updated.subtotalMax, 45000);
  });
}
