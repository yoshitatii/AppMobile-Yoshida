class ItemTransaksi {
  final int? id;
  final int transaksiId;
  final int barangId;
  final String namaBarang;
  final int jumlah;
  final double harga;
  final double subtotal;

  ItemTransaksi({
    this.id,
    required this.transaksiId,
    required this.barangId,
    required this.namaBarang,
    required this.jumlah,
    required this.harga,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaksi_id': transaksiId,
      'barang_id': barangId,
      'nama_barang': namaBarang,
      'jumlah': jumlah,
      'harga': harga,
      'subtotal': subtotal,
    };
  }

  factory ItemTransaksi.fromMap(Map<String, dynamic> map) {
    return ItemTransaksi(
      id: map['id'] as int?,
      transaksiId: map['transaksi_id'] as int,
      barangId: map['barang_id'] as int,
      namaBarang: map['nama_barang'] as String,
      jumlah: map['jumlah'] as int,
      harga: (map['harga'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}