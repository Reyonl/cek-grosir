import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/grocery_item.dart';

class LocalStorageService {
  static const String priceMemoryBoxName = 'price_memory_box';
  static const String cartBoxName = 'cart_box';
  static const String settingsBoxName = 'settings_box';

  static const String _apiKeySettingKey = 'gemini_api_key';
  static const String _modelSettingKey = 'gemini_model_name';
  static const String _cartItemsKey = 'active_cart_items';

  static const String defaultModelName = 'gemini-2.5-flash';

  static const Map<String, Map<String, dynamic>> initialGrosirBatakPrices = {
    'royco_renteng': {
      'nama': 'Royco Bumbu Kaldu',
      'kategori': 'Sembako & Bumbu',
      'satuan': 'Renteng',
      'harga': 5000,
    },
    'ladaku_renteng': {
      'nama': 'Ladaku Merica Bubuk',
      'kategori': 'Sembako & Bumbu',
      'satuan': 'Renteng',
      'harga': 10500,
    },
    'minyak_2l': {
      'nama': 'Minyak Goreng 2L',
      'kategori': 'Sembako & Bumbu',
      'satuan': 'Pouch (2L)',
      'harga': 35000,
    },
    'indocafe_renteng': {
      'nama': 'Indocafe Coffeemix',
      'kategori': 'Minuman Sachet',
      'satuan': 'Renteng',
      'harga': 17000,
    },
    'good_day_mocacinno_renteng': {
      'nama': 'Good Day Merah (Mocacinno)',
      'kategori': 'Minuman Sachet',
      'satuan': 'Renteng',
      'harga': 15000,
    },
    'susu_putih_renteng': {
      'nama': 'Susu Kental Manis Sachet',
      'kategori': 'Minuman Sachet',
      'satuan': 'Renteng',
      'harga': 8000,
    },
    'kapal_api_mini_renteng': {
      'nama': 'Kapal Api Mini',
      'kategori': 'Minuman Sachet',
      'satuan': 'Renteng',
      'harga': 10000,
    },
    'abc_susu_renteng': {
      'nama': 'Kopi ABC Susu',
      'kategori': 'Minuman Sachet',
      'satuan': 'Renteng',
      'harga': 17000,
    },
    'panther_dus': {
      'nama': 'Panther Cup Gelas',
      'kategori': 'Minuman Dus & Botol',
      'satuan': 'Dus',
      'harga': 20000,
    },
    'le_minerale_besar_dus': {
      'nama': 'Le Minerale Besar 1500ml',
      'kategori': 'Minuman Dus & Botol',
      'satuan': 'Dus',
      'harga': 52000,
    },
    'aqua_tanggung_dus': {
      'nama': 'Aqua Tanggung 600ml',
      'kategori': 'Minuman Dus & Botol',
      'satuan': 'Dus',
      'harga': 47000,
    },
  };

  static Box get _priceBox => Hive.box(priceMemoryBoxName);
  static Box get _cartBox => Hive.box(cartBoxName);
  static Box get _settingsBox => Hive.box(settingsBoxName);

  static ValueListenable<Box> get priceBoxListenable => _priceBox.listenable();
  static ValueListenable<Box> get cartBoxListenable => _cartBox.listenable();
  static ValueListenable<Box> get settingsBoxListenable =>
      _settingsBox.listenable();

  /// Inisialisasi Hive & Seed Data Awal Harga Asli Grosir Batak jika kosong
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(priceMemoryBoxName);
    await Hive.openBox(cartBoxName);
    await Hive.openBox(settingsBoxName);

    if (_priceBox.isEmpty) {
      await seedInitialPrices();
    }
  }

  /// Mengisi data awal harga langganan Grosir Batak ke Hive
  static Future<void> seedInitialPrices() async {
    for (final entry in initialGrosirBatakPrices.entries) {
      await _priceBox.put(entry.key, {
        ...entry.value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ==================== SETTINGS (API KEY & MODEL) ====================

  static String getApiKey() {
    return (_settingsBox.get(_apiKeySettingKey, defaultValue: '') ?? '')
        .toString()
        .trim();
  }

  static Future<void> saveApiKey(String apiKey) async {
    await _settingsBox.put(_apiKeySettingKey, apiKey.trim());
  }

  static String getModelName() {
    final model = (_settingsBox.get(_modelSettingKey,
                defaultValue: defaultModelName) ??
            defaultModelName)
        .toString()
        .trim();
    return model.isEmpty ? defaultModelName : model;
  }

  static Future<void> saveModelName(String modelName) async {
    await _settingsBox.put(
      _modelSettingKey,
      modelName.trim().isEmpty ? defaultModelName : modelName.trim(),
    );
  }

  // ==================== PRICE MEMORY (HARGA LANGGANAN) ====================

  static Map<String, Map<String, dynamic>> getAllSavedPrices() {
    final Map<String, Map<String, dynamic>> result = {};
    for (final key in _priceBox.keys) {
      final raw = _priceBox.get(key);
      if (raw is Map) {
        result[key.toString()] = Map<String, dynamic>.from(raw);
      }
    }
    return result;
  }

  static Map<String, dynamic>? getSavedPriceData(
    String normalizedKey, {
    String? namaProdukStandar,
    String? inputAsli,
  }) {
    final cleanKey = GroceryItem.normalizeKey(normalizedKey);
    if (_priceBox.containsKey(cleanKey)) {
      final raw = _priceBox.get(cleanKey);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    }

    if (namaProdukStandar != null && namaProdukStandar.isNotEmpty) {
      final stdKey = GroceryItem.normalizeKey(namaProdukStandar);
      if (_priceBox.containsKey(stdKey)) {
        final raw = _priceBox.get(stdKey);
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    }

    if (inputAsli != null && inputAsli.isNotEmpty) {
      final rawInputKey = GroceryItem.normalizeKey(inputAsli);
      if (_priceBox.containsKey(rawInputKey)) {
        final raw = _priceBox.get(rawInputKey);
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    }

    return null;
  }

  /// Mencocokkan item hasil AI dengan memori harga lokal di Hive
  static GroceryItem applyLocalPriceMemory(GroceryItem item) {
    final saved = getSavedPriceData(
      item.normalizedKey,
      namaProdukStandar: item.namaProdukStandar,
      inputAsli: item.inputAsli,
    );

    if (saved == null) {
      return item;
    }

    final int? hargaLangganan = saved['harga'] is int
        ? saved['harga'] as int
        : int.tryParse(saved['harga']?.toString() ?? '');

    if (hargaLangganan == null || hargaLangganan <= 0) {
      return item;
    }

    final String savedSatuan =
        (saved['satuan'] ?? item.satuan).toString().trim();

    return item.copyWith(
      hargaSatuanMin: hargaLangganan,
      hargaSatuanMax: hargaLangganan,
      satuan: savedSatuan.isNotEmpty ? savedSatuan : item.satuan,
      isCustomPrice: true,
    );
  }

  static Future<void> saveCustomPrice({
    required String normalizedKey,
    required String nama,
    required String kategori,
    required String satuan,
    required int harga,
  }) async {
    final key = GroceryItem.normalizeKey(normalizedKey);
    if (key.isEmpty) return;

    await _priceBox.put(key, {
      'nama': nama,
      'kategori': kategori,
      'satuan': satuan,
      'harga': harga,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteCustomPrice(String normalizedKey) async {
    final key = GroceryItem.normalizeKey(normalizedKey);
    await _priceBox.delete(key);
  }

  // ==================== CART (KERANJANG AKTIF) ====================

  static List<GroceryItem> getCartItems() {
    final rawList = _cartBox.get(_cartItemsKey, defaultValue: <dynamic>[]);
    if (rawList is! List) return [];

    final List<GroceryItem> items = [];
    for (final element in rawList) {
      if (element is Map) {
        items.add(
          GroceryItem.fromJson(Map<String, dynamic>.from(element)),
        );
      }
    }
    return items;
  }

  static Future<void> saveCartItems(List<GroceryItem> items) async {
    final serialized = items.map((e) => e.toJson()).toList();
    await _cartBox.put(_cartItemsKey, serialized);
  }

  static Future<void> clearCart() async {
    await _cartBox.put(_cartItemsKey, <Map<String, dynamic>>[]);
  }
}
