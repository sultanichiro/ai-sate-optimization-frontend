import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';

class EditLokasiScreen extends StatefulWidget {
  final Map<String, dynamic> lokasi;

  const EditLokasiScreen({super.key, required this.lokasi});

  @override
  State<EditLokasiScreen> createState() => _EditLokasiScreenState();
}

class _EditLokasiScreenState extends State<EditLokasiScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  
  bool _isLoading = false;
  bool _isFetchingGps = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.lokasi['nama']?.toString());
    _latitudeController = TextEditingController(text: widget.lokasi['latitude']?.toString());
    _longitudeController = TextEditingController(text: widget.lokasi['longitude']?.toString());
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      _latitudeController.text = position.latitude.toString();
      _longitudeController.text = position.longitude.toString();
      
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
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi GPS berhasil diperbarui'), backgroundColor: Colors.green),
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
      setState(() => _isLoading = true);
      
      final data = {
        'nama': _namaController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
      };
      
      final id = widget.lokasi['id'].toString();
      final result = await ApiService.updateLokasi(id, data);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Lokasi berhasil diperbarui'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Gagal memperbarui lokasi'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Lokasi'),
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.edit_location_alt, size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text(
                        'Perbarui lokasi menggunakan koordinat saat ini',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
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
                            _isFetchingGps ? 'Mengambil GPS...' : 'Ambil Ulang GPS',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: const Icon(Icons.explore),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Harus diisi';
                          if (double.tryParse(value) == null) return 'Format salah';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: const Icon(Icons.explore),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Harus diisi';
                          if (double.tryParse(value) == null) return 'Format salah';
                          return null;
                        },
                      ),
                    ),
                  ],
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
                        : const Text('PERBARUI LOKASI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
