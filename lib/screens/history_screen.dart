import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Riwayat Penjualan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const TransactionHistoryList(),
    );
  }
}

class TransactionHistoryList extends StatefulWidget {
  const TransactionHistoryList({super.key});

  @override
  State<TransactionHistoryList> createState() => _TransactionHistoryListState();
}

class _TransactionHistoryListState extends State<TransactionHistoryList> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _sesiList = [];
  List<dynamic> _filteredSesiList = [];

  // Filters
  int _limit = 50;
  DateTime? _selectedDate;
  String? _selectedWeather;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getSesi(limit: _limit);

      if (response['success'] == true) {
        final List<dynamic> sesiData = response['data'] ?? [];

        // Sort descending by waktu_mulai
        sesiData.sort((a, b) {
          final t1 =
              DateTime.tryParse(a['waktu_mulai']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final t2 =
              DateTime.tryParse(b['waktu_mulai']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return t2.compareTo(t1);
        });

        if (mounted) {
          setState(() {
            _sesiList = sesiData;
            _applyFilters();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = response['message'] ?? 'Gagal memuat data riwayat';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    _filteredSesiList = _sesiList.where((item) {
      final waktuMulaiStr = item['waktu_mulai']?.toString();
      if (waktuMulaiStr == null) return false;

      final dt = DateTime.tryParse(waktuMulaiStr);
      if (dt == null) return false;

      // Filter Date
      if (_selectedDate != null) {
        if (dt.year != _selectedDate!.year ||
            dt.month != _selectedDate!.month ||
            dt.day != _selectedDate!.day) {
          return false;
        }
      }

      // Filter Weather
      if (_selectedWeather != null && _selectedWeather != 'Semua') {
        final cuaca = item['kondisi_cuaca']?.toString().toLowerCase() ?? '';
        if (cuaca != _selectedWeather!.toLowerCase()) return false;
      }

      return true;
    }).toList();
  }

  void _onFilterChanged() {
    setState(() {
      _applyFilters();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedDate = null;
      _selectedWeather = null;
      _applyFilters();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _onFilterChanged();
    }
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_selectedDate != null || _selectedWeather != null)
                InkWell(
                  onTap: _resetFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Reset",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _buildFilterChip(
                  label: _selectedDate != null
                      ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                      : "Tanggal",
                  icon: Icons.calendar_month,
                  isActive: _selectedDate != null,
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(width: 10),
                _buildModernDropdown(
                  hint: "Cuaca",
                  value: _selectedWeather,
                  items: const ['Semua', 'Cerah', 'Hujan', 'Mendung'],
                  icon: Icons.cloud,
                  onChanged: (val) {
                    setState(
                      () => _selectedWeather = val == 'Semua' ? null : val,
                    );
                    _onFilterChanged();
                  },
                ),
                const SizedBox(width: 10),
                _buildModernDropdown(
                  hint: "Data Limit",
                  value: '$_limit',
                  items: const ['20', '50', '100'],
                  icon: Icons.list_alt,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _limit = int.parse(val);
                        _selectedDate = null;
                        _selectedWeather = null;
                      });
                      _fetchData();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isActive =
        value != null && value != 'Semua' && items.contains(value);
    final String displayValue = (isActive) ? value : hint;

    // For limit dropdown where active implies value != null
    final bool isLimit = hint == "Data Limit";
    final bool finalActive = isLimit ? true : isActive;
    final String finalDisplay = isLimit ? "$value Sesi" : displayValue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      height: 38,
      decoration: BoxDecoration(
        color: finalActive && !isLimit
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: finalActive && !isLimit
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: finalActive && !isLimit
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                finalDisplay,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: finalActive && !isLimit
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: finalActive && !isLimit
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          icon: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: finalActive && !isLimit
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
          ),
          isDense: true,
          alignment: Alignment.center,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_filteredSesiList.isEmpty) {
      return _buildEmptyState("Tidak ada riwayat yang sesuai dengan filter");
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredSesiList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _filteredSesiList[index];
          return _buildSesiCard(item);
        },
      ),
    );
  }

  Widget _buildSesiCard(Map<String, dynamic> item) {
    final waktuMulai = item['waktu_mulai']?.toString() ?? '-';
    final waktuSelesai = item['waktu_selesai']?.toString();

    String formattedDate = waktuMulai;
    String formattedTime = "";
    try {
      final dtMulai = DateTime.parse(waktuMulai);
      formattedDate = DateFormat('EEEE dd-MM-yyyy', 'id').format(dtMulai);
      final jamMulai = DateFormat('HH.mm').format(dtMulai);

      String jamSelesai = "?";
      if (waktuSelesai != null &&
          waktuSelesai != 'null' &&
          waktuSelesai != '-') {
        final dtSelesai = DateTime.parse(waktuSelesai);
        jamSelesai = DateFormat('HH.mm').format(dtSelesai);
      }

      formattedTime = "$jamMulai - $jamSelesai";
    } catch (_) {}

    final totalPendapatan = item['total_pendapatan'] ?? 0;
    final totalTransaksi = item['total_transaksi'] ?? 0;
    final totalLokasi = item['total_lokasi_dikunjungi'] ?? 0;
    final durasi = item['durasi_total'] ?? 0.0;
    final cuaca = item['kondisi_cuaca']?.toString() ?? 'cerah';
    final hariKuliah = item['hari_kuliah'] == 1 ? "Hari Kuliah" : "Hari Libur";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryDetailScreen(sesiId: item['id']),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.account_balance_wallet,
                  NumberFormat.currency(
                    locale: 'id',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(totalPendapatan),
                  Colors.green,
                ),
                _buildInfoItem(
                  Icons.people,
                  "$totalTransaksi Pembeli",
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.location_on,
                  "$totalLokasi Lokasi",
                  Colors.redAccent,
                ),
                _buildInfoItem(
                  Icons.timer,
                  "${durasi.toStringAsFixed(1)} Jam",
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wb_sunny,
                        size: 12,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cuaca.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 12, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        hariKuliah.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
