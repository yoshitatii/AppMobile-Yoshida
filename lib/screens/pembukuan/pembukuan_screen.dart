import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/pembukuan_provider.dart';
import '../../models/pembukuan.dart';

// ============= CURRENCY FORMATTER =============
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final number = int.parse(digitsOnly);
    final formatted = _formatNumber(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int number) {
    final parts = number.toString().split('').reversed.toList();
    final formatted = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) formatted.add('.');
      formatted.add(parts[i]);
    }
    return formatted.reversed.join();
  }
}

class PembukuanScreen extends StatefulWidget {
  const PembukuanScreen({super.key});

  @override
  State<PembukuanScreen> createState() => _PembukuanScreenState();
}

class _PembukuanScreenState extends State<PembukuanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Daftar nilai valid untuk dropdown — harus PERSIS sama dengan value di DropdownMenuItem
  static const List<String> _validJenis = ['pemasukan', 'pengeluaran'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    await Provider.of<PembukuanProvider>(context, listen: false).loadPembukuan();
  }

  // ============= HELPERS =============
  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('').reversed.toList();
    final formatted = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) formatted.add('.');
      formatted.add(parts[i]);
    }
    return 'Rp ${formatted.reversed.join()}';
  }

  String _formatNumberWithDots(double number) {
    final parts = number.toStringAsFixed(0).split('').reversed.toList();
    final formatted = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) formatted.add('.');
      formatted.add(parts[i]);
    }
    return formatted.reversed.join();
  }

  // Hanya ambil digit lalu parse — tidak ada titik ribuan di dalam hasil
  double _parseFormattedNumber(String text) {
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.isEmpty ? 0.0 : double.parse(digitsOnly);
  }

  // KUNCI FIX DROPDOWN: Normalisasi nilai jenis agar selalu cocok dengan item
  String _normalizeJenis(String? raw) {
    final val = (raw ?? 'pemasukan').toLowerCase().trim();
    return _validJenis.contains(val) ? val : 'pemasukan';
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    final color = isError
        ? Colors.red
        : isWarning
            ? Colors.orange
            : Colors.green;
    final icon = isError
        ? Icons.error
        : isWarning
            ? Icons.info
            : Icons.check_circle;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============= BUILD =============
  @override
  Widget build(BuildContext context) {
    final pembukuanProvider = Provider.of<PembukuanProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pembukuan'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _showExportPdfDialog,
            tooltip: 'Export PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Pemasukan'),
            Tab(text: 'Pengeluaran'),
          ],
        ),
      ),
      body: pembukuanProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(pembukuanProvider.pembukuanList),
                _buildList(pembukuanProvider.pembukuanList
                    .where((p) => p.jenis == 'pemasukan')
                    .toList()),
                _buildList(pembukuanProvider.pembukuanList
                    .where((p) => p.jenis == 'pengeluaran')
                    .toList()),
              ],
            ),
      // Satu tombol FAB saja
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'main',
        onPressed: _showQuickAddOptions,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList(List<Pembukuan> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.account_balance_wallet_outlined,
                  size: 80, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text('Belum Ada Catatan',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text('Tap tombol + Tambah untuk menambah pembukuan',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildPembukuanCard(items[index]),
      ),
    );
  }

  Widget _buildPembukuanCard(Pembukuan pembukuan) {
    final isPemasukan = pembukuan.jenis == 'pemasukan';
    final formatter = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPemasukan
                      ? [const Color(0xFF43e97b), const Color(0xFF38f9d7)]
                      : [const Color(0xFFfa709a), const Color(0xFFfee140)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: (isPemasukan ? Colors.green : Colors.red)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(
                isPemasukan
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              isPemasukan ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pembukuan.kategori,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPemasukan
                                  ? Colors.green[700]
                                  : Colors.red[700]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(formatter.format(pembukuan.tanggal),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(pembukuan.keterangan,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(pembukuan.nominal),
                    style: TextStyle(
                        color:
                            isPemasukan ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10)),
                child:
                    Icon(Icons.more_vert, color: Colors.grey[700], size: 20),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'template',
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.bookmark_add_outlined,
                            size: 18, color: Colors.purple[700])),
                    const SizedBox(width: 12),
                    const Text('Simpan Template'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.edit_outlined,
                            size: 18, color: Colors.blue[700])),
                    const SizedBox(width: 12),
                    const Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red[700])),
                    const SizedBox(width: 12),
                    Text('Hapus',
                        style: TextStyle(color: Colors.red[700])),
                  ]),
                ),
              ],
              onSelected: (value) {
                if (value == 'template') {
                  _saveAsTemplate(pembukuan);
                } else if (value == 'edit') {
                  _showSmartFormDialog(pembukuan: pembukuan);
                } else if (value == 'delete') {
                  _showDeleteDialog(pembukuan);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============= QUICK ADD =============
  void _showQuickAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tambah Pembukuan',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Pilih cara menambah pembukuan',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 20),
                  _buildQuickOption(
                    icon: Icons.bookmark_rounded,
                    title: 'Gunakan Template',
                    subtitle: 'Transaksi yang sering dilakukan',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _showTemplateList();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildQuickOption(
                    icon: Icons.calculate_rounded,
                    title: 'Kalkulator',
                    subtitle: 'Hitung & langsung simpan',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _showCalculatorInput();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildQuickOption(
                    icon: Icons.edit_rounded,
                    title: 'Input Manual',
                    subtitle: 'Isi form lengkap',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _showSmartFormDialog();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ============= TEMPLATE =============
  Future<List<Map<String, dynamic>>> _getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getStringList('templates') ?? [];
    return templatesJson
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _saveTemplate(Map<String, dynamic> template) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await _getTemplates();
    templates.add(template);
    await prefs.setStringList(
        'templates', templates.map((e) => json.encode(e)).toList());
  }

  Future<void> _deleteTemplate(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await _getTemplates();
    templates.removeAt(index);
    await prefs.setStringList(
        'templates', templates.map((e) => json.encode(e)).toList());
  }

  void _saveAsTemplate(Pembukuan pembukuan) async {
    await _saveTemplate({
      // FIXED: simpan jenis dalam lowercase agar konsisten
      'jenis': pembukuan.jenis.toLowerCase().trim(),
      'nominal': pembukuan.nominal,
      'kategori': pembukuan.kategori,
      'keterangan': pembukuan.keterangan,
    });
    _showSnackBar('Template berhasil disimpan');
  }

  void _showTemplateList() async {
    final templates = await _getTemplates();
    if (!mounted) return;

    if (templates.isEmpty) {
      _showSnackBar('Belum ada template. Simpan transaksi dari menu 3 titik',
          isWarning: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.bookmark_rounded,
                          color: Colors.purple[700]),
                    ),
                    const SizedBox(width: 12),
                    const Text('Template Transaksi',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    // FIXED: normalisasi jenis dari template
                    final jenisTemplate =
                        _normalizeJenis(template['jenis'] as String?);
                    final isPemasukan = jenisTemplate == 'pemasukan';
                    final nominal =
                        (template['nominal'] as num).toDouble();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showSmartFormDialog(
                            autoFillJenis: jenisTemplate,
                            autoFillNominal: nominal,
                            autoFillKategori:
                                template['kategori'] as String,
                            autoFillKeterangan:
                                template['keterangan'] as String,
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: isPemasukan
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                child: Icon(
                                    isPemasukan
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: isPemasukan
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        template['kategori']
                                            as String,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(
                                        template['keterangan']
                                            as String,
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_formatCurrency(nominal),
                                        style: TextStyle(
                                            color: isPemasukan
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await _deleteTemplate(index);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  _showTemplateList();
                                },
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red[400]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============= KALKULATOR (FIXED - BISA HITUNG BEBERAPA OPERASI) =============
  void _showCalculatorInput() {
    // expression: menyimpan seluruh ekspresi dalam format string (misal: "10 + 90 + 1 + 4")
    String expression = '';
    // currentInput: angka yang sedang diketik saat ini
    String currentInput = '';
    // result: hasil kalkulasi terakhir
    double? result;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setCalcState) {
          void handleNumber(String num) {
            setCalcState(() {
              if (currentInput.length < 15) {
                currentInput += num;
              }
            });
          }

          void handleOperator(String op) {
            setCalcState(() {
              if (currentInput.isNotEmpty) {
                // Tambahkan angka saat ini ke expression
                if (expression.isEmpty) {
                  expression = currentInput;
                } else {
                  expression += ' $currentInput';
                }
                currentInput = '';
                // Tambahkan operator ke expression
                expression += ' $op';
              } else if (expression.isNotEmpty && !expression.endsWith(' ')) {
                // Jika sudah ada hasil sebelumnya, gunakan hasil tersebut
                if (result != null) {
                  expression = result!.toStringAsFixed(0) + ' $op';
                  result = null;
                }
              }
            });
          }

          void calculate() {
            setCalcState(() {
              // Tambahkan angka terakhir ke expression
              if (currentInput.isNotEmpty) {
                if (expression.isEmpty) {
                  expression = currentInput;
                } else {
                  expression += ' $currentInput';
                }
                currentInput = '';
              }

              // Evaluasi expression
              try {
                result = _evaluateExpression(expression);
                // Reset untuk perhitungan baru
                expression = '';
                currentInput = result!.toStringAsFixed(0);
              } catch (e) {
                expression = 'Error';
                currentInput = '';
                result = null;
              }
            });
          }

          void clear() {
            setCalcState(() {
              expression = '';
              currentInput = '';
              result = null;
            });
          }

          void backspace() {
            setCalcState(() {
              if (currentInput.isNotEmpty) {
                currentInput =
                    currentInput.substring(0, currentInput.length - 1);
              }
            });
          }

          // Menentukan apa yang ditampilkan di layar
          String getDisplay() {
            String displayText = expression;
            if (currentInput.isNotEmpty) {
              displayText += (expression.isEmpty ? '' : ' ') + currentInput;
            }
            if (displayText.isEmpty) {
              displayText = '0';
            }
            return displayText;
          }

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12)),
                        child:
                            Icon(Icons.calculate, color: Colors.orange[700]),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('Kalkulator',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold))),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      getDisplay(),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Keypad — 4x4 grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      _calcBtn('7', () => handleNumber('7')),
                      _calcBtn('8', () => handleNumber('8')),
                      _calcBtn('9', () => handleNumber('9')),
                      _calcBtn('÷', () => handleOperator('÷'),
                          isOperator: true),
                      _calcBtn('4', () => handleNumber('4')),
                      _calcBtn('5', () => handleNumber('5')),
                      _calcBtn('6', () => handleNumber('6')),
                      _calcBtn('×', () => handleOperator('×'),
                          isOperator: true),
                      _calcBtn('1', () => handleNumber('1')),
                      _calcBtn('2', () => handleNumber('2')),
                      _calcBtn('3', () => handleNumber('3')),
                      _calcBtn('-', () => handleOperator('-'),
                          isOperator: true),
                      _calcBtn('C', clear, isSpecial: true),
                      _calcBtn('0', () => handleNumber('0')),
                      _calcBtn('⌫', backspace, isSpecial: true),
                      _calcBtn('+', () => handleOperator('+'),
                          isOperator: true),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tombol = terpisah
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: calculate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('=',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tombol gunakan nominal
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        double nominal = 0;
                        
                        // Jika ada hasil kalkulasi, gunakan hasil tersebut
                        if (result != null) {
                          nominal = result!;
                        } 
                        // Jika belum dihitung tapi ada input, parse input terakhir
                        else if (currentInput.isNotEmpty) {
                          nominal = double.tryParse(currentInput) ?? 0;
                        }
                        
                        if (nominal <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Masukkan nominal lebih dari 0 atau tekan = untuk menghitung'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _showSmartFormDialog(
                            autoFillNominal: nominal);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Gunakan Nominal Ini'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Fungsi untuk mengevaluasi ekspresi matematika
  double _evaluateExpression(String expr) {
    if (expr.isEmpty) return 0;
    
    // Parse expression menjadi list of tokens
    List<String> tokens = expr.split(' ');
    
    if (tokens.isEmpty) return 0;
    
    // Jika hanya ada satu token (angka tunggal)
    if (tokens.length == 1) {
      return double.tryParse(tokens[0]) ?? 0;
    }
    
    // Stack untuk angka dan operator
    List<double> numbers = [];
    List<String> operators = [];
    
    // Parse tokens
    for (int i = 0; i < tokens.length; i++) {
      String token = tokens[i].trim();
      if (token.isEmpty) continue;
      
      // Jika token adalah angka
      if (double.tryParse(token) != null) {
        numbers.add(double.parse(token));
      } 
      // Jika token adalah operator
      else if (['+', '-', '×', '÷'].contains(token)) {
        operators.add(token);
      }
    }
    
    // Validasi: jumlah operator harus = jumlah angka - 1
    if (operators.length != numbers.length - 1) {
      throw Exception('Invalid expression');
    }
    
    // Proses perkalian dan pembagian terlebih dahulu
    int i = 0;
    while (i < operators.length) {
      if (operators[i] == '×' || operators[i] == '÷') {
        double left = numbers[i];
        double right = numbers[i + 1];
        double result;
        
        if (operators[i] == '×') {
          result = left * right;
        } else {
          if (right == 0) throw Exception('Division by zero');
          result = left / right;
        }
        
        // Replace angka dengan hasil
        numbers[i] = result;
        numbers.removeAt(i + 1);
        operators.removeAt(i);
      } else {
        i++;
      }
    }
    
    // Proses penjumlahan dan pengurangan
    i = 0;
    while (i < operators.length) {
      double left = numbers[i];
      double right = numbers[i + 1];
      double result;
      
      if (operators[i] == '+') {
        result = left + right;
      } else {
        result = left - right;
      }
      
      // Replace angka dengan hasil
      numbers[i] = result;
      numbers.removeAt(i + 1);
      operators.removeAt(i);
    }
    
    return numbers[0];
  }

  Widget _calcBtn(String label, VoidCallback onTap,
      {bool isOperator = false, bool isSpecial = false}) {
    return Material(
      color: isOperator
          ? Colors.orange[400]
          : isSpecial
              ? Colors.blue[400]
              : Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isOperator || isSpecial
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ============= FORM DIALOG (FULLY FIXED) =============
  void _showSmartFormDialog({
    Pembukuan? pembukuan,
    String? autoFillJenis,
    double? autoFillNominal,
    String? autoFillKategori,
    String? autoFillKeterangan,
  }) {
    final formKey = GlobalKey<FormState>();
    final nominalController = TextEditingController(
      text: autoFillNominal != null
          ? _formatNumberWithDots(autoFillNominal)
          : pembukuan != null
              ? _formatNumberWithDots(pembukuan.nominal)
              : '',
    );
    final kategoriController = TextEditingController(
        text: autoFillKategori ?? pembukuan?.kategori ?? '');
    final keteranganController = TextEditingController(
        text: autoFillKeterangan ?? pembukuan?.keterangan ?? '');

    // KUNCI: Selalu normalisasi — tidak boleh ada value selain 'pemasukan' atau 'pengeluaran'
    String jenis = _normalizeJenis(autoFillJenis ?? pembukuan?.jenis);
    DateTime tanggal = pembukuan?.tanggal ?? DateTime.now();
    List<String> suggestedCategories = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (suggestedCategories.isEmpty) {
            final provider =
                Provider.of<PembukuanProvider>(context, listen: false);
            suggestedCategories = provider.pembukuanList
                .where((p) => p.jenis == jenis)
                .map((p) => p.kategori)
                .toSet()
                .take(5)
                .toList();
          }

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius:
                                    BorderRadius.circular(12)),
                            child: Icon(
                                pembukuan == null
                                    ? Icons.add_rounded
                                    : Icons.edit_rounded,
                                color: Colors.white,
                                size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              pembukuan == null
                                  ? 'Tambah Pembukuan'
                                  : 'Edit Pembukuan',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              icon: const Icon(Icons.close,
                                  color: Colors.white)),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // FIXED DROPDOWN: value selalu salah satu dari 'pemasukan' / 'pengeluaran'
                          DropdownButtonFormField<String>(
                            value: jenis,
                            decoration: InputDecoration(
                              labelText: 'Jenis',
                              prefixIcon: Icon(
                                  Icons.category_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pemasukan',
                                child: Row(children: [
                                  Icon(Icons.trending_up,
                                      color: Colors.green,
                                      size: 20),
                                  SizedBox(width: 8),
                                  Text('Pemasukan'),
                                ]),
                              ),
                              DropdownMenuItem(
                                value: 'pengeluaran',
                                child: Row(children: [
                                  Icon(Icons.trending_down,
                                      color: Colors.red,
                                      size: 20),
                                  SizedBox(width: 8),
                                  Text('Pengeluaran'),
                                ]),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                jenis = value!;
                                suggestedCategories = [];
                                final provider =
                                    Provider.of<PembukuanProvider>(
                                        context,
                                        listen: false);
                                suggestedCategories = provider
                                    .pembukuanList
                                    .where(
                                        (p) => p.jenis == jenis)
                                    .map((p) => p.kategori)
                                    .toSet()
                                    .take(5)
                                    .toList();
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Nominal — hanya CurrencyInputFormatter
                          TextFormField(
                            controller: nominalController,
                            decoration: InputDecoration(
                              labelText: 'Nominal',
                              prefixIcon: Icon(
                                  Icons.payments_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.number,
                            // FIXED: Hanya 1 formatter, sudah cukup
                            inputFormatters: [
                              CurrencyInputFormatter(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nominal wajib diisi';
                              }
                              final d = value.replaceAll(
                                  RegExp(r'[^\d]'), '');
                              if (d.isEmpty || int.parse(d) <= 0) {
                                return 'Nominal harus lebih dari 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Quick amount chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              10000,
                              20000,
                              50000,
                              100000,
                              500000
                            ].map((amount) {
                              return InkWell(
                                onTap: () => setDialogState(() =>
                                    nominalController.text =
                                        _formatNumberWithDots(
                                            amount.toDouble())),
                                child: Chip(
                                  label: Text(_formatCurrency(
                                      amount.toDouble())),
                                  backgroundColor: Colors.blue[50],
                                  labelStyle: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Kategori
                          TextFormField(
                            controller: kategoriController,
                            decoration: InputDecoration(
                              labelText: 'Kategori',
                              prefixIcon: Icon(Icons.label_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Kategori wajib diisi'
                                    : null,
                          ),

                          if (suggestedCategories.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Sering Digunakan:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children:
                                  suggestedCategories.map((cat) {
                                return InkWell(
                                  onTap: () => setDialogState(
                                      () =>
                                          kategoriController.text =
                                              cat),
                                  child: Chip(
                                    label: Text(cat),
                                    backgroundColor:
                                        Colors.purple[50],
                                    labelStyle: TextStyle(
                                        color: Colors.purple[700],
                                        fontSize: 12),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Keterangan
                          TextFormField(
                            controller: keteranganController,
                            decoration: InputDecoration(
                              labelText: 'Keterangan',
                              prefixIcon: Icon(Icons.notes_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            maxLines: 3,
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Keterangan wajib diisi'
                                    : null,
                          ),
                          const SizedBox(height: 16),

                          // Tanggal
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tanggal,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(
                                    () => tanggal = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                      Icons.calendar_today_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 12),
                                  Text(
                                      DateFormat('dd MMMM yyyy')
                                          .format(tanggal),
                                      style: const TextStyle(
                                          fontSize: 16)),
                                  const Spacer(),
                                  Icon(Icons.arrow_drop_down,
                                      color: Colors.grey[600]),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets
                                        .symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12)),
                                  ),
                                  child: const Text('Batal'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (!formKey.currentState!
                                        .validate()) return;

                                    final newPembukuan =
                                        Pembukuan(
                                      id: pembukuan?.id,
                                      jenis: jenis,
                                      tanggal: tanggal,
                                      nominal:
                                          _parseFormattedNumber(
                                              nominalController
                                                  .text),
                                      kategori:
                                          kategoriController.text
                                              .trim(),
                                      keterangan:
                                          keteranganController
                                              .text
                                              .trim(),
                                    );

                                    final provider =
                                        Provider.of<PembukuanProvider>(
                                            context,
                                            listen: false);
                                    final bool success =
                                        pembukuan == null
                                            ? await provider
                                                .addPembukuan(
                                                    newPembukuan)
                                            : await provider
                                                .updatePembukuan(
                                                    newPembukuan);

                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    _showSnackBar(
                                      success
                                          ? 'Pembukuan berhasil disimpan'
                                          : 'Gagal menyimpan pembukuan',
                                      isError: !success,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets
                                        .symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12)),
                                  ),
                                  child: const Text('Simpan'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============= EXPORT PDF =============
  void _showExportPdfDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.picture_as_pdf,
                  color: Colors.red[700], size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Export PDF')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pilih periode laporan:',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            _buildPdfOption(context, 'Hari Ini', Icons.today,
                () => _exportPdf('today')),
            const SizedBox(height: 8),
            _buildPdfOption(context, 'Minggu Ini',
                Icons.date_range, () => _exportPdf('week')),
            const SizedBox(height: 8),
            _buildPdfOption(context, 'Bulan Ini',
                Icons.calendar_month, () => _exportPdf('month')),
            const SizedBox(height: 8),
            _buildPdfOption(context, 'Pilih Tanggal',
                Icons.calendar_today, () => _exportPdfCustom()),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfOption(BuildContext context, String title,
      IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900]))),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.blue[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(String period) async {
    if (!mounted) return;
    final provider =
        Provider.of<PembukuanProvider>(context, listen: false);
    final now = DateTime.now();
    DateTime startDate;
    String periodLabel;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        periodLabel =
            'Hari Ini - ${DateFormat('dd MMMM yyyy').format(now)}';
        break;
      case 'week':
        startDate =
            now.subtract(Duration(days: now.weekday - 1));
        periodLabel =
            'Minggu Ini - ${DateFormat('dd MMM').format(startDate)} s/d ${DateFormat('dd MMM yyyy').format(now)}';
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        periodLabel =
            'Bulan ${DateFormat('MMMM yyyy').format(now)}';
        break;
      default:
        return;
    }

    final filteredData = provider.pembukuanList
        .where((p) => !p.tanggal.isBefore(startDate))
        .toList();
    await _generatePdf(filteredData, periodLabel);
  }

  Future<void> _exportPdfCustom() async {
    if (!mounted) return;
    final provider =
        Provider.of<PembukuanProvider>(context, listen: false);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    final startDate = DateTime(
        picked.start.year, picked.start.month, picked.start.day);
    final endDate = DateTime(picked.end.year, picked.end.month,
        picked.end.day, 23, 59, 59);

    final filteredData = provider.pembukuanList
        .where((p) =>
            !p.tanggal.isBefore(startDate) &&
            !p.tanggal.isAfter(endDate))
        .toList();

    final periodLabel =
        '${DateFormat('dd MMM yyyy').format(picked.start)} s/d ${DateFormat('dd MMM yyyy').format(picked.end)}';
    await _generatePdf(filteredData, periodLabel);
  }

  Future<void> _generatePdf(
      List<Pembukuan> data, String period) async {
    if (data.isEmpty) {
      _showSnackBar('Tidak ada data untuk periode ini',
          isWarning: true);
      return;
    }

    final pdf = pw.Document();
    final totalPemasukan = data
        .where((p) => p.jenis == 'pemasukan')
        .fold(0.0, (sum, p) => sum + p.nominal);
    final totalPengeluaran = data
        .where((p) => p.jenis == 'pengeluaran')
        .fold(0.0, (sum, p) => sum + p.nominal);
    final saldo = totalPemasukan - totalPengeluaran;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfCtx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('LAPORAN PEMBUKUAN',
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(period,
                  style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(
                  'Dicetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600)),
              pw.Divider(thickness: 2),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfSummaryItem(
                    'Pemasukan', totalPemasukan, PdfColors.green),
                _buildPdfSummaryItem('Pengeluaran',
                    totalPengeluaran, PdfColors.red),
                _buildPdfSummaryItem(
                    'Saldo',
                    saldo,
                    saldo >= 0 ? PdfColors.blue : PdfColors.red),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200),
                children: [
                  _buildPdfTableCell('Tanggal',
                      isHeader: true),
                  _buildPdfTableCell('Jenis',
                      isHeader: true),
                  _buildPdfTableCell('Kategori',
                      isHeader: true),
                  _buildPdfTableCell('Keterangan',
                      isHeader: true),
                  _buildPdfTableCell('Nominal',
                      isHeader: true,
                      align: pw.TextAlign.right),
                ],
              ),
              ...data.map(
                (p) => pw.TableRow(
                  children: [
                    _buildPdfTableCell(
                        DateFormat('dd/MM/yy')
                            .format(p.tanggal)),
                    _buildPdfTableCell(
                        p.jenis == 'pemasukan'
                            ? 'Masuk'
                            : 'Keluar'),
                    _buildPdfTableCell(p.kategori),
                    _buildPdfTableCell(p.keterangan),
                    _buildPdfTableCell(
                        _formatCurrency(p.nominal),
                        align: pw.TextAlign.right,
                        color: p.jenis == 'pemasukan'
                            ? PdfColors.green800
                            : PdfColors.red800),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Transaksi: ${data.length}',
                    style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Dibuat oleh Aplikasi Kasir UMKM',
                    style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async =>
            pdf.save());
    if (!mounted) return;
    _showSnackBar('PDF berhasil dibuat!');
  }

  pw.Widget _buildPdfSummaryItem(
      String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(_formatCurrency(amount),
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ],
    );
  }

  pw.Widget _buildPdfTableCell(String text,
      {bool isHeader = false,
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ??
              (isHeader ? PdfColors.black : PdfColors.grey800),
        ),
        textAlign: align,
      ),
    );
  }

  // ============= DELETE =============
  void _showDeleteDialog(Pembukuan pembukuan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.warning_rounded,
                  color: Colors.red[700], size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Hapus Pembukuan')),
          ],
        ),
        content: const Text(
            'Yakin ingin menghapus catatan ini? Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await Provider.of<PembukuanProvider>(
                          context,
                          listen: false)
                      .deletePembukuan(pembukuan.id!);
              if (!mounted) return;
              _showSnackBar(
                success
                    ? 'Pembukuan berhasil dihapus'
                    : 'Gagal menghapus pembukuan',
                isError: !success,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}