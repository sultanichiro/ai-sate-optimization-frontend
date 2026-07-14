import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class HistoryDetailScreen extends StatefulWidget {
  final int sesiId;

  const HistoryDetailScreen({super.key, required this.sesiId});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _sesiData;
  List<dynamic> _kunjunganList = [];
  Map<String, String> _lokasiMap = {};

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        ApiService.getSesiDetail(widget.sesiId),
        ApiService.getLokasi(),
      ]);

      final detailResult = results[0];
      final lokasiResult = results[1];

      if (detailResult['success'] == true && lokasiResult['success'] == true) {
        final Map<String, dynamic> sesiData = detailResult['data'] ?? {};
        final List<dynamic> kunjunganData =
            detailResult['kunjungan_list'] ?? [];
        final List<dynamic> lokasiData = lokasiResult['data'] ?? [];

        Map<String, String> tempLokasiMap = {};
        for (var loc in lokasiData) {
          tempLokasiMap[loc['id'].toString()] =
              loc['nama']?.toString() ?? 'Lokasi Tidak Diketahui';
        }

        if (mounted) {
          setState(() {
            _sesiData = sesiData;
            _kunjunganList = kunjunganData;
            _lokasiMap = tempLokasiMap;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                detailResult['message'] ??
                lokasiResult['message'] ??
                'Gagal memuat detail sesi';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detail Sesi Penjualan")),
      body: _buildBody(),
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
            ElevatedButton(
              onPressed: _fetchDetail,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_sesiData == null) {
      return const Center(child: Text("Data sesi tidak ditemukan"));
    }

    return Column(
      children: [
        _buildSesiHeader(),
        Expanded(child: _buildKunjunganList()),
      ],
    );
  }

  Widget _buildSesiHeader() {
    final waktuMulai = _sesiData!['waktu_mulai']?.toString() ?? '-';
    String formattedDate = waktuMulai;
    try {
      final dt = DateTime.parse(waktuMulai);
      formattedDate = DateFormat('EEEE dd-MM-yyyy', 'id').format(dt);
    } catch (_) {}

    final totalPendapatan = _sesiData!['total_pendapatan'] ?? 0;
    final totalTransaksi = _sesiData!['total_transaksi'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat(
                "Total Pendapatan",
                NumberFormat.currency(
                  locale: 'id',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(totalPendapatan),
                Icons.account_balance_wallet,
              ),
              _buildHeaderStat(
                "Total Pembeli",
                "$totalTransaksi",
                Icons.people,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKunjunganList() {
    if (_kunjunganList.isEmpty) {
      return const Center(
        child: Text("Belum ada lokasi yang dikunjungi pada sesi ini."),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kunjunganList.length,
      itemBuilder: (context, index) {
        final item = _kunjunganList[index];
        final lokasiId = item['lokasi_id']?.toString() ?? '';
        final namaLokasi = _lokasiMap[lokasiId] ?? 'Lokasi Tidak Diketahui';

        final waktuMulai = item['waktu_mulai']?.toString() ?? '-';
        final waktuSelesai = item['waktu_selesai']?.toString();
        
        String formattedTime = waktuMulai;
        try {
          final dtMulai = DateTime.parse(waktuMulai);
          final jamMulai = DateFormat('HH.mm').format(dtMulai);
          
          String jamSelesai = "Sekarang";
          if (waktuSelesai != null && waktuSelesai != 'null' && waktuSelesai != '-') {
            final dtSelesai = DateTime.parse(waktuSelesai);
            jamSelesai = DateFormat('HH.mm').format(dtSelesai);
          }
          
          formattedTime = "$jamMulai - $jamSelesai";
        } catch (_) {}

        final totalPendapatan = item['total_pendapatan'] ?? 0;
        final durasi = item['durasi_mangkal'] ?? 0.0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        namaLokasi,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      Icons.account_balance_wallet,
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(totalPendapatan),
                      Colors.green,
                    ),
                    _buildStatItem(
                      Icons.timer,
                      "${durasi.toStringAsFixed(1)} Jam",
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
