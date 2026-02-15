class Pembukuan {
  final int? id;
  final String jenis;
  final DateTime tanggal;
  final double nominal;
  final String kategori;
  final String keterangan;
  final bool isAuto; // Penanda apakah otomatis
  final String? source; // Sumber: 'sms', 'template', 'manual'

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenis': jenis,
      'tanggal': tanggal.toIso8601String(),
      'nominal': nominal,
      'kategori': kategori,
      'keterangan': keterangan,
      'isAuto': isAuto,
      'source': source,
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
      isAuto: map['isAuto'] ?? false,
      source: map['source'] ?? 'manual',
    );
  }
}

// Model untuk template transaksi berulang
class TransaksiTemplate {
  final int? id;
  final String nama;
  final String jenis;
  final double nominal;
  final String kategori;
  final String keterangan;
  final int tanggalBerulang; // Tanggal dalam bulan (1-31)
  final bool isActive;

  TransaksiTemplate({
    this.id,
    required this.nama,
    required this.jenis,
    required this.nominal,
    required this.kategori,
    required this.keterangan,
    required this.tanggalBerulang,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'jenis': jenis,
      'nominal': nominal,
      'kategori': kategori,
      'keterangan': keterangan,
      'tanggalBerulang': tanggalBerulang,
      'isActive': isActive,
    };
  }

  factory TransaksiTemplate.fromMap(Map<String, dynamic> map) {
    return TransaksiTemplate(
      id: map['id'],
      nama: map['nama'] ?? '',
      jenis: map['jenis'] ?? '',
      nominal: (map['nominal'] as num).toDouble(),
      kategori: map['kategori'] ?? '',
      keterangan: map['keterangan'] ?? '',
      tanggalBerulang: map['tanggalBerulang'] ?? 1,
      isActive: map['isActive'] ?? true,
    );
  }
}