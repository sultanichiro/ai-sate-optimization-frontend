import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'optimasi_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToHistory;

  const DashboardScreen({super.key, this.onNavigateToHistory});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // Sesi state
  Map<String, dynamic>? _sesiAktif;
  bool _isLoadingSesi = false;
  bool _isLoadingAction = false;

  // Timer untuk durasi berjalan
  Timer? _durationTimer;
  Duration _elapsedDuration = Duration.zero;

  // Cuaca
  String _selectedCuaca = 'cerah';
  final List<String> _cuacaOptions = ['cerah', 'mendung', 'hujan'];

  @override
  void initState() {
    super.initState();
    _checkSesiAktif();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // API CALLS
  // ============================================================

  Future<void> _checkSesiAktif() async {
    setState(() => _isLoadingSesi = true);
    final result = await ApiService.getSesiAktif();

    if (mounted) {
      setState(() {
        _isLoadingSesi = false;
        if (result['success'] == true && result['data'] != null) {
          _sesiAktif = result['data'];
          _startDurationTimer();
        } else {
          _sesiAktif = null;
        }
      });
    }
  }

  Future<void> _startBerjualan() async {
    setState(() => _isLoadingAction = true);

    final now = DateTime.now();
    final hariKuliah = (now.weekday >= 1 && now.weekday <= 5) ? 1 : 0;

    final data = {
      'kondisi_cuaca': _selectedCuaca,
      'hari_kuliah': hariKuliah,
    };

    final result = await ApiService.startSesi(data);

    if (mounted) {
      setState(() => _isLoadingAction = false);

      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _sesiAktif = result['data'];
          _startDurationTimer();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sesi berjualan dimulai!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memulai sesi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopBerjualan() async {
    // Konfirmasi dulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.stop_circle, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Stop Berjualan?'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengakhiri sesi berjualan hari ini?\n\n'
          'Semua kunjungan aktif akan ditutup dan ringkasan akan ditampilkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Stop'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoadingAction = true);

    final result = await ApiService.stopSesi();

    if (mounted) {
      setState(() => _isLoadingAction = false);

      if (result['success'] == true) {
        _durationTimer?.cancel();
        setState(() {
          _sesiAktif = null;
          _elapsedDuration = Duration.zero;
        });

        // Tampilkan ringkasan
        _showRingkasanDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal stop sesi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startDurationTimer() {
    _durationTimer?.cancel();

    if (_sesiAktif != null && _sesiAktif!['waktu_mulai'] != null) {
      final waktuMulai = DateTime.parse(_sesiAktif!['waktu_mulai']);
      _elapsedDuration = DateTime.now().toUtc().difference(waktuMulai);

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _elapsedDuration += const Duration(seconds: 1);
          });
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // ============================================================
  // RINGKASAN DIALOG
  // ============================================================

  void _showRingkasanDialog(Map<String, dynamic> result) {
    final data = result['data'];
    if (data == null) return;

    final totalPendapatan = data['total_pendapatan'] ?? 0;
    final totalTransaksi = data['total_transaksi'] ?? 0;
    final totalLokasi = data['total_lokasi_dikunjungi'] ?? 0;
    final durasiTotal = data['durasi_total'];

    String durasiText = '-';
    if (durasiTotal != null) {
      final jam = (durasiTotal as num).floor();
      final menit = ((durasiTotal - jam) * 60).round();
      durasiText = '${jam}j ${menit}m';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(0),
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Sesi Selesai!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ringkasan Penjualan Hari Ini',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildRingkasanItem(
                      Icons.payments,
                      'Total Pendapatan',
                      'Rp ${NumberFormat('#,###').format(totalPendapatan)}',
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRingkasanCard(
                            Icons.people,
                            '$totalTransaksi',
                            'Transaksi',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildRingkasanCard(
                            Icons.location_on,
                            '$totalLokasi',
                            'Lokasi',
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildRingkasanCard(
                            Icons.timer,
                            durasiText,
                            'Durasi',
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRingkasanItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRingkasanCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool sesiAktif = _sesiAktif != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Beranda"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _checkSesiAktif,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ApiService.logout();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoadingSesi
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Status Header Card
                  _buildStatusCard(sesiAktif),

                  const SizedBox(height: 20),

                  // 2. Action Button (Start / Stop)
                  _buildActionButton(sesiAktif),

                  const SizedBox(height: 24),

                  // 3. Info sesi aktif (jika ada)
                  if (sesiAktif) _buildSesiInfo(),

                  if (sesiAktif) const SizedBox(height: 24),

                  // 4. Quick actions / Recommendation
                  _buildRecommendationCard(sesiAktif),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // WIDGET BUILDERS
  // ============================================================

  Widget _buildStatusCard(bool sesiAktif) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: sesiAktif
              ? [Colors.green.shade400, Colors.green.shade700]
              : [Colors.blueGrey.shade300, Colors.blueGrey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (sesiAktif ? Colors.green : Colors.blueGrey)
                .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              sesiAktif ? Icons.storefront : Icons.nightlight_round,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sesiAktif ? "SEDANG BERJUALAN" : "BELUM BERJUALAN",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (sesiAktif) ...[
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_elapsedDuration),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Tekan Start untuk mulai berjualan hari ini',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool sesiAktif) {
    if (sesiAktif) {
      // STOP BUTTON
      return SizedBox(
        height: 64,
        child: ElevatedButton.icon(
          onPressed: _isLoadingAction ? null : _stopBerjualan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 4,
          ),
          icon: _isLoadingAction
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Icon(Icons.stop_circle, size: 32),
          label: Text(
            _isLoadingAction ? 'Menghentikan...' : 'STOP BERJUALAN',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    } else {
      // START BUTTON + Cuaca selector
      return Column(
        children: [
          // Cuaca selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud, color: Colors.blue.shade400, size: 22),
                const SizedBox(width: 10),
                Text('Cuaca:',
                    style: TextStyle(
                        color: Colors.grey[700], fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCuaca,
                      isDense: true,
                      items: _cuacaOptions.map((String value) {
                        IconData icon;
                        switch (value) {
                          case 'cerah':
                            icon = Icons.wb_sunny;
                            break;
                          case 'mendung':
                            icon = Icons.cloud;
                            break;
                          case 'hujan':
                            icon = Icons.grain;
                            break;
                          default:
                            icon = Icons.wb_sunny;
                        }
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                value[0].toUpperCase() + value.substring(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCuaca = newValue!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // START button
          SizedBox(
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _isLoadingAction ? null : _startBerjualan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
              icon: _isLoadingAction
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.play_circle_fill, size: 32),
              label: Text(
                _isLoadingAction ? 'Memulai...' : 'START BERJUALAN',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSesiInfo() {
    final waktuMulai = _sesiAktif?['waktu_mulai'] != null
        ? DateFormat('HH:mm').format(
            DateTime.parse(_sesiAktif!['waktu_mulai']).toLocal())
        : '-';
    final totalTransaksi = _sesiAktif?['total_transaksi'] ?? 0;
    final totalPendapatan = _sesiAktif?['total_pendapatan'] ?? 0;
    final cuaca = _sesiAktif?['kondisi_cuaca'] ?? 'cerah';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Info Sesi Aktif',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(Icons.schedule, 'Mulai', waktuMulai),
              ),
              Expanded(
                child: _buildInfoChip(
                    Icons.people, 'Transaksi', '$totalTransaksi'),
              ),
              Expanded(
                child: _buildInfoChip(
                  Icons.payments,
                  'Pendapatan',
                  'Rp ${NumberFormat('#,###').format(totalPendapatan)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.cloud, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                cuaca[0].toUpperCase() + cuaca.substring(1),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildRecommendationCard(bool sesiAktif) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assistant, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                "AI RECOMMENDATION",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sesiAktif
                ? 'Sesi berjualan aktif. Catat transaksi di halaman Penjualan.'
                : 'Mulai sesi berjualan untuk mendapatkan rekomendasi rute.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.onNavigateToHistory != null) {
                  widget.onNavigateToHistory!(1);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OptimasiScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Text('🗺️', style: TextStyle(fontSize: 18)),
              label: const Text(
                'Lihat Rute Optimal Hari Ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
