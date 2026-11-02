import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/repositories/parking_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ParkingRepository _parkingRepo = ParkingRepository();
  String _selectedPeriod = 'daily'; // 'daily', 'weekly', 'monthly'
  Map<String, dynamic>? _metrics;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final data = await _parkingRepo.getAnalyticsMetrics(period: _selectedPeriod);
    if (mounted) {
      setState(() {
        _metrics = data;
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
    _loadMetrics();
  }

  @override
  Widget build(BuildContext context) {
    final cash = _metrics?['cashTotal'] as double? ?? 0.0;
    final digital = _metrics?['digitalTotal'] as double? ?? 0.0;
    final grandTotal = _metrics?['grandTotal'] as double? ?? 0.0;
    final totalVehicles = _metrics?['totalVehiclesProcessed'] as int? ?? 0;
    final hourlyDistribution = (_metrics?['hourlyDistribution'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics & Traffic'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Period Toggle: Daily | Weekly | Monthly
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildFilterTab('daily', 'Today'),
                          _buildFilterTab('weekly', 'Last 7 Days'),
                          _buildFilterTab('monthly', 'Last 30 Days'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Grand Total Revenue Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL REVENUE',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Rs. ${grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Total Vehicles Processed: $totalVehicles',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Split Breakdown: Cash vs Digital QR
                    Row(
                      children: [
                        Expanded(
                          child: _buildSplitCard(
                            title: 'Cash Drawer',
                            amount: cash,
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF15803D),
                            bgColor: const Color(0xFFDCFCE7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSplitCard(
                            title: 'Digital QR Pay',
                            amount: digital,
                            icon: Icons.qr_code_2_rounded,
                            color: const Color(0xFF0369A1),
                            bgColor: const Color(0xFFE0F2FE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Peak Parking Hours Chart
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Peak Parking Hours (Traffic Volume)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Distribution of cleared vehicles across hours of the day',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 180,
                              child: hourlyDistribution.isEmpty
                                  ? const Center(
                                      child: Text('No traffic data recorded in this period yet', style: TextStyle(color: Colors.grey)),
                                    )
                                  : BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        maxY: _getMaxCount(hourlyDistribution) * 1.25,
                                        barTouchData: BarTouchData(enabled: true),
                                        titlesData: FlTitlesData(
                                          show: true,
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              getTitlesWidget: (val, meta) {
                                                final idx = val.toInt();
                                                if (idx >= 0 && idx < hourlyDistribution.length) {
                                                  final hour = hourlyDistribution[idx]['hour'].toString();
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text('${hour}h', style: const TextStyle(fontSize: 10)),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                            ),
                                          ),
                                          leftTitles: const AxisTitles(
                                            sideTitles: SideTitles(showTitles: false),
                                          ),
                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        gridData: const FlGridData(show: false),
                                        borderData: FlBorderData(show: false),
                                        barGroups: List.generate(hourlyDistribution.length, (index) {
                                          final item = hourlyDistribution[index];
                                          final count = (item['count'] as num).toDouble();
                                          return BarChartGroupData(
                                            x: index,
                                            barRods: [
                                              BarChartRodData(
                                                toY: count,
                                                color: const Color(0xFF1E3A8A),
                                                width: 14,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  double _getMaxCount(List<dynamic> list) {
    double maxVal = 5.0;
    for (final item in list) {
      final c = (item['count'] as num).toDouble();
      if (c > maxVal) maxVal = c;
    }
    return maxVal;
  }

  Widget _buildFilterTab(String periodKey, String label) {
    final isSelected = _selectedPeriod == periodKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPeriodChanged(periodKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF1E3A8A) : Colors.black54,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}
