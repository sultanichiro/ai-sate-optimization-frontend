import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/optimasi_model.dart';
import '../services/api_service.dart';

class RuteDetailScreen extends StatelessWidget {
  final OptimasiResponse result;

  const RuteDetailScreen({super.key, required this.result});

  /// Format angka ke Rupiah: 1500000 → "Rp 1.500.000"
  String _formatRupiah(int nilai) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(nilai)}';
  }

  /// Warna dan emoji berdasarkan kategori
  Map<String, dynamic> _kategoriStyle(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'sepi':
        return {
          'color': const Color(0xFFE53935),
          'bgColor': const Color(0xFFFFEBEE),
          'emoji': '😔',
          'borderColor': const Color(0xFFEF9A9A),
        };
      case 'lumayan':
        return {
          'color': const Color(0xFFF57C00),
          'bgColor': const Color(0xFFFFF3E0),
          'emoji': '🙂',
          'borderColor': const Color(0xFFFFCC80),
        };
      case 'ramai':
        return {
          'color': const Color(0xFF2E7D32),
          'bgColor': const Color(0xFFE8F5E9),
          'emoji': '😄',
          'borderColor': const Color(0xFFA5D6A7),
        };
      case 'sangat menguntungkan':
        return {
          'color': const Color(0xFF1565C0),
          'bgColor': const Color(0xFFE3F2FD),
          'emoji': '🤩',
          'borderColor': const Color(0xFF90CAF9),
        };
      default:
        return {
          'color': const Color(0xFF757575),
          'bgColor': const Color(0xFFF5F5F5),
          'emoji': '📊',
          'borderColor': const Color(0xFFBDBDBD),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final rute = result.ruteUntukTampil;
    final katStyle = _kategoriStyle(result.kategori);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Detail Rute Optimal',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Success Banner ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Text('✅', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rute Terbaik Ditemukan!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Ikuti urutan di bawah ini ya!',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Perkiraan Penghasilan Card ---
            if (result.perkiraanPenghasilan > 0 || result.kategori.isNotEmpty)
              _buildPerkiraanPenghasilanCard(result, katStyle),
            if (result.perkiraanPenghasilan > 0 || result.kategori.isNotEmpty)
              const SizedBox(height: 16),

            // --- Statistik Ringkas ---
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    emoji: '📏',
                    label: 'Total Jarak',
                    value: '${result.totalJarakKm.toStringAsFixed(1)} km',
                    color: const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    emoji: '📍',
                    label: 'Jumlah Lokasi',
                    value: '${rute.length} lokasi',
                    color: const Color(0xFF6A1B9A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Rute Step-by-Step ---
            if (rute.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('📍', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'Urutan Lokasi Jualan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mulai dari nomor 1 ya, Pak/Bu!',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    ...rute.asMap().entries.map((entry) {
                      final index = entry.key;
                      final loc = entry.value;
                      final isLast = index == rute.length - 1;

                      int? durasi;
                      double? reward;
                      if (result.durasiRekomendasi.isNotEmpty) {
                        try {
                          final durLoc = result.durasiRekomendasi
                              .firstWhere((d) => d.lokasiId == loc.lokasiId);
                          durasi = durLoc.durasiMenit;
                          reward = durLoc.reward;
                        } catch (_) {}
                      }

                      return _buildRouteStep(loc, isLast, durasi, reward);
                    }),
                  ],
                ),
              ),
            ] else ...[
              _buildEmptyRoute(),
            ],
            const SizedBox(height: 16),

            // --- Penjelasan AI ---
            if (result.penjelasan.isNotEmpty) ...[
              _buildPenjelasanCard(result.penjelasan),
              const SizedBox(height: 16),
            ] else if (result.rekomendasi.isNotEmpty) ...[
              _buildRekomendasiCard(result.rekomendasi),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  showDialog(
                    context: context, 
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator())
                  );
                  final raw = await ApiService.startOptimasi({
                    'max_episodes': 100,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context); // close dialog
                  
                  if (raw['success'] == true) {
                    final response = OptimasiResponse.fromJson(raw);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RuteDetailScreen(result: response),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal membuat rute baru.')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cari Rute Lagi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPerkiraanPenghasilanCard(
    OptimasiResponse result,
    Map<String, dynamic> katStyle,
  ) {
    final katColor = katStyle['color'] as Color;
    final katBg = katStyle['bgColor'] as Color;
    final katEmoji = katStyle['emoji'] as String;
    final katBorder = katStyle['borderColor'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: katBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: katBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: katColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(katEmoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perkiraan Hari Ini',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: katColor.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    result.kategori.isNotEmpty ? result.kategori : '-',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: katColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'Perkiraan Penghasilan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRupiah(result.perkiraanPenghasilan),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: katColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenjelasanCard(String penjelasan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('💡', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Analisis AI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B5E20),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            penjelasan,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2E7D32),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRekomendasiCard(String rekomendasi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF57F17).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('💡', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Saran dari AI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE65100),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rekomendasi,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4E342E),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String emoji,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(RuteLokasiResponse loc, bool isLast, int? durasi, double? reward) {
    final stepColors = [
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFF4E342E),
    ];
    final colorIndex = (loc.urutan - 1) % stepColors.length;
    final color = stepColors[colorIndex];

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${loc.urutan}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Text('📌', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.nama,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          if (loc.jarakDariSebelumnya > 0)
                            Text(
                              '${loc.jarakDariSebelumnya.toStringAsFixed(1)} km dari sebelumnya',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          if (durasi != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined,
                                          size: 14, color: color),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Mangkal ~ $durasi menit',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (reward != null && reward > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.monetization_on_outlined,
                                            size: 14, color: color),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Estimasi: ${_formatRupiah(reward.round())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyRoute() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Rute belum tersedia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pastikan Anda sudah menambahkan\nlokasi jualan terlebih dahulu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
