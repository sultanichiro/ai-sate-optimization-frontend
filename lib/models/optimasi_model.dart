class RuteLokasiResponse {
  final int urutan;
  final int lokasiId;
  final String nama;
  final double latitude;
  final double longitude;
  final double jarakDariSebelumnya;

  RuteLokasiResponse({
    required this.urutan,
    required this.lokasiId,
    required this.nama,
    required this.latitude,
    required this.longitude,
    this.jarakDariSebelumnya = 0.0,
  });

  factory RuteLokasiResponse.fromJson(Map<String, dynamic> json) {
    return RuteLokasiResponse(
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
      lokasiId: (json['lokasi_id'] as num?)?.toInt() ?? 0,
      nama: json['nama']?.toString() ?? '-',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      jarakDariSebelumnya:
          (json['jarak_dari_sebelumnya'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OptimasiResponse {
  final bool success;
  final String message;

  // ---- Field baru (frontend-friendly) ----
  final List<RuteLokasiResponse> rekomendasiRute;
  final double totalJarakKm;
  final int perkiraanPenghasilan;
  final String kategori;
  final String penjelasan;
  final String kondisiCuaca;
  final int hariKuliah;

  // ---- Field lama (backward compat) ----
  final List<RuteLokasiResponse> ruteOptimal;
  final double totalReward;
  final double totalJarak;
  final String rekomendasi;
  final List<double> episodeRewards;

  OptimasiResponse({
    required this.success,
    required this.message,
    this.rekomendasiRute = const [],
    this.totalJarakKm = 0.0,
    this.perkiraanPenghasilan = 0,
    this.kategori = '',
    this.penjelasan = '',
    this.kondisiCuaca = 'cerah',
    this.hariKuliah = 1,
    this.ruteOptimal = const [],
    this.totalReward = 0.0,
    this.totalJarak = 0.0,
    this.rekomendasi = '',
    this.episodeRewards = const [],
  });

  factory OptimasiResponse.fromJson(Map<String, dynamic> json) {
    // Parse rekomendasi_rute list (field baru)
    List<RuteLokasiResponse> rekRute = [];
    if (json['rekomendasi_rute'] != null && json['rekomendasi_rute'] is List) {
      rekRute = (json['rekomendasi_rute'] as List)
          .map((e) => RuteLokasiResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Parse rute_optimal list (field lama / backward compat)
    List<RuteLokasiResponse> rute = [];
    if (json['rute_optimal'] != null && json['rute_optimal'] is List) {
      rute = (json['rute_optimal'] as List)
          .map((e) => RuteLokasiResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Parse episode_rewards list
    List<double> episodes = [];
    if (json['episode_rewards'] != null && json['episode_rewards'] is List) {
      episodes = (json['episode_rewards'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return OptimasiResponse(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      // Field baru
      rekomendasiRute: rekRute,
      totalJarakKm: (json['total_jarak_km'] as num?)?.toDouble() ?? 0.0,
      perkiraanPenghasilan:
          (json['perkiraan_penghasilan'] as num?)?.toInt() ?? 0,
      kategori: json['kategori']?.toString() ?? '',
      penjelasan: json['penjelasan']?.toString() ?? '',
      kondisiCuaca: json['kondisi_cuaca']?.toString() ?? 'cerah',
      hariKuliah: (json['hari_kuliah'] as num?)?.toInt() ?? 1,
      // Field lama
      ruteOptimal: rute,
      totalReward: (json['total_reward'] as num?)?.toDouble() ?? 0.0,
      totalJarak: (json['total_jarak'] as num?)?.toDouble() ?? 0.0,
      rekomendasi: json['rekomendasi']?.toString() ?? '',
      episodeRewards: episodes,
    );
  }

  /// Convenience: gunakan rekomendasiRute jika ada, fallback ke ruteOptimal
  List<RuteLokasiResponse> get ruteUntukTampil =>
      rekomendasiRute.isNotEmpty ? rekomendasiRute : ruteOptimal;
}
