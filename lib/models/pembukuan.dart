class Pembukuan {
  final int? id;
  final String jenis; // Isinya: 'Pemasukan' atau 'Pengeluaran'
  final DateTime tanggal;
  final double nominal;
  final String kategori;
  final String keterangan;
  final bool isAuto;
  final String? source;

  Pembukuan({
    this.id, 
    required this.jenis, 
    required this.tanggal, 
    required this.nominal, 
    required this.kategori, 
    required this.keterangan,
    this.isAuto = false,
    this.source = 'manual',
  });

  // ===========================================================
  // LOGIKA BRUTO & NETO
  // ===========================================================
  
  // Bruto: Total uang masuk kotor (hanya dihitung jika jenisnya Pemasukan)
  double get bruto => jenis.toLowerCase() == 'pemasukan' ? nominal : 0;

  // Neto: Nilai bersih (Plus jika pemasukan, Minus jika pengeluaran)
  double get neto => jenis.toLowerCase() == 'pemasukan' ? nominal : -nominal;
  
  // ===========================================================

  // Mengubah objek ke Map (untuk simpan ke Database/SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenis': jenis,
      'tanggal': tanggal.toIso8601String(),
      'nominal': nominal,
      'kategori': kategori,
      'keterangan': keterangan,
      'isAuto': isAuto ? 1 : 0, // SQLite simpan boolean sebagai integer
      'source': source,
    };
  }

  // Mengubah Map dari Database kembali ke objek Pembukuan
  factory Pembukuan.fromMap(Map<String, dynamic> map) {
    return Pembukuan(
      id: map['id'],
      jenis: map['jenis'] ?? '',
      tanggal: DateTime.parse(map['tanggal']),
      nominal: (map['nominal'] as num).toDouble(),
      kategori: map['kategori'] ?? '',
      keterangan: map['keterangan'] ?? '',
      isAuto: map['isAuto'] == 1 || map['isAuto'] == true,
      source: map['source'] ?? 'manual',
    );
  }
}