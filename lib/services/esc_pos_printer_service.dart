import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:qr/qr.dart';
import '../models/vehicle_parked.dart';
import '../models/parking_history.dart';

class EscPosPrinterService {
  static final EscPosPrinterService instance = EscPosPrinterService._init();
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  EscPosPrinterService._init();

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<bool> isConnected() async {
    return (await _bluetooth.isConnected) ?? false;
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      final connected = await _bluetooth.isConnected ?? false;
      if (connected) {
        await _bluetooth.disconnect();
      }
      await _bluetooth.connect(device);
      _connectedDevice = device;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
      _connectedDevice = null;
    } catch (_) {}
  }

  /// Converts any string payload into an uncompressed raster bitmap for thermal 58mm ESC/POS printers
  img.Image generateQrBitmap(String data, {int size = 200}) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(255, 255, 255)); // white background

    final scale = size / qrImage.moduleCount;
    for (int x = 0; x < qrImage.moduleCount; x++) {
      for (int y = 0; y < qrImage.moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          // Draw dark pixel block
          img.fillRect(
            image,
            x1: (x * scale).toInt(),
            y1: (y * scale).toInt(),
            x2: ((x + 1) * scale).toInt(),
            y2: ((y + 1) * scale).toInt(),
            color: img.ColorRgb8(0, 0, 0), // black
          );
        }
      }
    }
    return image;
  }

  /// Build ESC/POS bytes for 58mm Paper: Vehicle Entry Ticket
  Future<List<int>> generateEntryReceiptBytes({
    required VehicleParked vehicle,
    required String parkingLotName,
    String? contactPhone,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDate = dateFormat.format(vehicle.entryTimestamp);

    // Header
    bytes += generator.reset();
    bytes += generator.text(
      parkingLotName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'ENTRY TICKET',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr(ch: '=');

    // Vehicle Details
    bytes += generator.text(
      'PLATE: ${vehicle.vehicleNumber}',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text('TYPE: ${vehicle.vehicleType}');
    bytes += generator.text('TIME: $formattedDate');
    bytes += generator.text('TICKET ID: ${vehicle.sessionId.substring(0, 8)}');
    bytes += generator.text('GUARD ID: ${vehicle.attendantIdEntry}');
    bytes += generator.hr();

    // QR Code for quick scan at exit gate
    final qrImg = generateQrBitmap(vehicle.sessionId, size: 220);
    bytes += generator.imageRaster(qrImg, align: PosAlign.center);
    bytes += generator.text(
      'Scan at Exit Gate',
      styles: const PosStyles(align: PosAlign.center, italic: true),
    );
    bytes += generator.hr();

    // Footer & Disclaimer
    bytes += generator.text(
      'Please keep ticket safe.',
      styles: const PosStyles(align: PosAlign.center),
    );
    if (contactPhone != null && contactPhone.isNotEmpty) {
      bytes += generator.text(
        'Helpline: $contactPhone',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Build ESC/POS bytes for 58mm Paper: Vehicle Exit Clearance Receipt
  Future<List<int>> generateExitReceiptBytes({
    required ParkingHistory history,
    required String parkingLotName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final inTime = dateFormat.format(history.entryTimestamp);
    final outTime = dateFormat.format(history.exitTimestamp);

    bytes += generator.reset();
    bytes += generator.text(
      parkingLotName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'PAYMENT CLEARANCE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr(ch: '=');

    bytes += generator.text('PLATE: ${history.vehicleNumber}', styles: const PosStyles(bold: true));
    bytes += generator.text('TYPE: ${history.vehicleType}');
    bytes += generator.text('IN : $inTime');
    bytes += generator.text('OUT: $outTime');
    bytes += generator.text('DURATION: ${history.durationMinutes} mins');
    bytes += generator.hr();

    bytes += generator.text(
      'FEE: Rs. ${history.feeCharged.toStringAsFixed(2)}',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text('MODE: ${history.paymentMode}');
    bytes += generator.text('GUARD: ${history.attendantIdExit}');
    bytes += generator.hr();

    bytes += generator.text('THANK YOU! DRIVE SAFELY', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Print directly to Bluetooth Thermal Printer
  Future<bool> printBytes(List<int> bytes) async {
    try {
      final isConn = await isConnected();
      if (!isConn) return false;
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }
}
