import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../data/models/vehicle_parked.dart';
import '../../data/repositories/parking_repository.dart';
import '../../data/repositories/hotlist_repository.dart';
import '../../services/theft_alert_service.dart';
import '../../services/esc_pos_printer_service.dart';
import '../../services/ocr_service.dart';
import '../../core/utils/app_prefs.dart';
import '../widgets/stolen_alert_dialog.dart';
import '../widgets/receipt_preview_dialog.dart';

class ScanEntryScreen extends StatefulWidget {
  const ScanEntryScreen({super.key});

  @override
  State<ScanEntryScreen> createState() => _ScanEntryScreenState();
}

class _ScanEntryScreenState extends State<ScanEntryScreen> {
  final ParkingRepository _parkingRepo = ParkingRepository();
  final HotlistRepository _hotlistRepo = HotlistRepository();
  final TheftAlertService _theftAlertService = TheftAlertService();
  final OcrService _ocrService = OcrService();
  final Uuid _uuid = const Uuid();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingOcr = false;

  final TextEditingController _plateController = TextEditingController();
  String _selectedVehicleType = 'Car';
  bool _isLoading = false;
  String _attendantName = 'Guard 1';
  String _lotName = 'CENTRAL PARKING';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initCamera();
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
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (_) {
      // Camera optional / fallback for testing on emulator or devices without camera
    }
  }

  /// On-Device OCR Trigger
  Future<void> _captureAndScanPlate() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not ready. You can type the plate manually below.')),
      );
      return;
    }

    if (_isProcessingOcr) return;

    setState(() => _isProcessingOcr = true);
    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final plates = await _ocrService.extractLicensePlates(inputImage);

      if (plates.isNotEmpty) {
        final detected = plates.first;
        _plateController.text = detected;
        await _onPlateChanged(detected);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detected Plate: $detected')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No plate recognized. Adjust angle or type manually.')),
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

  /// Live check against Stolen_Hotlist
  Future<void> _onPlateChanged(String text) async {
    final cleaned = HotlistRepository.normalizePlate(text);
    if (cleaned.length >= 3) {
      final stolenMatch = await _hotlistRepo.checkPlate(cleaned);
      if (stolenMatch != null && mounted) {
        // Trigger alert siren & vibration
        await _theftAlertService.triggerTheftAlert(stolenMatch);
        // Display full-screen red warning modal
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => StolenAlertDialog(
              stolenInfo: stolenMatch,
              alertService: _theftAlertService,
              attendantName: _attendantName,
            ),
          );
        }
      }
    }
  }

  /// Confirm Entry and Print Ticket
  Future<void> _confirmEntry() async {
    final plate = HotlistRepository.normalizePlate(_plateController.text);
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter a vehicle plate number')),
      );
      return;
    }

    // Verify if already parked
    final alreadyParked = await _parkingRepo.getParkedVehicleByPlate(plate);
    if (alreadyParked != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            content: Text('Vehicle $plate is already parked inside since ${DateFormat('HH:mm').format(alreadyParked.entryTimestamp)}!'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final newSession = VehicleParked(
      sessionId: _uuid.v4(),
      vehicleNumber: plate,
      vehicleType: _selectedVehicleType,
      entryTimestamp: DateTime.now(),
      attendantIdEntry: _attendantName,
      status: 'PARKED',
    );

    await _parkingRepo.parkVehicle(newSession);

    // Generate ESC/POS byte sequence
    final receiptBytes = await EscPosPrinterService.instance.generateEntryReceiptBytes(
      vehicle: newSession,
      parkingLotName: _lotName,
    );

    // Attempt direct Bluetooth thermal print
    final printed = await EscPosPrinterService.instance.printBytes(receiptBytes);

    setState(() => _isLoading = false);

    if (mounted) {
      // Show receipt preview dialog with success confirmation
      await showDialog(
        context: context,
        builder: (_) => ReceiptPreviewDialog(
          title: 'Entry Ticket',
          vehicleNumber: newSession.vehicleNumber,
          vehicleType: newSession.vehicleType,
          timeLabel: 'Entry Time:',
          formattedTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(newSession.entryTimestamp),
          ticketOrSessionId: newSession.sessionId,
          attendantName: newSession.attendantIdEntry,
          getReceiptBytes: () async => receiptBytes,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Vehicle $plate parked successfully! ${printed ? "Receipt printed." : ""}'),
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
    _theftAlertService.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Vehicle Entry'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Camera Viewfinder Box
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    CameraPreview(_cameraController!)
                  else
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Camera ready / Manual Entry below', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),

                  // Viewfinder Target Overlay
                  Center(
                    child: Container(
                      width: 260,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyanAccent, width: 2.5),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.cyanAccent.withOpacity(0.08),
                      ),
                      child: const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Align Plate Here',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // OCR Scan Button Floating at bottom
                  Positioned(
                    bottom: 12,
                    right: 16,
                    left: 16,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isProcessingOcr
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.document_scanner_rounded),
                      label: Text(_isProcessingOcr ? 'Scanning On-Device ML Kit...' : 'Capture Plate OCR'),
                      onPressed: _isProcessingOcr ? null : _captureAndScanPlate,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Plate Input Field
                  TextField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      labelText: 'Vehicle License Plate',
                      hintText: 'e.g. ABC1234',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _plateController.clear(),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: _onPlateChanged,
                  ),
                  const SizedBox(height: 20),

                  // Vehicle Type Selector Chips
                  const Text('Select Vehicle Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildTypeChip('Car', Icons.directions_car_rounded),
                      const SizedBox(width: 10),
                      _buildTypeChip('Bike', Icons.two_wheeler_rounded),
                      const SizedBox(width: 10),
                      _buildTypeChip('Other', Icons.local_shipping_rounded),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Confirm Entry Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _confirmEntry,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_rounded),
                              SizedBox(width: 10),
                              Text('CONFIRM ENTRY & PRINT RECEIPT', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, IconData icon) {
    final isSelected = _selectedVehicleType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedVehicleType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(height: 4),
              Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
