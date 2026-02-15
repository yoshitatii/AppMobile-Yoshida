class Barang {
  final int? id;
  final String kode;
  final String nama;
  final double hargaBeli;
  final double hargaJual;
  final int stok;
  final String satuan;
  final String kategori;
  final DateTime updatedAt;
  final int isiPack; 
  final int isiBox; 

  Barang({
    this.id,
    required this.kode,
    required this.nama,
    required this.hargaBeli,
    required this.hargaJual,
    required this.stok,
    this.satuan = 'pcs',
    this.kategori = 'Umum',
    this.isiPack = 1,
    this.isiBox = 1,
    DateTime? updatedAt, // Hapus 'this.' di sini karena kita pakai initializer di bawah
  }) : updatedAt = updatedAt ?? DateTime.now(); // Ini adalah initializer list yang benar

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kode': kode,
      'nama': nama,
      'hargaBeli': hargaBeli,
      'hargaJual': hargaJual,
      'stok': stok,
      'satuan': satuan,
      'kategori': kategori,
      'isiPack': isiPack,
      'isiBox': isiBox,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Barang.fromMap(Map<String, dynamic> map) {
    return Barang(
      id: map['id'] as int?,
      kode: map['kode']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      hargaBeli: (map['hargaBeli'] as num?)?.toDouble() ?? 0.0,
      hargaJual: (map['hargaJual'] as num?)?.toDouble() ?? 0.0,
      stok: (map['stok'] as int?) ?? 0,
      satuan: map['satuan']?.toString() ?? 'pcs',
      kategori: map['kategori']?.toString() ?? 'Umum',
      isiPack: map['isiPack'] as int? ?? 1,
      isiBox: map['isiBox'] as int? ?? 1,
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
    );
  }

  Barang copyWith({
    int? id,
    String? kode,
    String? nama,
    double? hargaBeli,
    double? hargaJual,
    int? stok,
    String? satuan,
    String? kategori,
    int? isiPack,
    int? isiBox,
    DateTime? updatedAt,
  }) {
    return Barang(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
      stok: stok ?? this.stok,
      satuan: satuan ?? this.satuan,
      kategori: kategori ?? this.kategori,
      isiPack: isiPack ?? this.isiPack,
      isiBox: isiBox ?? this.isiBox,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}