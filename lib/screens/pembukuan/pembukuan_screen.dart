import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pembukuan_provider.dart';
import '../../models/pembukuan.dart';

class PembukuanScreen extends StatefulWidget {
  const PembukuanScreen({super.key});

  @override
  State<PembukuanScreen> createState() => _PembukuanScreenState();
}

class _PembukuanScreenState extends State<PembukuanScreen> {
  // Secara otomatis filter awal nampilin 'pemasukan'
  String _selectedFilter = 'pemasukan'; 

  // Fungsi format rupiah dengan titik (contoh: 2.000.000)
  String formatRupiah(double nominal) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(nominal);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PembukuanProvider>(context);
    
    // LOGIKA OTOMATIS: Filter list berdasarkan kotak mana yang aktif (diklik)
    final filteredList = provider.pembukuanList
        .where((item) => item.jenis.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Pembukuan", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf, color: Colors.black)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KOTAK RINGKASAN (Klik di sini untuk ganti tampilan list secara otomatis)
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Daftar ${_selectedFilter.toUpperCase()}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ),

          // LIST YANG BISA DI-SCROLL
          Expanded(
            child: filteredList.isEmpty
                ? Center(child: Text("Belum ada data $_selectedFilter"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
        label: const Text("Tambah", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // Widget Kotak Pemasukan/Pengeluaran (Berfungsi sebagai Filter)
  Widget _buildSummaryBox({required String label, required double amount, required Color color, required String type}) {
    bool isActive = _selectedFilter == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Text(formatRupiah(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.kategori, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(item.keterangan, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          Text(
            formatRupiah(item.nominal),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: item.jenis == 'pemasukan' ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  // Tampilan Input Sesuai Gambar ke-2
  void _showInputSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ModalTambahPembukuan(),
    );
  }
}

// WIDGET MODAL INPUT (PERSIS GAMBAR KE-2)
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Biru Sesuai Gambar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xFF4A76A8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.add, color: Colors.white)),
                const SizedBox(width: 15),
                const Text("Tambah Pembukuan", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input Jenis
                _buildLabel("Jenis"),
                DropdownButtonFormField<String>(
                  value: _jenis,
                  decoration: _inputDecoration(Icons.category_outlined),
                  items: const [
                    DropdownMenuItem(value: 'pemasukan', child: Text("Pemasukan")),
                    DropdownMenuItem(value: 'pengeluaran', child: Text("Pengeluaran")),
                  ],
                  onChanged: (val) => setState(() => _jenis = val!),
                ),
                
                const SizedBox(height: 15),
                _buildLabel("Nominal"),
                TextField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(Icons.payments_outlined, prefix: "Rp "),
                ),
                
                // Shortcut Nominal Sesuai Gambar
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [10000, 20000, 50000, 100000, 500000].map((val) {
                    return ActionChip(
                      label: Text("Rp ${NumberFormat('#,###', 'id_ID').format(val)}"),
                      onPressed: () => _nominalController.text = val.toString(),
                      backgroundColor: Colors.blue[50],
                      labelStyle: const TextStyle(color: Colors.blue, fontSize: 12),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 15),
                _buildLabel("Kategori"),
                TextField(
                  readOnly: true,
                  decoration: _inputDecoration(Icons.label_important_outline, hint: _kategori),
                ),

                const SizedBox(height: 15),
                _buildLabel("Keterangan"),
                TextField(
                  controller: _ketController,
                  maxLines: 2,
                  decoration: _inputDecoration(Icons.notes, hint: "Contoh: Pembelian stok barang"),
                ),

                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("Batal"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if(_nominalController.text.isEmpty) return;
                          final data = Pembukuan(
                            jenis: _jenis,
                            nominal: double.parse(_nominalController.text),
                            kategori: _kategori,
                            keterangan: _ketController.text,
                            tanggal: DateTime.now(),
                          );
                          context.read<PembukuanProvider>().addPembukuan(data);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[300]!))
                        ),
                        child: const Text("Simpan", style: TextStyle(color: Color(0xFF4A76A8), fontWeight: FontWeight.bold)),
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
    return Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)));
  }

  InputDecoration _inputDecoration(IconData icon, {String? prefix, String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: const Color(0xFF4A76A8)),
      prefixText: prefix,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
    );
  }
}