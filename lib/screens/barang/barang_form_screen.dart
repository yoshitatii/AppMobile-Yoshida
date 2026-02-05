import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/barang.dart';
import '../../providers/barang_provider.dart';
import 'barcode_scanner_screen.dart'; // Import layar scannermu beb

class BarangFormScreen extends StatefulWidget {
  final Barang? barang;
  const BarangFormScreen({super.key, this.barang});

  @override
  State<BarangFormScreen> createState() => _BarangFormScreenState();
}

class _BarangFormScreenState extends State<BarangFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  final _hargaBeliController = TextEditingController();
  final _hargaJualController = TextEditingController();
  final _stokController = TextEditingController();
  
  // List Kategori sesuai permintaanmu beb
  String? _selectedKategori;
  final List<String> _categories = ['Sembako', 'Makeup', 'Alat Tulis', 'Makanan', 'Minuman', 'Lainnya'];
  
  String _selectedSatuan = 'pcs';
  final List<String> _units = ['pcs', 'kg', 'liter', 'box', 'pack'];

  @override
  void initState() {
    super.initState();
    if (widget.barang != null) {
      _kodeController.text = widget.barang!.kode;
      _namaController.text = widget.barang!.nama;
      _hargaBeliController.text = _formatNumber(widget.barang!.hargaBeli.toStringAsFixed(0));
      _hargaJualController.text = _formatNumber(widget.barang!.hargaJual.toStringAsFixed(0));
      _stokController.text = widget.barang!.stok.toString();
      _selectedSatuan = widget.barang!.satuan;
      _selectedKategori = widget.barang!.kategori;
    }
  }

  // Fungsi Format Titik (19.000)
  String _formatNumber(String s) => s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

  // FUNGSI SCAN BARCODE
  Future<void> _onScanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _kodeController.text = result; // Masukkan hasil scan ke kolom Kode Barang
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.barang == null ? 'Tambah Barang' : 'Edit Barang', style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // HEADER CARD
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add_box, color: Colors.blue),
                    ),
                    const SizedBox(width: 15),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tambah Barang Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Scan barcode atau input manual', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // TOMBOL SCAN BARCODE BIRU
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _onScanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('SCAN BARCODE', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("ATAU INPUT MANUAL", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))), Expanded(child: Divider())]),
              const SizedBox(height: 25),

              // INPUT KODE BARANG
              _buildTextField(_kodeController, 'Kode Barang *', Icons.grid_view_rounded),
              const SizedBox(height: 20),

              // INPUT NAMA BARANG
              _buildTextField(_namaController, 'Nama Barang *', Icons.shopping_bag_outlined),
              const SizedBox(height: 20),

              // DROPDOWN KATEGORI
              DropdownButtonFormField<String>(
                value: _selectedKategori,
                decoration: InputDecoration(
                  labelText: 'Kategori Barang *',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                hint: const Text('Pilih kategori'),
                items: _categories.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (v) => setState(() => _selectedKategori = v),
                validator: (v) => v == null ? 'Pilih kategori dulu beb' : null,
              ),

              const SizedBox(height: 25),
              const Align(alignment: Alignment.centerLeft, child: Text("HARGA & STOK", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
              const SizedBox(height: 15),

              // HARGA BELI & JUAL
              Row(
                children: [
                  Expanded(child: _buildTextField(_hargaBeliController, 'Harga Beli *', Icons.shopping_cart_outlined, isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField(_hargaJualController, 'Harga Jual *', Icons.label_outline, isNumber: true)),
                ],
              ),
              const SizedBox(height: 20),

              // STOK & SATUAN
              Row(
                children: [
                  Expanded(flex: 2, child: _buildTextField(_stokController, 'Stok Barang *', Icons.inventory_2_outlined, isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _selectedSatuan,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _selectedSatuan = v!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
              
              // TOMBOL SIMPAN
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42709A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SIMPAN DATA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [
        FilteringTextInputFormatter.digitsOnly,
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.isEmpty) return newValue.copyWith(text: '');
          final int num = int.parse(newValue.text.replaceAll('.', ''));
          final String formatted = _formatNumber(num.toString());
          return newValue.copyWith(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
        }),
      ] : [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
    );
  }

  void _simpan() async {
    if (_formKey.currentState!.validate()) {
      final barang = Barang(
        id: widget.barang?.id,
        kode: _kodeController.text,
        nama: _namaController.text,
        hargaBeli: double.parse(_hargaBeliController.text.replaceAll('.', '')),
        hargaJual: double.parse(_hargaJualController.text.replaceAll('.', '')),
        stok: int.parse(_stokController.text.replaceAll('.', '')),
        satuan: _selectedSatuan,
        // Perbaikan error Null Safety di sini beb:
        kategori: _selectedKategori ?? 'Lainnya', 
      );

      final provider = Provider.of<BarangProvider>(context, listen: false);
      if (widget.barang == null) {
        await provider.addBarang(barang);
      } else {
        await provider.updateBarang(barang);
      }
      if (mounted) Navigator.pop(context);
    }
  }
}