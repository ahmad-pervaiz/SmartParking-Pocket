import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/vehicle_parked.dart';
import '../../data/repositories/parking_repository.dart';
import 'scan_exit_screen.dart';

class LostTicketScreen extends StatefulWidget {
  const LostTicketScreen({super.key});

  @override
  State<LostTicketScreen> createState() => _LostTicketScreenState();
}

class _LostTicketScreenState extends State<LostTicketScreen> {
  final ParkingRepository _parkingRepo = ParkingRepository();
  final TextEditingController _searchController = TextEditingController();
  List<VehicleParked> _parkedList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllParked();
  }

  Future<void> _loadAllParked() async {
    setState(() => _isLoading = true);
    final list = await _parkingRepo.getAllParkedVehicles();
    if (mounted) {
      setState(() {
        _parkedList = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      await _loadAllParked();
      return;
    }
    setState(() => _isLoading = true);
    final results = await _parkingRepo.searchParkedVehicles(query);
    if (mounted) {
      setState(() {
        _parkedList = results;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Ticket Recovery'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF1F5F9),
            child: TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Search by full or partial plate...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadAllParked();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _performSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_parkedList.length} Active Sessions Found',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  onPressed: _loadAllParked,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _parkedList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No vehicles found matching criteria', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _parkedList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _parkedList[index];
                          final duration = DateTime.now().difference(item.entryTimestamp);
                          final hours = duration.inHours;
                          final mins = duration.inMinutes % 60;
                          final durationStr = hours > 0 ? '$hours hr $mins min' : '$mins min';

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: item.vehicleType == 'Bike'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFDBEAFE),
                                    foregroundColor: item.vehicleType == 'Bike'
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF1D4ED8),
                                    radius: 26,
                                    child: Icon(
                                      item.vehicleType == 'Bike'
                                          ? Icons.two_wheeler_rounded
                                          : Icons.directions_car_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.vehicleNumber,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'In: ${DateFormat('HH:mm (dd MMM)').format(item.entryTimestamp)}',
                                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                                        ),
                                        Text(
                                          'Parked for: $durationStr',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: () async {
                                      final cleared = await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => ScanExitScreen(initialPlate: item.vehicleNumber),
                                        ),
                                      );
                                      if (cleared == true) {
                                        _loadAllParked();
                                      }
                                    },
                                    child: const Text('Exit & Pay', style: TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
