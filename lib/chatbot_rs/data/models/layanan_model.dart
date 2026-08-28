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
    final m = <String, dynamic>{
      'nama_layanan': namaLayanan,
      'deskripsi': deskripsi,
      'lokasi_gedung': lokasiGedung,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory LayananModel.fromMap(Map<String, dynamic> map) {
    final rawNama = map['nama_layanan'];
    final rawDesk = map['deskripsi'];
    final rawLokasi = map['lokasi_gedung'];
    if (rawNama == null || rawDesk == null || rawLokasi == null) {
      throw FormatException('LayananModel missing required fields: $map');
    }
    return LayananModel(
      id: map['id'] as int?,
      namaLayanan: rawNama as String,
      deskripsi: rawDesk as String,
      lokasiGedung: rawLokasi as String,
    );
  }
}
