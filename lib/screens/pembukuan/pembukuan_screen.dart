import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pembukuan_provider.dart';
import '../../models/pembukuan.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus semua karakter non-digit
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Format dengan titik sebagai pemisah ribuan
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
      if (i > 0 && i % 3 == 0) {
        formatted.add('.');
      }
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

class _PembukuanScreenState extends State<PembukuanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
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
    await Provider.of<PembukuanProvider>(context, listen: false).loadPembukuan();
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('').reversed.toList();
    final formatted = <String>[];
    
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted.add('.');
      }
      formatted.add(parts[i]);
    }
    
    return 'Rp ${formatted.reversed.join()}';
  }

  String _formatNumberWithDots(double number) {
    final parts = number.toStringAsFixed(0).split('').reversed.toList();
    final formatted = <String>[];
    
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted.add('.');
      }
      formatted.add(parts[i]);
    }
    
    return formatted.reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final pembukuanProvider = Provider.of<PembukuanProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pembukuan'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 15,
          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
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
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Catatan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap tombol + untuk menambah',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildPembukuanCard(items[index]);
        },
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon dengan gradient
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
                    color: (isPemasukan ? Colors.green : Colors.red).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isPemasukan ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPemasukan ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pembukuan.kategori,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPemasukan ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        formatter.format(pembukuan.tanggal),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pembukuan.keterangan,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(pembukuan.nominal),
                    style: TextStyle(
                      color: isPemasukan ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Menu button
            PopupMenuButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.more_vert, color: Colors.grey[700], size: 20),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue[700]),
                      ),
                      const SizedBox(width: 12),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red[700]),
                      ),
                      const SizedBox(width: 12),
                      Text('Hapus', style: TextStyle(color: Colors.red[700])),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showFormDialog(pembukuan: pembukuan);
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

  void _showFormDialog({Pembukuan? pembukuan}) {
    final formKey = GlobalKey<FormState>();
    final nominalController = TextEditingController(
      text: pembukuan != null ? _formatNumberWithDots(pembukuan.nominal) : '',
    );
    final kategoriController = TextEditingController(
      text: pembukuan?.kategori ?? '',
    );
    final keteranganController = TextEditingController(
      text: pembukuan?.keterangan ?? '',
    );
    String jenis = pembukuan?.jenis ?? 'pemasukan';
    DateTime tanggal = pembukuan?.tanggal ?? DateTime.now();

    double _parseFormattedNumber(String text) {
      final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
      return digitsOnly.isEmpty ? 0 : double.parse(digitsOnly);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            pembukuan == null ? Icons.add_rounded : Icons.edit_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            pembukuan == null ? 'Tambah Pembukuan' : 'Edit Pembukuan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  
                  // Form Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Jenis
                        DropdownButtonFormField<String>(
                          value: jenis,
                          decoration: InputDecoration(
                            labelText: 'Jenis',
                            prefixIcon: Icon(
                              Icons.category_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pemasukan',
                              child: Row(
                                children: [
                                  Icon(Icons.trending_up, color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text('Pemasukan'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'pengeluaran',
                              child: Row(
                                children: [
                                  Icon(Icons.trending_down, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Pengeluaran'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => jenis = value!);
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Nominal
                        TextFormField(
                          controller: nominalController,
                          decoration: InputDecoration(
                            labelText: 'Nominal',
                            prefixIcon: Icon(
                              Icons.payments_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            prefixText: 'Rp ',
                            prefixStyle: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nominal wajib diisi';
                            }
                            final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                            if (digitsOnly.isEmpty || int.parse(digitsOnly) <= 0) {
                              return 'Nominal harus lebih dari 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Kategori
                        TextFormField(
                          controller: kategoriController,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            prefixIcon: Icon(
                              Icons.label_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kategori wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Keterangan
                        TextFormField(
                          controller: keteranganController,
                          decoration: InputDecoration(
                            labelText: 'Keterangan',
                            prefixIcon: Icon(
                              Icons.notes_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
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
                              setDialogState(() => tanggal = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd MMMM yyyy').format(tanggal),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Spacer(),
                                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
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
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Batal'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;

                                  final newPembukuan = Pembukuan(
                                    id: pembukuan?.id,
                                    jenis: jenis,
                                    tanggal: tanggal,
                                    nominal: _parseFormattedNumber(nominalController.text),
                                    kategori: kategoriController.text,
                                    keterangan: keteranganController.text,
                                  );

                                  final pembukuanProvider = Provider.of<PembukuanProvider>(
                                    context,
                                    listen: false,
                                  );

                                  final success = pembukuan == null
                                      ? await pembukuanProvider.addPembukuan(newPembukuan)
                                      : await pembukuanProvider.updatePembukuan(newPembukuan);

                                  if (!context.mounted) return;

                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            success ? Icons.check_circle : Icons.error,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            success
                                                ? 'Pembukuan berhasil disimpan'
                                                : 'Gagal menyimpan pembukuan',
                                          ),
                                        ],
                                      ),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
        ),
      ),
    );
  }

  void _showDeleteDialog(Pembukuan pembukuan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red[700], size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Hapus Pembukuan')),
          ],
        ),
        content: const Text('Yakin ingin menghapus catatan ini? Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await Provider.of<PembukuanProvider>(
                context,
                listen: false,
              ).deletePembukuan(pembukuan.id!);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(success ? 'Pembukuan berhasil dihapus' : 'Gagal menghapus pembukuan'),
                    ],
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}