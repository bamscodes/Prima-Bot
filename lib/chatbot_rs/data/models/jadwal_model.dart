class JadwalModel {
  final int? id;
  final String namaDokter;
  final String spesialisasi;
  final String hari;
  final String jamMulai;
  final String jamSelesai;
  final int idLayanan;

  JadwalModel({
    this.id,
    required this.namaDokter,
    required this.spesialisasi,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.idLayanan,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'nama_dokter': namaDokter,
      'spesialisasi': spesialisasi,
      'hari': hari,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'id_layanan': idLayanan,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory JadwalModel.fromMap(Map<String, dynamic> map) {
    final rawNama = map['nama_dokter'];
    final rawSpes = map['spesialisasi'];
    final rawHari = map['hari'];
    final rawMulai = map['jam_mulai'];
    final rawSelesai = map['jam_selesai'];
    final rawIdLayanan = map['id_layanan'];
    if (rawNama == null || rawSpes == null || rawHari == null || rawMulai == null || rawSelesai == null || rawIdLayanan == null) {
      throw FormatException('JadwalModel missing required fields: $map');
    }
    int parsedIdLayanan;
    if (rawIdLayanan is int) {
      parsedIdLayanan = rawIdLayanan;
    } else if (rawIdLayanan is num) {
      parsedIdLayanan = rawIdLayanan.toInt();
    } else {
      parsedIdLayanan = int.parse('$rawIdLayanan');
    }
    return JadwalModel(
      id: map['id'] as int?,
      namaDokter: rawNama as String,
      spesialisasi: rawSpes as String,
      hari: rawHari as String,
      jamMulai: rawMulai as String,
      jamSelesai: rawSelesai as String,
      idLayanan: parsedIdLayanan,
    );
  }
}
