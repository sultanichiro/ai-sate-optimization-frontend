import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/optimasi_model.dart';
import 'login_screen.dart';
import 'rute_detail_screen.dart';

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

  Timer? _durationTimer;
  Duration _elapsedDuration = Duration.zero;

  // Q-Learning Next Step state
  int? _currentLokasiId;
  String _currentLokasiNama = 'Titik Awal';
  Map<String, dynamic>? _rekomendasiSelanjutnya;
  bool _isLoadingRekomendasi = false;

  @override
  void initState() {
    super.initState();
    _checkSesiAktif();
    _fetchInitialLokasi();
  }

  Future<void> _fetchInitialLokasi() async {
    final result = await ApiService.getLokasi();
    if (result['success'] == true && result['data'] != null) {
      final List<dynamic> lokasiList = result['data'];

      final prefs = await SharedPreferences.getInstance();
      final savedLokasiId = prefs.getString('selected_lokasi_id');

      Map<String, dynamic>? selectedLokasi;
      if (savedLokasiId != null) {
        selectedLokasi = lokasiList.firstWhere(
          (loc) => loc['id'].toString() == savedLokasiId,
          orElse: () => null,
        );
      }

      if (selectedLokasi == null) {
        selectedLokasi = lokasiList.firstWhere(
          (loc) => loc['is_default'] == true,
          orElse: () => null,
        );
      }

      if (selectedLokasi == null && lokasiList.isNotEmpty) {
        selectedLokasi = lokasiList.first;
      }

      if (selectedLokasi != null) {
        if (mounted) {
          setState(() {
            _currentLokasiId = selectedLokasi!['id'];
            _currentLokasiNama = selectedLokasi!['nama'];
          });
        }
      }
    }
  }

  Future<void> _mintaRekomendasiSelanjutnya() async {
    if (_currentLokasiId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi saat ini belum diketahui (Lokasi default tidak ditemukan).',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingRekomendasi = true);

    // Perkirakan sisa waktu, asumsi 8 jam (480 menit) dari waktu mulai. Jika tidak, pakai 120 menit default.
    int sisaWaktu = 120;
    if (_sesiAktif != null && _sesiAktif!['waktu_mulai'] != null) {
      final waktuMulai = DateTime.parse(_sesiAktif!['waktu_mulai']).toLocal();
      final elapsedMenit = DateTime.now().difference(waktuMulai).inMinutes;
      sisaWaktu = 480 - elapsedMenit;
      if (sisaWaktu < 30) sisaWaktu = 30; // minimal 30 menit
    }

    final data = {
      'lokasi_saat_ini_id': _currentLokasiId,
      'sisa_waktu_menit': sisaWaktu,
    };

    final result = await ApiService.optimasiSelanjutnya(data);

    if (mounted) {
      setState(() => _isLoadingRekomendasi = false);
      if (result['success'] == true) {
        setState(() {
          _rekomendasiSelanjutnya = result;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Gagal mendapatkan rekomendasi.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    final data = <String, dynamic>{};

    final result = await ApiService.startSesi(data);

    if (mounted) {
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _sesiAktif = result['data'];
          _startDurationTimer();
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_lokasi_id');

        await _fetchInitialLokasi();

        if (mounted) {
          setState(() => _isLoadingAction = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Sesi berjualan dimulai!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoadingAction = false);
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
          _rekomendasiSelanjutnya = null;
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
      final strTime = _sesiAktif!['waktu_mulai'] as String;
      final waktuMulai = DateTime.parse(
        strTime.endsWith('Z') ? strTime : '${strTime}Z',
      );
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
      final totalMenit = (durasiTotal as num);
      final jam = (totalMenit / 60).floor();
      final menit = (totalMenit % 60).round();
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
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.celebration,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kerja Bagus Hari Ini!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result['message'] ?? 'Sesi telah diakhiri',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Ringkasan
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Pendapatan Besar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Pendapatan',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rp ${NumberFormat('#,###').format(totalPendapatan)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Grid stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildRingkasanItem(
                            Icons.receipt_long,
                            'Transaksi',
                            '$totalTransaksi',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildRingkasanItem(
                            Icons.location_on,
                            'Lokasi',
                            '$totalLokasi',
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildRingkasanItem(
                            Icons.timer,
                            'Durasi',
                            durasiText,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
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
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
        title: const Text(
          "Beranda",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                            builder: (context) => const LoginScreen(),
                          ),
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

                  // 5. Shortcut ke halaman penjualan
                  if (sesiAktif) _buildShortcutPenjualan(),
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
            color: (sesiAktif ? Colors.green : Colors.blueGrey).withOpacity(
              0.3,
            ),
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
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
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
      // START BUTTON
      return SizedBox(
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
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
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
      );
    }
  }

  Widget _buildSesiInfo() {
    final strTime = _sesiAktif?['waktu_mulai'] as String?;
    final waktuMulai = strTime != null
        ? DateFormat('HH:mm').format(
            DateTime.parse(
              strTime.endsWith('Z') ? strTime : '${strTime}Z',
            ).toLocal(),
          )
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
                  Icons.people,
                  'Transaksi',
                  '$totalTransaksi',
                ),
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
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, color: Colors.blueGrey, size: 22),
              SizedBox(width: 8),
              Text(
                "AJO CERDAS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 13,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!sesiAktif)
            Text(
              'Mulai berjualan untuk mendapatkan rekomendasi cerdas dari AJO yang akan terus memandu Anda di setiap lokasi.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lokasi Saat Ini:',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _currentLokasiNama,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_rekomendasiSelanjutnya != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    Row(
                      children: [
                        Icon(
                          _rekomendasiSelanjutnya!['keputusan'] == 'MOVE'
                              ? Icons.directions_run
                              : Icons.pan_tool,
                          color: _rekomendasiSelanjutnya!['keputusan'] == 'MOVE'
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Keputusan: ${_rekomendasiSelanjutnya!['keputusan']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                _rekomendasiSelanjutnya!['keputusan'] == 'MOVE'
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_rekomendasiSelanjutnya!['keputusan'] == 'MOVE')
                      Text(
                        'Tujuan: ${_rekomendasiSelanjutnya!['nama_lokasi_tujuan']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    Text(
                      'Durasi Rekomendasi: ${_rekomendasiSelanjutnya!['rekomendasi_durasi_menit']} menit',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _rekomendasiSelanjutnya!['alasan'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    if (_rekomendasiSelanjutnya!['keputusan'] == 'MOVE') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final targetId =
                                _rekomendasiSelanjutnya!['lokasi_tujuan_id'];
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'selected_lokasi_id',
                              targetId.toString(),
                            );

                            setState(() {
                              _currentLokasiId = targetId;
                              _currentLokasiNama =
                                  _rekomendasiSelanjutnya!['nama_lokasi_tujuan'] ??
                                  'Lokasi Baru';
                              _rekomendasiSelanjutnya = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Anda berpindah ke $_currentLokasiNama',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Konfirmasi Pindah Lokasi'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoadingRekomendasi
                    ? null
                    : _mintaRekomendasiSelanjutnya,
                icon: _isLoadingRekomendasi
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.explore),
                label: Text(
                  _isLoadingRekomendasi
                      ? 'Ajo mencari lokasi'
                      : 'Minta Keputusan Ajo',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  final optRaw = await ApiService.getOptimasi();
                  if (!mounted) return;
                  Navigator.pop(context);

                  if (optRaw['success'] == true) {
                    final response = OptimasiResponse.fromJson(optRaw);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RuteDetailScreen(result: response),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal mendapatkan rute detail.'),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Minta Ajo Carikan Rute',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShortcutPenjualan() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        onTap: () {
          if (widget.onNavigateToHistory != null) {
            // Index 2 is now PenjualanScreen after Rute was removed
            widget.onNavigateToHistory!(2);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA5D6A7), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Mulai berjualan hari ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF2E7D32),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
