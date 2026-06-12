import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Gunakan 10.0.2.2 untuk Android Emulator, 127.0.0.1 untuk iOS Simulator / Web.
  // static String get baseUrl {
  //   if (kIsWeb) return 'http://127.0.0.1:8000';
  //   if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  //   return 'http://127.0.0.1:8000';
  // }

  static const bool isProduction = true;

  static String get baseUrl {
    if (isProduction) {
      return "https://ai-sate-optimization-backend-production.up.railway.app";
    } else {
      return "http://10.0.2.2:8000";
    }
  }

  static const String _tokenKey = 'jwt_token';

  // --- TOKEN MANAGEMENT ---
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString('last_active_time', DateTime.now().toIso8601String());
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('last_active_time');
  }

  // --- HELPERS ---
  static Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      logout(); // Token expired atau tidak valid
      return {
        'success': false,
        'message': 'Sesi telah habis, silakan login kembali',
      };
    }

    try {
      final data = jsonDecode(response.body);
      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      // Jika response berupa Map
      if (data is Map<String, dynamic>) {
        if (!data.containsKey('success')) {
          data['success'] = isSuccess;
        }
        return data;
      }

      // Jika response berupa List atau tipe lain
      return {'success': isSuccess, 'data': data};
    } catch (e) {
      return {
        'success': false,
        'message': 'Format respons tidak valid',
        'data': response.body,
      };
    }
  }

  // --- AUTH ---
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = _handleResponse(response);

      if (data['success'] == true && data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(
    String nama,
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'nama': nama,
          'username': username,
          'password': password,
        }),
      );
      final data = _handleResponse(response);

      if (data['success'] == true && data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: await _getHeaders(),
      );
      final data = _handleResponse(response);

      if (data['success'] == true && data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- LOKASI ---
  static Future<Map<String, dynamic>> getLokasi() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lokasi'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> addLokasi(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lokasi'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateLokasi(
    String lokasiId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/lokasi/$lokasiId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteLokasi(String lokasiId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/lokasi/$lokasiId'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- PENJUALAN ---
  static Future<Map<String, dynamic>> getPerformaPenjualan({
    int days = 7,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/penjualan/performa?days=$days'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPenjualan({
    int limit = 20,
    int offset = 0,
    int? lokasiId,
    int? hariKuliah,
  }) async {
    String url = '$baseUrl/penjualan?limit=$limit&offset=$offset';

    if (lokasiId != null) {
      url += '&lokasi_id=$lokasiId';
    }
    if (hariKuliah != null) {
      url += '&hari_kuliah=$hariKuliah';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> getKunjungan({
    int limit = 20,
    int offset = 0,
    int? lokasiId,
    int? hariKuliah,
  }) async {
    String url = '$baseUrl/kunjungan?limit=$limit&offset=$offset';

    if (lokasiId != null) {
      url += '&lokasi_id=$lokasiId';
    }
    if (hariKuliah != null) {
      url += '&hari_kuliah=$hariKuliah';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> addTransaksi(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transaksi'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- SESI PENJUALAN (Start/Stop) ---
  static Future<Map<String, dynamic>> startSesi(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sesi/start'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> stopSesi() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sesi/stop'),
        headers: await _getHeaders(),
        body: jsonEncode({}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> getSesiAktif() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sesi/aktif'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- OPTIMASI ---
  static Future<Map<String, dynamic>> getOptimasi() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/optimasi'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> startOptimasi(
    Map<String, dynamic> params,
  ) async {
    try {
      // Build query parameters from the params map
      final queryParams = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final response = await http.get(
        Uri.parse('$baseUrl/optimasi?$queryParams'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- EPISODE ---
  static Future<Map<String, dynamic>> getEpisodes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/episodes'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- RUTE OPTIMAL ---
  static Future<Map<String, dynamic>> getRuteOptimal() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rute-optimal'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- Q-LEARNING ---
  static Future<Map<String, dynamic>> getQLearning() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/qlearning'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- HEALTH CHECK ---
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: await _getHeaders(auth: false),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }
}
