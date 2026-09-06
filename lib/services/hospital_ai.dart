import 'dart:math' as math;

// =============================================================================
// HospitalAI — Otak AI Chatbot RS Prima Insan Mulia (100% Full Dart, Client-Side)
//
// Karakteristik & Standar Desain:
//  1. ANTI-BIAS & ANTI-HALUSINASI: Berpijak 100% pada data resmi RS Prima Insan Mulia.
//     Tidak mengarang nama dokter, jam, nomor telepon, atau alamat.
//  2. HIDUP & RESPONSIF: Variasi sapaan dan penolakan ramah, tidak monoton/konstan,
//     namun tetap mengarahkan secara konsisten ke fakta rumah sakit.
//  3. DIRECT & RELEVAN: Menjawab tepat apa yang ditanyakan user tanpa information dumping.
//  4. KONSULTASI KESEHATAN & TRIASE: Memberikan empati, rekomendasi poli/dokter yang tepat,
//     jadwal praktik, edukasi awal, tanda bahaya IGD 24 Jam, dan nomor pendaftaran.
//  5. DOKTER CHECKER: Memastikan apakah dokter ada/tidak, dan mengarahkan dengan jelas.
//  6. TAUTAN GOOGLE MAPS KONSISTEN: Tautan navigasi selalu disertakan dalam format markdown
//     aktif [Buka di Google Maps](...).
// =============================================================================

/// Fakta statis rumah sakit — Sumber Kebenaran Tunggal (Single Source of Truth).
class HospitalFakta {
  HospitalFakta._();

  static const String nama = 'RS Prima Insan Mulia';
  static const String namaSingkat = 'Prima';
  static const String alamat =
      'Jln. Raya Losari Lor, Kec. Losari, Kab. Brebes, Jawa Tengah, Indonesia';
  static const String alamatMapsQuery = 'RS Prima Insan Mulia Losari Brebes';
  static const String urlMaps =
      'https://www.google.com/maps/search/?api=1&query=RS+Prima+Insan+Mulia+Losari+Brebes';

  // Kontak resmi
  static const String telpPendaftaran = '0815 1100 0600';
  static const String telpIgd = '0856 4507 7831';
  static const String telpHumas = '0856 4507 7830';
  static const String telpCallCenter = '0283 847 3333';
  static const String email = 'primainsan2021@gmail.com';

  static const String layananUmum =
      'Poliklinik Anak, Bedah, Kandungan, Penyakit Dalam, Poli Umum, dan VCT';
  static const String igdJam = '24 jam';

  /// Daftar dokter & poliklinik lengkap.
  static const List<DokterData> daftarDokter = [
    DokterData(
      nama: 'dr. Akil Baehaqi, Sp.A',
      kunci: ['akil', 'baehaqi'],
      poli: 'Anak',
      layanan: 'Poliklinik Anak',
      lokasi: 'Gedung Utama',
      jadwal: [
        Jadwal('Senin', '10:30', '12:30'),
        Jadwal('Selasa', '10:30', '12:30'),
        Jadwal('Rabu', '10:30', '12:30'),
        Jadwal('Kamis', '10:30', '12:30'),
        Jadwal('Jumat', '10:30', '12:30'),
      ],
    ),
    DokterData(
      nama: 'dr. Mintardi, Sp.B',
      kunci: ['mintardi'],
      poli: 'Bedah',
      layanan: 'Poliklinik Bedah',
      lokasi: 'Gedung Utama',
      jadwal: [
        Jadwal('Senin', '07:00', '08:30'),
        Jadwal('Selasa', '14:00', '16:00'),
        Jadwal('Rabu', '07:00', '08:30'),
        Jadwal('Kamis', '14:00', '16:00'),
        Jadwal('Sabtu', '14:00', '16:00'),
      ],
    ),
    DokterData(
      nama: 'dr. Amy Cynthia De Meriyenes, Sp.OG',
      kunci: ['amy', 'meriyenes', 'cynthia'],
      poli: 'Kandungan',
      layanan: 'Poliklinik Kandungan',
      lokasi: 'Gedung Utama',
      jadwal: [
        Jadwal('Kamis', '13:00', '15:00'),
        Jadwal('Sabtu', '13:00', '15:00'),
      ],
    ),
    DokterData(
      nama: 'dr. Idham Khalid, Sp.PD',
      kunci: ['idham', 'khalid'],
      poli: 'Penyakit Dalam',
      layanan: 'Poliklinik Penyakit Dalam',
      lokasi: 'Gedung Utama',
      jadwal: [
        Jadwal('Senin', '09:00', '12:00'),
        Jadwal('Rabu', '09:00', '12:00'),
        Jadwal('Jumat', '09:00', '11:30'),
      ],
    ),
    DokterData(
      nama: 'Dokter Umum',
      kunci: ['dokter umum', 'poli umum'],
      poli: 'Umum',
      layanan: 'Poli Umum',
      lokasi: 'Gedung Utama',
      jadwal: [
        Jadwal('Senin', '09:00', '14:00'),
        Jadwal('Selasa', '09:00', '14:00'),
        Jadwal('Rabu', '09:00', '14:00'),
        Jadwal('Kamis', '09:00', '14:00'),
        Jadwal('Jumat', '09:00', '14:00'),
        Jadwal('Sabtu', '09:00', '14:00'),
      ],
    ),
    DokterData(
      nama: 'Klinik VCT',
      kunci: ['vct', 'klinik vct'],
      poli: 'VCT',
      layanan: 'Poli VCT',
      lokasi: 'Gedung Utama',
      jadwal: [
        Jadwal('Selasa', '08:00', '15:00'),
        Jadwal('Kamis', '08:00', '15:00'),
      ],
    ),
  ];

  static const List<String> urutanHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
}

class Jadwal {
  final String hari;
  final String jamMulai;
  final String jamSelesai;
  const Jadwal(this.hari, this.jamMulai, this.jamSelesai);
}

class DokterData {
  final String nama;
  final List<String> kunci;
  final String poli;
  final String layanan;
  final String lokasi;
  final List<Jadwal> jadwal;

  const DokterData({
    required this.nama,
    required this.kunci,
    required this.poli,
    required this.layanan,
    required this.lokasi,
    required this.jadwal,
  });

  /// Mencocokkan nama dokter dari teks.
  static DokterData? cariNama(String teks) {
    final String t = teks.toLowerCase();
    for (final d in HospitalFakta.daftarDokter) {
      for (final kunci in d.kunci) {
        if (kunci == 'vct' || kunci == 'dokter umum' || kunci == 'poli umum') {
          continue;
        }
        if (t.contains(kunci)) return d;
      }
      if (t.contains(d.nama.toLowerCase())) return d;
    }
    return null;
  }

  /// Mencari dokter berdasarkan poliklinik / spesialisasi.
  static DokterData? cariPoli(String poli) {
    final String t = poli.toLowerCase();
    for (final d in HospitalFakta.daftarDokter) {
      if (d.poli.toLowerCase() == t) return d;
      if (d.layanan.toLowerCase().contains(t)) return d;
    }
    return null;
  }
}

/// Hasil deteksi intent dan entitas.
class HasilDeteksi {
  final IntentAi intent;
  final DokterData? dokter;
  final String? namaDokterDicari;
  final String? keluhanMedis;
  final String? poli;
  final String? hari;
  final bool adaTandaPertanyaan;
  final bool tanyaKeberadaan;

  const HasilDeteksi({
    required this.intent,
    this.dokter,
    this.namaDokterDicari,
    this.keluhanMedis,
    this.poli,
    this.hari,
    this.adaTandaPertanyaan = false,
    this.tanyaKeberadaan = false,
  });
}

enum IntentAi {
  sapaan,
  terimaKasih,
  pergilah,
  igd,
  dokterSpesifik,
  dokterTidakAda,
  simtom,
  jadwal,
  daftarDokter,
  kontak,
  lokasi,
  pendaftaran,
  biaya,
  vct,
  layanan,
  jamOperasional,
  umumHospital,
  diLuarKonteks,
  kosong,
}

/// Respon akhir bot dengan format markdown UI dan plain text TTS.
class JawabanBot {
  final String tampilan;
  final String tts;
  final List<String> saran;

  const JawabanBot({
    required this.tampilan,
    required this.tts,
    this.saran = const [],
  });
}

class HospitalAI {
  final math.Random _acak;

  HospitalAI({math.Random? acak}) : _acak = acak ?? math.Random();

  // ---------------------------------------------------------------------------
  // Pola regex & kata kunci
  // ---------------------------------------------------------------------------
  static final RegExp _reApaKabar = RegExp(
    r'apa\s*kabar|gimana\s*kabar|kabar\s*apa|how\s*are\s*you',
    caseSensitive: false,
  );

  static const List<String> _kataSapaan = [
    'halo',
    'hai',
    'hey',
    'hello',
    'hi',
    'pagi',
    'siang',
    'sore',
    'malam',
    'assalamualaikum',
    'assalamu alaikum',
    'selamat pagi',
    'selamat siang',
    'selamat sore',
    'selamat malam',
    'permisi',
    'hei',
    'haloo',
    'sampurasun',
    'kulonuwun',
  ];

  static const List<String> _kataTerimaKasih = [
    'terima kasih',
    'trimakasih',
    'makasih',
    'thanks',
    'thank you',
    'matur nuwun',
    'nuhun',
    'sami sami',
  ];

  static const List<String> _kataPergilah = [
    'sampai jumpa',
    'sampai ketemu',
    'bye',
    'selamat tinggal',
    'dadah',
    'pergi dulu',
    'pamit',
  ];

  static final RegExp _reIgd = RegExp(
    r'\bigd\b|gawat\s*darurat|\bdarurat\b|ambulans|emergency|pingsan|kejang|sesak\s*parah|muntah\s*darah',
    caseSensitive: false,
  );

  static final RegExp _reKontak = RegExp(
    r'\b(nomor|nomer|telepon|telp|telpon|telponya|teleponnya|telpnya|nomornya|nomernya|telefon|'
    r'hp|wa|whatsapp|watsapp|call\s*center|callcenter|callcentre|hubungi|kontak|number|email|surel)\b',
    caseSensitive: false,
  );

  static final RegExp _reLokasi = RegExp(
    r'\b(alamat|alamatnya|lokasi|dimana|di\s*mana|maps|google\s*maps|peta|gedung|gedungnya|posisinya|arah|daerah\s*mana|rute)\b',
    caseSensitive: false,
  );

  static final RegExp _reDiLuar = RegExp(
    r'presiden|wakil presiden|pemilu|pilpres|politik|partai|menteri|dpr|'
    r'cuaca|resep|masak|film|lagu|musik|game|sepak bola|futsal|sejarah|'
    r'matematika|rumus|coding|programming|flutter|dart|javascript|python|'
    r'harga hp|harga mobil|belanja|tokopedia|shopee|instagram|tiktok|facebook|'
    r'candaan|jokes|tebak|teka teki|puzzle|kuis|prediksi|judi|slot|'
    r'pacaran|jodoh|zodiak|horoskop',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // Entry point utama
  // ---------------------------------------------------------------------------

  JawabanBot jawab(String mentah) {
    final String q = _bersih(mentah);
    if (q.isEmpty) {
      return const JawabanBot(
        tampilan:
            'Silakan ketik pertanyaan Anda, saya siap membantu seputar RS Prima Insan Mulia.',
        tts:
            'Silakan ketik pertanyaan Anda, saya siap membantu seputar Rumah Sakit Prima Insan Mulia.',
      );
    }

    final HasilDeteksi d = deteksi(q);
    switch (d.intent) {
      case IntentAi.kosong:
        return _jawabanKosong();
      case IntentAi.sapaan:
        return _jawabanSapaan(q);
      case IntentAi.terimaKasih:
        return _jawabanTerimaKasih();
      case IntentAi.pergilah:
        return _jawabanPergilah();
      case IntentAi.igd:
        return _jawabanIgd();
      case IntentAi.dokterSpesifik:
        return _jawabanDokter(d.dokter!, d.hari, d.tanyaKeberadaan);
      case IntentAi.dokterTidakAda:
        return _jawabanDokterTidakAda(d.namaDokterDicari ?? 'yang Anda tanyakan');
      case IntentAi.simtom:
        return _jawabanSimtom(q, d);
      case IntentAi.jadwal:
        return _jawabanJadwal(d);
      case IntentAi.daftarDokter:
        return _jawabanDaftarDokter(d.hari);
      case IntentAi.kontak:
        return _jawabanKontak();
      case IntentAi.lokasi:
        return _jawabanLokasi();
      case IntentAi.pendaftaran:
        return _jawabanPendaftaran();
      case IntentAi.biaya:
        return _jawabanBiaya();
      case IntentAi.vct:
        return _jawabanVct();
      case IntentAi.layanan:
        return _jawabanLayanan();
      case IntentAi.jamOperasional:
        return _jawabanJamOperasional();
      case IntentAi.umumHospital:
        return _jawabanUmumHospital(q);
      case IntentAi.diLuarKonteks:
        return _jawabanDiLuarKonteks(q);
    }
  }

  // ---------------------------------------------------------------------------
  // Engine Deteksi Intent & Entitas
  // ---------------------------------------------------------------------------

  HasilDeteksi deteksi(String q) {
    final String t = _norm(q);

    // 1) Gawat darurat / IGD (prioritas keselamatan pertama).
    if (_reIgd.hasMatch(t)) {
      return const HasilDeteksi(intent: IntentAi.igd, adaTandaPertanyaan: true);
    }

    // 2) Sapaan, terima kasih, perpisahan.
    if (_apakahSapaan(t)) return const HasilDeteksi(intent: IntentAi.sapaan);
    if (_apakahTerimaKasih(t)) return const HasilDeteksi(intent: IntentAi.terimaKasih);
    if (_apakahPergilah(t)) return const HasilDeteksi(intent: IntentAi.pergilah);

    // 3) Pertanyaan keberadaan / jadwal dokter spesifik di database.
    final bool tanyaAdaDokter = _apakahTanyaKeberadaan(t);
    final DokterData? dokterAda = DokterData.cariNama(t);
    if (dokterAda != null) {
      return HasilDeteksi(
        intent: IntentAi.dokterSpesifik,
        dokter: dokterAda,
        poli: dokterAda.poli,
        hari: _cariHari(t),
        tanyaKeberadaan: tanyaAdaDokter,
        adaTandaPertanyaan: true,
      );
    }

    // 4) Lokasi / alamat / peta Google Maps.
    if (_apakahLokasi(t)) {
      return const HasilDeteksi(intent: IntentAi.lokasi, adaTandaPertanyaan: true);
    }

    // 5) Kontak / nomor telepon resmi.
    if (_apakahKontak(t)) {
      return const HasilDeteksi(intent: IntentAi.kontak, adaTandaPertanyaan: true);
    }

    // 6) Biaya / BPJS / Asuransi.
    if (_apakahBiaya(t)) {
      return const HasilDeteksi(intent: IntentAi.biaya, adaTandaPertanyaan: true);
    }

    // 7) Pendaftaran & antrean.
    if (_apakahPendaftaran(t)) {
      return const HasilDeteksi(intent: IntentAi.pendaftaran, adaTandaPertanyaan: true);
    }

    // 8) Dokter yang dicari tidak ada di database (misal: "dr Budi ada ga", "dr Tirta praktek ga").
    final String? namaDokterAsing = _ekstrakNamaDokterTidakAda(t);
    if (namaDokterAsing != null) {
      return HasilDeteksi(
        intent: IntentAi.dokterTidakAda,
        namaDokterDicari: namaDokterAsing,
        adaTandaPertanyaan: true,
      );
    }

    // 9) Konsultasi keluhan / simtom kesehatan (sakit perut, mencet, pusing, batuk, dll).
    final SimtomResult? simtom = _analisisSimtom(t);
    if (simtom != null) {
      return HasilDeteksi(
        intent: IntentAi.simtom,
        poli: simtom.poli,
        keluhanMedis: simtom.keluhan,
        hari: _cariHari(t),
        adaTandaPertanyaan: true,
      );
    }

    // 10) VCT / HIV.
    if (t.contains('vct') || t.contains('hiv') || t.contains('aids')) {
      final DokterData? vct = DokterData.cariPoli('VCT');
      return HasilDeteksi(
        intent: IntentAi.vct,
        dokter: vct,
        poli: 'VCT',
        hari: _cariHari(t),
      );
    }

    // 11) Jam operasional rumah sakit.
    if (_apakahJamOperasional(t)) {
      return const HasilDeteksi(intent: IntentAi.jamOperasional, adaTandaPertanyaan: true);
    }

    // 12) Jadwal / daftar dokter / pencarian poli.
    final String? poliJadwal = _cariPoli(t);
    final bool daftar = _apakahDaftarDokter(t);
    if (_apakahJadwal(t) || daftar || poliJadwal != null) {
      final bool hanyaDaftar = daftar && poliJadwal == null && _cariHari(t) == null;
      return HasilDeteksi(
        intent: hanyaDaftar ? IntentAi.daftarDokter : IntentAi.jadwal,
        dokter: poliJadwal == null ? null : DokterData.cariPoli(poliJadwal),
        poli: poliJadwal,
        hari: _cariHari(t),
        adaTandaPertanyaan: true,
      );
    }

    // 13) Layanan / fasilitas poliklinik.
    if (_apakahLayanan(t)) {
      return const HasilDeteksi(intent: IntentAi.layanan, adaTandaPertanyaan: true);
    }

    // 14) Di luar konteks RS & kesehatan (guardrail).
    if (_reDiLuar.hasMatch(t) && !_adaKataHospitalKuat(t)) {
      return const HasilDeteksi(intent: IntentAi.diLuarKonteks, adaTandaPertanyaan: true);
    }

    // 15) Pertanyaan umum seputar rumah sakit.
    if (_adaKataHospitalKuat(t)) {
      return const HasilDeteksi(intent: IntentAi.umumHospital, adaTandaPertanyaan: true);
    }

    // 16) Fallback klarifikasi lembut.
    return const HasilDeteksi(intent: IntentAi.kosong, adaTandaPertanyaan: true);
  }

  String _bersih(String mentah) =>
      mentah.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _norm(String q) => _bersih(q).toLowerCase();

  // ---------------------------------------------------------------------------
  // Helper Klasifikasi Sapaan & Intent
  // ---------------------------------------------------------------------------

  bool _apakahSapaan(String t) {
    if (_reApaKabar.hasMatch(t) && t.length <= 60) return true;

    // Abaikan tanda baca
    final String bersih = t.replaceAll(RegExp(r'[^\p{L}\s]', caseSensitive: false), ' ');
    final List<String> kata =
        bersih.split(' ').where((k) => k.isNotEmpty).toList();
    if (kata.isEmpty) return false;

    // Jika ada kata kunci topik medis/jadwal/alamat -> bukan sapaan murni
    final RegExp sinyalTopik = RegExp(
      r'\b(jadwal|dokter|dr|poli|spesialis|nomor|nomer|telepon|telp|telpon|'
      r'alamat|lokasi|sakit|biaya|bpjs|pendaftaran|daftar|kontak|vct|igd|'
      r'bayar|tarif|operasional|presiden|mencret|mencet|demam|luka)\b',
    );
    if (sinyalTopik.hasMatch(t)) return false;

    // Cek sapaan multi-kata (seperti "halo apa kabar prima insan disini")
    for (final s in _kataSapaan) {
      if (t.startsWith(s)) return true;
    }

    // Kata sapaan tunggal atau pendek
    if (kata.length <= 4) {
      if (kata.any((k) => _kataSapaan.contains(k))) return true;
    }

    return false;
  }

  bool _apakahTerimaKasih(String t) {
    if (t.length > 50) return false;
    for (final k in _kataTerimaKasih) {
      if (t.contains(k)) return true;
    }
    return false;
  }

  bool _apakahPergilah(String t) {
    if (t.length > 50) return false;
    for (final k in _kataPergilah) {
      if (t.contains(k)) return true;
    }
    return false;
  }

  bool _apakahTanyaKeberadaan(String t) {
    return RegExp(
      r'(ada\s*ga|ada\s*gak|ada\s*tidak|apakah\s*ada|buka\s*ga|praktek\s*ga|praktik\s*ga|bertugas|tersedia)',
    ).hasMatch(t);
  }

  String? _ekstrakNamaDokterTidakAda(String t) {
    // Deteksi bila user menanyakan "dr. X" atau "dokter X" yang tidak dikenal
    final RegExp re = RegExp(r'\b(dr\.?|dokter)\s+([a-zA-Z]{3,})\b');
    final match = re.firstMatch(t);
    if (match != null) {
      final kataNama = match.group(2)!.toLowerCase();
      // Pastikan bukan kata spesialisasi generik, kata tanya, kata ganti, atau kata penghubung
      const kataBukanDokter = [
        'yang',
        'mana',
        'apa',
        'siapa',
        'ini',
        'itu',
        'aja',
        'saja',
        'ada',
        'jaga',
        'tugas',
        'bertugas',
        'praktik',
        'praktek',
        'jadwal',
        'spesialis',
        'gigi',
        'mata',
        'umum',
        'anak',
        'bedah',
        'kandungan',
        'obsgyn',
        'penyakit',
        'dalam',
        'vct',
        'klinik',
        'poliklinik',
        'tamu',
        'pengganti',
        'rumah',
        'sakit',
        'prima',
        'insan',
        'mulia',
        'bisa',
        'mau',
        'hari',
        'senin',
        'selasa',
        'rabu',
        'kamis',
        'jumat',
        'sabtu',
        'minggu',
        'pagi',
        'siang',
        'sore',
        'malam',
        'baru',
        'lama',
        'lain',
        'lainnya',
        'rujukan',
        'rujuk',
        'konsul',
        'konsultasi',
        'periksa',
        'obat',
        'resep',
        'bpjs',
        'asuransi',
        'biaya',
        'tarif',
        'loket',
        'daftar',
        'pendaftaran',
        'di',
        'ke',
        'dari',
        'pada',
        'untuk',
        'dengan',
        'tentang',
      ];
      if (kataBukanDokter.contains(kataNama)) return null;

      // Cek apakah ada di daftar dokter resmi
      final dokterAda = DokterData.cariNama(kataNama);
      if (dokterAda == null) {
        final namaFormat =
            kataNama[0].toUpperCase() + kataNama.substring(1).toLowerCase();
        return 'dr. $namaFormat';
      }
    }
    return null;
  }

  bool _apakahKontak(String t) => _reKontak.hasMatch(t);

  bool _apakahLokasi(String t) => _reLokasi.hasMatch(t);

  bool _apakahPendaftaran(String t) => RegExp(
        r'(pendaftaran|mendaftar|registrasi|booking|reservasi|antrian|antrean|cara\s*daftar|mau\s*daftar|alur\s*daftar)',
      ).hasMatch(t);

  bool _apakahBiaya(String t) => RegExp(
        r'(biaya|tarif|harga|bayar|pembayaran|bpjs|asuransi|klaim|cashless|kartu\s*kis)',
      ).hasMatch(t);

  bool _apakahJamOperasional(String t) => RegExp(
        r'(operasional|jam\s*buka|buka\s*jam|jam\s*kerja|jam\s*pelayanan|buka\s*sampai)',
      ).hasMatch(t);

  bool _apakahJadwal(String t) => RegExp(
        r'(jadwal|praktek|praktik|kapan|jam\s*berapa|hari\s*apa|besok|lusa|hari\s*ini)',
      ).hasMatch(t);

  bool _apakahDaftarDokter(String t) => RegExp(
        r'(daftar|list|siapa\s*saja|dokter\s*apa\s*saja|semua\s*dokter|dokter\s*mana\s*saja|dokter\s*yang\s*ada|dokter\s*tersedia)',
      ).hasMatch(t);

  bool _apakahLayanan(String t) => RegExp(
        r'(layanan|fasilitas|poli\s*apa|jenis\s*poli|spesialis\s*apa|bidang\s*apa|melayani\s*apa|spesialis\s*mana)',
      ).hasMatch(t);

  bool _adaKataHospitalKuat(String t) {
    const kuat = [
      'rumah sakit',
      'rs prima',
      'prima insan',
      'poliklinik',
      'pendaftaran',
      'bpjs',
      'call center',
      'brebes',
      'losari',
      'dokter',
      'poli',
      'jadwal',
      'alamat',
      'telepon',
      'kontak',
      'layanan',
    ];
    return kuat.any((k) => t.contains(k));
  }

  // ---------------------------------------------------------------------------
  // Analisis Simtom & Rekomendasi Medis Awal
  // ---------------------------------------------------------------------------

  SimtomResult? _analisisSimtom(String t) {
    // Bersihkan penyebutan rumah sakit agar kata 'sakit' pada 'rumah sakit' tidak terpicu
    final String tt = t
        .replaceAll(RegExp(r'rumah\s*sakit', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'rs\s*prima(\s*insan\s*mulia)?', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\brs\b', caseSensitive: false), ' ')
        .toLowerCase();

    // 1. Pencernaan & Sakit Perut (termasuk mencet, mencret, diare, mual muntah)
    if (RegExp(
      r'(mencet|mencret|diare|bab\s*cair|sakit\s*perut|nyeri\s*perut|perut\s*melilit|mules|'
      r'mual|muntah|lambung|maag|gerd|asam\s*lambung|nyeri\s*ulu\s*hati|kembung|begah)',
    ).hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Penyakit Dalam',
        keluhan: 'keluhan sakit perut dan gangguan pencernaan (seperti mencret/diare atau asam lambung)',
      );
    }

    // 2. Anak & Bayi
    if (RegExp(
      r'(anak\s*demam|anak\s*panas|anak\s*batuk|anak\s*sakit|bayi|balita|imunisasi|campak|anak\s*mencret)',
    ).hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Anak',
        keluhan: 'keluhan kesehatan pada anak atau balita',
      );
    }

    // 3. Kandungan, Kehamilan, & Reproduksi Wanita
    if (RegExp(
      r'(hamil|kehamilan|kandungan|telat\s*haid|telat\s*bulan|nyeri\s*haid|haid|'
      r'usg|melahirkan|persalinan|keputihan|promil|kebidanan)',
    ).hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Kandungan',
        keluhan: 'keluhan seputar kehamilan, pemeriksaan kandungan, atau kesehatan reproduksi wanita',
      );
    }

    // 4. Bedah, Luka, Benjolan, & Cedera Fisik
    if (RegExp(
      r'(luka|luka\s*bakar|patah|fraktur|terkilir|kecelakaan|benjolan|tumor|kista|'
      r'usus\s*buntu|hernia|wasir|ambeien|operasi|bisul\s*parah)',
    ).hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Bedah',
        keluhan: 'keluhan luka, cedera fisik, benjolan, atau indikasi tindakan bedah',
      );
    }

    // 5. Penyakit Dalam / Metabolik / Kronis
    if (RegExp(
      r'(gula\s*darah|diabetes|tensi|hipertensi|jantung|ginjal|paru|asma|sesak|kolesterol|nyeri\s*sendi)',
    ).hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Penyakit Dalam',
        keluhan: 'keluhan penyakit dalam atau gangguan metabolik/kronis',
      );
    }

    // 6. Skrining VCT / HIV
    if (RegExp(r'(vct|hiv|aids|skrining\s*hiv|konseling\s*vct|tes\s*vct)').hasMatch(tt)) {
      return const SimtomResult(
        poli: 'VCT',
        keluhan: 'konseling sukarela dan pemeriksaan VCT (HIV)',
      );
    }

    // 7. Keluhan Umum Ringan (pusing, flu, demam dewasa, cek kesehatan)
    if (RegExp(
      r'(pusing|sakit\s*kepala|flu|pilek|batuk|demam|badan\s*lemas|meriang|cek\s*kesehatan|surat\s*dokter|minta\s*surat)',
    ).hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Umum',
        keluhan: 'keluhan kesehatan umum atau pemeriksaan awal',
      );
    }

    // 8. Kata keluhan umum tanpa konteks spesifik
    if (RegExp(r'(sakit|nyeri|keluhan|konsultasi|periksa|saran\s*dokter)').hasMatch(tt)) {
      return const SimtomResult(
        poli: 'Umum',
        keluhan: 'keluhan kesehatan yang Anda rasakan',
      );
    }

    return null;
  }

  String? _cariHari(String t) {
    final RegExp reHari = RegExp(
      r'\b(senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b',
      caseSensitive: false,
    );
    final RegExpMatch? m = reHari.firstMatch(t);
    if (m != null) {
      final String h = m.group(1)!;
      return h[0].toUpperCase() + h.substring(1).toLowerCase();
    }
    if (t.contains('besok')) return _namaHari(DateTime.now().weekday + 1);
    if (t.contains('lusa')) return _namaHari(DateTime.now().weekday + 2);
    if (t.contains('hari ini')) return _namaHari(DateTime.now().weekday);
    return null;
  }

  String _namaHari(int weekday) {
    if (weekday > 7) weekday -= 7;
    const names = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return names[weekday];
  }

  String? _cariPoli(String t) {
    final String tt = t.toLowerCase();
    if (RegExp(r'\b(anak|pediatri)\b').hasMatch(tt)) return 'Anak';
    if (RegExp(r'\b(bedah|operasi)\b').hasMatch(tt)) return 'Bedah';
    if (RegExp(r'(kandungan|obsgyn|obgyn|sp\.?og|hamil|kebidanan)').hasMatch(tt)) {
      return 'Kandungan';
    }
    if (RegExp(r'(penyakit\s*dalam|sp\.?pd|internis)').hasMatch(tt)) {
      return 'Penyakit Dalam';
    }
    if (RegExp(r'\bvct\b').hasMatch(tt)) return 'VCT';
    if (RegExp(r'\b(umum|general)\b').hasMatch(tt)) return 'Umum';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pembangun Jawaban Responsif & Hidup
  // ---------------------------------------------------------------------------

  String _pilih(List<String> opsi) => opsi[_acak.nextInt(opsi.length)];

  String _pilihBuka() => _pilih(const [
        'Tentu, dengan senang hati saya bantu',
        'Baik, berikut informasi resmi yang Anda butuhkan',
        'Siap, ini informasi lengkap dari RS Prima Insan Mulia',
        'Tentu, silakan simak rincian berikut',
        'Baik, berikut data yang tersedia di sistem kami',
      ]);

  String _pilihTutup() => _pilih(const [
        'Apakah ada hal lain yang ingin Anda tanyakan?',
        'Silakan beri tahu saya jika butuh jadwal dokter atau informasi lainnya.',
        'Ada yang bisa saya bantu kembali seputar layanan rumah sakit?',
        'Semoga Anda dan keluarga senantiasa sehat selalu.',
        'Saya siap membantu jika ada pertanyaan lanjutan.',
      ]);

  JawabanBot _jawabanKosong() {
    final String buka = _pilih(const [
      'Mohon maaf, saya belum sepenuhnya menangkap maksud pertanyaan Anda.',
      'Pertanyaan Anda tampak belum spesifik, saya ingin membantu dengan tepat.',
      'Boleh diperjelas kembali hal yang ingin Anda tanyakan?',
    ]);
    final String arah = _pilih(const [
      'Anda bisa menanyakan jadwal dokter, lokasi rumah sakit, informasi pendaftaran, atau keluhan kesehatan yang ingin dikonsultasikan.',
      'Silakan tanyakan nama dokter, poliklinik spesialis, nomor telepon pendaftaran, atau alamat RS Prima Insan Mulia.',
      'Saya siap memberikan informasi jadwal praktik, IGD 24 jam, maupun kontak rumah sakit.',
    ]);
    final String teks = '$buka\n\n$arah';
    return JawabanBot(
      tampilan: teks,
      tts: teks,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
    );
  }

  JawabanBot _jawabanSapaan(String q) {
    final String t = q.toLowerCase();

    // Salam islami
    if (t.contains('assalam')) {
      final String salam = _pilih(const [
        'Waalaikumsalam warahmatullahi wabarakatuh',
        'Waalaikumsalam wr. wb.',
        'Waalaikumsalam, selamat datang',
      ]);
      final String pesan = _pilih(const [
        'Saya Prima, asisten informasi resmi RS Prima Insan Mulia. Ada yang bisa saya bantu untuk jadwal dokter, pendaftaran, atau layanan rumah sakit hari ini?',
        'Senang menyapa Anda. Saya Prima, siap membantu Anda mengetahui jadwal poliklinik, lokasi, kontak, maupun rekomendasi dokter di RS Prima Insan Mulia.',
      ]);
      final String teks = '$salam!\n\n$pesan';
      return JawabanBot(
        tampilan: teks,
        tts: teks,
        saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
      );
    }

    // Apa kabar
    if (_reApaKabar.hasMatch(t)) {
      final String kabar = _pilih(const [
        'Alhamdulillah, saya Prima dalam keadaan baik dan selalu siap melayani Anda',
        'Kabar baik di sini, terima kasih telah bertanya! Saya Prima siap membantu Anda di RS Prima Insan Mulia',
        'Prima siap siaga melayani kebutuhan informasi RS Prima Insan Mulia untuk Anda',
      ]);
      final String lanjut = _pilih(const [
        'Ada yang ingin Anda tanyakan seputar jadwal dokter, layanan poliklinik, lokasi, atau pendaftaran di RS Prima Insan Mulia?',
        'Apakah ada jadwal dokter atau layanan RS Prima Insan Mulia yang sedang Anda cari tahu hari ini?',
      ]);
      final String teks = '$kabar.\n\n$lanjut';
      return JawabanBot(
        tampilan: teks,
        tts: teks,
        saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
      );
    }

    // Sapaan umum (Halo, Hai, Pagi, Siang, dll)
    final int jam = DateTime.now().hour;
    String salamWaktu;
    if (jam >= 4 && jam < 11) {
      salamWaktu = _pilih(const ['Selamat pagi', 'Pagi, semoga hari Anda penuh semangat']);
    } else if (jam >= 11 && jam < 15) {
      salamWaktu = _pilih(const ['Selamat siang', 'Siang, semoga aktivitas Anda lancar']);
    } else if (jam >= 15 && jam < 18) {
      salamWaktu = _pilih(const ['Selamat sore', 'Sore, semoga selalu sehat']);
    } else {
      salamWaktu = _pilih(const ['Selamat malam', 'Malam, semoga beristirahat dengan nyaman']);
    }

    final String variasiBuka = _pilih([
      'Halo! $salamWaktu. Selamat datang di layanan informasi RS Prima Insan Mulia.',
      'Hai! $salamWaktu. Saya Prima, siap mendampingi kebutuhan informasi rumah sakit Anda.',
      'Halo Prima Insan! $salamWaktu. Ada yang bisa saya bantu hari ini?',
      'Selamat datang di Prima Bot RS Prima Insan Mulia! $salamWaktu.',
    ]);

    final String variasiArah = _pilih(const [
      'Silakan tanyakan jadwal dokter, lokasi RS, kontak pendaftaran, atau keluhan kesehatan yang ingin Anda konsultasikan.',
      'Anda bisa menanyakan jadwal praktik spesialis, alur pendaftaran BPJS/umum, maupun kontak resmi rumah sakit.',
      'Saya dapat membantu mencarikan dokter yang tepat untuk keluhan Anda, mengecek jadwal hari ini, hingga nomor IGD 24 Jam.',
    ]);

    final String teks = '$variasiBuka\n\n$variasiArah';
    return JawabanBot(
      tampilan: teks,
      tts: teks,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
    );
  }

  JawabanBot _jawabanTerimaKasih() {
    final String teks = _pilih(const [
      'Sama-sama! Senang sekali bisa membantu Anda. Jika memerlukan informasi lebih lanjut mengenai RS Prima Insan Mulia, jangan ragu untuk bertanya kembali ya.',
      'Terima kasih kembali. Semoga lekas sehat dan urusan Anda di RS Prima Insan Mulia berjalan lancar!',
      'Sama-sama. Saya selalu siap membantu kapan pun Anda butuh informasi jadwal atau layanan rumah sakit.',
    ]);
    return JawabanBot(
      tampilan: teks,
      tts: teks,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
    );
  }

  JawabanBot _jawabanPergilah() {
    final String teks = _pilih(const [
      'Sampai jumpa! Tetap jaga kesehatan Anda dan keluarga. Saya siap membantu lagi kapan saja.',
      'Baik, terima kasih telah menghubungi RS Prima Insan Mulia. Semoga hari Anda menyenangkan dan sehat selalu!',
      'Sampai ketemu lagi! Untuk kebutuhan pendaftaran langsung, Anda juga bisa menghubungi 0815 1100 0600.',
    ]);
    return JawabanBot(
      tampilan: teks,
      tts: teks,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
    );
  }

  JawabanBot _jawabanIgd() {
    final String teks =
        'Untuk kondisi gawat darurat, layanan **IGD (Instalasi Gawat Darurat)** ${HospitalFakta.nama} buka **24 Jam** tanpa libur di **Gedung Utama**.\n\n'
        '- **Telepon Langsung IGD:** [${HospitalFakta.telpIgd}](tel:${HospitalFakta.telpIgd.replaceAll(' ', '')})\n'
        '- **Informasi & Pendaftaran:** [${HospitalFakta.telpPendaftaran}](tel:${HospitalFakta.telpPendaftaran.replaceAll(' ', '')})\n'
        '- **Alamat:** ${HospitalFakta.alamat}\n\n'
        'Jika pasien membutuhkan pertolongan darurat atau ambulans, segera hubungi kontak IGD di atas.';
    final String tts =
        'Untuk kondisi gawat darurat, layanan I G D Rumah Sakit Prima Insan Mulia buka 24 jam di Gedung Utama. '
        'Telepon langsung I G D di ${HospitalFakta.telpIgd}. Pendaftaran di ${HospitalFakta.telpPendaftaran}.';
    return JawabanBot(
      tampilan: teks,
      tts: tts,
      saran: const ['Lokasi RS', 'Informasi Kontak', 'Kembali'],
    );
  }

  JawabanBot _jawabanDokter(DokterData d, String? hari, bool tanyaKeberadaan) {
    final List<Jadwal> saring = (hari != null)
        ? d.jadwal.where((j) => j.hari.toLowerCase() == hari.toLowerCase()).toList()
        : d.jadwal;

    final StringBuffer buffer = StringBuffer();
    if (tanyaKeberadaan) {
      buffer.writeln('Ya, ada! **${d.nama}** aktif bertugas di **${HospitalFakta.nama}** pada **${d.layanan}**.');
    } else {
      buffer.writeln('${_pilihBuka()}, berikut informasi jadwal **${d.nama}** (${d.layanan}):');
    }
    buffer.writeln();

    if (saring.isEmpty) {
      buffer.writeln('Pada hari **$hari**, beliau tidak memiliki jadwal praktik.');
      buffer.writeln('Berikut jadwal lengkap beliau pada hari lainnya:');
      for (int i = 0; i < d.jadwal.length; i++) {
        final j = d.jadwal[i];
        buffer.writeln('${i + 1}. **${j.hari}**: ${j.jamMulai}–${j.jamSelesai}');
      }
    } else {
      buffer.writeln('**Jadwal Praktik:**');
      for (int i = 0; i < saring.length; i++) {
        final j = saring[i];
        buffer.writeln('${i + 1}. **${j.hari}**: ${j.jamMulai}–${j.jamSelesai}');
      }
    }

    buffer.writeln();
    buffer.writeln('- **Lokasi Ruang Praktik:** ${d.lokasi}');
    buffer.writeln(
      '- **Pendaftaran & Kuota:** [${HospitalFakta.telpPendaftaran}](tel:${HospitalFakta.telpPendaftaran.replaceAll(' ', '')})',
    );
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        '${tanyaKeberadaan ? 'Ya, ada! ' : ''}${d.nama} di ${d.layanan}. '
        '${_formatJadwalDokterTts(d, saring)} Lokasi di ${d.lokasi}. Hubungi pendaftaran di ${HospitalFakta.telpPendaftaran}.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Lokasi RS', 'Informasi Kontak', 'Kembali'],
    );
  }

  String _formatJadwalDokterTts(DokterData d, List<Jadwal> daftar) {
    if (daftar.isEmpty) return 'Tidak ada jadwal pada hari yang diminta.';
    final List<String> parts = [];
    for (final j in daftar) {
      parts.add('${j.hari} jam ${j.jamMulai} sampai ${j.jamSelesai}');
    }
    return 'Jadwal praktiknya: ${parts.join(', ')}.';
  }

  JawabanBot _jawabanDokterTidakAda(String namaDokter) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Mohon maaf, **$namaDokter** saat ini belum terdaftar dalam jadwal dokter di **${HospitalFakta.nama}**.');
    buffer.writeln();
    buffer.writeln('Berikut adalah daftar dokter dan poliklinik yang saat ini aktif bertugas:');
    var i = 1;
    for (final d in HospitalFakta.daftarDokter) {
      buffer.writeln('$i. **${d.nama}** — ${d.layanan}');
      i++;
    }
    buffer.writeln();
    buffer.writeln(
      'Untuk informasi ketersediaan dokter tamu atau konsultasi spesialis pengganti, silakan hubungi Informasi & Pendaftaran di **${HospitalFakta.telpPendaftaran}**.',
    );

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Mohon maaf, $namaDokter saat ini belum terdaftar di Rumah Sakit Prima Insan Mulia. '
        'Silakan hubungi pendaftaran di ${HospitalFakta.telpPendaftaran} untuk informasi dokter spesialis yang tersedia.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'],
    );
  }

  JawabanBot _jawabanSimtom(String q, HasilDeteksi d) {
    final String poli = d.poli ?? 'Umum';
    final DokterData? dokter = DokterData.cariPoli(poli);
    final String namaPoli = dokter?.layanan ?? 'Poli Umum';
    final String namaDokter = dokter?.nama ?? 'Dokter Umum';

    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Saya memahami ${d.keluhanMedis ?? 'keluhan yang Anda rasakan'} tentu menimbulkan rasa tidak nyaman dan membutuhkan penanganan yang tepat.',
    );
    buffer.writeln();
    buffer.writeln('**Rekomendasi Poliklinik & Dokter:**');
    buffer.writeln(
      'Sebaiknya Anda berkonsultasi langsung ke **$namaPoli** dengan **$namaDokter**.',
    );
    buffer.writeln();

    if (dokter != null && dokter.jadwal.isNotEmpty) {
      buffer.writeln('**Jadwal Praktik di RS Prima Insan Mulia:**');
      for (final j in dokter.jadwal) {
        buffer.writeln('- **${j.hari}**: ${j.jamMulai}–${j.jamSelesai} (${dokter.lokasi})');
      }
      buffer.writeln();
    }

    // Saran pertolongan awal mandiri
    if (poli == 'Penyakit Dalam' || q.contains('mencet') || q.contains('mencret') || q.contains('perut')) {
      buffer.writeln('**Anjuran Awal Mandiri:**');
      buffer.writeln('- Cukupi asupan cairan dengan air putih atau larutan oralit agar tidak dehidrasi.');
      buffer.writeln('- Konsumsi makanan lunak/ringan dan hindari makanan pedas, asam, atau berminyak.');
      buffer.writeln();
    } else if (poli == 'Anak') {
      buffer.writeln('**Anjuran Awal Mandiri:**');
      buffer.writeln('- Berikan kompres hangat dan pastikan anak cukup minum cairan.');
      buffer.writeln('- Pantau suhu tubuh dan segera periksa jika demam menetap.');
      buffer.writeln();
    }

    // Tanda Bahaya Darurat
    buffer.writeln('⚠️ **Penting:** Jika keluhan memberat secara mendadak, timbul lemas ekstrem, sesak napas, pendarahan, atau nyeri hebat, segera bawa ke **IGD 24 Jam ${HospitalFakta.nama}** atau hubungi IGD di **${HospitalFakta.telpIgd}**.');
    buffer.writeln();
    buffer.writeln(
      'Untuk pendaftaran dan konfirmasi nomor antrean, silakan hubungi Informasi & Pendaftaran di **${HospitalFakta.telpPendaftaran}**.',
    );

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Untuk keluhan Anda, saya sarankan berkonsultasi ke $namaPoli dengan $namaDokter di Gedung Utama. '
        'Jika kondisi darurat, segera ke I G D 24 jam di nomor ${HospitalFakta.telpIgd}. Pendaftaran hubungi ${HospitalFakta.telpPendaftaran}.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: ['Jadwal $namaPoli', 'Lokasi RS', 'Informasi Kontak', 'Kembali'],
    );
  }

  JawabanBot _jawabanJadwal(HasilDeteksi d) {
    final String? hari = d.hari;
    final String? poli = d.poli;
    final DokterData? dokter = d.dokter ?? (poli == null ? null : DokterData.cariPoli(poli));

    // Jika user menanyakan jadwal dokter atau poli tertentu
    if (dokter != null) {
      final List<Jadwal> saring = (hari != null)
          ? dokter.jadwal.where((j) => j.hari.toLowerCase() == hari.toLowerCase()).toList()
          : dokter.jadwal;

      final StringBuffer buffer = StringBuffer();
      buffer.writeln('${_pilihBuka()}, berikut jadwal **${dokter.nama}** (${dokter.layanan}):');
      buffer.writeln();

      if (saring.isEmpty) {
        buffer.writeln('Tidak ada jadwal praktik pada hari **$hari**.');
        buffer.writeln('Jadwal pada hari lainnya:');
        for (final j in dokter.jadwal) {
          buffer.writeln('- **${j.hari}**: ${j.jamMulai}–${j.jamSelesai}');
        }
      } else {
        for (final j in saring) {
          buffer.writeln('- **${j.hari}**: ${j.jamMulai}–${j.jamSelesai}');
        }
      }

      buffer.writeln();
      buffer.writeln('- **Lokasi:** ${dokter.lokasi}');
      buffer.writeln('- **Pendaftaran:** ${HospitalFakta.telpPendaftaran}');
      buffer.writeln();
      buffer.writeln(_pilihTutup());

      final String tampilan = buffer.toString().trim();
      final String tts =
          'Jadwal ${dokter.nama} di ${dokter.layanan}. ${_formatJadwalDokterTts(dokter, saring)} '
          'Lokasi ${dokter.lokasi}. Hubungi pendaftaran di ${HospitalFakta.telpPendaftaran}.';

      return JawabanBot(
        tampilan: tampilan,
        tts: tts,
        saran: const ['Jadwal Poliklinik', 'Lokasi RS', 'Informasi Kontak', 'Kembali'],
      );
    }

    // Jika user menanyakan jadwal pada hari tertentu (misal: "jadwal dokter yang hari Senin apa aja")
    if (hari != null) {
      final List<Map<String, dynamic>> dokterHari = [];
      for (final doc in HospitalFakta.daftarDokter) {
        final match = doc.jadwal.where((j) => j.hari.toLowerCase() == hari.toLowerCase()).toList();
        if (match.isNotEmpty) {
          dokterHari.add({'dokter': doc, 'jadwal': match});
        }
      }

      final StringBuffer buffer = StringBuffer();
      buffer.writeln('${_pilihBuka()}, berikut jadwal dokter yang berpraktik pada hari **$hari**:');
      buffer.writeln();

      if (dokterHari.isEmpty) {
        buffer.writeln('Tidak ada jadwal praktik poliklinik reguler pada hari $hari (IGD tetap buka 24 jam).');
      } else {
        var no = 1;
        for (final item in dokterHari) {
          final doc = item['dokter'] as DokterData;
          final jList = item['jadwal'] as List<Jadwal>;
          final jamStr = jList.map((j) => '${j.jamMulai}–${j.jamSelesai}').join(', ');
          buffer.writeln('$no. **${doc.nama}** — ${doc.poli}');
          buffer.writeln('   Waktu: $jamStr (${doc.lokasi})');
          no++;
        }
      }

      buffer.writeln();
      buffer.writeln('Jadwal dapat berubah. Untuk pendaftaran dan konfirmasi kuota antrean, hubungi **${HospitalFakta.telpPendaftaran}**.');
      buffer.writeln();
      buffer.writeln(_pilihTutup());

      final String tampilan = buffer.toString().trim();
      final String tts =
          'Berikut jadwal dokter pada hari $hari di RS Prima Insan Mulia. '
          'Tersedia ${dokterHari.length} dokter yang berpraktik. Untuk pendaftaran hubungi ${HospitalFakta.telpPendaftaran}.';

      return JawabanBot(
        tampilan: tampilan,
        tts: tts,
        saran: const ['Jadwal Poliklinik', 'Lokasi RS', 'Informasi Kontak', 'Kembali'],
      );
    }

    // Default ke daftar dokter lengkap
    return _jawabanDaftarDokter(null);
  }

  JawabanBot _jawabanDaftarDokter(String? hari) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, berikut daftar dokter dan layanan poliklinik di **${HospitalFakta.nama}**:');
    buffer.writeln();

    var no = 1;
    for (final d in HospitalFakta.daftarDokter) {
      final List<Jadwal> saring = (hari != null)
          ? d.jadwal.where((j) => j.hari.toLowerCase() == hari.toLowerCase()).toList()
          : d.jadwal;
      final String jadwalStr = saring.isEmpty
          ? 'Tidak ada praktik hari $hari'
          : saring.map((j) => '${j.hari} ${j.jamMulai}–${j.jamSelesai}').join(', ');

      buffer.writeln('$no. **${d.nama}** — ${d.layanan}');
      buffer.writeln('   Jadwal: $jadwalStr');
      no++;
    }

    buffer.writeln();
    buffer.writeln('Seluruh poliklinik berlokasi di **Gedung Utama**.');
    buffer.writeln('Untuk pendaftaran dan konfirmasi kuota, silakan hubungi **${HospitalFakta.telpPendaftaran}**.');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Berikut daftar dokter di Rumah Sakit Prima Insan Mulia: '
        'dr. Akil Baehaqi spesialis anak, dr. Mintardi spesialis bedah, '
        'dr. Amy spesialis kandungan, dr. Idham Khalid spesialis penyakit dalam, '
        'Dokter Umum, dan Klinik VCT. Pendaftaran di ${HospitalFakta.telpPendaftaran}.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const [
        'Jadwal Poli Anak',
        'Jadwal Poli Bedah',
        'Jadwal Kandungan',
        'Jadwal Penyakit Dalam',
        'Poli Umum',
        'Poli VCT',
      ],
    );
  }

  JawabanBot _jawabanKontak() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, berikut kontak resmi **${HospitalFakta.nama}**:');
    buffer.writeln();
    buffer.writeln('1. **Informasi & Pendaftaran:** [${HospitalFakta.telpPendaftaran}](tel:${HospitalFakta.telpPendaftaran.replaceAll(' ', '')})');
    buffer.writeln('2. **IGD 24 Jam (Gawat Darurat):** [${HospitalFakta.telpIgd}](tel:${HospitalFakta.telpIgd.replaceAll(' ', '')})');
    buffer.writeln('3. **Humas / Human Capital:** [${HospitalFakta.telpHumas}](tel:${HospitalFakta.telpHumas.replaceAll(' ', '')})');
    buffer.writeln('4. **Call Center:** [${HospitalFakta.telpCallCenter}](tel:${HospitalFakta.telpCallCenter.replaceAll(' ', '')})');
    buffer.writeln('5. **Email:** [${HospitalFakta.email}](mailto:${HospitalFakta.email})');
    buffer.writeln();
    buffer.writeln('Layanan Informasi & IGD siaga melayani Anda **24 Jam**.');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Berikut kontak resmi RS Prima Insan Mulia. '
        'Informasi dan pendaftaran di ${HospitalFakta.telpPendaftaran}. '
        'I G D gawat darurat di ${HospitalFakta.telpIgd}. '
        'Call center di ${HospitalFakta.telpCallCenter}. '
        'Email di ${HospitalFakta.email}. Layanan siaga 24 jam.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Lokasi RS', 'Jadwal Poliklinik', 'Kembali'],
    );
  }

  JawabanBot _jawabanLokasi() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, berikut alamat dan lokasi **${HospitalFakta.nama}**:');
    buffer.writeln();
    buffer.writeln('📍 **Alamat Lengkap:**');
    buffer.writeln(HospitalFakta.alamat);
    buffer.writeln();
    buffer.writeln('🗺️ **Petunjuk Navigasi & Peta:**');
    buffer.writeln('[Buka di Google Maps](${HospitalFakta.urlMaps})');
    buffer.writeln();
    buffer.writeln(
      'Rumah sakit kami terletak di jalur utama Losari Brebes (Gedung Utama). '
      'Anda dapat langsung mengetuk tautan Google Maps di atas atau mencari **"${HospitalFakta.alamatMapsQuery}"** pada aplikasi navigasi Anda.',
    );
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'RS Prima Insan Mulia berlokasi di ${HospitalFakta.alamat}. '
        'Tautan peta Google Maps telah tersedia di layar chat untuk memudahkan navigasi Anda.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'],
    );
  }

  JawabanBot _jawabanPendaftaran() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, berikut alur dan cara pendaftaran di **${HospitalFakta.nama}**:');
    buffer.writeln();
    buffer.writeln('**1. Pendaftaran Online / Telepon:**');
    buffer.writeln(
      '- Hubungi nomor pendaftaran di [${HospitalFakta.telpPendaftaran}](tel:${HospitalFakta.telpPendaftaran.replaceAll(' ', '')}) '
      'untuk konfirmasi kuota dan pendaftaran antrean sebelum datang.',
    );
    buffer.writeln();
    buffer.writeln('**2. Pendaftaran Langsung:**');
    buffer.writeln('- Silakan datang ke **Loket Pendaftaran di Gedung Utama**.');
    buffer.writeln('- Disarankan hadir 30 menit sebelum jam praktik dokter dimulai.');
    buffer.writeln();
    buffer.writeln('**Dokumen yang Perlu Dibawa:**');
    buffer.writeln('- Kartu Identitas (KTP/KIA)');
    buffer.writeln('- Kartu BPJS Kesehatan / KIS / Asuransi rekanan (bila ada)');
    buffer.writeln('- Surat rujukan faskes tingkat 1 yang masih aktif (khusus rujukan BPJS)');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Untuk pendaftaran di RS Prima Insan Mulia, Anda bisa menghubungi nomor pendaftaran '
        'di ${HospitalFakta.telpPendaftaran} atau datang langsung ke Gedung Utama dengan membawa KTP dan kartu BPJS atau asuransi.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'],
    );
  }

  JawabanBot _jawabanBiaya() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, mengenai informasi biaya, BPJS, dan asuransi:');
    buffer.writeln();
    buffer.writeln('**RS Prima Insan Mulia melayani:**');
    buffer.writeln('- Pasien **BPJS Kesehatan / KIS**');
    buffer.writeln('- Pasien **Asuransi Rekanan Swasta**');
    buffer.writeln('- Pasien **Umum (Mandiri)**');
    buffer.writeln();
    buffer.writeln('**Catatan Tarif & Rujukan:**');
    buffer.writeln(
      'Biaya tindakan medis, tarif konsultasi spesialis, serta rawat inap disesuaikan dengan jenis penanganan dan kelas perawatan. '
      'Untuk pasien BPJS, pastikan rujukan faskes tingkat 1 (Puskesmas/Klinik) masih aktif.',
    );
    buffer.writeln();
    buffer.writeln('Untuk rincian estimasi biaya tindakan atau konfirmasi kuota BPJS hari ini, silakan hubungi:');
    buffer.writeln('- **Informasi & Pendaftaran:** [${HospitalFakta.telpPendaftaran}](tel:${HospitalFakta.telpPendaftaran.replaceAll(' ', '')})');
    buffer.writeln('- **Call Center:** [${HospitalFakta.telpCallCenter}](tel:${HospitalFakta.telpCallCenter.replaceAll(' ', '')})');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'RS Prima Insan Mulia melayani pasien BPJS Kesehatan, asuransi rekanan, dan pasien umum. '
        'Untuk rincian tarif tindakan dan kuota BPJS, silakan hubungi pendaftaran di ${HospitalFakta.telpPendaftaran} atau call center di ${HospitalFakta.telpCallCenter}.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Informasi Kontak', 'Jadwal Poliklinik', 'Kembali'],
    );
  }

  JawabanBot _jawabanVct() {
    final DokterData? vct = DokterData.cariPoli('VCT');
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Layanan **Klinik VCT (Voluntary Counseling and Testing)** tersedia di **${HospitalFakta.nama}**.');
    buffer.writeln();
    buffer.writeln('Klinik ini melayani konseling sukarela dan pemeriksaan HIV/AIDS secara rahasia, nyaman, dan profesional.');
    buffer.writeln();
    buffer.writeln('**Jadwal Layanan VCT:**');
    buffer.writeln('- **Selasa:** 08:00–15:00');
    buffer.writeln('- **Kamis:** 08:00–15:00');
    buffer.writeln('- **Lokasi:** ${vct?.lokasi ?? 'Gedung Utama'}');
    buffer.writeln();
    buffer.writeln('Untuk informasi jadwal dan konsultasi privasi, hubungi Pendaftaran di **${HospitalFakta.telpPendaftaran}**.');

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Layanan Klinik VCT tersedia di RS Prima Insan Mulia setiap hari Selasa dan Kamis jam 08:00 sampai 15:00 di Gedung Utama. '
        'Layanan bersifat rahasia dan aman. Hubungi pendaftaran di ${HospitalFakta.telpPendaftaran}.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'],
    );
  }

  JawabanBot _jawabanLayanan() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, berikut layanan medis dan poliklinik di **${HospitalFakta.nama}**:');
    buffer.writeln();
    buffer.writeln('1. **Poliklinik Anak** — Pemeriksaan kesehatan anak, balita, dan tumbuh kembang');
    buffer.writeln('2. **Poliklinik Bedah** — Konsultasi dan tindakan bedah umum');
    buffer.writeln('3. **Poliklinik Kandungan (Obsgyn)** — USG, kesehatan ibu hamil, persalinan, dan reproduksi');
    buffer.writeln('4. **Poliklinik Penyakit Dalam** — Spesialis internis, diabetes, hipertensi, pencernaan, ginjal');
    buffer.writeln('5. **Poli Umum** — Pemeriksaan umum awal, pengobatan keluhan harian, surat dokter');
    buffer.writeln('6. **Klinik VCT** — Konseling dan tes HIV/AIDS');
    buffer.writeln('7. **IGD 24 Jam** — Siaga gawat darurat dan ambulans');
    buffer.writeln();
    buffer.writeln('Seluruh fasilitas berada di **Gedung Utama**. Layanan poliklinik apa yang ingin Anda ketahui jadwalnya?');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'RS Prima Insan Mulia menyediakan layanan Poliklinik Anak, Bedah, Kandungan, Penyakit Dalam, Poli Umum, VCT, dan IGD 24 jam. '
        'Semua berlokasi di Gedung Utama. Ingin mengetahui jadwal poliklinik yang mana?';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const [
        'Jadwal Poli Anak',
        'Jadwal Poli Bedah',
        'Jadwal Kandungan',
        'Jadwal Penyakit Dalam',
        'Poli Umum',
        'Poli VCT',
      ],
    );
  }

  JawabanBot _jawabanJamOperasional() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, berikut jam operasional layanan di **${HospitalFakta.nama}**:');
    buffer.writeln();
    buffer.writeln('- 🚨 **IGD:** 24 Jam Nonstop setiap hari');
    buffer.writeln('- 👶 **Poliklinik Anak:** Senin–Jumat, 10:30–12:30');
    buffer.writeln('- 🩺 **Poliklinik Bedah:** Senin & Rabu 07:00–08:30; Selasa, Kamis & Sabtu 14:00–16:00');
    buffer.writeln('- 🤰 **Poliklinik Kandungan:** Kamis & Sabtu, 13:00–15:00');
    buffer.writeln('- 💊 **Poliklinik Penyakit Dalam:** Senin & Rabu 09:00–12:00; Jumat 09:00–11:30');
    buffer.writeln('- 🏥 **Poli Umum:** Senin–Sabtu, 09:00–14:00');
    buffer.writeln('- 🔬 **Klinik VCT:** Selasa & Kamis, 08:00–15:00');
    buffer.writeln();
    buffer.writeln('Jadwal dapat mengalami penyesuaian kuota. Konfirmasi pendaftaran di **${HospitalFakta.telpPendaftaran}**.');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Jam operasional RS Prima Insan Mulia: IGD buka 24 jam setiap hari. '
        'Poliklinik beroperasi sesuai jadwal dokter masing-masing di Gedung Utama. Hubungi pendaftaran di ${HospitalFakta.telpPendaftaran}.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Lokasi RS', 'Kembali'],
    );
  }

  JawabanBot _jawabanUmumHospital(String q) {
    final String? poli = _cariPoli(q.toLowerCase());
    if (poli != null) {
      return _jawabanJadwal(
        HasilDeteksi(
          intent: IntentAi.jadwal,
          dokter: DokterData.cariPoli(poli),
          poli: poli,
        ),
      );
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${_pilihBuka()}, **${HospitalFakta.nama}** siap melayani kebutuhan kesehatan Anda dan keluarga.');
    buffer.writeln();
    buffer.writeln('Kami menyediakan ${HospitalFakta.layananUmum}, serta layanan **IGD 24 Jam** di Gedung Utama.');
    buffer.writeln();
    buffer.writeln('Silakan tanyakan hal spesifik yang ingin Anda ketahui:');
    buffer.writeln('- Jadwal dokter atau poliklinik tertentu');
    buffer.writeln('- Alamat dan link Google Maps');
    buffer.writeln('- Nomor telepon dan pendaftaran BPJS / Umum');
    buffer.writeln('- Rekomendasi poli untuk keluhan kesehatan Anda');
    buffer.writeln();
    buffer.writeln(_pilihTutup());

    final String tampilan = buffer.toString().trim();
    final String tts =
        'Rumah Sakit Prima Insan Mulia melayani ${HospitalFakta.layananUmum} dan IGD 24 jam. '
        'Silakan tanyakan jadwal dokter, lokasi, kontak pendaftaran, atau rekomendasi dokter untuk keluhan Anda.';

    return JawabanBot(
      tampilan: tampilan,
      tts: tts,
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
    );
  }

  JawabanBot _jawabanDiLuarKonteks(String q) {
    final String maaf = _pilih(const [
      'Mohon maaf, pertanyaan tersebut berada di luar lingkup informasi saya di RS Prima Insan Mulia.',
      'Maaf ya, saya adalah asisten informasi khusus Rumah Sakit Prima Insan Mulia.',
      'Mohon maaf, saya belum bisa membantu untuk topik di luar informasi RS Prima Insan Mulia dan kesehatan.',
    ]);
    final String alihkan = _pilih(const [
      'Sebagai asisten Prima Bot, fokus saya adalah membantu Anda mendapatkan informasi jadwal dokter, layanan poliklinik, lokasi, pendaftaran, dan kontak RS Prima Insan Mulia.',
      'Saya dirancang khusus untuk RS Prima Insan Mulia guna menjawab seputar fasilitas rumah sakit, jadwal praktik dokter, nomor telepon resmi, dan rekomendasi poli untuk keluhan medis.',
      'Silakan tanyakan mengenai jadwal praktik spesialis di RS Prima Insan Mulia, alur pendaftaran BPJS, lokasi RS di Losari Brebes, atau nomor IGD 24 jam ya!',
    ]);
    final String teks = '$maaf\n\n$alihkan\n\nAda informasi seputar RS Prima Insan Mulia yang bisa saya bantu?';
    return JawabanBot(
      tampilan: teks,
      tts: '$maaf $alihkan',
      saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
    );
  }
}

class SimtomResult {
  final String poli;
  final String keluhan;

  const SimtomResult({required this.poli, required this.keluhan});
}
