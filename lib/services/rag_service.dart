import 'dart:convert';
import 'dart:math' as matematika;
import 'package:flutter/services.dart';

/// Model dokumen untuk kebutuhan Retrieval Augmented Generation.
/// Setiap dokumen mewakili satu potongan pengetahuan rumah sakit yang bisa dicari.
class DokumenRag {
  final String id;
  final String konten;
  final String kategori;
  final Map<String, dynamic> metadata;
  final List<String> token;

  DokumenRag({
    required this.id,
    required this.konten,
    required this.kategori,
    required this.metadata,
    required this.token,
  });
}

/// Hasil pencarian RAG yang sudah diberi skor kemiripan.
class HasilPencarianRag {
  final DokumenRag dokumen;
  final double skor;

  HasilPencarianRag({required this.dokumen, required this.skor});
}

/// Layanan RAG enterprise full Dart tanpa dependensi eksternal.
/// Menggunakan TF-IDF + cosine similarity dengan normalisasi bahasa Indonesia.
///
/// Keunggulan:
/// - 100 persen Dart, gratis, tanpa API eksternal untuk retrieval
/// - Tokenisasi khusus bahasa Indonesia dengan stopwords
/// - Skor BM25-like sederhana untuk ranking yang relevan
/// - Anti halusinasi melalui konteks terkurasi dan validasi
class LayananRag {
  static final LayananRag _instansi = LayananRag._internal();
  factory LayananRag() => _instansi;
  LayananRag._internal();

  final List<DokumenRag> _koleksiDokumen = [];
  final Map<String, double> _nilaiIdf = {};
  final Map<String, Map<String, double>> _vektorTfidfDokumen = {};
  final Map<String, double> _normaVektorDokumen = {};
  bool _sudahDiindeks = false;

  // Daftar stopwords bahasa Indonesia yang diabaikan saat tokenisasi
  static const Set<String> _stopwords = {
    'yang',
    'dan',
    'di',
    'ke',
    'dari',
    'untuk',
    'pada',
    'adalah',
    'dengan',
    'ini',
    'itu',
    'atau',
    'sebagai',
    'dalam',
    'oleh',
    'karena',
    'akan',
    'juga',
    'sudah',
    'telah',
    'ada',
    'saya',
    'kamu',
    'anda',
    'kami',
    'kita',
    'mereka',
    'dia',
    'nya',
    'ya',
    'tidak',
    'bisa',
    'dapat',
    'harus',
    'perlu',
    'ingin',
    'mau',
    'apa',
    'bagaimana',
    'kapan',
    'dimana',
    'siapa',
    'kenapa',
    'mengapa',
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
  };

  // Sinonim untuk ekspansi query agar pencarian lebih robust
  static const Map<String, List<String>> _sinonim = {
    'jadwal': ['jadwal', 'praktek', 'praktik', 'jam', 'hari'],
    'dokter': ['dokter', 'dr', 'dok'],
    'anak': ['anak', 'pediatri', 'spA'],
    'bedah': ['bedah', 'spB', 'operasi'],
    'kandungan': ['kandungan', 'obsgyn', 'spOG', 'hamil', 'kebidanan'],
    'penyakit dalam': ['penyakit dalam', 'spPD', 'internis', 'dalam'],
    'umum': ['umum', 'general'],
    'vct': ['vct', 'hiv', 'konseling', 'voluntary'],
    'gigi': ['gigi', 'dentist'],
    'lokasi': ['lokasi', 'alamat', 'tempat', 'dimana', 'maps', 'gedung'],
    'kontak': ['kontak', 'telepon', 'telp', 'hp', 'wa', 'whatsapp', 'nomor', 'hubungi', 'call'],
    'biaya': ['biaya', 'tarif', 'harga', 'bayar', 'bpjs', 'asuransi'],
  };

  bool get sudahSiap => _sudahDiindeks && _koleksiDokumen.isNotEmpty;
  int get jumlahDokumen => _koleksiDokumen.length;
  Future<void>? _initFuture;

  /// Inisialisasi indeks RAG dari data lokal.
  /// Dipanggil sekali saat aplikasi mulai, data diambil dari assets/data_rs.json
  /// dan dokumen statis kontak/lokasi.
  Future<void> inisialisasi() async {
    if (_sudahDiindeks) return;
    if (_initFuture != null) return await _initFuture;
    _initFuture = _doInit();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInit() async {
    await _muatDokumenDariAset();
    _bangunIndeksTfidf();
    _sudahDiindeks = true;
  }

  /// Memuat dokumen dari assets dan data statis rumah sakit.
  Future<void> _muatDokumenDariAset() async {
    _koleksiDokumen.clear();

    // 1. Muat data jadwal dan layanan dari JSON
    try {
      final String jsonString = await rootBundle.loadString('assets/data_rs.json');
      final Map<String, dynamic> dataJson = json.decode(jsonString) as Map<String, dynamic>;

      final List<dynamic> daftarLayanan = dataJson['layanan'] as List<dynamic>;
      for (int i = 0; i < daftarLayanan.length; i++) {
        final Map<String, dynamic> item = daftarLayanan[i] as Map<String, dynamic>;
        final String namaLayanan = item['nama_layanan'] as String;
        final String deskripsi = item['deskripsi'] as String;
        final String lokasi = item['lokasi_gedung'] as String;

        final String konten =
            'Layanan $namaLayanan: $deskripsi. Lokasi di $lokasi. '
            'Kata kunci: ${namaLayanan.toLowerCase()} ${deskripsi.toLowerCase()}';

        _koleksiDokumen.add(
          DokumenRag(
            id: 'layanan_$i',
            konten: konten,
            kategori: 'layanan',
            metadata: {
              'nama_layanan': namaLayanan,
              'deskripsi': deskripsi,
              'lokasi_gedung': lokasi,
            },
            token: _tokenisasi(konten),
          ),
        );
      }

      final List<dynamic> daftarJadwal = dataJson['jadwal_dokter'] as List<dynamic>;
      for (int i = 0; i < daftarJadwal.length; i++) {
        final Map<String, dynamic> item = daftarJadwal[i] as Map<String, dynamic>;
        final String namaDokter = item['nama_dokter'] as String;
        final String spesialisasi = item['spesialisasi'] as String;
        final String hari = item['hari'] as String;
        final String jamMulai = item['jam_mulai'] as String;
        final String jamSelesai = item['jam_selesai'] as String;

        final String konten =
            'Jadwal dokter $spesialisasi: $namaDokter praktek pada hari $hari '
            'pukul $jamMulai sampai $jamSelesai. Spesialisasi $spesialisasi. '
            'Dokter $namaDokter hari $hari jam $jamMulai-$jamSelesai.';

        _koleksiDokumen.add(
          DokumenRag(
            id: 'jadwal_$i',
            konten: konten,
            kategori: 'jadwal',
            metadata: {
              'nama_dokter': namaDokter,
              'spesialisasi': spesialisasi,
              'hari': hari,
              'jam_mulai': jamMulai,
              'jam_selesai': jamSelesai,
            },
            token: _tokenisasi(konten),
          ),
        );
      }
    } catch (e, st) {
      // Jika gagal memuat JSON, tetap lanjutkan dengan dokumen statis tapi log
      // ignore: avoid_print
      print('[RAG] Gagal memuat data_rs.json: $e\n$st');
    }

    // 2. Dokumen statis: kontak, lokasi, informasi umum
    _tambahkanDokumenStatis();
  }

  /// Menambahkan dokumen statis yang tidak ada di JSON
  void _tambahkanDokumenStatis() {
    final List<Map<String, String>> dokumenStatis = [
      {
        'id': 'kontak_utama',
        'kategori': 'kontak',
        'konten':
            'Kontak RS Prima Insan Mulia layanan 24 jam. Informasi dan Pendaftaran telepon 0815 1100 0600. '
            'IGD Gawat Darurat telepon 0856 4507 7831. Humas HC telepon 0856 4507 7830. '
            'Call Center telepon 0283 847 3333. Email primainsan2021@gmail.com. '
            'Kata kunci: kontak telepon nomor hp wa whatsapp darurat igd pendaftaran humas call center email',
      },
      {
        'id': 'lokasi_utama',
        'kategori': 'lokasi',
        'konten':
            'Lokasi RS Prima Insan Mulia berada di Jalan Raya Losari Lor, Kecamatan Losari, Kabupaten Brebes, Jawa Tengah, Indonesia. '
            'Alamat lengkap Jln. Raya Losari Lor, Kec. Losari, Kab. Brebes, Jawa Tengah. '
            'Tersedia di Google Maps dengan pencarian RS Prima Insan Mulia Losari Brebes. Lokasi di Gedung Utama. '
            'Kata kunci: lokasi alamat maps gedung jalan losari brebes jawa tengah',
      },
      {
        'id': 'info_umum_rs',
        'kategori': 'informasi',
        'konten':
            'RS Prima Insan Mulia adalah rumah sakit umum yang menyediakan layanan poliklinik spesialis Anak, Bedah, Kandungan Obsgyn, Penyakit Dalam, Poli Umum, dan Poli VCT. '
            'Jam operasional poliklinik bervariasi per spesialisasi. Tersedia layanan IGD 24 jam untuk gawat darurat. '
            'Kata kunci: rumah sakit prima insan mulia layanan fasilitas poliklinik spesialis igd',
      },
      {
        'id': 'faq_pendaftaran',
        'kategori': 'faq',
        'konten':
            'Cara pendaftaran di RS Prima Insan Mulia dapat melalui telepon Informasi dan Pendaftaran 0815 1100 0600 atau datang langsung ke Gedung Utama. '
            'Pasien disarankan datang 30 menit sebelum jadwal praktek dokter. Bawa kartu identitas dan kartu BPJS atau asuransi jika ada. '
            'Kata kunci: pendaftaran daftar cara registrasi bpjs asuransi kartu identitas',
      },
      {
        'id': 'faq_jam_operasional',
        'kategori': 'faq',
        'konten':
            'Jam operasional RS Prima Insan Mulia untuk poliklinik mengikuti jadwal dokter masing-masing. IGD buka 24 jam setiap hari. '
            'Poliklinik Anak praktek Senin sampai Jumat jam 10:30 sampai 12:30. Poliklinik Bedah Senin Rabu jam 07:00 sampai 08:30, Selasa Kamis Sabtu jam 14:00 sampai 16:00. '
            'Poliklinik Kandungan Kamis dan Sabtu jam 13:00 sampai 15:00. Poliklinik Penyakit Dalam Senin Rabu jam 09:00 sampai 12:00, Jumat jam 09:00 sampai 11:30. '
            'Poli Umum Senin sampai Sabtu jam 09:00 sampai 14:00. Klinik VCT Selasa dan Kamis jam 08:00 sampai 15:00.',
      },
      {
        'id': 'faq_bpjs',
        'kategori': 'faq',
        'konten':
            'RS Prima Insan Mulia melayani pasien BPJS, asuransi, dan umum. Untuk informasi tarif, biaya, dan kepesertaan BPJS hubungi Pendaftaran 0815 1100 0600 atau Call Center 0283 847 3333. '
            'Kata kunci: bpjs asuransi biaya tarif harga bayar umum',
      },
    ];

    for (final data in dokumenStatis) {
      _koleksiDokumen.add(
        DokumenRag(
          id: data['id']!,
          konten: data['konten']!,
          kategori: data['kategori']!,
          metadata: {},
          token: _tokenisasi(data['konten']!),
        ),
      );
    }
  }

  // Precompiled regex untuk performa
  static final RegExp _reNonWord = RegExp(r'[^\w\s]');
  static final RegExp _reSpaces = RegExp(r'\s+');
  // Simpan angka (jam) sebagai token agar query "jam 10" tetap match
  static final RegExp _reTimeColon = RegExp(r'(\d{1,2}):(\d{2})');

  /// Tokenisasi teks menjadi daftar kata yang sudah dinormalisasi.
  /// Menghapus tanda baca, mengubah ke huruf kecil, dan membuang stopwords.
  /// Angka dipertahankan (mis. jam 10:30 -> token "1030" + "10" + "30") agar
  /// pencarian jadwal berbasis waktu tetap relevan.
  List<String> _tokenisasi(String teks) {
    if (teks.trim().isEmpty) return [];

    // Normalisasi: huruf kecil, pertahankan angka, ganti tanda baca dengan spasi
    String normal = teks.toLowerCase();
    // Ubah jam 10:30 -> 10 30 agar angka tidak hilang
    normal = normal.replaceAll(_reTimeColon, r'$1 $2');
    normal = normal.replaceAll(_reNonWord, ' ');
    normal = normal.replaceAll(_reSpaces, ' ').trim();

    if (normal.isEmpty) return [];

    final List<String> semuaToken = normal.split(' ');
    // Buang stopwords dan token terlalu pendek, tapi pertahankan token angka
    return semuaToken.where((t) {
      if (t.length <= 1) return false;
      if (_stopwords.contains(t)) return false;
      return true;
    }).toList();
  }

  /// Ekspansi query dengan sinonim untuk meningkatkan recall
  List<String> _ekspansiQuery(List<String> tokenAsli, String queryAsli) {
    final String queryLower = queryAsli.toLowerCase();
    final Set<String> hasil = {...tokenAsli};

    for (final entri in _sinonim.entries) {
      final String kunci = entri.key;
      final List<String> daftarSinonim = entri.value;
      // Jika query mengandung kata kunci, tambahkan semua sinonimnya
      bool mengandungKunci = daftarSinonim.any((s) => queryLower.contains(s)) || queryLower.contains(kunci);
      if (mengandungKunci) {
        for (final sinonim in daftarSinonim) {
          hasil.addAll(_tokenisasi(sinonim));
        }
      }
    }

    return hasil.toList();
  }

  /// Membangun indeks TF-IDF untuk semua dokumen.
  void _bangunIndeksTfidf() {
    if (_koleksiDokumen.isEmpty) return;

    final int jumlahDokumen = _koleksiDokumen.length;

    // Hitung document frequency untuk setiap term
    final Map<String, int> frekuensiDokumen = {};
    for (final dokumen in _koleksiDokumen) {
      final Set<String> termUnik = dokumen.token.toSet();
      for (final term in termUnik) {
        frekuensiDokumen[term] = (frekuensiDokumen[term] ?? 0) + 1;
      }
    }

    // Hitung IDF untuk setiap term
    for (final entri in frekuensiDokumen.entries) {
      final String term = entri.key;
      final int df = entri.value;
      // IDF dengan smoothing agar tidak nol
      _nilaiIdf[term] = matematika.log(1 + (jumlahDokumen / df));
    }

    // Hitung vektor TF-IDF untuk setiap dokumen
    for (final dokumen in _koleksiDokumen) {
      final Map<String, int> hitungTerm = {};
      for (final term in dokumen.token) {
        hitungTerm[term] = (hitungTerm[term] ?? 0) + 1;
      }

      final int panjangDokumen = dokumen.token.length;
      final Map<String, double> vektor = {};

      for (final entri in hitungTerm.entries) {
        final String term = entri.key;
        final int frekuensi = entri.value;
        final double tf = frekuensi / panjangDokumen;
        final double idf = _nilaiIdf[term] ?? 0;
        vektor[term] = tf * idf;
      }

      _vektorTfidfDokumen[dokumen.id] = vektor;

      // Hitung norma vektor untuk cosine similarity
      double jumlahKuadrat = 0;
      for (final nilai in vektor.values) {
        jumlahKuadrat += nilai * nilai;
      }
      _normaVektorDokumen[dokumen.id] = matematika.sqrt(jumlahKuadrat);
    }
  }

  /// Mencari dokumen yang paling relevan dengan query.
  /// Mengembalikan daftar hasil yang sudah diurutkan berdasarkan skor tertinggi.
  List<HasilPencarianRag> cari(String query, {int batasHasil = 5, double ambangBatas = 0.05}) {
    if (!_sudahDiindeks || _koleksiDokumen.isEmpty) return [];
    if (query.trim().isEmpty) return [];

    final List<String> tokenQuery = _tokenisasi(query);
    if (tokenQuery.isEmpty) return [];

    final List<String> tokenEkspansi = _ekspansiQuery(tokenQuery, query);

    // Hitung TF untuk query
    final Map<String, int> hitungQuery = {};
    for (final term in tokenEkspansi) {
      hitungQuery[term] = (hitungQuery[term] ?? 0) + 1;
    }

    final int panjangQuery = tokenEkspansi.length;
    final Map<String, double> vektorQuery = {};
    for (final entri in hitungQuery.entries) {
      final String term = entri.key;
      final int frekuensi = entri.value;
      final double tf = frekuensi / panjangQuery;
      final double idf = _nilaiIdf[term] ?? matematika.log(1 + (_koleksiDokumen.length / 1));
      vektorQuery[term] = tf * idf;
    }

    // Hitung norma vektor query
    double jumlahKuadratQuery = 0;
    for (final nilai in vektorQuery.values) {
      jumlahKuadratQuery += nilai * nilai;
    }
    final double normaQuery = matematika.sqrt(jumlahKuadratQuery);
    if (normaQuery == 0) return [];

    // Hitung cosine similarity untuk setiap dokumen
    final List<HasilPencarianRag> hasil = [];
    for (final dokumen in _koleksiDokumen) {
      final Map<String, double>? vektorDokumen = _vektorTfidfDokumen[dokumen.id];
      final double? normaDokumen = _normaVektorDokumen[dokumen.id];
      if (vektorDokumen == null || normaDokumen == null || normaDokumen == 0) continue;

      double dotProduct = 0;
      for (final entri in vektorQuery.entries) {
        final String term = entri.key;
        final double nilaiQuery = entri.value;
        final double nilaiDokumen = vektorDokumen[term] ?? 0;
        dotProduct += nilaiQuery * nilaiDokumen;
      }

      final double skor = dotProduct / (normaQuery * normaDokumen);

      // Beri bonus jika kategori cocok dengan intent query
      double skorAkhir = skor;
      final String queryLower = query.toLowerCase();
      if (dokumen.kategori == 'jadwal' &&
          (queryLower.contains('jadwal') ||
              queryLower.contains('dokter') ||
              queryLower.contains('poli') ||
              queryLower.contains('praktek'))) {
        skorAkhir *= 1.2;
      }
      if (dokumen.kategori == 'kontak' &&
          (queryLower.contains('kontak') ||
              queryLower.contains('telepon') ||
              queryLower.contains('nomor') ||
              queryLower.contains('hubungi'))) {
        skorAkhir *= 1.3;
      }
      if (dokumen.kategori == 'lokasi' &&
          (queryLower.contains('lokasi') ||
              queryLower.contains('alamat') ||
              queryLower.contains('dimana') ||
              queryLower.contains('maps'))) {
        skorAkhir *= 1.3;
      }

      if (skorAkhir >= ambangBatas) {
        hasil.add(HasilPencarianRag(dokumen: dokumen, skor: skorAkhir));
      }
    }

    // Urutkan berdasarkan skor tertinggi
    hasil.sort((a, b) => b.skor.compareTo(a.skor));

    // Jika tidak ada yang melewati ambang batas, kembalikan fallback berdasarkan kecocokan kategori
    if (hasil.isEmpty) {
      return _pencarianFallback(query, batasHasil);
    }

    return hasil.take(batasHasil).toList();
  }

  /// Pencarian fallback berbasis pencocokan kategori kasar jika TF-IDF tidak menemukan hasil
  List<HasilPencarianRag> _pencarianFallback(String query, int batas) {
    final String queryLower = query.toLowerCase();
    final List<HasilPencarianRag> fallback = [];

    for (final dokumen in _koleksiDokumen) {
      double skorFallback = 0;
      if (dokumen.kategori == 'kontak' && _mengandungKataKunci(queryLower, ['kontak', 'telepon', 'nomor', 'hp', 'wa'])) {
        skorFallback = 0.15;
      } else if (dokumen.kategori == 'lokasi' && _mengandungKataKunci(queryLower, ['lokasi', 'alamat', 'maps', 'gedung'])) {
        skorFallback = 0.15;
      } else if (dokumen.kategori == 'jadwal' && _mengandungKataKunci(queryLower, ['jadwal', 'dokter', 'poli', 'spesialis'])) {
        skorFallback = 0.12;
      }
      if (skorFallback > 0) {
        fallback.add(HasilPencarianRag(dokumen: dokumen, skor: skorFallback));
      }
    }

    fallback.sort((a, b) => b.skor.compareTo(a.skor));
    return fallback.take(batas).toList();
  }

  bool _mengandungKataKunci(String teks, List<String> kataKunci) {
    return kataKunci.any((k) => teks.contains(k));
  }

  /// Membangun konteks terkurasi untuk dikirim ke LLM.
  /// Menggabungkan hasil pencarian terbaik menjadi satu string konteks dengan penomoran sumber.
  String bangunKonteks(List<HasilPencarianRag> hasilPencarian) {
    if (hasilPencarian.isEmpty) {
      return 'Tidak ada data relevan ditemukan di basis pengetahuan lokal.';
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < hasilPencarian.length; i++) {
      final hasil = hasilPencarian[i];
      buffer.writeln('[Sumber ${i + 1} - ${hasil.dokumen.kategori.toUpperCase()} | skor: ${hasil.skor.toStringAsFixed(2)}]');
      buffer.writeln(hasil.dokumen.konten);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Validasi jawaban LLM agar tidak mengandung halusinasi jadwal dokter.
  /// Memeriksa apakah nama dokter atau jadwal yang disebut ada di konteks.
  /// Mengembalikan null jika valid, atau pesan peringatan jika terdeteksi halusinasi.
  String? validasiJawaban(String jawabanLlm, List<HasilPencarianRag> konteks) {
    if (jawabanLlm.trim().isEmpty) return null;

    // Kumpulkan semua nama dokter yang valid dari konteks
    final Set<String> dokterValid = {};
    for (final hasil in konteks) {
      final namaDokter = hasil.dokumen.metadata['nama_dokter'] as String?;
      if (namaDokter != null) {
        dokterValid.add(namaDokter.toLowerCase());
        // Tambahkan juga versi tanpa gelar
        final String tanpaGelar = namaDokter.replaceAll(RegExp(r'dr\.\s*', caseSensitive: false), '').trim().toLowerCase();
        dokterValid.add(tanpaGelar);
      }
    }

    // Jika tidak ada dokter di konteks, lewati validasi dokter
    if (dokterValid.isEmpty) return null;

    // Cari pola "dr. Nama" di jawaban
    final RegExp polaDokter = RegExp(r'dr\.\s*([A-Za-z\s,\.]+)', caseSensitive: false);
    final Iterable<RegExpMatch> temuan = polaDokter.allMatches(jawabanLlm);

    for (final match in temuan) {
      final String namaDitemukan = match.group(0)!.toLowerCase().trim();
      bool ditemukanDiKonteks = dokterValid.any((valid) => namaDitemukan.contains(valid) || valid.contains(namaDitemukan.replaceAll(RegExp(r'dr\.\s*'), '')));

      // Jika nama dokter tidak ada di konteks, beri peringatan tapi jangan blokir total
      // Skor rendah menunjukkan kemungkinan halusinasi
      if (!ditemukanDiKonteks) {
        // Cek apakah jawaban mengandung detail jadwal spesifik yang tidak ada di konteks
        // Jika ya, kemungkinan halusinasi tinggi
        final bool menyebutJadwalSpesifik = RegExp(r'(senin|selasa|rabu|kamis|jumat|sabtu|minggu)', caseSensitive: false).hasMatch(namaDitemukan) ||
            RegExp(r'\d{1,2}[:\.]\d{2}').hasMatch(jawabanLlm);
        if (menyebutJadwalSpesifik) {
          return 'Peringatan: jawaban mengandung jadwal dokter yang tidak ada di basis data lokal. Harap verifikasi ke pendaftaran.';
        }
      }
    }

    return null;
  }

  /// Menghasilkan jawaban ekstraktif fallback saat LLM tidak tersedia.
  /// Menggabungkan dokumen teratas menjadi jawaban langsung tanpa LLM.
  String jawabanEkstraktif(String query, List<HasilPencarianRag> hasil) {
    if (hasil.isEmpty) {
      return 'Maaf, informasi yang Anda cari belum tersedia di sistem kami. '
          'Silakan hubungi Informasi dan Pendaftaran di 0815 1100 0600 atau Call Center 0283 847 3333 untuk bantuan lebih lanjut.';
    }

    // Jika pertanyaan tentang jadwal, format sebagai daftar
    final String queryLower = query.toLowerCase();
    final bool isJadwal = queryLower.contains('jadwal') || queryLower.contains('dokter') || queryLower.contains('poli');

    if (isJadwal) {
      final List<HasilPencarianRag> jadwalHasil = hasil.where((h) => h.dokumen.kategori == 'jadwal').toList();
      if (jadwalHasil.isNotEmpty) {
        final StringBuffer buffer = StringBuffer();
        buffer.writeln('Berikut informasi jadwal yang tersedia berdasarkan data rumah sakit:');
        buffer.writeln();
        for (int i = 0; i < jadwalHasil.length; i++) {
          buffer.writeln('${i + 1}. ${jadwalHasil[i].dokumen.konten}');
        }
        buffer.writeln();
        buffer.writeln('Untuk informasi lebih detail, hubungi Pendaftaran 0815 1100 0600.');
        return buffer.toString();
      }
    }

    // Fallback umum: gabungkan konten dokumen teratas
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Berdasarkan informasi rumah sakit:');
    buffer.writeln();
    for (int i = 0; i < hasil.length && i < 3; i++) {
      buffer.writeln('- ${hasil[i].dokumen.konten}');
      buffer.writeln();
    }
    buffer.writeln('Jika membutuhkan informasi lebih lanjut, silakan hubungi Call Center 0283 847 3333.');
    return buffer.toString().trim();
  }

  /// Membersihkan dan mereset indeks (untuk testing)
  void reset() {
    _koleksiDokumen.clear();
    _nilaiIdf.clear();
    _vektorTfidfDokumen.clear();
    _normaVektorDokumen.clear();
    _sudahDiindeks = false;
    _initFuture = null;
  }
}
