/// Kelas untuk menormalisasi teks Bahasa Indonesia agar dibaca lancar
/// oleh Piper TTS (on-device, ringan, neural, tidak robotik).
///
/// Prinsip perbaikan:
/// - Urutan pembersihan diperbaiki agar tidak merusak deteksi URL dan tautan
/// - Penanganan jeda untuk daftar bernomor dan poin bullet dibuat eksplisit
/// - Normalisasi nomor telepon, alamat, dan waktu dibuat lebih robust
/// - Semua komentar dan penamaan variabel menggunakan Bahasa Indonesia yang jelas
class IndonesianTextProcessor {
  /// Normalisasi teks utama sebelum dikirim ke Piper TTS.
  /// Menangani: markdown, emoji, tautan, singkatan, slang, dan simbol.
  static String normalizeForMalayVoice(String teks) {
    if (teks.trim().isEmpty) return teks;

    String hasil = teks;

    // 1. Ekstrak markdown gambar dan tautan TERLEBIH DAHULU sebelum simbol lain diubah
    //    Penting agar deteksi URL tidak rusak oleh penggantian titik dua menjadi koma
    //    Gambar: ![teks alternatif](url) -> teks alternatif
    hasil = hasil.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
      (cocok) => cocok.group(1) ?? '',
    );
    //    Tautan: [teks](url) -> teks (jika teks hanya angka, abaikan agar tidak dibaca sebagai nomor urut)
    hasil = hasil.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      (cocok) {
        final text = cocok.group(1) ?? '';
        if (RegExp(r'^\d+$').hasMatch(text)) return ' '; // Jika tautan hanya angka misal [1], hilangkan saja
        return text;
      },
    );

    // 1b. Bersihkan sisa tanda kurung siku berisi angka rujukan seperti [1], [2] yang kadang muncul dari markdown
    hasil = hasil.replaceAll(RegExp(r'\[\s*\d+\s*\]'), ' ');

    // 2. Hapus URL mentah yang tersisa (http://, https://, www.)
    //    Dilakukan SEBELUM penggantian titik dua agar pola https:// masih terdeteksi
    //    Ganti dengan spasi agar tidak ada fragmen url yang terbaca aneh seperti "1$" atau "satu dollar"
    hasil = hasil.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), ' ');
    hasil = hasil.replaceAll(RegExp(r'www\.\S+', caseSensitive: false), ' ');

    // 2b. Hapus email mentah agar tidak dibaca karakter per karakter
    hasil = hasil.replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'), ' ');

    // 3. Tangani baris baru dan pemisah
    hasil = hasil.replaceAll(RegExp(r'\r\n'), '\n');

    //    Daftar bullet dengan tanda - atau * atau bullet di awal baris
    hasil = hasil.replaceAll(RegExp(r'\n\s*[-*•]\s+'), '. ');
    hasil = hasil.replaceAll(RegExp(r'^\s*[-*•]\s+'), '');
    
    //    Daftar bernomor di baris baru atau awal string: 1. teks -> . 1, teks (beri jeda setelah nomor)
    hasil = hasil.replaceAllMapped(
      RegExp(r'(?:^|\n)\s*(\d+)[\.\)]\s+'),
      (cocok) => '.\n${cocok.group(1)}, ',
    );

    // 3b. Ganti baris baru dengan titik untuk memberi jeda natural pada setiap baris/daftar
    hasil = hasil.replaceAll(RegExp(r'\n+'), '. ');
    
    //    Ganti titik dua dengan koma agar tidak terbaca aneh oleh sebagian engine TTS
    //    Dilakukan setelah URL dihapus agar tidak merusak URL
    hasil = hasil.replaceAll(':', ',');

    // 3c. Tangani daftar bernomor inline yang masih tersisa: "1. teks" -> "1, teks" untuk jeda
    hasil = hasil.replaceAllMapped(
      RegExp(r'\b(\d+)\.\s+'),
      (cocok) => '${cocok.group(1)}, ',
    );

    // 3d. Ganti tanda kurung yang mengapit singkatan atau alternatif dengan kata "atau" untuk jeda natural
    //    Contoh: "Spesialis Kandungan (Obsgyn)" -> "Spesialis Kandungan atau Obsgyn"
    //    Contoh: "dr. Akil (Senin, 10,30-12,30)" -> "dr. Akil atau Senin, 10,30-12,30"
    //    Kurung buka dibaca "atau" agar tidak terbaca "satu" oleh TTS, kurung tutup jadi spasi
    hasil = hasil.replaceAll('(', ' atau ').replaceAll(')', ' ');

    // 3e. Ganti garis miring dan pemisah vertikal dengan spasi
    hasil = hasil.replaceAll('/', ' ').replaceAll('|', ' ').replaceAll('\\', ' ');

    // 4. Hapus simbol markdown yang tersisa (bold, italic, heading, code, blockquote)
    hasil = hasil
        .replaceAll(RegExp(r'\*\*'), '') // hapus bold **
        .replaceAll(RegExp(r'\*'), '') // hapus italic *
        .replaceAll(RegExp(r'__'), '') // hapus underline __
        .replaceAll(RegExp(r'#{1,6}\s?'), '') // hapus heading #
        .replaceAll(RegExp(r'`'), '') // hapus code `
        .replaceAll(RegExp(r'^>\s?', multiLine: true), ''); // hapus blockquote >

    // 5. Hapus emoji dan simbol unicode yang tidak perlu dibaca
    hasil = hasil.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}]|' // emoji modern
        r'[\u{2600}-\u{27FF}]|' // simbol umum
        r'[\u{2B00}-\u{2BFF}]|' // simbol panah
        r'[\u{FE00}-\u{FEFF}]|' // variation selector
        r'[\u{200D}]', // zero-width joiner
        unicode: true,
      ),
      ' ',
    );

    // 6. Normalisasi simbol yang sering jadi masalah saat dibaca TTS
    //    Hapus dollar agar tidak terbaca "dollar", tangani Rupiah, dan, persen
    hasil = hasil
        .replaceAll('\$', ' ') // hapus simbol dollar (bug "1 dollar")
        .replaceAll('＄', ' ')
        .replaceAll(RegExp(r'\bRp\.?\s?', caseSensitive: false), 'Rupiah ')
        .replaceAll('&amp;', ' dan ')
        .replaceAll('&', ' dan ')
        .replaceAll('@', ' ')
        .replaceAll('%', ' persen ')
        .replaceAll('—', ' ')
        .replaceAll('–', ' ')
        .replaceAll('…', ', ')
        .replaceAll('...', ', ')
        .replaceAll(';', ', ')
        .replaceAll(RegExp(r'\s*=\s*'), ' sama dengan ');

    // 6b. Bersihkan sisa karakter markdown/table seperti | -- |
    hasil = hasil.replaceAll(RegExp(r'\|\s*'), ' ').replaceAll(RegExp(r'-{2,}'), ' ');

    // 7. Ekspansi singkatan alamat (gunakan word boundary agar tidak salah ganti di tengah kata)
    final Map<String, String> petaAlamat = {
      r'\bJln\.': 'Jalan',
      r'\bJl\.': 'Jalan',
      r'\bKec\.': 'Kecamatan',
      r'\bKab\.': 'Kabupaten',
      r'\bKel\.': 'Kelurahan',
      r'\bDs\.': 'Desa',
      r'\bNo\.': 'Nomor',
      r'\bTelp\.?': 'Telepon',
      r'\bTel\.?': 'Telepon',
      r'\bDr\.': 'Dokter',
      r'\bProf\.': 'Profesor',
    };

    petaAlamat.forEach((pola, pengganti) {
      hasil = hasil.replaceAll(RegExp(pola, caseSensitive: false), pengganti);
    });

    // 8. Ekspansi singkatan khusus Rumah Sakit
    final Map<String, String> petaRumahSakit = {
      r'\bRSUD\b': 'Rumah Sakit Umum Daerah',
      r'\bRS\b': 'Rumah Sakit',
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

    // Lindungi frasa "atau <Singkatan>" agar tidak menjadi duplikat setelah ekspansi
    // Contoh: "Spesialis Kandungan (Obsgyn)" sudah menjadi " atau Obsgyn " setelah langkah 3d
    // Jika langsung di-expand, akan menjadi "atau Spesialis Kandungan" sehingga duplikat
    // Simpan placeholder sebelum mapping, kembalikan setelahnya
    final Map<String, String> petaPlaceholder = {};
    int indeksPlaceholder = 0;
    for (final kunci in petaRumahSakit.keys) {
      // Ekstrak singkatan dari pola regex, contoh r'\bSpA\b' -> SpA
      // Hapus \b dan karakter regex lain agar dapat singkatan murni
      final String singkatan = kunci.replaceAll(r'\b', '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      if (singkatan.isEmpty) continue;
      final RegExp polaAtauSingkatan = RegExp(r'atau\s+' + RegExp.escape(singkatan), caseSensitive: false);
      if (polaAtauSingkatan.hasMatch(hasil)) {
        final String placeholder = '__PH_${indeksPlaceholder}__';
        petaPlaceholder[placeholder] = 'atau $singkatan';
        hasil = hasil.replaceAll(polaAtauSingkatan, placeholder);
        indeksPlaceholder++;
      }
    }

    // Urutkan dari kunci terpanjang agar RSUD tidak tertimpa RS
    final daftarKunciRs = petaRumahSakit.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final kunci in daftarKunciRs) {
      final pengganti = petaRumahSakit[kunci]!;
      hasil = hasil.replaceAll(RegExp(kunci, caseSensitive: false), pengganti);
    }

    // Kembalikan placeholder menjadi bentuk natural "atau <Singkatan>"
    petaPlaceholder.forEach((placeholder, asli) {
      hasil = hasil.replaceAll(placeholder, asli);
    });

    // 8b. Tangani tanda hubung untuk rentang dan jeda SEBELUM konversi jam
    //    Rentang angka/waktu tanpa spasi: 10,30-12,30 -> 10,30 sampai 12,30
    //    Regex mendukung koma di dalam angka agar jam (10,30) tetap terdeteksi utuh
    hasil = hasil.replaceAllMapped(
      RegExp(r'(\d+(?:,\d+)?)\s*[-–—]\s*(\d+(?:,\d+)?)'),
      (cocok) => '${cocok.group(1)} sampai ${cocok.group(2)}',
    );
    //    Rentang hari: Senin - Jumat -> Senin sampai Jumat
    hasil = hasil.replaceAllMapped(
      RegExp(r'\b(Senin|Selasa|Rabu|Kamis|Jumat|Sabtu|Minggu)\s*[-–—]\s*(Senin|Selasa|Rabu|Kamis|Jumat|Sabtu|Minggu)\b', caseSensitive: false),
      (cocok) => '${cocok.group(1)} sampai ${cocok.group(2)}',
    );
    //    Strip yang dikelilingi spasi sebagai pemisah umum -> ganti dengan koma untuk jeda
    hasil = hasil.replaceAll(RegExp(r'\s+-\s+'), ', ');

    // 8c. Ekspansi jam dan waktu
    //     Peta waktu menggunakan koma karena titik dua sudah diubah menjadi koma
    final Map<String, String> petaWaktu = {
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

    // Ganti waktu yang paling spesifik dulu agar tidak tumpang tindih
    petaWaktu.forEach((waktu, ucapan) {
      hasil = hasil.replaceAll(waktu, ucapan);
    });

    // 8d. Tangani waktu generik yang belum ada di peta, misal 09,15 -> jam sembilan lewat lima belas
    //     Pola: angka jam , angka menit yang belum diubah
    hasil = hasil.replaceAllMapped(
      RegExp(r'\b(\d{1,2}),(\d{2})\b'),
      (cocok) {
        final jam = int.tryParse(cocok.group(1)!);
        final menit = int.tryParse(cocok.group(2)!);
        if (jam == null || menit == null) return cocok.group(0)!;
        if (menit == 0) return 'jam $jam';
        return 'jam $jam lewat $menit';
      },
    );

    // 9. Verbalisasi nomor telepon agar dibaca per digit dengan jeda
    //    Deteksi pola nomor Indonesia: 0 atau +62 diikuti 7-15 digit
    hasil = hasil.replaceAllMapped(
      RegExp(r'\b(?:0|\+62)[\d\s\-]{7,15}\b'),
      (cocok) => _verbalisasiNomorTelepon(cocok.group(0)!),
    );

    // 10. Normalisasi slang Indonesia menjadi bahasa baku
    final Map<String, String> petaSlang = {
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

    petaSlang.forEach((slang, baku) {
      hasil = hasil.replaceAll(
        RegExp('\\b${RegExp.escape(slang)}\\b', caseSensitive: false),
        baku,
      );
    });

    // 11. Bersihkan karakter dan whitespace berlebih
    //     Ganti multiple koma dan titik yang berdekatan
    hasil = hasil
        .replaceAll(RegExp(r',\s*,'), ',')
        .replaceAll(RegExp(r'\.\s*\.'), '.')
        .replaceAll(RegExp(r',\s*\.'), '.')
        .replaceAll(RegExp(r'\.\s*,'), ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 11b. Jika hasil menjadi kosong setelah pembersihan (misal hanya berisi tautan), beri fallback
    if (hasil.isEmpty || hasil == '.' || hasil == ',') {
      return 'Silakan lihat informasi di layar.';
    }

    // 12. Pastikan ada tanda baca akhir agar intonasi lebih natural
    if (!RegExp(r'[.!?]$').hasMatch(hasil)) {
      hasil = '$hasil.';
    }

    // 12b. Rapikan spasi sebelum tanda baca (gunakan replaceAllMapped agar $1 terbaca sebagai grup)
    hasil = hasil.replaceAllMapped(RegExp(r'\s+([.,!?])'), (cocok) => cocok.group(1)!);
    hasil = hasil.replaceAll(RegExp(r'\s+'), ' ').trim();

    return hasil;
  }

  /// Mengubah nomor telepon menjadi ucapan per digit dengan jeda koma.
  /// Contoh: "0815 1100 0600" -> "kosong delapan satu lima, satu satu kosong kosong, kosong enam kosong kosong"
  static String _verbalisasiNomorTelepon(String nomorMentah) {
    // Bersihkan non-digit dulu, tangani +62
    String hanyaDigit = nomorMentah.replaceAll(RegExp(r'[^\d]'), '');
    if (nomorMentah.startsWith('+62') || nomorMentah.startsWith('62')) {
      if (hanyaDigit.startsWith('62')) {
        hanyaDigit = '0${hanyaDigit.substring(2)}';
      }
    }
    
    if (hanyaDigit.length < 8) return nomorMentah;

    const Map<String, String> petaDigit = {
      '0': 'kosong',
      '1': 'satu',
      '2': 'dua',
      '3': 'tiga',
      '4': 'empat',
      '5': 'lima',
      '6': 'enam',
      '7': 'tujuh',
      '8': 'delapan',
      '9': 'sembilan',
    };

    // Kelompokkan per 4 digit agar ada jeda natural seperti penulisan telepon
    final List<String> kelompok = [];
    for (int i = 0; i < hanyaDigit.length; i += 4) {
      final int akhir = (i + 4 < hanyaDigit.length) ? i + 4 : hanyaDigit.length;
      final String potongan = hanyaDigit.substring(i, akhir);
      final List<String> ucapanDigit = potongan.split('').map((d) => petaDigit[d] ?? d).toList();
      kelompok.add(ucapanDigit.join(' '));
    }

    return kelompok.join(', ');
  }

  /// Versi ringkas untuk preview atau logging tanpa ekspansi penuh.
  static String ringkasUntukLog(String teks, {int batas = 120}) {
    if (teks.length <= batas) return teks;
    return '${teks.substring(0, batas)}...';
  }
}
