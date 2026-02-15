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
      version: 3, // NAIK KE VERSI 3
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrasi dari versi 1 ke 2 (Tambah kolom kode)
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE barang ADD COLUMN kode TEXT NOT NULL DEFAULT ""');
      } catch (e) {
        print("Kolom kode mungkin sudah ada: $e");
      }
    }
    
    // Migrasi dari versi 2 ke 3 (Tambah kolom isiPack dan isiBox)
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE barang ADD COLUMN isiPack INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE barang ADD COLUMN isiBox INTEGER DEFAULT 1');
        print("Database upgraded to version 3: added isiPack & isiBox");
      } catch (e) {
        print("Error upgrade ke v3: $e");
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Barang (Lengkap dengan kolom konversi)
    await db.execute('''
      CREATE TABLE barang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode TEXT NOT NULL,
        nama TEXT NOT NULL,
        kategori TEXT,
        hargaBeli REAL,
        hargaJual REAL,
        stok INTEGER,
        satuan TEXT,
        isiPack INTEGER DEFAULT 1,
        isiBox INTEGER DEFAULT 1,
        updatedAt TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_barang_kode ON barang (kode)');
    await db.execute('CREATE INDEX idx_barang_nama ON barang (nama)');

    // Tabel Transaksi
    await db.execute('''
      CREATE TABLE transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_transaksi TEXT NOT NULL,
        tanggal TEXT,
        total_harga REAL,
        bayar REAL,
        kembalian REAL,
        catatan TEXT
      )
    ''');
    
    await db.execute('CREATE INDEX idx_transaksi_tanggal ON transaksi (tanggal)');

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
        satuan_jual TEXT -- Tambahan: simpan apakah jual pcs/pack/box
      )
    ''');
  }

  // --- CRUD METHODS (Tetap sama) ---
  
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, List<dynamic> args) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }
}