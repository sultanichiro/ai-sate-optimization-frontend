import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/optimasi_model.dart';
import 'package:intl/intl.dart';

class OptimasiScreen extends StatefulWidget {
  const OptimasiScreen({super.key});

  @override
  State<OptimasiScreen> createState() => _OptimasiScreenState();
}

class _OptimasiScreenState extends State<OptimasiScreen>
    with SingleTickerProviderStateMixin {
  // --- State ---
  String _selectedCuaca = 'cerah';
  int _selectedHari = 1; // 1 = hari kuliah, 0 = akhir pekan
  bool _isLoading = false;
  OptimasiResponse? _result;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cuaca options
  final List<Map<String, dynamic>> _cuacaOptions = [
    {
      'value': 'cerah',
      'label': 'Cerah',
      'emoji': '☀️',
      'color': Color(0xFFFF9800),
    },
    {
      'value': 'mendung',
      'label': 'Mendung',
      'emoji': '🌥️',
      'color': Color(0xFF78909C),
    },
    {
      'value': 'hujan',
      'label': 'Hujan',
      'emoji': '🌧️',
      'color': Color(0xFF1E88E5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runOptimasi() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final raw = await ApiService.startOptimasi({
        'kondisi_cuaca': _selectedCuaca,
        'hari_kuliah': _selectedHari,
        'max_episodes': 100,
      });

      if (!mounted) return;

      if (raw['success'] == true) {
        final response = OptimasiResponse.fromJson(raw);
        setState(() {
          _result = response;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              raw['message']?.toString() ?? 'Terjadi kesalahan. Coba lagi ya!';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Tidak bisa terhubung ke server. Pastikan Anda terhubung ke internet.';
        _isLoading = false;
      });
    }
  }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // --- AppBar ---
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🗺️',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cari Rute Terbaik',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Biar dagangan cepat habis!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // --- Input Panel ---
                  _buildInputPanel(),
                  const SizedBox(height: 20),

                  // --- Result / Loading / Error ---
                  if (_isLoading) _buildLoadingState(),
                  if (_errorMessage != null && !_isLoading) _buildErrorState(),
                  if (_result != null && !_isLoading) _buildResultPanel(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── INPUT PANEL ────────────────────────────────────────────────────
  Widget _buildInputPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cuaca Section
          _buildSectionHeader('☁️', 'Cuaca Hari Ini'),
          const SizedBox(height: 12),
          Row(
            children: _cuacaOptions.map((opt) {
              final isSelected = _selectedCuaca == opt['value'];
              final color = opt['color'] as Color;
              return Expanded(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => setState(() => _selectedCuaca = opt['value']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          opt['emoji'] as String,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? color : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Hari Section
          _buildSectionHeader('📅', 'Hari Ini'),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHariButton(
                value: 1,
                emoji: '🎓',
                label: 'Hari Kuliah',
                sublabel: 'Senin – Jumat',
                color: const Color(0xFF5C6BC0),
              ),
              const SizedBox(width: 12),
              _buildHariButton(
                value: 0,
                emoji: '🏖️',
                label: 'Akhir Pekan',
                sublabel: 'Sabtu – Minggu',
                color: const Color(0xFFEF6C00),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _runOptimasi,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    _isLoading ? 'Sedang Mencari...' : 'CARI RUTE TERBAIK',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildHariButton({
    required int value,
    required String emoji,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    final isSelected = _selectedHari == value;
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : () => setState(() => _selectedHari = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? color.withValues(alpha: 0.8)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── LOADING STATE ────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI sedang bekerja...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sedang mencari rute terbaik\nuntuk Anda hari ini 🔍',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Color(0xFFE8F5E9),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ERROR STATE ────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
      ),
      child: Column(
        children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Ups, ada masalah!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC62828),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Terjadi kesalahan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _runOptimasi,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFEF9A9A)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESULT PANEL ────────────────────────────────────────────────────
  Widget _buildResultPanel() {
    final result = _result!;
    final rute = result.ruteUntukTampil;
    final katStyle = _kategoriStyle(result.kategori);

    return Column(
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

        // --- Perkiraan Penghasilan Card (NEW) ---
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
                  return _buildRouteStep(loc, isLast);
                }),
              ],
            ),
          ),
        ] else ...[
          _buildEmptyRoute(),
        ],

        const SizedBox(height: 16),

        // --- Penjelasan AI (NEW — replaces old rekomendasi) ---
        if (result.penjelasan.isNotEmpty) ...[
          _buildPenjelasanCard(result.penjelasan),
          const SizedBox(height: 16),
        ] else if (result.rekomendasi.isNotEmpty) ...[
          // Backward compat: tampilkan rekomendasi lama jika penjelasan kosong
          _buildRekomendasiCard(result.rekomendasi),
          const SizedBox(height: 16),
        ],

        // --- Tombol Ulangi ---
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _runOptimasi,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Cari Rute Lagi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PERKIRAAN PENGHASILAN CARD (NEW) ────────────────────────────────
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
          // Emoji & Kategori
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
          // Nominal penghasilan
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

  // ─── PENJELASAN CARD (NEW) ──────────────────────────────────────────
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

  Widget _buildRouteStep(RuteLokasiResponse loc, bool isLast) {
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
            // Nomor urut
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
            // Nama lokasi + jarak
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Panah koneksi
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
}
