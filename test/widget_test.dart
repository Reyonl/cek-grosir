import 'dart:convert';
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

  test('GroceryItem parses user Gemini Chat JSON correctly', () {
    const rawJson = '''[
  {
    "nama": "Lantiza",
    "jumlah": 6,
    "harga": 38900
  },
  {
    "nama": "Gingku",
    "jumlah": 3,
    "harga": 20000
  },
  {
    "nama": "Nabati",
    "jumlah": 10,
    "harga": 18000
  },
  {
    "nama": "Cocolatos 1000",
    "jumlah": 1,
    "harga": 21000
  },
  {
    "nama": "1 kg gula",
    "jumlah": 1,
    "harga": 18500
  }
]''';

    final decoded = jsonDecode(rawJson) as List<dynamic>;
    final items = decoded
        .map((e) => GroceryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    expect(items.length, 5);
    expect(items[0].namaProdukStandar, 'Lantiza');
    expect(items[0].qty, 6);
    expect(items[0].hargaSatuanMax, 38900);
    expect(items[0].subtotalMax, 233400);

    expect(items[2].namaProdukStandar, 'Nabati');
    expect(items[2].qty, 10);
    expect(items[2].hargaSatuanMax, 18000);

    expect(items[4].namaProdukStandar, '1 kg gula');
    expect(items[4].satuan, 'Kg');
    expect(items[4].kategori, 'Sembako & Bumbu');
    expect(items[4].hargaSatuanMax, 18500);
  });
}
