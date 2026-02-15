import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pembukuan_provider.dart';  // PERBAIKI INI (tambah ../)
import '../../models/pembukuan.dart';               // PERBAIKI INI (tambah ../)

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showTemplateForm({TransaksiTemplate? template}) {
    final isEdit = template != null;
    final formKey = GlobalKey<FormState>();
    
    final namaController = TextEditingController(text: template?.nama ?? '');
    String selectedJenis = template?.jenis ?? 'pengeluaran';
    final nominalController = TextEditingController(
      text: template?.nominal.toStringAsFixed(0) ?? ''
    );
    final kategoriController = TextEditingController(text: template?.kategori ?? '');
    final keteranganController = TextEditingController(text: template?.keterangan ?? '');
    int selectedDate = template?.tanggalBerulang ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Template' : 'Tambah Template'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Template',
                      hintText: 'Misal: Listrik Bulanan'
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedJenis,
                    items: ['pemasukan', 'pengeluaran'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value[0].toUpperCase() + value.substring(1)),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedJenis = val!),
                    decoration: const InputDecoration(labelText: 'Jenis'),
                  ),
                  TextFormField(
                    controller: nominalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      prefixText: 'Rp '
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: kategoriController,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                  ),
                  TextFormField(
                    controller: keteranganController,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                  ),
                  DropdownButtonFormField<int>(
                    value: selectedDate,
                    items: List.generate(31, (i) => i + 1).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('Tanggal $value setiap bulan'),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedDate = val!),
                    decoration: const InputDecoration(labelText: 'Berulang Setiap'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final newTemplate = TransaksiTemplate(
                    id: template?.id,
                    nama: namaController.text,
                    jenis: selectedJenis,
                    nominal: double.parse(nominalController.text),
                    kategori: kategoriController.text.isEmpty ? 'Umum' : kategoriController.text,
                    keterangan: keteranganController.text.isEmpty ? '-' : keteranganController.text,
                    tanggalBerulang: selectedDate,
                    isActive: template?.isActive ?? true,
                  );

                  final provider = Provider.of<PembukuanProvider>(context, listen: false);
                  if (isEdit) {
                    provider.updateTemplate(newTemplate);
                  } else {
                    provider.addTemplate(newTemplate);
                  }

                  Navigator.pop(context);
                  _showSnackBar('Template berhasil disimpan');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTemplate(TransaksiTemplate template) {
    final updated = TransaksiTemplate(
      id: template.id,
      nama: template.nama,
      jenis: template.jenis,
      nominal: template.nominal,
      kategori: template.kategori,
      keterangan: template.keterangan,
      tanggalBerulang: template.tanggalBerulang,
      isActive: !template.isActive,
    );
    Provider.of<PembukuanProvider>(context, listen: false).updateTemplate(updated);
  }

  void _deleteTemplate(TransaksiTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Template?'),
        content: Text('Template "${template.nama}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<PembukuanProvider>(context, listen: false)
                  .deleteTemplate(template.id!);
              Navigator.pop(context);
              _showSnackBar('Template berhasil dihapus');
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PembukuanProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Transaksi Berulang'),
      ),
      body: provider.templateList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada template',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Template otomatis menambah transaksi\nrutin seperti gaji, listrik, dll',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.templateList.length,
              itemBuilder: (context, index) {
                final template = provider.templateList[index];
                return Card(
                  child: ListTile(
                    leading: Switch(
                      value: template.isActive,
                      onChanged: (_) => _toggleTemplate(template),
                    ),
                    title: Text(template.nama),
                    subtitle: Text(
                      '${template.kategori} • Tanggal ${template.tanggalBerulang}\n${template.keterangan}',
                    ),
                    trailing: Text(
                      _formatCurrency(template.nominal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: template.jenis == 'pemasukan' 
                            ? Colors.green[700] 
                            : Colors.red[700],
                      ),
                    ),
                    onTap: () => _showTemplateForm(template: template),
                    onLongPress: () => _deleteTemplate(template),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTemplateForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}