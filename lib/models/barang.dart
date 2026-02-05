class Barang {
  final int? id;
  final String kode;
  final String nama;
  final double hargaBeli;
  final double hargaJual;
  final int stok;
  final String satuan;
  final String kategori; // Aku ubah jadi non-nullable ya beb biar konsisten
  final DateTime createdAt;
  final DateTime updatedAt;

  Barang({
    this.id,
    required this.kode,
    required this.nama,
    required this.hargaBeli,
    required this.hargaJual,
    required this.stok,
    this.satuan = 'pcs',
    this.kategori = 'Sembako', // Kasih default 'Sembako' biar gak error
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kode': kode,
      'nama': nama,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok': stok,
      'satuan': satuan,
      'kategori': kategori, // Sekarang tersimpan rapi di DB
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Barang.fromMap(Map<String, dynamic> map) {
    return Barang(
      id: map['id'] as int?,
      kode: map['kode'] as String,
      nama: map['nama'] as String,
      hargaBeli: (map['harga_beli'] as num).toDouble(),
      hargaJual: (map['harga_jual'] as num).toDouble(),
      stok: map['stok'] as int,
      satuan: map['satuan'] ?? 'pcs',
      // Jika di DB kosong, otomatis jadi 'Sembako'
      kategori: map['kategori'] as String? ?? 'Sembako', 
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  // Jangan lupa copyWith juga diupdate kategorinya beb
  Barang copyWith({
    int? id,
    String? kode,
    String? nama,
    double? hargaBeli,
    double? hargaJual,
    int? stok,
    String? satuan,
    String? kategori,
    DateTime? createdAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}