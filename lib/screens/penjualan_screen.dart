import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
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

  List<dynamic> _lokasiList = [];
  String? _selectedLokasiId;
  String _selectedCuaca = 'Cerah';
  final List<String> _cuacaOptions = ['Cerah', 'Berawan', 'Hujan', 'Badai'];

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
        } else {
          _isSesiAktif = false;
        }
      });
    }
  }

  Future<void> _fetchLokasi() async {
    final result = await ApiService.getLokasi();
    if (mounted && result['success'] == true) {
      setState(() {
        _lokasiList = result['data'] ?? [];
        if (_lokasiList.isNotEmpty) {
          _selectedLokasiId = _lokasiList.first['id'].toString();
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


      final now = DateTime.now();
      // 1-5 is Mon-Fri, 6-7 is Sat-Sun
      final hariKuliah = (now.weekday >= 1 && now.weekday <= 5) ? 1 : 0;

      final data = {
        'lokasi_id': int.parse(_selectedLokasiId!),
        'jumlah_terjual': nominal,
        'kondisi_cuaca': _selectedCuaca,
        'hari_kuliah': hariKuliah,
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

  // Bersihkan input agar hanya angka yang tersimpan
  void _onNominalChanged(String value) {
    // Tidak perlu formatting — simpan raw integer
    // Validator sudah memastikan hanya angka yang bisa dimasukkan
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Penjualan'),
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
                        Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Sesi Belum Dimulai',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Silakan mulai sesi berjualan dari halaman Beranda sebelum mencatat penjualan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
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
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Data Lingkungan',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.access_time, 'Waktu', _currentTime),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.cloud, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Cuaca:',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCuaca,
                              isDense: true,
                              items: _cuacaOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Input Lokasi
              const Text(
                'Lokasi Penjualan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLokasiId,
                    hint: const Text('Pilih Lokasi'),
                    items: _lokasiList.map((dynamic item) {
                      return DropdownMenuItem<String>(
                        value: item['id'].toString(),
                        child: Text(item['nama'] ?? 'Lokasi ${item['id']}'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLokasiId = newValue;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Input Nominal
              const Text(
                'Nominal Belanja',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nominalController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(
                    Icons.payments,
                    color: Colors.green,
                    size: 32,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
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

              const SizedBox(height: 48),

              // Submit
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePenjualan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SIMPAN PENJUALAN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label:', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
