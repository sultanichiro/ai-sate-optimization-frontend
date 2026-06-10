import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'add_lokasi_screen.dart';
import 'edit_lokasi_screen.dart';

class LokasiScreen extends StatefulWidget {
  const LokasiScreen({super.key});

  @override
  State<LokasiScreen> createState() => _LokasiScreenState();
}

class _LokasiScreenState extends State<LokasiScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _lokasiList = [];

  @override
  void initState() {
    super.initState();
    _fetchLokasi();
  }

  Future<void> _fetchLokasi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await ApiService.getLokasi();

    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _lokasiList = result['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal mengambil data lokasi';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLokasi(String id) async {
    // Tampilkan dialog konfirmasi
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Lokasi'),
        content: const Text('Apakah Anda yakin ingin menghapus lokasi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final result = await ApiService.deleteLokasi(id);
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Lokasi berhasil dihapus'), backgroundColor: Colors.green),
          );
          _fetchLokasi(); // Muat ulang data
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Gagal menghapus lokasi'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Lokasi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLokasi,
            tooltip: 'Segarkan',
          )
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigasi ke tambah lokasi dan fetch ulang jika kembali dengan true
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLokasiScreen()),
          );
          if (result == true) {
            _fetchLokasi();
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Tambah Lokasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchLokasi, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_lokasiList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada lokasi tersimpan.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLokasi,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
        itemCount: _lokasiList.length,
        itemBuilder: (context, index) {
          final lokasi = _lokasiList[index];
          final id = lokasi['id'].toString();
          
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(Icons.storefront, color: Theme.of(context).primaryColor),
              ),
              title: Text(
                lokasi['nama'] ?? 'Lokasi Tanpa Nama',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Lat: ${lokasi['latitude']}\nLng: ${lokasi['longitude']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditLokasiScreen(lokasi: lokasi)),
                      );
                      if (result == true) {
                        _fetchLokasi();
                      }
                    },
                    tooltip: 'Edit Lokasi',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteLokasi(id),
                    tooltip: 'Hapus Lokasi',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
