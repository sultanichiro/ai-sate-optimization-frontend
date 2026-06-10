import 'package:flutter/material.dart';
import '../models/q_learning_model.dart';
import '../models/transaction_model.dart';
import '../models/stock_record_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class AppDataProvider extends ChangeNotifier {
  final QLearningModel _qLearning = QLearningModel();
  // GPS Tracking
  final List<LatLng> _routePoints = [];
  final List<Transaction> _transactionHistory = [];
  final List<StockRecord> _stockHistory = [];

  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;

  String _currentLocation = "Pangkalan 1";
  bool _isMoving = false; // true = "Di Jalan/Pindah", false = "Mangkal"
  int _tusukSateStok = 500;
  int _ketupatStok = 50;
  int _kerupukStok = 50;
  final String _weatherCondition = "Cerah"; // Cerah, Hujan
  final String _campusStatus = "Aktif"; // Aktif, Libur
  String _currentRecommendation = "Mulai Berjualan";

  // Mock Daily Sales (Senin - Minggu)
  final List<int> _dailySales = [120, 150, 80, 200, 250, 300, 180];

  String get currentLocation => _currentLocation;
  bool get isMoving => _isMoving;
  int get tusukSateStok => _tusukSateStok;
  int get ketupatStok => _ketupatStok;
  int get kerupukStok => _kerupukStok;
  String get weatherCondition => _weatherCondition;
  String get campusStatus => _campusStatus;
  String get currentRecommendation => _currentRecommendation;
  List<int> get dailySales => _dailySales;
  List<LatLng> get routePoints => _routePoints;
  List<Transaction> get transactionHistory => _transactionHistory;
  List<StockRecord> get stockHistory => _stockHistory;
  LatLng? get currentPosition => _currentPosition;

  int get totalSalesToday =>
      500 -
      _tusukSateStok; // Simple logic: initial - current (assuming 500 start)

  void updateLocation(String newLocation) {
    _currentLocation = newLocation;
    _generateRecommendation();
    notifyListeners();
  }

  void startMovingTo(String targetLocation) {
    _currentLocation = targetLocation; // Set target
    if (!_isMoving) {
      _isMoving = true;
      _startTracking();
      _currentRecommendation = "Menuju ke $targetLocation...";
    }
    notifyListeners();
  }

  void arriveAtLocation() {
    if (_isMoving) {
      _isMoving = false;
      _stopTracking();
      _generateRecommendation();
    }
    notifyListeners();
  }

  void toggleStatus() {
    _isMoving = !_isMoving;
    if (_isMoving) {
      _startTracking();
    } else {
      _stopTracking();
      // Arrived at location
      _generateRecommendation();
    }
    notifyListeners();
  }

  void updateStock(int soldAmount) {
    _tusukSateStok = (_tusukSateStok - soldAmount).clamp(0, 500);
    notifyListeners();
  }

  void sellItem(String type) {
    if (type == 'sate') {
      _tusukSateStok = (_tusukSateStok - 1).clamp(0, 1000);
    } else if (type == 'ketupat') {
      _ketupatStok = (_ketupatStok - 1).clamp(0, 1000);
    } else if (type == 'kerupuk') {
      _kerupukStok = (_kerupukStok - 1).clamp(0, 1000);
    }
    notifyListeners();
  }

  void recordTransaction({
    required int sate,
    required int ketupat,
    required int kerupuk,
    String? note,
  }) {
    // Add to history
    _transactionHistory.add(
      Transaction(
        timestamp: DateTime.now(),
        sate: sate,
        ketupat: ketupat,
        kerupuk: kerupuk,
        location: _currentPosition,
        locationNote: _currentLocation,
        weather: _weatherCondition,
        note: note ?? "",
      ),
    );

    _tusukSateStok = (_tusukSateStok - sate).clamp(0, 1000);
    _ketupatStok = (_ketupatStok - ketupat).clamp(0, 1000);
    _kerupukStok = (_kerupukStok - kerupuk).clamp(0, 1000);

    // Update daily sales for "Today" (Index 6)
    // This is a simple mock update just to show the chart changing
    _dailySales[6] += sate;

    notifyListeners();
  }

  void updateAllStock({
    required int sate,
    required int ketupat,
    required int kerupuk,
  }) {
    _tusukSateStok = sate;
    _ketupatStok = ketupat;
    _kerupukStok = kerupuk;
    _generateRecommendation(); // Re-evaluate recommendation based on new stock
    notifyListeners();
  }

  void recordStockUpdate({
    required int sate,
    required int ketupat,
    required int kerupuk,
  }) {
    _stockHistory.add(
      StockRecord(
        timestamp: DateTime.now(),
        sate: sate,
        ketupat: ketupat,
        kerupuk: kerupuk,
      ),
    );
    // Also update current stock
    updateAllStock(sate: sate, ketupat: ketupat, kerupuk: kerupuk);
  }

  // --- GPS Logic ---

  // Call this on app start
  Future<void> initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      // If we assume app starts at home, we might not want to add to route yet unless status is moving
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _currentRecommendation = "GPS Mati. Nyalakan GPS.";
      notifyListeners();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _currentRecommendation = "Izin Lokasi Ditolak.";
        notifyListeners();
        return;
      }
    }

    _routePoints
        .clear(); // Clear previous route on new start? Or keep accumulating? User said "awal sampai pulang", so maybe clear only on App Restart. Let's keep it simple: clear on new "move" for this demo, or append.
    // Ideally we append if it's the same day. Let's just append for now.

    // Initial position
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _routePoints.add(_currentPosition!);
    } catch (e) {
      // ignore
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position? position) {
            if (position != null) {
              _currentPosition = LatLng(position.latitude, position.longitude);
              _routePoints.add(_currentPosition!);
              notifyListeners();
            }
          },
        );

    _currentRecommendation = "Sedang melacak rute...";
    notifyListeners();
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void _generateRecommendation() {
    // Construct state string
    String state = "$_currentLocation-$_weatherCondition-$_campusStatus";
    // Mock simulation of 'sales' to influence recommendation for demo
    if (_tusukSateStok < 50) {
      _currentRecommendation = "Stok Menipis: Pulang / Restock";
    } else {
      _currentRecommendation = _qLearning.getRecommendation(state);
    }
    notifyListeners();
  }
}
