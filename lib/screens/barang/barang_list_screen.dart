import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/barang_provider.dart';
import '../../models/barang.dart';
import 'barang_form_screen.dart';

class BarangListScreen extends StatefulWidget {
  const BarangListScreen({super.key});

  @override
  State<BarangListScreen> createState() => _BarangListScreenState();
}

class _BarangListScreenState extends State<BarangListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Memanggil data saat pertama kali halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarangProvider>().loadBarang();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi navigasi yang menunggu hasil balik dari form untuk refresh data
  Future<void> _navigasiKeForm([Barang? barang]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BarangFormScreen(barang: barang)),
    );
    // Setelah balik ke sini, paksa refresh data agar perubahan langsung muncul
    if (mounted) {
      context.read<BarangProvider>().loadBarang(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Data Barang', style: TextStyle(fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Kotak Pencarian (Search Bar)
          Container(
            color: Colors.blue[800],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                // Memicu Consumer di bawah untuk memfilter ulang list
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Cari nama atau kode...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // 2. Area Consumer (Loading, Kosong, atau Daftar Data)
          Expanded(
            child: Consumer<BarangProvider>(
              builder: (context, provider, child) {
                
                // A. Kondisi jika sedang loading
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // B. Ambil data yang sudah difilter oleh Provider
                final list = provider.filterBarang(_searchController.text);

                // C. Kondisi jika data kosong atau tidak ditemukan
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty 
                              ? "Belum ada data barang" 
                              : "Barang tidak ditemukan",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // D. Kondisi jika data ada, tampilkan ListView
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return BarangItemTile(
                      key: ValueKey(item.id),
                      barang: item,
                      onTap: () => _navigasiKeForm(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[800],
        onPressed: () => _navigasiKeForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Widget satuan untuk tiap baris barang
class BarangItemTile extends StatelessWidget {
  final Barang barang;
  final VoidCallback onTap;

  const BarangItemTile({
    super.key, 
    required this.barang, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey[50],
          child: Text(
            barang.nama.isNotEmpty ? barang.nama[0].toUpperCase() : '?', 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)
          ),
        ),
        title: Text(
          barang.nama, 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Stok: ${barang.stok} | Kode: ${barang.kode}", 
            style: const TextStyle(fontSize: 12, color: Colors.grey)
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Harga
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Rp ${barang.hargaJual.toInt()}", 
                style: TextStyle(
                  color: Colors.green[700], 
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Menu Button
            PopupMenuButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Text('Hapus', style: TextStyle(color: Colors.red[700])),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  onTap(); // Buka form edit
                } else if (value == 'delete') {
                  _showDeleteDialog(context, barang);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Barang barang) {
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
            const Expanded(child: Text('Hapus Barang')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yakin ingin menghapus barang ini?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    barang.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kode: ${barang.kode}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data yang dihapus tidak dapat dikembalikan.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await Provider.of<BarangProvider>(
                context,
                listen: false,
              ).deleteBarang(barang.id!);

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        success ? Icons.check_circle : Icons.error,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(success ? 'Barang berhasil dihapus' : 'Gagal menghapus barang'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}