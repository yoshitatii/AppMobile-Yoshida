import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pos_umkm.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Barang
    await db.execute('''
      CREATE TABLE barang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode TEXT NOT NULL UNIQUE,
        nama TEXT NOT NULL,
        harga_beli REAL NOT NULL,
        harga_jual REAL NOT NULL,
        stok INTEGER NOT NULL,
        satuan TEXT,
        kategori TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabel Transaksi
    await db.execute('''
      CREATE TABLE transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_transaksi TEXT NOT NULL UNIQUE,
        tanggal TEXT NOT NULL,
        total_harga REAL NOT NULL,
        bayar REAL NOT NULL,
        kembalian REAL NOT NULL,
        catatan TEXT
      )
    ''');

    // Tabel Item Transaksi
    await db.execute('''
      CREATE TABLE item_transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaksi_id INTEGER NOT NULL,
        barang_id INTEGER NOT NULL,
        nama_barang TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        harga REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaksi_id) REFERENCES transaksi (id) ON DELETE CASCADE,
        FOREIGN KEY (barang_id) REFERENCES barang (id)
      )
    ''');

    // Tabel Pembukuan
    await db.execute('''
      CREATE TABLE pembukuan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jenis TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        nominal REAL NOT NULL,
        kategori TEXT NOT NULL,
        keterangan TEXT NOT NULL
      )
    ''');

    // Index untuk optimalisasi query
    await db.execute('CREATE INDEX idx_barang_kode ON barang(kode)');
    await db.execute('CREATE INDEX idx_transaksi_tanggal ON transaksi(tanggal)');
    await db.execute('CREATE INDEX idx_pembukuan_tanggal ON pembukuan(tanggal)');
  }

  // ===========================================================
  // FUNGSI TRANSAKSI SAKTI (SIMPAN + POTONG STOK + PEMBUKUAN)
  // ===========================================================
  
  Future<void> simpanTransaksiLengkap(Map<String, dynamic> transaksiData, List<Map<String, dynamic>> items) async {
    final db = await database;

    // Menggunakan transaction agar data konsisten beb
    await db.transaction((txn) async {
      // 1. Simpan Header Transaksi ke tabel 'transaksi'
      int transaksiId = await txn.insert('transaksi', transaksiData);

      // 2. Loop setiap barang yang dibeli
      for (var item in items) {
        // Masukkan ID transaksi yang baru dibuat ke data item
        Map<String, dynamic> itemData = Map.from(item);
        itemData['transaksi_id'] = transaksiId;
        
        // Simpan ke tabel 'item_transaksi'
        await txn.insert('item_transaksi', itemData);

        // 3. LOGIKA POTONG STOK OTOMATIS
        await txn.execute('''
          UPDATE barang 
          SET stok = stok - ?, updated_at = ? 
          WHERE id = ?
        ''', [item['jumlah'], DateTime.now().toIso8601String(), item['barang_id']]);
      }

      // 4. OTOMATIS CATAT KE PEMBUKUAN SEBAGAI UANG MASUK
      await txn.insert('pembukuan', {
        'jenis': 'MASUK',
        'tanggal': transaksiData['tanggal'],
        'nominal': transaksiData['total_harga'],
        'kategori': 'Penjualan',
        'keterangan': 'Penjualan No. ${transaksiData['nomor_transaksi']}'
      });
    });
  }

  // ===========================================================
  // METODE GENERIC UNTUK QUERY LAINNYA
  // ===========================================================

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<int> update(String table, Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}