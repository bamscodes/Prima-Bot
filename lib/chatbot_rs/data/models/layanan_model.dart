class LayananModel {
  final int? id;
  final String namaLayanan;
  final String deskripsi;
  final String lokasiGedung;

  LayananModel({
    this.id,
    required this.namaLayanan,
    required this.deskripsi,
    required this.lokasiGedung,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_layanan': namaLayanan,
      'deskripsi': deskripsi,
      'lokasi_gedung': lokasiGedung,
    };
  }

  factory LayananModel.fromMap(Map<String, dynamic> map) {
    return LayananModel(
      id: map['id'],
      namaLayanan: map['nama_layanan'],
      deskripsi: map['deskripsi'],
      lokasiGedung: map['lokasi_gedung'],
    );
  }
}
