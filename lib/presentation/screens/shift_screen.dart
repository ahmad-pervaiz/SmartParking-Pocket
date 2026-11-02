import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendant_shift.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/parking_repository.dart';
import '../../services/whatsapp_service.dart';
import '../../core/utils/app_prefs.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final ShiftRepository _shiftRepo = ShiftRepository();
  final ParkingRepository _parkingRepo = ParkingRepository();

  AttendantShift? _activeShift;
  bool _isLoading = false;
  int _bikesHandled = 0;
  int _carsHandled = 0;
  int _otherHandled = 0;
  String _parkingLotName = 'CENTRAL PARKING';
  String _ownerPhone = '+923001234567';

  @override
  void initState() {
    super.initState();
    _loadShiftData();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    final lot = await AppPrefs.getLotName();
    final ownerPhone = await AppPrefs.getOwnerPhone();
    final currentShift = await _shiftRepo.getActiveShift();

    int bikes = 0;
    int cars = 0;
    int other = 0;

    if (currentShift != null) {
      final history = await _parkingRepo.getHistory(from: currentShift.startTime);
      for (final h in history) {
        if (h.vehicleType == 'Bike') {
          bikes++;
        } else if (h.vehicleType == 'Car') {
          cars++;
        } else {
          other++;
        }
      }
    }

    if (mounted) {
      setState(() {
        _parkingLotName = lot;
        _ownerPhone = ownerPhone;
        _activeShift = currentShift;
        _bikesHandled = bikes;
        _carsHandled = cars;
        _otherHandled = other;
        _isLoading = false;
      });
    }
  }

  Future<void> _startNewShift() async {
    final nameController = TextEditingController(text: await AppPrefs.getAttendantName());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start New Shift'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Attendant Name',
            hintText: 'e.g. Guard Ali',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await AppPrefs.setAttendantName(name);
                await _shiftRepo.startShift(name);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadShiftData();
              }
            },
            child: const Text('Start Shift'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeShiftAndReport() async {
    if (_activeShift == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Active Shift?'),
        content: const Text(
          'Closing this shift will finalize cash in drawer and produce the WhatsApp closing report for the parking owner.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Close'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final closedShift = await _shiftRepo.closeShift(_activeShift!.shiftId);
    setState(() => _isLoading = false);

    if (closedShift != null && mounted) {
      final reportText = WhatsAppShiftReportService.formatShiftReport(
        shift: closedShift,
        bikesHandled: _bikesHandled,
        carsHandled: _carsHandled,
        otherVehiclesHandled: _otherHandled,
        parkingLotName: _parkingLotName,
      );

      // Show summary and WhatsApp send button
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                  SizedBox(width: 8),
                  Text('Shift Closed Successfully', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  reportText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text('SEND REPORT TO OWNER VIA WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final launched = await WhatsAppShiftReportService.sendViaWhatsApp(
                    ownerPhoneNumber: _ownerPhone,
                    reportText: reportText,
                  );
                  if (ctx.mounted) {
                    if (!launched) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('WhatsApp not installed or invalid phone number.')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );

      _loadShiftData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendant Shift Handover'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeShift == null) ...[
                    // No active shift
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No Active Shift in Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Start your shift to begin recording payments and vehicle entries.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start Shift Now'),
                              onPressed: _startNewShift,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Active shift details
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ACTIVE ATTENDANT', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text(
                                    _activeShift!.attendantName,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    CircleAvatar(backgroundColor: Color(0xFF16A34A), radius: 4),
                                    SizedBox(width: 6),
                                    Text('LIVE', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _infoLine('Shift Started:', DateFormat('yyyy-MM-dd HH:mm').format(_activeShift!.startTime)),
                          _infoLine('Elapsed Time:', _calculateElapsed(_activeShift!.startTime)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shift Handled Counts
                    Row(
                      children: [
                        _buildVehicleCounter('Cars Handled', _carsHandled, Icons.directions_car_rounded, const Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        _buildVehicleCounter('Bikes Handled', _bikesHandled, Icons.two_wheeler_rounded, const Color(0xFF059669)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Financial Reconciliation
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CASH & DIGITAL RECONCILIATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('💵 Cash in Drawer:', style: TextStyle(fontSize: 15)),
                              Text('Rs. ${_activeShift!.cashCollected.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('📱 Digital QR Payments:', style: TextStyle(fontSize: 15)),
                              Text('Rs. ${_activeShift!.digitalCollected.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL SHIFT REVENUE:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              Text(
                                'Rs. ${_activeShift!.totalRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Shift Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('CLOSE SHIFT & EXPORT TO WHATSAPP', style: TextStyle(fontSize: 15)),
                      onPressed: _closeShiftAndReport,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _calculateElapsed(DateTime start) {
    final diff = DateTime.now().difference(start);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '$hours hr $mins min';
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVehicleCounter(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(count.toString(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
