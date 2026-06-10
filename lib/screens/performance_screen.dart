import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  List<dynamic> performaData = [];
  bool isLoading = true;
  int totalPendapatan = 0;
  int totalTransaksi = 0;
  double maxPendapatan = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final response = await ApiService.getPerformaPenjualan(days: 7);
    if (response['success'] == true) {
      final data = response['data'] as List<dynamic>? ?? [];
      int tempTotalPendapatan = 0;
      int tempTotalTransaksi = 0;
      double tempMax = 0;

      for (var item in data) {
        final pendapatan = ((item['total_pendapatan'] ?? 0) as num).toInt();
        final transaksi = ((item['total_transaksi'] ?? 0) as num).toInt();
        tempTotalPendapatan += pendapatan;
        tempTotalTransaksi += transaksi;
        if (pendapatan.toDouble() > tempMax) tempMax = pendapatan.toDouble();
      }

      setState(() {
        performaData = data;
        totalPendapatan = tempTotalPendapatan;
        totalTransaksi = tempTotalTransaksi;
        maxPendapatan = tempMax;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal memuat data')),
        );
      }
    }
  }

  String _getDayName(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      switch (date.weekday) {
        case 1: return 'Sen';
        case 2: return 'Sel';
        case 3: return 'Rab';
        case 4: return 'Kam';
        case 5: return 'Jum';
        case 6: return 'Sab';
        case 7: return 'Min';
        default: return '';
      }
    } catch (e) {
      return '';
    }
  }

  /// Format angka ke Rupiah: 1500000 → "Rp 1.500.000"
  String _formatRupiah(int nilai) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(nilai)}';
  }

  /// Format singkat untuk tooltip chart: 150000 → "150rb"
  String _formatRupiahSingkat(int nilai) {
    if (nilai >= 1000000) {
      final juta = nilai / 1000000;
      return '${juta.toStringAsFixed(juta == juta.roundToDouble() ? 0 : 1)} jt';
    } else if (nilai >= 1000) {
      final ribu = nilai / 1000;
      return '${ribu.toStringAsFixed(ribu == ribu.roundToDouble() ? 0 : 1)} rb';
    }
    return nilai.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Performa Penjualan"), elevation: 0),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Summary Cards
            Row(
              children: [
                _buildSummaryCard(
                  context,
                  "Total Pendapatan (7 hari)",
                  _formatRupiah(totalPendapatan), 
                  Icons.attach_money,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryCard(
                  context,
                  "Total Transaksi (7 hari)",
                  '$totalTransaksi konsumen',
                  Icons.people_outline,
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 2. Weekly Sales Chart
            const Text(
              "Pendapatan Harian (7 Hari Terakhir)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (performaData.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Belum ada data penjualan."),
              ))
            else
              AspectRatio(
                aspectRatio: 1.5,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxPendapatan + (maxPendapatan * 0.2) + 10,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            _formatRupiahSingkat(rod.toY.round()),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() >= 0 && value.toInt() < performaData.length) {
                              final data = performaData[value.toInt()];
                              final dateString = data['tanggal']?.toString() ?? '';
                              final text = _getDayName(dateString);
                              return SideTitleWidget(
                                meta: meta,
                                space: 4,
                                child: Text(
                                  text, 
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                    barGroups: performaData.asMap().entries.map((entry) {
                      final pendapatan = (entry.value['total_pendapatan'] ?? 0).toDouble();
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: pendapatan,
                            color: pendapatan == maxPendapatan && maxPendapatan > 0
                                ? Colors.orange
                                : Colors.blueAccent,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Grafik menampilkan total pendapatan harian dalam 7 hari terakhir.",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
