class Transaksi {
  final int? id;
  final String nomorTransaksi;
  final DateTime tanggal;
  final double totalHarga;
  final double bayar;
  final double kembalian;
  final String? catatan;

  Transaksi({
    this.id,
    required this.nomorTransaksi,
    required this.tanggal,
    required this.totalHarga,
    required this.bayar,
    required this.kembalian,
    this.catatan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomor_transaksi': nomorTransaksi,
      'tanggal': tanggal.toIso8601String(),
      'total_harga': totalHarga,
      'bayar': bayar,
      'kembalian': kembalian,
      'catatan': catatan,
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      id: map['id'] as int?,
      nomorTransaksi: map['nomor_transaksi'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      totalHarga: (map['total_harga'] as num).toDouble(),
      bayar: (map['bayar'] as num).toDouble(),
      kembalian: (map['kembalian'] as num).toDouble(),
      catatan: map['catatan'] as String?,
    );
  }
}