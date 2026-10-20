import urllib.request
import json
import base64

api_key = 'AIzaSyDb42HWIHnsvQLlvRvm4LJiKDcORG_PfJk'
model_name = 'gemini-2.5-flash'

receipt_system_instruction = '''
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
'''

# Create a sample synthetic receipt image (PNG with text drawn or clean base64)
# Let's create an image using PIL if available, or test with PIL
try:
    from PIL import Image, ImageDraw, ImageFont
    img = Image.new('RGB', (400, 300), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((10, 10), "TOKO GROSIR BERKAH JAYA\n16/10/2026\n--------------------\nGood Day Mocca 2 Rtg  30.000\nKapal Api Mini 2 Rtg 20.000\nMinyak 2L 1 Pouch     35.000\n--------------------\nTOTAL: 85.000", fill=(0, 0, 0))
    import io
    buf = io.BytesIO()
    img.save(buf, format='JPEG')
    img_b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    mime = 'image/jpeg'
except Exception as e:
    print('PIL not available:', e)
    img_b64 = ''
    mime = 'image/jpeg'

url = f'https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}'
payload = {
    'systemInstruction': {
        'parts': [{'text': receipt_system_instruction}]
    },
    'contents': [{
        'role': 'user',
        'parts': [
            {'inlineData': {'mimeType': mime, 'data': img_b64}},
            {'text': 'Ekstrak seluruh daftar barang, jumlah (qty), satuan grosir, dan harga riil per satuan dari foto bon belanja ini ke format JSON terstruktur.'}
        ]
    }],
    'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1
    }
}

req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
try:
    with urllib.request.urlopen(req, timeout=30) as res:
        resp_data = json.loads(res.read().decode('utf-8'))
        raw_text = resp_data['candidates'][0]['content']['parts'][0]['text']
        print("Raw AI response:\n", raw_text)
        parsed = json.loads(raw_text)
        print("Parsed JSON SUCCESS. Items count:", len(parsed.get('items', [])))
        for it in parsed.get('items', []):
            print("  Item:", it)
except Exception as e:
    print("ERROR calling Gemini OCR:", e)
