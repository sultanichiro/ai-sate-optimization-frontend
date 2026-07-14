import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PenjualanScreen extends StatefulWidget {
  const PenjualanScreen({super.key});

  @override
  State<PenjualanScreen> createState() => _PenjualanScreenState();
}

class _PenjualanScreenState extends State<PenjualanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nominalController = TextEditingController();

  String _currentTime = "";
  late Timer _timer;

  bool _isLoading = false;
  bool _isLoadingSesi = true;
  bool _isSesiAktif = false;
  Map<String, dynamic>? _sesiAktifData;

  List<dynamic> _lokasiList = [];
  String? _selectedLokasiId;

  // Q-Learning AI State
  Map<String, dynamic>? _rekomendasiSelanjutnya;
  bool _isLoadingRekomendasi = false;

  @override
  void initState() {
    super.initState();
    _checkSesiAktif();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );
    _fetchLokasi();
  }

  Future<void> _checkSesiAktif() async {
    final result = await ApiService.getSesiAktif();
    if (mounted) {
      setState(() {
        _isLoadingSesi = false;
        if (result['success'] == true && result['data'] != null) {
          _isSesiAktif = true;
          _sesiAktifData = result['data'];
        } else {
          _isSesiAktif = false;
          _sesiAktifData = null;
        }
      });
    }
  }

  Future<void> _fetchLokasi() async {
    final result = await ApiService.getLokasi();
    if (mounted && result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      final savedLokasiId = prefs.getString('selected_lokasi_id');

      setState(() {
        _lokasiList = result['data'] ?? [];
        if (_lokasiList.isNotEmpty) {
          if (savedLokasiId != null) {
            _selectedLokasiId = savedLokasiId;
          } else {
            final basecamp = _lokasiList.firstWhere(
              (loc) =>
                  loc['nama']?.toString().toLowerCase().contains('basecamp') ==
                  true,
              orElse: () => _lokasiList.first,
            );
            _selectedLokasiId = basecamp['id'].toString();
          }
        }
      });
    }
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat(
          'dd MMM yyyy, HH:mm:ss',
        ).format(DateTime.now());
      });
    }
  }

  Future<void> _mintaRekomendasiSelanjutnya() async {
    if (_selectedLokasiId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi saat ini belum dipilih.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingRekomendasi = true);

    int sisaWaktu = 120;
    if (_sesiAktifData != null && _sesiAktifData!['waktu_mulai'] != null) {
      final strTime = _sesiAktifData!['waktu_mulai'] as String;
      final waktuMulai = DateTime.parse(
        strTime.endsWith('Z') ? strTime : '${strTime}Z',
      ).toLocal();
      final elapsedMenit = DateTime.now().difference(waktuMulai).inMinutes;
      sisaWaktu = 480 - elapsedMenit;
      if (sisaWaktu < 30) sisaWaktu = 30; // minimal 30 menit
    }

    final data = {
      'lokasi_saat_ini_id': int.parse(_selectedLokasiId!),
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

  Future<void> _pindahLokasiKeBackend(String lokasiId) async {
    if (!_isSesiAktif) return;

    final data = {'lokasi_id': int.parse(lokasiId)};

    final result = await ApiService.pindahLokasi(data);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi berhasil diperbarui di sistem'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Gagal memperbarui lokasi di sistem',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _savePenjualan() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedLokasiId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih lokasi terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final nominal = int.tryParse(_nominalController.text.trim()) ?? 0;

      final data = {
        'lokasi_id': int.parse(_selectedLokasiId!),
        'jumlah_terjual': nominal,
      };

      final result = await ApiService.addTransaksi(data);

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Transaksi berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
          _nominalController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menyimpan penjualan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _onNominalChanged(String value) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Transaksi Penjualan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: _isLoadingSesi
          ? const Center(child: CircularProgressIndicator())
          : !_isSesiAktif
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 80,
                        color: Colors.orange.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Sesi Belum Dimulai',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Silakan mulai sesi berjualan dari halaman Beranda sebelum mencatat penjualan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Data Lingkungan
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Data Lingkungan',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.access_time,
                            'Waktu',
                            _currentTime,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Q-Learning AI Recommendation Card
                    _buildAiRecommendationCard(),

                    const SizedBox(height: 24),

                    // Input Lokasi
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Lokasi Saat Ini',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedLokasiId,
                          hint: const Text('Pilih Lokasi'),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),
                          items: _lokasiList.map((dynamic item) {
                            return DropdownMenuItem<String>(
                              value: item['id'].toString(),
                              child: Text(
                                item['nama'] ?? 'Lokasi ${item['id']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) async {
                            setState(() {
                              _selectedLokasiId = newValue;
                              _rekomendasiSelanjutnya =
                                  null; // reset reko jika user pindah manual
                            });
                            if (newValue != null) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                'selected_lokasi_id',
                                newValue,
                              );
                              _pindahLokasiKeBackend(newValue);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Input Nominal
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Nominal Belanja (Rp)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: '0',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 20,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.payments_rounded,
                            color: Colors.green.shade500,
                            size: 24,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.green.shade400,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: _onNominalChanged,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nominal belanja wajib diisi';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'Masukkan angka saja (contoh: 12000)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Submit
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 64,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _savePenjualan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'SIMPAN PENJUALAN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAiRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.purple.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Asisten Pintar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 16,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_rekomendasiSelanjutnya == null) ...[
            Text(
              'Gunakan asisten pintar untuk menentukan apakah Anda sebaiknya tetap di lokasi ini atau pindah ke lokasi lain yang lebih menguntungkan.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
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
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoadingRekomendasi
                      ? 'Memproses AI...'
                      : 'Minta Rekomendasi AI',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _rekomendasiSelanjutnya!['keputusan'] == 'MOVE'
                            ? Icons.directions_run
                            : Icons.pan_tool,
                        color: _rekomendasiSelanjutnya!['keputusan'] == 'MOVE'
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keputusan: ${_rekomendasiSelanjutnya!['keputusan']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color:
                                _rekomendasiSelanjutnya!['keputusan'] == 'MOVE'
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_rekomendasiSelanjutnya!['keputusan'] == 'MOVE') ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.purple.shade400,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tujuan: ${_rekomendasiSelanjutnya!['nama_lokasi_tujuan']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        color: Colors.purple.shade400,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Estimasi Mangkal: ${_rekomendasiSelanjutnya!['rekomendasi_durasi_menit']} menit',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _rekomendasiSelanjutnya!['alasan'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (_rekomendasiSelanjutnya!['keputusan'] == 'MOVE') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final targetId =
                              _rekomendasiSelanjutnya!['lokasi_tujuan_id']
                                  .toString();
                          final targetNama =
                              _rekomendasiSelanjutnya!['nama_lokasi_tujuan'];

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('selected_lokasi_id', targetId);

                          setState(() {
                            _selectedLokasiId = targetId;
                            _rekomendasiSelanjutnya = null;
                          });

                          _pindahLokasiKeBackend(targetId);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lokasi diubah ke $targetNama'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Gunakan Lokasi Rekomendasi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoadingRekomendasi
                          ? null
                          : _mintaRekomendasiSelanjutnya,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade600,
                        side: BorderSide(color: Colors.purple.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Minta Rekomendasi Ulang',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade400),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
