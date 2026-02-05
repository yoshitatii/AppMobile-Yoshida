class Transaksi {
  final int? id;
  final String nomorTransaksi;
  final DateTime tanggal;
  final double totalHarga;
  final double bayar;
  final double kembalian;
  final String? catatan;
  final List<TransaksiDetail> details; // Ini yang bikin error kalau tidak diisi

  Transaksi({
    this.id,
    required this.nomorTransaksi,
    required this.tanggal,
    required this.totalHarga,
    required this.bayar,
    required this.kembalian,
    this.catatan,
    this.details = const [], // Kita kasih default list kosong biar gak error lagi beb
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

  // INI FUNGSI YANG HILANG TADI BEB (fromMap)
  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      id: map['id'] as int?,
      nomorTransaksi: map['nomor_transaksi'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      totalHarga: (map['total_harga'] as num).toDouble(),
      bayar: (map['bayar'] as num).toDouble(),
      kembalian: (map['kembalian'] as num).toDouble(),
      catatan: map['catatan'] as String?,
      details: [], // Saat ambil list utama, kita kosongkan dulu detailnya
    );
  }
}

class TransaksiDetail {
  final int? id;
  final int? transaksiId;
  final int barangId;
  final String namaBarang;
  final int jumlah;
  final double harga;
  final double subtotal;

  TransaksiDetail({
    this.id,
    this.transaksiId,
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
}