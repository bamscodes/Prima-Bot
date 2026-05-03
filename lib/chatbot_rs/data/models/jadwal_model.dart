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
    return {
      'id': id,
      'nama_dokter': namaDokter,
      'spesialisasi': spesialisasi,
      'hari': hari,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'id_layanan': idLayanan,
    };
  }

  factory JadwalModel.fromMap(Map<String, dynamic> map) {
    return JadwalModel(
      id: map['id'],
      namaDokter: map['nama_dokter'],
      spesialisasi: map['spesialisasi'],
      hari: map['hari'],
      jamMulai: map['jam_mulai'],
      jamSelesai: map['jam_selesai'],
      idLayanan: map['id_layanan'],
    );
  }
}
