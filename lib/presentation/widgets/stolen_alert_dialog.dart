import 'package:flutter/material.dart';
import '../../data/models/stolen_hotlist.dart';
import '../../services/theft_alert_service.dart';

class StolenAlertDialog extends StatelessWidget {
  final StolenHotlist stolenInfo;
  final TheftAlertService alertService;
  final String attendantName;

  const StolenAlertDialog({
    super.key,
    required this.stolenInfo,
    required this.alertService,
    required this.attendantName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFF991B1B), // Intense Warning Red
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 96,
                ),
                const SizedBox(height: 16),
                const Text(
                  'HOTLIST THEFT ALERT!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This vehicle is flagged as STOLEN in the local police database.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        stolenInfo.vehicleNumber,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFEF08A), // Light Amber
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      _detailRow('FIR Number:', stolenInfo.firNumber),
                      const SizedBox(height: 6),
                      _detailRow('Owner Contact:', stolenInfo.ownerContact.isEmpty ? 'Not Provided' : stolenInfo.ownerContact),
                      const SizedBox(height: 6),
                      _detailRow('Date Added:', stolenInfo.dateAdded.toString().substring(0, 10)),
                    ],
                  ),
                ),
                const Spacer(),
                // Actions
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF991B1B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.sms_rounded),
                  label: const Text(
                    'DISPATCH EMERGENCY ALERT SMS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () async {
                    final sent = await alertService.sendOwnerEmergencySms(
                      stolenInfo: stolenInfo,
                      attendantName: attendantName,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent ? 'Emergency SMS client opened!' : 'Failed to launch SMS. Check phone number.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.volume_off_rounded),
                  label: const Text(
                    'SILENCE ALARM & DISMISS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () async {
                    await alertService.stopAlert();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}
