import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/pembukuan_provider.dart';
import '../../models/pembukuan.dart';

class PembukuanScreen extends StatefulWidget {
  const PembukuanScreen({super.key});

  @override
  State<PembukuanScreen> createState() => _PembukuanScreenState();
}

class _PembukuanScreenState extends State<PembukuanScreen> {
  String _selectedFilter = 'pemasukan';

  String formatRupiah(double nominal) {
    return NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(nominal);
  }

  // ============================================================
  // FUNGSI GENERATE PDF - tidak diubah sama sekali
  // ============================================================
  Future<void> _generatePDF(BuildContext context) async {
    final provider = Provider.of<PembukuanProvider>(context, listen: false);

    String? jenisLaporan = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.picture_as_pdf, color: Color(0xFF1E3A8A)),
            SizedBox(width: 10),
            Text("Pilih Jenis Laporan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPDFOption(
                context, "Laporan Pemasukan", "pemasukan", Colors.green),
            const SizedBox(height: 12),
            _buildPDFOption(
                context, "Laporan Pengeluaran", "pengeluaran", Colors.red),
            const SizedBox(height: 12),
            _buildPDFOption(
                context, "Laporan Lengkap", "semua", Colors.blue),
          ],
        ),
      ),
    );

    if (jenisLaporan == null) return;

    List<Pembukuan> dataLaporan;
    if (jenisLaporan == 'semua') {
      dataLaporan = provider.pembukuanList;
    } else {
      dataLaporan = provider.pembukuanList
          .where((item) =>
              item.jenis.toLowerCase() == jenisLaporan.toLowerCase())
          .toList();
    }

    if (dataLaporan.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Tidak ada data untuk laporan ${jenisLaporan == 'semua' ? 'lengkap' : jenisLaporan}"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdf = pw.Document();

    double totalPemasukan = dataLaporan
        .where((item) => item.jenis.toLowerCase() == 'pemasukan')
        .fold(0, (sum, item) => sum + item.nominal);

    double totalPengeluaran = dataLaporan
        .where((item) => item.jenis.toLowerCase() == 'pengeluaran')
        .fold(0, (sum, item) => sum + item.nominal);

    double saldo = totalPemasukan - totalPengeluaran;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue900,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "LAPORAN PEMBUKUAN",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    jenisLaporan == 'semua'
                        ? "Laporan Lengkap (Pemasukan & Pengeluaran)"
                        : "Laporan ${jenisLaporan.toUpperCase()}",
                    style: pw.TextStyle(
                        fontSize: 14, color: PdfColors.blue100),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Tanggal: ${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}",
                    style: pw.TextStyle(
                        fontSize: 11, color: PdfColors.blue100),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border:
                    pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPDFSummaryBox(
                      "Total Pemasukan", totalPemasukan, PdfColors.green),
                  _buildPDFSummaryBox(
                      "Total Pengeluaran", totalPengeluaran, PdfColors.red),
                  _buildPDFSummaryBox("Saldo", saldo,
                      saldo >= 0 ? PdfColors.blue : PdfColors.orange),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              "Detail Transaksi",
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell("Jenis", isHeader: true),
                    _buildTableCell("Kategori", isHeader: true),
                    _buildTableCell("Keterangan", isHeader: true),
                    _buildTableCell("Nominal", isHeader: true),
                  ],
                ),
                ...dataLaporan.map((item) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                        item.jenis.toUpperCase(),
                        color: item.jenis == 'pemasukan'
                            ? PdfColors.green
                            : PdfColors.red,
                      ),
                      _buildTableCell(item.kategori),
                      _buildTableCell(item.keterangan.isEmpty
                          ? "-"
                          : item.keterangan),
                      _buildTableCell(
                        formatRupiah(item.nominal),
                        align: pw.TextAlign.right,
                        isBold: true,
                      ),
                    ],
                  );
                }).toList(),
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildTableCell(""),
                    _buildTableCell(""),
                    _buildTableCell("TOTAL", isHeader: true),
                    _buildTableCell(
                      formatRupiah(dataLaporan.fold(
                          0.0, (sum, item) => sum + item.nominal)),
                      align: pw.TextAlign.right,
                      isBold: true,
                      isHeader: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Text(
              "Dokumen ini dibuat secara otomatis oleh sistem pembukuan",
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Laporan_${jenisLaporan}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPDFSummaryBox(
      String label, double amount, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          formatRupiah(amount),
          style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: (isHeader || isBold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.black : PdfColors.grey800),
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildPDFOption(
      BuildContext context, String title, String value, Color color) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: color, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PembukuanProvider>(context);

    final filteredList = provider.pembukuanList
        .where((item) =>
            item.jenis.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Pembukuan",
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _generatePDF(context),
            icon: const Icon(Icons.picture_as_pdf,
                color: Color(0xFF1E3A8A)),
            tooltip: "Download Laporan PDF",
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KOTAK RINGKASAN PEMASUKAN & PENGELUARAN — tidak diubah
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildSummaryBox(
                  label: "Pemasukan",
                  amount: provider.totalPemasukan,
                  color: Colors.green,
                  type: 'pemasukan',
                ),
                const SizedBox(width: 12),
                _buildSummaryBox(
                  label: "Pengeluaran",
                  amount: provider.totalPengeluaran,
                  color: Colors.red,
                  type: 'pengeluaran',
                ),
              ],
            ),
          ),

          // ✅ TAMBAHAN BARU: Kartu Bruto, Neto, Laba/Rugi
          _buildLabaRugiCard(provider),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Daftar ${_selectedFilter.toUpperCase()}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),

          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Text("Belum ada data $_selectedFilter"))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return _buildTransactionCard(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInputSheet(context),
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text("Tambah", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ✅ WIDGET BARU: Kartu ringkasan Bruto, Neto, Laba/Rugi
  Widget _buildLabaRugiCard(PembukuanProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header baris atas: judul + badge status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Laporan Laba / Rugi",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.isProfit
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  provider.isProfit ? "▲ UNTUNG" : "▼ RUGI",
                  style: TextStyle(
                    color: provider.isProfit
                        ? Colors.green[700]
                        : Colors.red[700],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Angka Laba Bersih utama
          Text(
            formatRupiah(provider.labaBersih),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: provider.isProfit
                  ? Colors.green[700]
                  : Colors.red[700],
            ),
          ),
          Text(
            "Margin: ${provider.profitMargin.toStringAsFixed(1)}%",
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const Divider(height: 20),

          // Baris metrik: Bruto, HPP, Laba Kotor, Biaya Ops, Neto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetrikItem("Bruto", provider.totalBruto, Colors.blue[700]!),
              _buildMetrikItem("HPP", provider.totalHPP, Colors.orange[700]!),
              _buildMetrikItem("Laba Kotor", provider.labaKotor, Colors.teal[700]!),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetrikItem("Biaya Ops", provider.biayaOperasional, Colors.purple[700]!),
              _buildMetrikItem("Neto", provider.totalNeto, Colors.indigo[700]!),
              _buildMetrikItem(
                "Laba Bersih",
                provider.labaBersih,
                provider.isProfit ? Colors.green[700]! : Colors.red[700]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ HELPER BARU untuk tiap metrik di kartu laba rugi
  Widget _buildMetrikItem(String label, double nilai, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            formatRupiah(nilai),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required double amount,
    required Color color,
    required String type,
  }) {
    bool isActive = _selectedFilter == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isActive ? color : Colors.transparent, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Text(formatRupiah(amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Pembukuan item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.kategori,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(item.keterangan,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          Text(
            formatRupiah(item.nominal),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: item.jenis == 'pemasukan'
                  ? Colors.green[700]
                  : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showInputSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ModalTambahPembukuan(),
    );
  }
}

// WIDGET MODAL INPUT — tidak diubah sama sekali
class ModalTambahPembukuan extends StatefulWidget {
  const ModalTambahPembukuan({super.key});

  @override
  State<ModalTambahPembukuan> createState() => _ModalTambahPembukuanState();
}

class _ModalTambahPembukuanState extends State<ModalTambahPembukuan> {
  String _jenis = 'pengeluaran';
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _ketController = TextEditingController();
  String _kategori = 'Belanja Stok';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xFF4A76A8),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.add, color: Colors.white)),
                const SizedBox(width: 15),
                const Text("Tambah Pembukuan",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("Jenis"),
                DropdownButtonFormField<String>(
                  value: _jenis,
                  decoration: _inputDecoration(Icons.category_outlined),
                  items: const [
                    DropdownMenuItem(
                        value: 'pemasukan', child: Text("Pemasukan")),
                    DropdownMenuItem(
                        value: 'pengeluaran',
                        child: Text("Pengeluaran")),
                  ],
                  onChanged: (val) => setState(() => _jenis = val!),
                ),
                const SizedBox(height: 15),
                _buildLabel("Nominal"),
                TextField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  decoration:
                      _inputDecoration(Icons.payments_outlined, prefix: "Rp "),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [10000, 20000, 50000, 100000, 500000].map((val) {
                    return ActionChip(
                      label: Text(
                          "Rp ${NumberFormat('#,###', 'id_ID').format(val)}"),
                      onPressed: () =>
                          _nominalController.text = val.toString(),
                      backgroundColor: Colors.blue[50],
                      labelStyle: const TextStyle(
                          color: Colors.blue, fontSize: 12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                _buildLabel("Kategori"),
                TextField(
                  readOnly: true,
                  decoration: _inputDecoration(
                      Icons.label_important_outline,
                      hint: _kategori),
                ),
                const SizedBox(height: 15),
                _buildLabel("Keterangan"),
                TextField(
                  controller: _ketController,
                  maxLines: 2,
                  decoration: _inputDecoration(Icons.notes,
                      hint: "Contoh: Pembelian stok barang"),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15))),
                        child: const Text("Batal"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_nominalController.text.isEmpty) return;
                          final data = Pembukuan(
                            jenis: _jenis,
                            nominal: double.parse(_nominalController.text),
                            kategori: _kategori,
                            keterangan: _ketController.text,
                            tanggal: DateTime.now(),
                          );
                          context
                              .read<PembukuanProvider>()
                              .addPembukuan(data);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                    color: Colors.grey[300]!))),
                        child: const Text("Simpan",
                            style: TextStyle(
                                color: Color(0xFF4A76A8),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13)));
  }

  InputDecoration _inputDecoration(IconData icon,
      {String? prefix, String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: const Color(0xFF4A76A8)),
      prefixText: prefix,
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!)),
    );
  }
}