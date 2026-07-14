import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';

class AddLokasiScreen extends StatefulWidget {
  final bool isFirstLocation;
  final bool hasDefault;
  
  const AddLokasiScreen({
    super.key, 
    this.isFirstLocation = false, 
    this.hasDefault = false
  });

  @override
  State<AddLokasiScreen> createState() => _AddLokasiScreenState();
}

class _AddLokasiScreenState extends State<AddLokasiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isFetchingGps = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.isFirstLocation) {
      _isDefault = true;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingGps = true);
    
    try {
      // Cek permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi dinonaktifkan. Silakan aktifkan GPS Anda.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak secara permanen. Aktifkan dari pengaturan.');
      }

      // Ambil posisi
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      _latitudeController.text = position.latitude.toString();
      _longitudeController.text = position.longitude.toString();
      
      // Coba dapatkan nama jalan/tempat dari koordinat (Reverse Geocoding)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, 
          position.longitude
        );
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String name = '';
          if (place.street != null && place.street!.isNotEmpty) {
            name = place.street!;
          } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            name = place.subLocality!;
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            name = place.locality!;
          } else if (place.name != null && place.name!.isNotEmpty) {
            name = place.name!;
          }
          
          if (name.isNotEmpty) {
            _namaController.text = name;
          }
        }
      } catch (e) {
        debugPrint("Geocoding error: $e");
        // Jika gagal mendapatkan nama, tidak apa-apa, user bisa mengisi manual
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi GPS berhasil diambil'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingGps = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_latitudeController.text.isEmpty || _longitudeController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan ambil lokasi GPS terlebih dahulu dengan menekan tombol di atas.'), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() => _isLoading = true);
      
      final data = {
        'nama': _namaController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        'is_default': _isDefault,
      };
      
      final result = await ApiService.addLokasi(data);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Lokasi berhasil ditambahkan'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // Kembali dengan state success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Gagal menambahkan lokasi'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Lokasi Baru'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.gps_fixed, size: 48, color: Colors.blue),
                      const SizedBox(height: 12),
                      const Text(
                        'Isi otomatis menggunakan GPS perangkat Anda',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isFetchingGps ? null : _getCurrentLocation,
                          icon: _isFetchingGps 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.my_location),
                          label: Text(
                            _isFetchingGps ? 'Mengambil GPS...' : 'Ambil Lokasi Saat Ini',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                
                TextFormField(
                  controller: _namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lokasi (Cth: Depan Kampus UNP)',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Nama lokasi tidak boleh kosong';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    title: const Text('Jadikan Lokasi Default', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      widget.isFirstLocation 
                          ? 'Lokasi pertama otomatis menjadi default.' 
                          : (widget.hasDefault && !_isDefault) 
                              ? 'Lokasi default sudah ada. Hapus centang di lokasi default sebelumnya terlebih dahulu.' 
                              : 'Akan digunakan sebagai titik mulai rute optimal.',
                      style: TextStyle(fontSize: 12, color: (widget.hasDefault && !widget.isFirstLocation && !_isDefault) ? Colors.red : Colors.grey),
                    ),
                    value: _isDefault,
                    onChanged: (widget.isFirstLocation || (widget.hasDefault && !_isDefault)) ? null : (bool? value) {
                      setState(() {
                        _isDefault = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                
                const SizedBox(height: 48),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SIMPAN LOKASI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
