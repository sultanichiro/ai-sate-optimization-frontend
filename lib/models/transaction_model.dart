import 'package:latlong2/latlong.dart';

class Transaction {
  final DateTime timestamp;
  final int sate;
  final int ketupat;
  final int kerupuk;
  final LatLng? location;
  final String locationNote;
  final String weather;
  final String note;

  Transaction({
    required this.timestamp,
    required this.sate,
    required this.ketupat,
    required this.kerupuk,
    this.location,
    this.locationNote = "",
    this.weather = "Unknown",
    this.note = "",
  });
}
