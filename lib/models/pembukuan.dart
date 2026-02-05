class Pembukuan {
  final int? id;
  final String jenis;
  final DateTime tanggal; // Jika ini String di DB, pastikan konsisten
  final double nominal;
  final String kategori;
  final String keterangan;

  Pembukuan({
    this.id, 
    required this.jenis, 
    required this.tanggal, 
    required this.nominal, 
    required this.kategori, 
    required this.keterangan,
    });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenis': jenis,
      'tanggal': tanggal.toIso8601String(),
      'nominal': nominal,
      'kategori': kategori,
      'keterangan': keterangan,
    };
  }

  factory Pembukuan.fromMap(Map<String, dynamic> map) {
    return Pembukuan(
      id: map['id'],
      jenis: map['jenis'] ?? '',
      tanggal: DateTime.parse(map['tanggal']),
      nominal: (map['nominal'] as num).toDouble(),
      kategori: map['kategori'] ?? '',
      keterangan: map['keterangan'] ?? '',
    );
  }
}