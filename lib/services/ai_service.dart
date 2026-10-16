import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/grocery_item.dart';
import '../models/receipt_scan_result.dart';
import 'local_storage_service.dart';

class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);

  @override
  String toString() => message;
}

class AiService {
  static const String systemInstruction = '''
Kamu adalah asisten harga grosir sembako dan warung di Indonesia (seperti Grosir Batak / agen kulakan warung).
Tugasmu adalah menerjemahkan daftar catatan belanja tidak baku dari pengguna menjadi JSON terstruktur beserta estimasi harga modal warung terbaru di Indonesia.

Aturan Penting:
1. Terjemahkan singkatan warung (contoh: "good day merah" -> "Good Day Mocacinno", "susu putih 2" -> "Susu Kental Manis Putih", qty: 2, "liong" -> "Kopi Liong Bulan").
2. Pahami format penulisan nota grosir seperti "2R" (2 Renteng), "1Ds" (1 Dus), "Lemin besar" (Le Minerale 1500ml), "Aqua T" (Aqua Tanggung 600ml), "K api mini" (Kapal Api Mini).
3. Gunakan satuan standar grosir warung jika user tidak menyebutkan satuan:
   - Kopi / minuman serbuk = Renteng (10 sachet)
   - Susu kental manis sachet = Renteng (6 sachet)
   - Bumbu dapur sachet (Royco, Ladaku, Masako) = Renteng (12 sachet)
   - Minuman gelas cup (Panther, Ale-ale, Teh Gelas) = Dus (24 cup)
   - Minyak goreng / sembako = sesuai ketikan (Pouch / Kg / Pak)
4. Berikan harga modal grosir agen (BUKAN harga eceran minimarket). Gunakan acuan harga modal grosir ini untuk menaksir barang lain yang sejenis:
   - Kopi sachet manis rata-rata Rp15.000-Rp17.000/renteng
   - Kopi hitam mini Rp10.000/renteng
   - SKM Rp8.000/renteng
   - Bumbu kaldu Rp5.000/renteng
   - Minuman cup Rp20.000/dus
   - Air mineral dus Rp47.000-Rp52.000/dus
5. PENTING - Pencocokan Key Database Lokal:
   Pastikan jika user mengetik salah satu dari 11 barang di bawah ini, "normalized_key" yang dihasilkan HARUS SAMA PERSIS dengan key berikut agar otomatis cocok dengan database Hive:
   - Royco / kaldu royco -> "royco_renteng"
   - Ladaku / merica ladaku -> "ladaku_renteng"
   - Minyak goreng 2 liter / minyak 2L -> "minyak_2l"
   - Indocafe / indocafe coffeemix -> "indocafe_renteng"
   - Good day merah / good day mocacinno -> "good_day_mocacinno_renteng"
   - Susu putih / SKM putih sachet -> "susu_putih_renteng"
   - Kapal api mini / K api mini -> "kapal_api_mini_renteng"
   - Kopi ABC / ABC susu -> "abc_susu_renteng"
   - Panther cup / panther gelas -> "panther_dus"
   - Le Minerale besar 1500ml / Lemin besar -> "le_minerale_besar_dus"
   - Aqua tanggung 600ml / Aqua T -> "aqua_tanggung_dus"
6. Kembalikan HANYA format JSON valid sesuai struktur ini:
{
  "items": [
    {
      "input_asli": "string",
      "normalized_key": "string (lowercase, kata kunci utama produk untuk pencocokan database lokal, contoh: 'good_day_mocacinno_renteng')",
      "nama_produk_standar": "string",
      "kategori": "Minuman Sachet | Minuman Dus & Botol | Sembako & Bumbu | Lainnya",
      "qty": 1,
      "satuan": "Renteng | Dus | Botol | Pouch | Kg | Pak",
      "harga_satuan_min": 15000,
      "harga_satuan_max": 17500,
      "catatan_grosir": "string (info isi per renteng/dus atau alternatif merk)"
    }
  ]
}
''';

  /// Memanggil REST API Gemini dengan Structured JSON Output & menerapkan Hybrid Hive Override
  static Future<List<GroceryItem>> analyzeGroceryList(String rawText) async {
    final trimmedText = rawText.trim();
    if (trimmedText.isEmpty) {
      throw const AiServiceException('Catatan belanja masih kosong.');
    }

    final apiKey = LocalStorageService.getApiKey();
    final modelName = LocalStorageService.getModelName();

    if (apiKey.isEmpty) {
      throw const AiServiceException(
        'API Key Gemini belum diatur. Silakan klik ikon kunci di pojok kanan atas untuk memasukkan API Key.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Terjemahkan daftar belanja warung berikut ke JSON terstruktur:\n$trimmedText'
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    };

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiServiceException(
        'Gagal terhubung ke server Gemini. Periksa koneksi internet Anda. Detail: $e',
      );
    }

    if (response.statusCode != 200) {
      String errorDetail = 'HTTP ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson['error'] is Map) {
          errorDetail =
              errJson['error']['message']?.toString() ?? errorDetail;
        }
      } catch (_) {}
      throw AiServiceException('Gagal memproses AI ($errorDetail)');
    }

    Map<String, dynamic> decodedResponse;
    try {
      decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const AiServiceException('Respons dari server bukan JSON valid.');
    }

    final candidates = decodedResponse['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiServiceException(
        'AI tidak mengembalikan hasil. Coba perjelas daftar belanja Anda.',
      );
    }

    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw const AiServiceException('Konten jawaban AI kosong.');
    }

    String rawJsonText = (parts.first['text'] ?? '').toString().trim();
    if (rawJsonText.startsWith('```')) {
      rawJsonText = rawJsonText
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    dynamic parsedPayload;
    try {
      parsedPayload = jsonDecode(rawJsonText);
    } catch (e) {
      throw const AiServiceException(
        'Gagal mengurai format JSON dari AI. Pastikan model mendukung JSON output.',
      );
    }

    List<dynamic> rawItems = [];
    if (parsedPayload is Map && parsedPayload['items'] is List) {
      rawItems = parsedPayload['items'] as List<dynamic>;
    } else if (parsedPayload is List) {
      rawItems = parsedPayload;
    } else {
      throw const AiServiceException(
        'Struktur JSON dari AI tidak memiliki daftar "items".',
      );
    }

    final List<GroceryItem> result = [];
    for (int i = 0; i < rawItems.length; i++) {
      final rawItem = rawItems[i];
      if (rawItem is Map) {
        final mapItem = Map<String, dynamic>.from(rawItem);
        mapItem['id'] =
            '${DateTime.now().microsecondsSinceEpoch}_${i}_${mapItem['normalized_key'] ?? ''}';
        final parsedItem = GroceryItem.fromJson(mapItem);
        // Pencocokan Memori Lokal (Hive Override)
        final matchedItem = LocalStorageService.applyLocalPriceMemory(parsedItem);
        result.add(matchedItem);
      }
    }

    if (result.isEmpty) {
      throw const AiServiceException(
        'Tidak ada item belanja yang terdeteksi dari catatan Anda.',
      );
    }

    return result;
  }

  /// Parser Kamus Lokal pintar jika user ingin mencoba langsung tanpa API Key
  static List<GroceryItem> analyzeOfflineWithLocalDictionary(String rawText) {
    final lines = rawText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final List<GroceryItem> items = [];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      int qty = 1;
      String? explicitUnit;

      // Deteksi pola nota grosir seperti "2R", "3 R", "2Ds", "1 Ds", atau angka di akhir/awal
      final rentengMatch =
          RegExp(r'\b(\d+)\s*(?:r|rtg|renteng)\b', caseSensitive: false)
              .firstMatch(line);
      final dusMatch =
          RegExp(r'\b(\d+)\s*(?:ds|dus|box)\b', caseSensitive: false)
              .firstMatch(line);
      final numberMatch =
          RegExp(r'(?:^|\s)(\d+)(?:\s*$|\s+(?:pcs|pak|pouch|kg|btl|botol))',
                  caseSensitive: false)
              .firstMatch(line);

      if (rentengMatch != null) {
        qty = int.tryParse(rentengMatch.group(1)!) ?? 1;
        explicitUnit = 'Renteng';
      } else if (dusMatch != null) {
        qty = int.tryParse(dusMatch.group(1)!) ?? 1;
        explicitUnit = 'Dus';
      } else if (numberMatch != null && !lower.contains('2l')) {
        qty = int.tryParse(numberMatch.group(1)!) ?? 1;
      }

      String normalizedKey;
      String namaStandar;
      String kategori;
      String satuan;
      int minPrice;
      int maxPrice;
      String catatan;

      if (lower.contains('royco')) {
        normalizedKey = 'royco_renteng';
        namaStandar = 'Royco Bumbu Kaldu';
        kategori = 'Sembako & Bumbu';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 5000;
        maxPrice = 5500;
        catatan = '1 Renteng isi 12 sachet';
      } else if (lower.contains('ladaku')) {
        normalizedKey = 'ladaku_renteng';
        namaStandar = 'Ladaku Merica Bubuk';
        kategori = 'Sembako & Bumbu';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 10000;
        maxPrice = 11000;
        catatan = '1 Renteng isi 12 sachet';
      } else if (lower.contains('minyak')) {
        normalizedKey = 'minyak_2l';
        namaStandar = 'Minyak Goreng 2L';
        kategori = 'Sembako & Bumbu';
        satuan = explicitUnit ?? 'Pouch (2L)';
        minPrice = 34000;
        maxPrice = 36500;
        catatan = 'Kemasan Pouch 2 Liter';
      } else if (lower.contains('indocafe')) {
        normalizedKey = 'indocafe_renteng';
        namaStandar = 'Indocafe Coffeemix';
        kategori = 'Minuman Sachet';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 16500;
        maxPrice = 17500;
        catatan = '1 Renteng isi 10 sachet';
      } else if (lower.contains('good day') || lower.contains('goodday')) {
        normalizedKey = 'good_day_mocacinno_renteng';
        namaStandar = 'Good Day Merah (Mocacinno)';
        kategori = 'Minuman Sachet';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 14500;
        maxPrice = 16000;
        catatan = '1 Renteng isi 10 sachet';
      } else if (lower.contains('susu') || lower.contains('skm') || lower.contains('frisian') || lower.contains('indomilk')) {
        normalizedKey = 'susu_putih_renteng';
        namaStandar = 'Susu Kental Manis Sachet';
        kategori = 'Minuman Sachet';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 7500;
        maxPrice = 8500;
        catatan = '1 Renteng isi 6 sachet';
      } else if (lower.contains('kapal api') || lower.contains('k api')) {
        normalizedKey = 'kapal_api_mini_renteng';
        namaStandar = 'Kapal Api Mini';
        kategori = 'Minuman Sachet';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 9500;
        maxPrice = 10500;
        catatan = '1 Renteng isi 10 sachet';
      } else if (lower.contains('abc')) {
        normalizedKey = 'abc_susu_renteng';
        namaStandar = 'Kopi ABC Susu';
        kategori = 'Minuman Sachet';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 16000;
        maxPrice = 17500;
        catatan = '1 Renteng isi 10 sachet';
      } else if (lower.contains('panther') || lower.contains('ale') || lower.contains('teh gelas')) {
        normalizedKey = lower.contains('panther')
            ? 'panther_dus'
            : GroceryItem.normalizeKey('${line}_dus');
        namaStandar = lower.contains('panther')
            ? 'Panther Cup Gelas'
            : 'Minuman Cup Gelas ($line)';
        kategori = 'Minuman Dus & Botol';
        satuan = explicitUnit ?? 'Dus';
        minPrice = 19500;
        maxPrice = 21000;
        catatan = '1 Dus isi 24 cup';
      } else if (lower.contains('lemin') || lower.contains('le minerale')) {
        normalizedKey = 'le_minerale_besar_dus';
        namaStandar = 'Le Minerale Besar 1500ml';
        kategori = 'Minuman Dus & Botol';
        satuan = explicitUnit ?? 'Dus';
        minPrice = 50000;
        maxPrice = 53000;
        catatan = '1 Dus isi 12 botol (1500ml)';
      } else if (lower.contains('aqua')) {
        normalizedKey = 'aqua_tanggung_dus';
        namaStandar = 'Aqua Tanggung 600ml';
        kategori = 'Minuman Dus & Botol';
        satuan = explicitUnit ?? 'Dus';
        minPrice = 46000;
        maxPrice = 48500;
        catatan = '1 Dus isi 24 botol (600ml)';
      } else {
        normalizedKey = GroceryItem.normalizeKey(line);
        namaStandar = line;
        kategori = 'Lainnya';
        satuan = explicitUnit ?? 'Renteng';
        minPrice = 15000;
        maxPrice = 17000;
        catatan = 'Estimasi benchmark grosir warung';
      }

      final rawItem = GroceryItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${i}_$normalizedKey',
        inputAsli: line,
        normalizedKey: normalizedKey,
        namaProdukStandar: namaStandar,
        kategori: kategori,
        qty: qty.clamp(1, 999),
        satuan: satuan,
        hargaSatuanMin: minPrice,
        hargaSatuanMax: maxPrice,
        aiHargaMinOriginal: minPrice,
        aiHargaMaxOriginal: maxPrice,
        catatanGrosir: catatan,
      );

      items.add(LocalStorageService.applyLocalPriceMemory(rawItem));
    }

    return items;
  }

  // ==================== MULTIMODAL OCR BON BELANJA ====================

  static const String receiptSystemInstruction = '''
Kamu adalah asisten OCR cerdas khusus membaca nota / bon belanjaan grosir warung dan toko sembako di Indonesia (gaya Grosir Batak / agen sembako).
Tugasmu adalah membaca foto bon belanjaan (bisa nota tulisan tangan, nota print kasir, atau nota carbon/kwitansi grosir), lalu mengekstrak setiap item barang yang dibeli beserta harga nyata/riil yang dibayar.

Aturan Penting:
1. Baca setiap baris barang, kuantitas (qty), satuan grosir (Renteng, Dus, Pouch, Pak, Kg, Botol, Pcs), dan harga satuan yang dibayar.
2. Jika di nota tertera harga subtotal dan qty > 1, bagi subtotal dengan qty untuk mendapatkan harga satuan yang tepat.
3. Standarkan singkatan warung menjadi nama produk yang jelas (misal: "GD Moca 2R" -> "Good Day Mocacinno", "Lemin bsr" -> "Le Minerale Besar 1500ml", "K api mini" -> "Kapal Api Mini").
4. Buat "normalized_key" produk yang konsisten huruf kecil dan garis bawah untuk pencocokan memori lokal Hive (contoh: "good_day_mocacinno_renteng", "minyak_2l", "royco_renteng").
5. Jika ada nama toko atau tanggal nota, ekstrak pada level atas.
6. Kembalikan HANYA format JSON valid sesuai skema:
{
  "nama_toko": "string (nama toko atau kosongkan jika tidak ada)",
  "tanggal_bon": "string (tanggal belanja jika terbaca)",
  "total_bon": 150000,
  "items": [
    {
      "input_asli": "string (teks persis yang tertera di bon)",
      "normalized_key": "string (kunci produk lowercase)",
      "nama_produk_standar": "string",
      "kategori": "Minuman Sachet | Minuman Dus & Botol | Sembako & Bumbu | Lainnya",
      "qty": 2,
      "satuan": "Renteng | Dus | Botol | Pouch | Kg | Pak | Pcs",
      "harga_satuan": 15000,
      "catatan_grosir": "string (keterangan)"
    }
  ]
}
''';

  /// Membaca foto bon/struk belanja fisik menggunakan Gemini Vision REST API
  static Future<ReceiptScanResult> scanReceiptImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = LocalStorageService.getApiKey();
    final modelName = LocalStorageService.getModelName();

    if (apiKey.isEmpty) {
      throw const AiServiceException(
        'API Key Gemini belum diatur. Silakan klik ikon kunci di pojok kanan atas untuk memasukkan API Key terlebih dahulu.',
      );
    }

    final base64Image = base64Encode(imageBytes);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': receiptSystemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image,
              }
            },
            {
              'text':
                  'Ekstrak seluruh daftar barang, jumlah (qty), satuan grosir, dan harga riil per satuan dari foto bon belanja ini ke format JSON terstruktur.'
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      },
    };

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 40));
    } catch (e) {
      throw AiServiceException(
        'Gagal mengirim gambar bon ke Gemini. Periksa koneksi internet Anda. Detail: $e',
      );
    }

    if (response.statusCode != 200) {
      String errorDetail = 'HTTP ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson['error'] is Map) {
          errorDetail =
              errJson['error']['message']?.toString() ?? errorDetail;
        }
      } catch (_) {}
      throw AiServiceException('Gagal memproses OCR bon ($errorDetail)');
    }

    Map<String, dynamic> decodedResponse;
    try {
      decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const AiServiceException('Respons dari server bukan JSON valid.');
    }

    final candidates = decodedResponse['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiServiceException(
        'AI tidak dapat mendeteksi tulisan pada bon. Pastikan foto cukup terang dan fokus.',
      );
    }

    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw const AiServiceException('Hasil baca bon dari AI kosong.');
    }

    String rawJsonText = (parts.first['text'] ?? '').toString().trim();
    if (rawJsonText.startsWith('```')) {
      rawJsonText = rawJsonText
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    dynamic parsedPayload;
    try {
      parsedPayload = jsonDecode(rawJsonText);
    } catch (e) {
      throw const AiServiceException(
        'Gagal mengurai format JSON dari hasil scan bon AI.',
      );
    }

    if (parsedPayload is! Map<String, dynamic>) {
      throw const AiServiceException(
        'Format JSON hasil OCR bon tidak sesuai struktur.',
      );
    }

    return ReceiptScanResult.fromJson(parsedPayload);
  }

  /// Contoh hasil scan bon grosir untuk pengetesan offline
  static ReceiptScanResult getSampleReceiptResult() {
    return ReceiptScanResult(
      namaToko: 'Agen Sembako & Grosir Berkah Jaya',
      tanggalBon: '16/10/2026',
      totalBon: 172000,
      items: [
        GroceryItem.fromJson({
          'input_asli': 'Good Day Mocacinno 2R',
          'normalized_key': 'good_day_mocacinno_renteng',
          'nama_produk_standar': 'Good Day Merah (Mocacinno)',
          'kategori': 'Minuman Sachet',
          'qty': 2,
          'satuan': 'Renteng',
          'harga_satuan': 15000,
          'catatan_grosir': 'Harga riil toko langganan',
          'is_custom_price': true,
        }),
        GroceryItem.fromJson({
          'input_asli': 'Kopi ABC Susu 2R',
          'normalized_key': 'abc_susu_renteng',
          'nama_produk_standar': 'Kopi ABC Susu',
          'kategori': 'Minuman Sachet',
          'qty': 2,
          'satuan': 'Renteng',
          'harga_satuan': 17000,
          'catatan_grosir': 'Harga riil toko langganan',
          'is_custom_price': true,
        }),
        GroceryItem.fromJson({
          'input_asli': 'Minyak Goreng 2L 2 Pouch',
          'normalized_key': 'minyak_2l',
          'nama_produk_standar': 'Minyak Goreng 2L',
          'kategori': 'Sembako & Bumbu',
          'qty': 2,
          'satuan': 'Pouch (2L)',
          'harga_satuan': 35000,
          'catatan_grosir': 'Harga riil toko langganan',
          'is_custom_price': true,
        }),
        GroceryItem.fromJson({
          'input_asli': 'Royco Sapi 4R',
          'normalized_key': 'royco_renteng',
          'nama_produk_standar': 'Royco Bumbu Kaldu',
          'kategori': 'Sembako & Bumbu',
          'qty': 4,
          'satuan': 'Renteng',
          'harga_satuan': 5000,
          'catatan_grosir': 'Harga riil toko langganan',
          'is_custom_price': true,
        }),
        GroceryItem.fromJson({
          'input_asli': 'Panther Cup 1Ds',
          'normalized_key': 'panther_dus',
          'nama_produk_standar': 'Panther Cup Gelas',
          'kategori': 'Minuman Dus & Botol',
          'qty': 1,
          'satuan': 'Dus',
          'harga_satuan': 20000,
          'catatan_grosir': 'Harga riil toko langganan',
          'is_custom_price': true,
        }),
      ],
    );
  }
}

