import 'package:flutter/material.dart';
import '../../data/repositories/parking_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/models/attendant_shift.dart';
import '../../core/utils/app_prefs.dart';
import 'scan_entry_screen.dart';
import 'scan_exit_screen.dart';
import 'lost_ticket_screen.dart';
import 'theft_hotlist_screen.dart';
import 'analytics_screen.dart';
import 'shift_screen.dart';
import 'printer_settings_screen.dart';
import 'rates_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ParkingRepository _parkingRepo = ParkingRepository();
  final ShiftRepository _shiftRepo = ShiftRepository();

  int _carsCount = 0;
  int _bikesCount = 0;
  int _totalCapacity = 150;
  String _lotName = 'CENTRAL PARKING';
  AttendantShift? _activeShift;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final cars = await _parkingRepo.getOccupancyCount('Car');
    final bikes = await _parkingRepo.getOccupancyCount('Bike');
    final cap = await AppPrefs.getLotCapacity();
    final lot = await AppPrefs.getLotName();
    final shift = await _shiftRepo.getActiveShift();

    if (mounted) {
      setState(() {
        _carsCount = cars;
        _bikesCount = bikes;
        _totalCapacity = cap;
        _lotName = lot;
        _activeShift = shift;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalParked = _carsCount + _bikesCount;
    final availableSpots = (_totalCapacity - totalParked) < 0 ? 0 : (_totalCapacity - totalParked);
    final occupancyRatio = _totalCapacity > 0 ? (totalParked / _totalCapacity).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_lotName),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Bluetooth Printer',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Rates & Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RatesSettingsScreen()),
              );
              _loadDashboardData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Attendant Banner
              InkWell(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShiftScreen()),
                  );
                  _loadDashboardData();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.person, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeShift != null ? 'Shift: ${_activeShift!.attendantName}' : 'No Active Shift (Tap to start)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (_activeShift != null)
                              Text(
                                'Drawer: Rs. ${_activeShift!.cashCollected.toStringAsFixed(0)} cash | Rs. ${_activeShift!.digitalCollected.toStringAsFixed(0)} QR',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1E3A8A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Occupancy Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LIVE LOT OCCUPANCY',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: availableSpots > 10 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$availableSpots SPOTS FREE',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$totalParked / $_totalCapacity',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${(occupancyRatio * 100).toStringAsFixed(0)}% FULL',
                          style: TextStyle(
                            color: occupancyRatio > 0.9 ? const Color(0xFFF87171) : Colors.cyanAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: occupancyRatio,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          occupancyRatio > 0.9 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _subCounter('Cars Inside', _carsCount, Icons.directions_car_rounded, const Color(0xFF60A5FA)),
                        ),
                        Container(width: 1, height: 30, color: Colors.white24),
                        Expanded(
                          child: _subCounter('Bikes Inside', _bikesCount, Icons.two_wheeler_rounded, const Color(0xFF4ADE80)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Big Action Grid (High-Contrast Buttons for Attendant)
              const Text('Guard Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'SCAN ENTRY',
                      subtitle: 'OCR Plate & Print Ticket',
                      icon: Icons.login_rounded,
                      color: const Color(0xFF1E3A8A),
                      onTap: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ScanEntryScreen()),
                        );
                        if (res == true) _loadDashboardData();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      title: 'SCAN EXIT',
                      subtitle: 'Auto-Fee & Clearance',
                      icon: Icons.logout_rounded,
                      color: const Color(0xFF0F766E), // Deep Teal
                      onTap: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ScanExitScreen()),
                        );
                        if (res == true) _loadDashboardData();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'LOST TICKET',
                      subtitle: 'Manual or Search by Plate',
                      icon: Icons.search_rounded,
                      color: const Color(0xFFB45309), // Amber/Brown
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LostTicketScreen()),
                        );
                        _loadDashboardData();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      title: 'THEFT HOTLIST',
                      subtitle: 'Police Stolen Records',
                      icon: Icons.shield_rounded,
                      color: const Color(0xFFB91C1C), // Deep Red
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TheftHotlistScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'ANALYTICS',
                      subtitle: 'Daily & Weekly Earnings',
                      icon: Icons.bar_chart_rounded,
                      color: const Color(0xFF4338CA), // Indigo
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      title: 'SHIFT REPORT',
                      subtitle: 'Close & WhatsApp Export',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF047857), // Emerald Green
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ShiftScreen()),
                        );
                        _loadDashboardData();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subCounter(String label, int val, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(val.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 125,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
