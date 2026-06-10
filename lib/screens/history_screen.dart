import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';
import '../services/api_service.dart';
import '../models/transaction_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Penjualan"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: const TransactionHistoryList(),
    );
  }
}

class TransactionHistoryList extends StatefulWidget {
  const TransactionHistoryList({super.key});

  @override
  State<TransactionHistoryList> createState() => _TransactionHistoryListState();
}

class _TransactionHistoryListState extends State<TransactionHistoryList> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _penjualanList = [];
  Map<String, String> _lokasiMap = {};
  
  // Filters
  int? _selectedLokasiId;
  int? _selectedHariKuliah;
  int _limit = 20;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        ApiService.getKunjungan(
          limit: _limit,
          lokasiId: _selectedLokasiId,
          hariKuliah: _selectedHariKuliah,
        ),
        ApiService.getLokasi(),
      ]);

      final penjualanResult = results[0];
      final lokasiResult = results[1];

      if (penjualanResult['success'] == true &&
          lokasiResult['success'] == true) {
        final List<dynamic> penjualanData = penjualanResult['data'] ?? [];
        final List<dynamic> lokasiData = lokasiResult['data'] ?? [];

        Map<String, String> tempLokasiMap = {};
        for (var loc in lokasiData) {
          tempLokasiMap[loc['id'].toString()] =
              loc['nama']?.toString() ?? 'Lokasi Tidak Diketahui';
        }

        // Urutkan dari yang terbaru ke terlama
        penjualanData.sort((a, b) {
          final t1 = DateTime.tryParse(a['waktu_mulai']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final t2 = DateTime.tryParse(b['waktu_mulai']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return t2.compareTo(t1);
        });

        if (mounted) {
          setState(() {
            _penjualanList = penjualanData;
            _lokasiMap = tempLokasiMap;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                penjualanResult['message'] ??
                lokasiResult['message'] ??
                'Gagal memuat data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }



  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Lokasi Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedLokasiId,
                  hint: const Text("Semua Lokasi", style: TextStyle(fontSize: 14)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text("Semua Lokasi", style: TextStyle(fontSize: 14))),
                    ..._lokasiMap.entries.map((e) => DropdownMenuItem<int?>(
                      value: int.tryParse(e.key),
                      child: Text(e.value, style: const TextStyle(fontSize: 14)),
                    ))
                  ],
                  onChanged: (val) {
                    setState(() { _selectedLokasiId = val; });
                    _fetchData();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Hari Kuliah Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedHariKuliah,
                  hint: const Text("Semua Hari", style: TextStyle(fontSize: 14)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  items: const [
                    DropdownMenuItem<int?>(value: null, child: Text("Semua Hari", style: TextStyle(fontSize: 14))),
                    DropdownMenuItem<int?>(value: 1, child: Text("Hari Kuliah", style: TextStyle(fontSize: 14))),
                    DropdownMenuItem<int?>(value: 0, child: Text("Hari Libur", style: TextStyle(fontSize: 14))),
                  ],
                  onChanged: (val) {
                    setState(() { _selectedHariKuliah = val; });
                    _fetchData();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Limit Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _limit,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  items: const [
                    DropdownMenuItem<int>(value: 10, child: Text("10 Data", style: TextStyle(fontSize: 14))),
                    DropdownMenuItem<int>(value: 20, child: Text("20 Data", style: TextStyle(fontSize: 14))),
                    DropdownMenuItem<int>(value: 50, child: Text("50 Data", style: TextStyle(fontSize: 14))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() { _limit = val; });
                      _fetchData();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
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
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_penjualanList.isEmpty) {
      return _buildEmptyState("Belum ada riwayat penjualan");
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _penjualanList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _penjualanList[index];
          return _buildPenjualanCard(item);
        },
      ),
    );
  }

  Widget _buildPenjualanCard(Map<String, dynamic> item) {
    final lokasiId = item['lokasi_id']?.toString() ?? '';
    final namaLokasi = _lokasiMap[lokasiId] ?? 'Lokasi Tidak Diketahui';
    final waktu = item['waktu_mulai']?.toString() ?? '-';

    String formattedTime = waktu;
    try {
      final dt = DateTime.parse(waktu);
      formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {}

    final jumlahTerjual = item['total_pendapatan'] ?? 0;
    final durasi = item['durasi_mangkal'] ?? 0;
    final cuaca = item['kondisi_cuaca']?.toString() ?? '-';
    final isKuliah = item['hari_kuliah'] == 1 || item['hari_kuliah'] == '1';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            namaLokasi,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedTime,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isKuliah
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isKuliah ? "Hari Kuliah" : "Hari Libur",
                  style: TextStyle(
                    color: isKuliah ? Colors.blue : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                Icons.shopping_bag,
                jumlahTerjual.toString(),
                Colors.green,
              ),
              _buildInfoItem(Icons.timer, "$durasi Jam", Colors.orange),
              _buildInfoItem(Icons.cloud, cuaca, Colors.lightBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

Widget _buildEmptyState(String message) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 18)),
      ],
    ),
  );
}
