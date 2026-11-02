import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/vehicle_parked.dart';
import '../../data/models/parking_history.dart';
import '../../data/repositories/parking_repository.dart';
import '../../data/repositories/rates_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/hotlist_repository.dart';
import '../../services/pricing_service.dart';
import '../../services/esc_pos_printer_service.dart';
import '../../services/ocr_service.dart';
import '../../core/utils/app_prefs.dart';
import '../widgets/receipt_preview_dialog.dart';

class ScanExitScreen extends StatefulWidget {
  final String? initialPlate;

  const ScanExitScreen({super.key, this.initialPlate});

  @override
  State<ScanExitScreen> createState() => _ScanExitScreenState();
}

class _ScanExitScreenState extends State<ScanExitScreen> {
  final ParkingRepository _parkingRepo = ParkingRepository();
  final RatesRepository _ratesRepo = RatesRepository();
  final ShiftRepository _shiftRepo = ShiftRepository();
  final OcrService _ocrService = OcrService();
  final Uuid _uuid = const Uuid();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingOcr = false;

  final TextEditingController _plateController = TextEditingController();
  VehicleParked? _matchedSession;
  PricingCalculationResult? _calculation;
  String _selectedPaymentMode = 'Cash'; // 'Cash' or 'Digital_QR'
  bool _isLoading = false;
  String _attendantName = 'Guard 1';
  String _lotName = 'CENTRAL PARKING';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initCamera();
    if (widget.initialPlate != null && widget.initialPlate!.isNotEmpty) {
      _plateController.text = widget.initialPlate!;
      _searchPlate(widget.initialPlate!);
    }
  }

  Future<void> _loadPrefs() async {
    final attendant = await AppPrefs.getAttendantName();
    final lot = await AppPrefs.getLotName();
    if (mounted) {
      setState(() {
        _attendantName = attendant;
        _lotName = lot;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (_) {}
  }

  Future<void> _captureAndScanPlate() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessingOcr) return;

    setState(() => _isProcessingOcr = true);
    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final plates = await _ocrService.extractLicensePlates(inputImage);

      if (plates.isNotEmpty) {
        final detected = plates.first;
        _plateController.text = detected;
        await _searchPlate(detected);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No plate detected. Adjust angle or type plate manually.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _searchPlate(String rawText) async {
    final cleaned = HotlistRepository.normalizePlate(rawText);
    if (cleaned.isEmpty) {
      setState(() {
        _matchedSession = null;
        _calculation = null;
      });
      return;
    }

    final session = await _parkingRepo.getParkedVehicleByPlate(cleaned);
    if (session != null) {
      final rate = await _ratesRepo.getRatesFor(session.vehicleType);
      final calc = PricingService.calculateFee(
        entryTime: session.entryTimestamp,
        exitTime: DateTime.now(),
        rateConfig: rate,
      );

      setState(() {
        _matchedSession = session;
        _calculation = calc;
      });
    } else {
      setState(() {
        _matchedSession = null;
        _calculation = null;
      });
    }
  }

  Future<void> _processExitAndClearance() async {
    if (_matchedSession == null || _calculation == null) return;

    setState(() => _isLoading = true);

    final exitTime = DateTime.now();
    final historyEntry = ParkingHistory(
      historyId: _uuid.v4(),
      sessionId: _matchedSession!.sessionId,
      vehicleNumber: _matchedSession!.vehicleNumber,
      vehicleType: _matchedSession!.vehicleType,
      entryTimestamp: _matchedSession!.entryTimestamp,
      exitTimestamp: exitTime,
      durationMinutes: _calculation!.durationMinutes,
      feeCharged: _calculation!.feeCharged,
      paymentMode: _selectedPaymentMode,
      attendantIdExit: _attendantName,
    );

    // 1. Transaction: Record history & purge from active parked
    await _parkingRepo.checkoutVehicle(historyEntry);

    // 2. Record cash/digital in active shift
    await _shiftRepo.recordPayment(
      amount: _calculation!.feeCharged,
      isCash: _selectedPaymentMode == 'Cash',
    );

    // 3. Generate ESC/POS exit clearance ticket
    final exitReceiptBytes = await EscPosPrinterService.instance.generateExitReceiptBytes(
      history: historyEntry,
      parkingLotName: _lotName,
    );

    // Print
    final printed = await EscPosPrinterService.instance.printBytes(exitReceiptBytes);

    setState(() => _isLoading = false);

    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => ReceiptPreviewDialog(
          title: 'Exit Clearance',
          vehicleNumber: historyEntry.vehicleNumber,
          vehicleType: historyEntry.vehicleType,
          timeLabel: 'Exit Time:',
          formattedTime: DateFormat('yyyy-MM-dd HH:mm').format(exitTime),
          ticketOrSessionId: historyEntry.sessionId,
          attendantName: historyEntry.attendantIdExit,
          fee: historyEntry.feeCharged,
          paymentMode: historyEntry.paymentMode,
          durationDesc: _calculation!.durationDescription,
          getReceiptBytes: () async => exitReceiptBytes,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Cleared ${_matchedSession!.vehicleNumber}! Fee: Rs. ${_calculation!.feeCharged.toStringAsFixed(2)} ${printed ? "(Printed)" : ""}'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ocrService.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Vehicle Exit & Payment')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Camera scanner view
            Container(
              height: 200,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    CameraPreview(_cameraController!)
                  else
                    const Center(
                      child: Text('Camera ready / Enter plate below', style: TextStyle(color: Colors.white70)),
                    ),
                  Positioned(
                    bottom: 10,
                    right: 16,
                    left: 16,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
                      icon: _isProcessingOcr
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(_isProcessingOcr ? 'Scanning Plate OCR...' : 'Scan Plate with OCR'),
                      onPressed: _isProcessingOcr ? null : _captureAndScanPlate,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Plate Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _plateController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Vehicle Plate to Exit',
                            hintText: 'e.g. ABC1234',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: _searchPlate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchPlate(_plateController.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_matchedSession != null && _calculation != null) ...[
                    // Active Session Found Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _matchedSession!.vehicleNumber,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                              ),
                              Chip(
                                label: Text(_matchedSession!.vehicleType),
                                backgroundColor: const Color(0xFFEFF6FF),
                              ),
                            ],
                          ),
                          const Divider(),
                          _infoRow('Parked In:', DateFormat('yyyy-MM-dd HH:mm').format(_matchedSession!.entryTimestamp)),
                          _infoRow('Current Time:', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
                          _infoRow('Total Duration:', _calculation!.durationDescription),
                          if (_calculation!.isGracePeriodApplied)
                            const Text(
                              '⚡ Grace period applied: Free of charge',
                              style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL PAYABLE:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  'Rs. ${_calculation!.feeCharged.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Payment Method Toggle
                    const Text('Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedPaymentMode = 'Cash'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedPaymentMode == 'Cash' ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '💵 Cash in Hand',
                                  style: TextStyle(
                                    color: _selectedPaymentMode == 'Cash' ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedPaymentMode = 'Digital_QR'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedPaymentMode == 'Digital_QR' ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '📱 Digital QR Pay',
                                  style: TextStyle(
                                    color: _selectedPaymentMode == 'Digital_QR' ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_selectedPaymentMode == 'Digital_QR') ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            const Text('Driver Scans to Pay via UPI / Digital Wallet:', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            QrImageView(
                              data: 'upi://pay?pa=parking@bank&am=${_calculation!.feeCharged}&cu=INR&tn=Parking_${_matchedSession!.vehicleNumber}',
                              version: QrVersions.auto,
                              size: 140.0,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Complete Exit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _processExitAndClearance,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded),
                                SizedBox(width: 8),
                                Text('COLLECT & CLEAR VEHICLE', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                    ),
                  ] else if (_plateController.text.isNotEmpty) ...[
                    // Not found warning
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'No active parking record found for "${_plateController.text.toUpperCase()}".',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Check plate spelling or use Lost Ticket Search.',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
