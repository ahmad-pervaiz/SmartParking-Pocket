import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/esc_pos_printer_service.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final String title;
  final String vehicleNumber;
  final String vehicleType;
  final String timeLabel;
  final String formattedTime;
  final String ticketOrSessionId;
  final String attendantName;
  final double? fee;
  final String? paymentMode;
  final String? durationDesc;
  final Future<List<int>> Function() getReceiptBytes;

  const ReceiptPreviewDialog({
    super.key,
    required this.title,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.timeLabel,
    required this.formattedTime,
    required this.ticketOrSessionId,
    required this.attendantName,
    this.fee,
    this.paymentMode,
    this.durationDesc,
    required this.getReceiptBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const Box64Constraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Receipt Paper Header Simulator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '58mm THERMAL RECEIPT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Text('SMARTPARKING POCKET', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(thickness: 1.5, height: 24),

              // Plate Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFFEF3C7),
                ),
                child: Text(
                  vehicleNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _row('Type:', vehicleType),
              _row(timeLabel, formattedTime),
              if (durationDesc != null) _row('Duration:', durationDesc!),
              if (fee != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Fee:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        'Rs. ${fee!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              if (paymentMode != null) _row('Payment Mode:', paymentMode!),
              _row('Ticket ID:', ticketOrSessionId.length > 8 ? ticketOrSessionId.substring(0, 8) : ticketOrSessionId),
              _row('Attendant:', attendantName),

              const Divider(thickness: 1.5, height: 24),

              // QR Code
              QrImageView(
                data: ticketOrSessionId,
                version: QrVersions.auto,
                size: 140.0,
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep receipt safe for exit gate verification',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print BT'),
                      onPressed: () async {
                        final bytes = await getReceiptBytes();
                        final printed = await EscPosPrinterService.instance.printBytes(bytes);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                printed
                                    ? 'Printed successfully!'
                                    : 'Printer not connected. Pair via Bluetooth in Settings.',
                              ),
                            ),
                          );
                        }
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
