import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/pembukuan.dart';

class PembukuanProvider with ChangeNotifier {
  List<Pembukuan> _pembukuanList = [];
  List<TransaksiTemplate> _templateList = [];
  bool _isLoading = false;
  bool _autoDetectEnabled = true;

  List<Pembukuan> get pembukuanList => _pembukuanList;
  List<TransaksiTemplate> get templateList => _templateList;
  bool get isLoading => _isLoading;
  bool get autoDetectEnabled => _autoDetectEnabled;

  // ===== FUNGSI DASAR & RINGKASAN =====
  
  double get totalPemasukan => _pembukuanList
      .where((item) => item.jenis == 'pemasukan')
      .fold(0.0, (sum, item) => sum + item.nominal);

  double get totalPengeluaran => _pembukuanList
      .where((item) => item.jenis == 'pengeluaran')
      .fold(0.0, (sum, item) => sum + item.nominal);

  Future<Map<String, double>> getTodaySummary() async {
    final today = DateTime.now();
    double pemasukan = 0;
    double pengeluaran = 0;

    for (var item in _pembukuanList) {
      if (item.tanggal.year == today.year &&
          item.tanggal.month == today.month &&
          item.tanggal.day == today.day) {
        if (item.jenis == 'pemasukan') {
          pemasukan += item.nominal;
        } else {
          pengeluaran += item.nominal;
        }
      }
    }
    return {'pemasukan': pemasukan, 'pengeluaran': pengeluaran};
  }

  // ===== LOAD & SAVE DATA =====

  Future<void> loadPembukuan() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    
    // Load pembukuan
    final String? dataString = prefs.getString('pembukuan_data');
    if (dataString != null) {
      final List<dynamic> decodedData = json.decode(dataString);
      _pembukuanList = decodedData.map((item) => Pembukuan.fromMap(item)).toList();
    }

    // Load templates
    final String? templateString = prefs.getString('template_data');
    if (templateString != null) {
      final List<dynamic> decodedData = json.decode(templateString);
      _templateList = decodedData.map((item) => TransaksiTemplate.fromMap(item)).toList();
    }

    // Load settings
    _autoDetectEnabled = prefs.getBool('auto_detect_enabled') ?? true;

    // Jalankan auto-process untuk template berulang
    await _processRecurringTemplates();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(_pembukuanList.map((item) => item.toMap()).toList());
    await prefs.setString('pembukuan_data', encodedData);
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(_templateList.map((item) => item.toMap()).toList());
    await prefs.setString('template_data', encodedData);
  }

  // ===== MANAJEMEN DATA (CRUD) =====

  Future<void> addPembukuan(Pembukuan data) async {
    final newEntry = Pembukuan(
      id: data.id ?? DateTime.now().millisecondsSinceEpoch,
      jenis: data.jenis,
      nominal: data.nominal,
      kategori: data.kategori,
      keterangan: data.keterangan,
      tanggal: data.tanggal,
      isAuto: data.isAuto,
      source: data.source,
    );
    _pembukuanList.insert(0, newEntry);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> updatePembukuan(Pembukuan data) async {
    final index = _pembukuanList.indexWhere((element) => element.id == data.id);
    if (index != -1) {
      _pembukuanList[index] = data;
      await _saveToPrefs();
      notifyListeners();
    }
  }

  Future<void> deletePembukuan(int id) async { 
    _pembukuanList.removeWhere((element) => element.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  // FUNGSI PENTING UNTUK SINKRONISASI DENGAN RIWAYAT
  Future<void> deletePembukuanByKeterangan(String keterangan) async {
    _pembukuanList.removeWhere((element) => element.keterangan == keterangan);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<List<Pembukuan>> getLaporanPeriode(DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return _pembukuanList.where((item) {
      return item.tanggal.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
             item.tanggal.isBefore(endDay.add(const Duration(seconds: 1)));
    }).toList();
  }

  // ===== FITUR AUTO DETECTION (SMS/CLIPBOARD) =====
  
  Map<String, dynamic>? parseTransactionText(String text) {
    text = text.toLowerCase();
    final patterns = [
      RegExp(r'(?:debet|kredit|transfer|terima|bayar).*?rp\s?([\d.,]+)', caseSensitive: false),
      RegExp(r'(?:mutasi|saldo|transaksi).*?rp\s?([\d.,]+)', caseSensitive: false),
      RegExp(r'(?:bayar|terima|transfer).*?rp\s?([\d.,]+)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final nominalStr = match.group(1)?.replaceAll(RegExp(r'[.,]'), '') ?? '0';
        final nominal = double.tryParse(nominalStr) ?? 0;
        
        if (nominal > 0) {
          String jenis = 'pengeluaran';
          if (text.contains('terima') || text.contains('kredit') || text.contains('masuk')) {
            jenis = 'pemasukan';
          }
          return {
            'nominal': nominal,
            'jenis': jenis,
            'kategori': _detectCategory(text),
            'keterangan': 'Auto-detected dari teks',
          };
        }
      }
    }
    return null;
  }

  String _detectCategory(String text) {
    final categories = {
      'Makan': ['makan', 'food', 'gofood', 'grabfood', 'resto', 'warung'],
      'Transport': ['grab', 'gojek', 'taxi', 'bensin', 'parkir', 'tol'],
      'Belanja': ['tokopedia', 'shopee', 'lazada', 'indomaret', 'alfamart', 'minimarket'],
      'Tagihan': ['listrik', 'pdam', 'internet', 'pulsa', 'token', 'bpjs'],
      'Gaji': ['gaji', 'salary', 'honor', 'thr'],
    };

    for (var entry in categories.entries) {
      for (var keyword in entry.value) {
        if (text.contains(keyword)) return entry.key;
      }
    }
    return 'Umum';
  }

  Future<bool> addAutoTransaction(String text) async {
    if (!_autoDetectEnabled) return false;
    final parsed = parseTransactionText(text);
    if (parsed != null) {
      final transaksi = Pembukuan(
        jenis: parsed['jenis'],
        nominal: parsed['nominal'],
        kategori: parsed['kategori'],
        keterangan: parsed['keterangan'],
        tanggal: DateTime.now(),
        isAuto: true,
        source: 'sms',
      );
      await addPembukuan(transaksi);
      return true;
    }
    return false;
  }

  // ===== TEMPLATE BERULANG =====
  
  Future<void> addTemplate(TransaksiTemplate template) async {
    final newTemplate = TransaksiTemplate(
      id: template.id ?? DateTime.now().millisecondsSinceEpoch,
      nama: template.nama,
      jenis: template.jenis,
      nominal: template.nominal,
      kategori: template.kategori,
      keterangan: template.keterangan,
      tanggalBerulang: template.tanggalBerulang,
      isActive: template.isActive,
    );
    _templateList.add(newTemplate);
    await _saveTemplates();
    notifyListeners();
  }

  Future<void> _processRecurringTemplates() async {
    final today = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastProcessed = prefs.getString('last_template_processed') ?? '';
    final todayKey = '${today.year}-${today.month}-${today.day}';

    if (lastProcessed == todayKey) return;

    for (var template in _templateList) {
      if (!template.isActive) continue;
      if (today.day == template.tanggalBerulang) {
        final existing = _pembukuanList.any((p) => 
          p.source == 'template' &&
          p.tanggal.day == today.day &&
          p.tanggal.month == today.month &&
          p.tanggal.year == today.year
        );

        if (!existing) {
          await addPembukuan(Pembukuan(
            jenis: template.jenis,
            nominal: template.nominal,
            kategori: template.kategori,
            keterangan: '${template.keterangan} (Auto - ${template.nama})',
            tanggal: DateTime.now(),
            isAuto: true,
            source: 'template',
          ));
        }
      }
    }
    await prefs.setString('last_template_processed', todayKey);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}