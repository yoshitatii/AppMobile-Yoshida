import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/barang.dart';
import '../../providers/barang_provider.dart';
import 'barcode_scanner_screen.dart';

class BarangFormScreen extends StatefulWidget {
  final Barang? barang;
  const BarangFormScreen({super.key, this.barang});

  @override
  State<BarangFormScreen> createState() => _BarangFormScreenState();
}

class _BarangFormScreenState extends State<BarangFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _kodeController;
  late TextEditingController _namaController;
  late TextEditingController _hargaBeliController;
  late TextEditingController _hargaJualController;
  late TextEditingController _stokController;
  // Tambahkan controller untuk isi per satuan (Contoh: 1 Box isi 24)
  late TextEditingController _isiController; 
  
  String? _selectedKategori;
  final List<String> _categories = ['Sembako', 'Makeup', 'Alat Tulis', 'Makanan', 'Minuman', 'Lainnya'];
  
  // Sesuai permintaan: Hanya PCS, PACK, BOX
  String _selectedSatuan = 'pcs';
  final List<String> _units = ['pcs', 'pack', 'box'];

  @override
  void initState() {
    super.initState();
    _kodeController = TextEditingController(text: widget.barang?.kode ?? '');
    _namaController = TextEditingController(text: widget.barang?.nama ?? '');
    _hargaBeliController = TextEditingController(text: widget.barang != null ? _formatNumber(widget.barang!.hargaBeli.toStringAsFixed(0)) : '');
    _hargaJualController = TextEditingController(text: widget.barang != null ? _formatNumber(widget.barang!.hargaJual.toStringAsFixed(0)) : '');
    _stokController = TextEditingController(text: widget.barang?.stok.toString() ?? '');
    
    // Default isi adalah 1 (jika pcs), atau ambil dari data lama (tambahkan field isi di model nanti)
    _isiController = TextEditingController(text: '1'); 
    
    _selectedSatuan = widget.barang?.satuan ?? 'pcs';
    _selectedKategori = widget.barang?.kategori;
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  String _formatNumber(String s) => s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

  Future<void> _onScanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      _kodeController.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.barang == null ? 'Tambah Barang' : 'Edit Barang', 
          style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RepaintBoundary(
              child: OutlinedButton.icon(
                onPressed: _onScanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('SCAN BARCODE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            _buildSimpleField(_kodeController, 'Kode Barang *', Icons.grid_view_rounded),
            const SizedBox(height: 12),
            _buildSimpleField(_namaController, 'Nama Barang *', Icons.shopping_bag_outlined),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedKategori,
              decoration: _inputDecoration('Kategori *', Icons.category_outlined),
              items: _categories.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) => setState(() => _selectedKategori = v),
              validator: (v) => v == null ? 'Wajib' : null,
            ),

            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 0.5)),

            Row(
              children: [
                Expanded(child: _buildSimpleField(_hargaBeliController, 'Harga Beli', Icons.attach_money, isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildSimpleField(_hargaJualController, 'Harga Jual', Icons.label_outline, isNumber: true)),
              ],
            ),
            const SizedBox(height: 12),

            // BAGIAN STOK DAN SATUAN (PACK/BOX)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildSimpleField(_stokController, 'Stok (Total Pcs)', Icons.inventory_2_outlined, isNumber: true)),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSatuan,
                    decoration: _inputDecoration('Satuan', null),
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase()))).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedSatuan = v!;
                        // Reset isi jika satuan balik ke pcs
                        if (_selectedSatuan == 'pcs') _isiController.text = '1';
                      });
                    },
                  ),
                ),
              ],
            ),

            // KOTAK PENJELASAN (Hanya muncul jika bukan PCS)
            if (_selectedSatuan != 'pcs') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Konversi 1 ${_selectedSatuan.toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text("1 ${_selectedSatuan} = ", style: TextStyle(fontSize: 14)),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            controller: _isiController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        Text(" Pcs", style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "* Kasir akan mengurangi stok otomatis berdasarkan angka ini.",
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
            
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SIMPAN DATA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UI Helpers (Tetap sama)
  InputDecoration _inputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildSimpleField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return RepaintBoundary(
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [
          FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((oldValue, newValue) {
            if (newValue.text.isEmpty) return newValue;
            final int? num = int.tryParse(newValue.text.replaceAll('.', ''));
            if (num == null) return oldValue;
            final String formatted = _formatNumber(num.toString());
            return newValue.copyWith(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
          }),
        ] : [],
        decoration: _inputDecoration(label, icon),
        validator: (v) => v!.isEmpty ? 'Wajib' : null,
      ),
    );
  }

  void _simpan() async {
    if (_formKey.currentState!.validate()) {
      // Logic: Kita simpan isi satuan ke database (pastikan model Barang sudah punya field ini)
      final barang = Barang(
        id: widget.barang?.id,
        kode: _kodeController.text,
        nama: _namaController.text,
        hargaBeli: double.tryParse(_hargaBeliController.text.replaceAll('.', '')) ?? 0,
        hargaJual: double.tryParse(_hargaJualController.text.replaceAll('.', '')) ?? 0,
        stok: int.tryParse(_stokController.text.replaceAll('.', '')) ?? 0,
        satuan: _selectedSatuan,
        kategori: _selectedKategori ?? 'Lainnya',
        // Opsional: Jika kamu ingin menyimpan nilai konversi ke database
        // isiSatuan: int.tryParse(_isiController.text) ?? 1, 
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