import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/attendant_shift.dart';

class WhatsAppShiftReportService {
  /// Generates human-readable, professional shift closing summary
  static String formatShiftReport({
    required AttendantShift shift,
    required int bikesHandled,
    required int carsHandled,
    required int otherVehiclesHandled,
    required String parkingLotName,
  }) {
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');
    final startTimeStr = timeFormat.format(shift.startTime);
    final endTimeStr = shift.endTime != null
        ? timeFormat.format(shift.endTime!)
        : timeFormat.format(DateTime.now());

    final totalVehicles = bikesHandled + carsHandled + otherVehiclesHandled;
    final totalRevenue = shift.cashCollected + shift.digitalCollected;

    return '''
📊 *PARKING SHIFT CLOSING REPORT*
-----------------------------------
🏢 *Lot:* $parkingLotName
👤 *Attendant:* ${shift.attendantName}
🆔 *Shift ID:* ${shift.shiftId.substring(0, 8)}
⏰ *Start:* $startTimeStr
🏁 *End:*   $endTimeStr
-----------------------------------
🛵 *Bikes Handled:* $bikesHandled
🚗 *Cars Handled:*  $carsHandled
🚐 *Other Vehicles:* $otherVehiclesHandled
📈 *Total Vehicles:* $totalVehicles
-----------------------------------
💵 *Cash in Drawer:* Rs. ${shift.cashCollected.toStringAsFixed(2)}
📱 *Digital QR:*     Rs. ${shift.digitalCollected.toStringAsFixed(2)}
💰 *TOTAL REVENUE:*  Rs. ${totalRevenue.toStringAsFixed(2)}
-----------------------------------
✅ Shift verified and closed.
''';
  }

  /// Launch WhatsApp with prefilled shift closing report
  static Future<bool> sendViaWhatsApp({
    required String ownerPhoneNumber,
    required String reportText,
  }) async {
    // Normalize phone number (digits only, e.g. international format without leading +)
    final cleanPhone = ownerPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMessage = Uri.encodeComponent(reportText);

    // Try wa.me deep link first, then whatsapp://send scheme
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
    final nativeUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');

    try {
      if (await canLaunchUrl(nativeUrl)) {
        return await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
