/// Kelas untuk menormalisasi teks Bahasa Indonesia agar dibaca lancar
/// oleh suara Malay (ms-MY-YasminNeural) dari Microsoft Edge TTS.
class IndonesianTextProcessor {
  /// Normalisasi teks utama sebelum dikirim ke Edge TTS.
  /// Menangani: markdown, emoji, singkatan, slang, dan simbol.
  static String normalizeForMalayVoice(String text) {
    if (text.trim().isEmpty) return text;

    String result = text;

    // 0. Ganti newline dengan titik agar TTS menjeda pada setiap baris (terutama list/daftar)
    // dan ganti titik dua dengan koma agar tidak terbaca 'satu' oleh TTS tertentu
    result = result.replaceAll('\n', '. ').replaceAll(':', ',');

    // 1. Ekstrak teks dari markdown link [teks](url) → hanya ambil teksnya
    //    Wajib pakai replaceAllMapped karena Dart tidak support backreference di replaceAll biasa
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      (match) => match.group(1) ?? '',
    );

    // 2. Hapus URL langsung (http:// atau www.) sebelum proses lain
    result = result
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'www\.\S+'), '');

    // 3. Hapus simbol markdown (bold, italic, heading, code)
    //    Gunakan replaceAllMapped untuk kasus _italic_ agar kontennya terjaga
    result = result
        .replaceAll(RegExp(r'\*\*'), '')   // hapus bold **
        .replaceAll(RegExp(r'\*'), '')      // hapus italic *
        .replaceAll(RegExp(r'__'), '')      // hapus underline __
        .replaceAll(RegExp(r'#{1,6}\s?'), '') // hapus heading #
        .replaceAll(RegExp(r'`'), '');       // hapus code `

    // 4. Hapus emoji (range unicode emoji utama)
    result = result.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}]|'  // emoji modern (📞📍🏥)
        r'[\u{2600}-\u{27FF}]|'    // simbol (✅❌☎)
        r'[\u{2B00}-\u{2BFF}]|'    // simbol panah dll
        r'[\u{FE00}-\u{FEFF}]|'    // variation selector
        r'[\u{200D}]',             // zero-width joiner
        unicode: true,
      ),
      '',
    );

    // 5. Normalisasi simbol yang sering jadi masalah saat dibaca TTS
    result = result
        .replaceAll(r'$', '')     // hapus simbol dollar (bug "1 dollar")
        .replaceAll(RegExp(r'\bRp\.?\s?', caseSensitive: false), 'Rupiah ')
        .replaceAll('&amp;', 'dan')
        .replaceAll('&', 'dan')
        .replaceAll('@', '')
        .replaceAll('%', 'persen');

    // 6. Ekspansi singkatan alamat (pattern sudah di-escape dengan literal \.)
    final Map<String, String> alamatMap = {
      r'Jln\.': 'Jalan',
      r'jln\.': 'jalan',
      r'Jl\.': 'Jalan',
      r'jl\.': 'jalan',
      r'Kec\.': 'Kecamatan',
      r'kec\.': 'kecamatan',
      r'Kab\.': 'Kabupaten',
      r'kab\.': 'kabupaten',
      r'Kel\.': 'Kelurahan',
      r'kel\.': 'kelurahan',
      r'Ds\.': 'Desa',
      r'ds\.': 'desa',
      r'No\.': 'Nomor',
      r'no\.': 'nomor',
      r'Telp\.?': 'Telepon',
      r'telp\.?': 'telepon',
      r'Tel\.?': 'Telepon',
      r'tel\.?': 'telepon',
      r'Dr\.': 'Dokter',
      r'dr\.': 'dokter',
      r'Prof\.': 'Profesor',
    };

    alamatMap.forEach((pattern, replacement) {
      result = result.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    // 7. Ekspansi singkatan khusus Rumah Sakit
    final Map<String, String> rsMap = {
      r'\bRS\b': 'Rumah Sakit',
      r'\bRSUD\b': 'Rumah Sakit Umum Daerah',
      r'\bIGD\b': 'I G D',
      r'\bUGD\b': 'U G D',
      r'\bVCT\b': 'V C T',
      r'\bHC\b': 'H C',
      r'\bSpA\b': 'Spesialis Anak',
      r'\bSpB\b': 'Spesialis Bedah',
      r'\bSpOG\b': 'Spesialis Kandungan',
      r'\bObsgyn\b': 'Spesialis Kandungan',
      r'\bSpPD\b': 'Spesialis Penyakit Dalam',
    };

    rsMap.forEach((pattern, replacement) {
      result = result.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    // 7.5. Ekspansi Jam dan Waktu
    final Map<String, String> timeMap = {
      '10,30': 'setengah sebelas',
      '12,30': 'setengah satu',
      '07,00': 'jam tujuh',
      '08,30': 'setengah sembilan',
      '14,00': 'jam dua siang',
      '16,00': 'jam empat sore',
      '13,00': 'jam satu siang',
      '15,00': 'jam tiga sore',
      '09,00': 'jam sembilan',
      '12,00': 'jam dua belas',
      '11,30': 'setengah dua belas',
      '08,00': 'jam delapan',
    };

    timeMap.forEach((time, text) {
      // time menggunakan koma karena kita sudah me-replace titik dua di atas
      result = result.replaceAll(time, text);
    });

    // 7.6. Ganti tanda strip yang memisahkan angka/waktu dengan kata "sampai"
    // Ganti strip yang DIKELILINGI spasi (contoh: Senin - Jumat)
    result = result.replaceAll(RegExp(r'\s+-\s+'), ' sampai ');
    // Ganti strip di antara angka tanpa spasi (contoh: 10,30-12,30 -> 10,30 sampai 12,30)
    result = result.replaceAllMapped(RegExp(r'(\d+)\s*-\s*(\d+)'), (m) => '${m.group(1)} sampai ${m.group(2)}');

    // 8. Normalisasi slang Indonesia
    //    Gunakan RegExp.escape agar karakter titik dll tidak dianggap regex wildcard
    final Map<String, String> slangMap = {
      'nggak': 'tidak',
      'gak': 'tidak',
      'kagak': 'tidak',
      'gue': 'saya',
      'gw': 'saya',
      'udah': 'sudah',
      'udh': 'sudah',
      'blm': 'belum',
      'belom': 'belum',
      'bgt': 'sangat',
      'banget': 'sangat',
      'dgn': 'dengan',
      'utk': 'untuk',
      'jgn': 'jangan',
      'krn': 'karena',
      'spt': 'seperti',
      'yg': 'yang',
      'bs': 'bisa',
      'sdh': 'sudah',
      'jg': 'juga',
    };

    slangMap.forEach((slang, formal) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(slang)}\\b', caseSensitive: false),
        formal,
      );
    });

    // 9. Bersihkan karakter dan whitespace berlebih
    result = result
        .replaceAll(RegExp(r'-{2,}'), ' ')   // ganti --- jadi spasi
        .replaceAll(RegExp(r'\s+'), ' ')     // spasi berlebih
        .trim();

    // 10. Pastikan ada tanda baca akhir agar intonasi lebih natural
    if (!RegExp(r'[.!?]$').hasMatch(result)) {
      result = '$result.';
    }

    return result;
  }
}
