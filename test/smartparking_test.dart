import 'package:flutter_test/flutter_test.dart';
import 'package:smartparking_pocket/data/models/rates_config.dart';
import 'package:smartparking_pocket/data/models/attendant_shift.dart';
import 'package:smartparking_pocket/services/ocr_service.dart';
import 'package:smartparking_pocket/services/pricing_service.dart';
import 'package:smartparking_pocket/services/whatsapp_service.dart';
import 'package:smartparking_pocket/data/repositories/hotlist_repository.dart';

void main() {
  group('Module 1: OCR & Plate Normalization Tests', () {
    test('Cleans spaces, hyphens, and lowercase symbols to uniform alphanumeric string', () {
      expect(OcrService.cleanPlateText('abc-1234'), 'ABC1234');
      expect(OcrService.cleanPlateText(' LEA 5544 '), 'LEA5544');
      expect(OcrService.cleanPlateText('ict_#9901!'), 'ICT9901');
      expect(HotlistRepository.normalizePlate('khi - 4521 '), 'KHI4521');
    });

    test('Identifies valid plate patterns vs invalid noise', () {
      expect(OcrService.looksLikePlate('ABC1234'), isTrue);
      expect(OcrService.looksLikePlate('LEA99'), isTrue);
      expect(OcrService.looksLikePlate('12'), isFalse); // too short
      expect(OcrService.looksLikePlate('ABCDEFGHIJKLMN'), isFalse); // too long
    });
  });

  group('Module 2: Pricing Engine Calculations', () {
    const flatBikeRate = RatesConfig(
      vehicleType: 'Bike',
      baseFee: 20.0,
      pricingModel: 'Flat_Rate',
      gracePeriodMins: 10,
    );

    const hourlyCarRate = RatesConfig(
      vehicleType: 'Car',
      baseFee: 50.0,
      pricingModel: 'Hourly_Slab',
      gracePeriodMins: 10,
    );

    test('Grace period (under 10 minutes) incurs zero fee', () {
      final entry = DateTime(2026, 11, 3, 10, 0);
      final exit = DateTime(2026, 11, 3, 10, 8); // 8 mins

      final result = PricingService.calculateFee(
        entryTime: entry,
        exitTime: exit,
        rateConfig: hourlyCarRate,
      );

      expect(result.durationMinutes, 8);
      expect(result.feeCharged, 0.0);
      expect(result.isGracePeriodApplied, isTrue);
    });

    test('Flat Rate for bike charges fixed base fee regardless of long duration', () {
      final entry = DateTime(2026, 11, 3, 8, 0);
      final exit = DateTime(2026, 11, 3, 14, 30); // 6.5 hours

      final result = PricingService.calculateFee(
        entryTime: entry,
        exitTime: exit,
        rateConfig: flatBikeRate,
      );

      expect(result.feeCharged, 20.0);
      expect(result.isGracePeriodApplied, isFalse);
    });

    test('Hourly Slab charges ceiling of hours', () {
      final entry = DateTime(2026, 11, 3, 10, 0);
      final exit = DateTime(2026, 11, 3, 11, 15); // 1 hr 15 mins => 2 hours billed

      final result = PricingService.calculateFee(
        entryTime: entry,
        exitTime: exit,
        rateConfig: hourlyCarRate,
      );

      expect(result.durationMinutes, 75);
      expect(result.feeCharged, 100.0); // 2 hours * 50
    });
  });

  group('Module 5: Shift Report WhatsApp Formatter', () {
    test('Correctly computes totals and formats WhatsApp text', () {
      final shift = AttendantShift(
        shiftId: 'shift-12345678-abc',
        attendantName: 'Guard Ali',
        startTime: DateTime(2026, 11, 3, 8, 0),
        endTime: DateTime(2026, 11, 3, 16, 0),
        cashCollected: 1200.0,
        digitalCollected: 850.0,
        status: 'CLOSED',
      );

      final report = WhatsAppShiftReportService.formatShiftReport(
        shift: shift,
        bikesHandled: 25,
        carsHandled: 15,
        otherVehiclesHandled: 2,
        parkingLotName: 'Metro Central Parking',
      );

      expect(report.contains('Metro Central Parking'), isTrue);
      expect(report.contains('Guard Ali'), isTrue);
      expect(report.contains('Bikes Handled:* 25'), isTrue);
      expect(report.contains('Cars Handled:*  15'), isTrue);
      expect(report.contains('Total Vehicles:* 42'), isTrue);
      expect(report.contains('Cash in Drawer:* Rs. 1200.00'), isTrue);
      expect(report.contains('Digital QR:*     Rs. 850.00'), isTrue);
      expect(report.contains('TOTAL REVENUE:*  Rs. 2050.00'), isTrue);
    });
  });
}
