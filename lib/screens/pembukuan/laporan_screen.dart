import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/transaksi_provider.dart';
import '../../models/transaksi.dart';

// Model sederhana untuk item pengeluaran
class ItemPengeluaran {
  final String keterangan;
  final double nominal;
  ItemPengeluaran({required this.keterangan, required this.nominal});
}

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Transaksi> _laporanData = [];
  bool _isLoading = false;
  bool _isGeneratingPdf = false;

  // ✅ Pengeluaran bisa ditambah berkali-kali
  final List<ItemPengeluaran> _daftarPengeluaran = [];

  @override
  void initState() {
    super.initState();
    _loadLaporan();
  }

  Future<void> _loadLaporan() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<TransaksiProvider>(context, listen: false);
    await provider.loadTransaksi();

    final startDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    final filtered = provider.transaksiList.where((t) {
      return t.tanggal.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
          t.tanggal.isBefore(endDay.add(const Duration(seconds: 1)));
    }).toList();

    setState(() {
      _laporanData = filtered;
      _isLoading = false;
    });
  }

  // ─── FORMAT ──────────────────────────────────────────────────

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  // ✅ Format angka menjadi 1.000 saat mengetik
  String _formatAngka(String raw) {
    if (raw.isEmpty) return '';
    final clean = raw.replaceAll('.', '').replaceAll(',', '');
    final num = int.tryParse(clean);
    if (num == null) return raw;
    return NumberFormat('#,###', 'id_ID').format(num).replaceAll(',', '.');
  }

  // ─── GETTER ──────────────────────────────────────────────────

  double get _totalPendapatan =>
      _laporanData.fold(0.0, (sum, t) => sum + t.totalHarga);

  double get _totalPengeluaran =>
      _daftarPengeluaran.fold(0.0, (sum, e) => sum + e.nominal);

  double get _pendapatanBersih => _totalPendapatan - _totalPengeluaran;

  // ─── DATE PICKER ─────────────────────────────────────────────

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadLaporan();
    }
  }

  // ─── DIALOG TAMBAH PENGELUARAN ───────────────────────────────

  Future<void> _showTambahPengeluaran() async {
    final ketController = TextEditingController();
    final nominalController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Pengeluaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ketController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Contoh: Beli stok, Listrik...',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            // ✅ Nominal otomatis format rupiah saat mengetik
            TextField(
              controller: nominalController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final formatted = _formatAngka(newValue.text);
                  return newValue.copyWith(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
              decoration: InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                hintText: '0',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final ket = ketController.text.trim();
              final nominal = double.tryParse(
                      nominalController.text.replaceAll('.', '').replaceAll(',', '')) ??
                  0;
              if (ket.isEmpty || nominal <= 0) return;
              setState(() {
                _daftarPengeluaran.add(ItemPengeluaran(keterangan: ket, nominal: nominal));
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tambah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── GENERATE PDF (LOW-END FRIENDLY) ─────────────────────────

  Future<void> _generatePdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document(compress: true);
      final isUntung = _pendapatanBersih >= 0;
      final tanggalCetak = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());
      final periodeStr =
          '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LAPORAN KEUANGAN',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600)),
                pw.Text(periodeStr,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ),
          footer: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Dicetak: $tanggalCetak',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text('Hal ${ctx.pageNumber} / ${ctx.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ),
          build: (ctx) => [
            // JUDUL
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('LAPORAN KEUANGAN TOKO',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text('Periode: $periodeStr',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.blue100)),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // RINGKASAN 3 KOTAK
            pw.Row(
              children: [
                _pdfBox('Total Pendapatan', _formatCurrency(_totalPendapatan), PdfColors.green700),
                pw.SizedBox(width: 8),
                _pdfBox('Total Pengeluaran', _formatCurrency(_totalPengeluaran), PdfColors.red700),
                pw.SizedBox(width: 8),
                _pdfBox(
                  isUntung ? 'Pendapatan Bersih (UNTUNG)' : 'Pendapatan Bersih (RUGI)',
                  _formatCurrency(_pendapatanBersih.abs()),
                  isUntung ? PdfColors.green800 : PdfColors.red800,
                  highlight: true,
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // RINCIAN PENGELUARAN
            if (_daftarPengeluaran.isNotEmpty) ...[
              pw.Text('Rincian Pengeluaran',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('Keterangan', bold: true),
                      _pdfCell('Nominal', bold: true, right: true),
                    ],
                  ),
                  ..._daftarPengeluaran.map((e) => pw.TableRow(
                        children: [
                          _pdfCell(e.keterangan),
                          _pdfCell(_formatCurrency(e.nominal), right: true),
                        ],
                      )),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.red50),
                    children: [
                      _pdfCell('TOTAL PENGELUARAN', bold: true),
                      _pdfCell(_formatCurrency(_totalPengeluaran),
                          bold: true, right: true, color: PdfColors.red700),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // RIWAYAT TRANSAKSI
            pw.Text('Riwayat Transaksi Penjualan',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            _laporanData.isEmpty
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Center(
                      child: pw.Text('Tidak ada transaksi pada periode ini',
                          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
                    ),
                  )
                : pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _pdfCell('No', bold: true),
                          _pdfCell('Nomor Transaksi', bold: true),
                          _pdfCell('Tanggal', bold: true),
                          _pdfCell('Total', bold: true, right: true),
                        ],
                      ),
                      ..._laporanData.asMap().entries.map((entry) {
                        final i = entry.key;
                        final t = entry.value;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                              color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                          children: [
                            _pdfCell('${i + 1}'),
                            _pdfCell(t.nomorTransaksi),
                            _pdfCell(DateFormat('dd/MM/yy HH:mm').format(t.tanggal)),
                            _pdfCell(_formatCurrency(t.totalHarga),
                                right: true, color: PdfColors.green700),
                          ],
                        );
                      }),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.green50),
                        children: [
                          _pdfCell(''),
                          _pdfCell(''),
                          _pdfCell('TOTAL', bold: true),
                          _pdfCell(_formatCurrency(_totalPendapatan),
                              bold: true, right: true, color: PdfColors.green800),
                        ],
                      ),
                    ],
                  ),

            pw.SizedBox(height: 20),

            // KESIMPULAN
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: isUntung ? PdfColors.green50 : PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                    color: isUntung ? PdfColors.green300 : PdfColors.red300, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('KESIMPULAN',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  _pdfRow('Total Pendapatan', _formatCurrency(_totalPendapatan), PdfColors.green700),
                  _pdfRow('Total Pengeluaran', _formatCurrency(_totalPengeluaran), PdfColors.red700),
                  pw.Divider(color: PdfColors.grey400),
                  _pdfRow(
                    isUntung ? 'Pendapatan Bersih (UNTUNG ▲)' : 'Pendapatan Bersih (RUGI ▼)',
                    _formatCurrency(_pendapatanBersih.abs()),
                    isUntung ? PdfColors.green800 : PdfColors.red800,
                    bold: true,
                    fontSize: 13,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ─── PDF HELPERS ─────────────────────────────────────────────

  pw.Widget _pdfBox(String label, String value, PdfColor color, {bool highlight = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: highlight ? color : PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color, width: highlight ? 0 : 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8, color: highlight ? PdfColors.white : PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? PdfColors.white : color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false, bool right = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _pdfRow(String label, String value, PdfColor color,
      {bool bold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: PdfColors.grey800)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isUntung = _pendapatanBersih >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Laporan Pendapatan',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Color(0xFF1E3A8A)),
            onPressed: _selectDateRange,
            tooltip: 'Pilih Periode',
          ),
          _isGeneratingPdf
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF1E3A8A)),
                  onPressed: _generatePdf,
                  tooltip: 'Download PDF',
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── KARTU RINGKASAN ─────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(_startDate)} — ${DateFormat('dd MMM yyyy').format(_endDate)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _summaryTile('Total Pendapatan', _totalPendapatan,
                                  Colors.green, Icons.arrow_upward_rounded)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: GestureDetector(
                            onTap: _showTambahPengeluaran,
                            child: _summaryTile('Total Pengeluaran', _totalPengeluaran,
                                Colors.red, Icons.arrow_downward_rounded,
                                editable: true),
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      // Pendapatan Bersih
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isUntung
                              ? Colors.green.withOpacity(0.08)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isUntung
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('Pendapatan Bersih',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_pendapatanBersih.abs()),
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isUntung ? Colors.green[700] : Colors.red[700]),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isUntung
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isUntung ? '▲ UNTUNG' : '▼ RUGI',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isUntung
                                        ? Colors.green[700]
                                        : Colors.red[700]),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatCurrency(_totalPendapatan)} − ${_formatCurrency(_totalPengeluaran)}',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 13, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('${_laporanData.length} transaksi',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── DAFTAR PENGELUARAN ───────────────────────
                if (_daftarPengeluaran.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Rincian Pengeluaran',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showTambahPengeluaran,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF1E3A8A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('+ Tambah',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1E3A8A),
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._daftarPengeluaran.asMap().entries.map((e) {
                          final idx = e.key;
                          final item = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: Colors.red, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(item.keterangan,
                                        style: const TextStyle(fontSize: 13))),
                                Text(_formatCurrency(item.nominal),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700])),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _daftarPengeluaran.removeAt(idx)),
                                  child: Icon(Icons.close,
                                      size: 16, color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // ─── JUDUL LIST + TOMBOL TAMBAH ───────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text('Detail Transaksi',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showTambahPengeluaran,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Tambah Pengeluaran',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                ),

                // ─── LIST TRANSAKSI ───────────────────────────
                Expanded(
                  child: _laporanData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 60, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada transaksi\npada periode ini',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _laporanData.length,
                          itemBuilder: (context, index) =>
                              _buildTransaksiCard(_laporanData[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryTile(String label, double amount, Color color, IconData icon,
      {bool editable = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600))),
              if (editable)
                Icon(Icons.add_circle_outline, size: 14, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 6),
          Text(_formatCurrency(amount),
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildTransaksiCard(Transaksi item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nomorTransaksi,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(item.tanggal),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(_formatCurrency(item.totalHarga),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.green[700])),
        ],
      ),
    );
  }
}