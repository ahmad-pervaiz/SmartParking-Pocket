import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../services/esc_pos_printer_service.dart';
import '../../data/models/vehicle_parked.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final EscPosPrinterService _printerService = EscPosPrinterService.instance;

  List<BluetoothDevice> _devices = [];
  bool _isConnected = false;
  bool _isLoading = false;
  BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _checkStatusAndLoad();
  }

  Future<void> _checkStatusAndLoad() async {
    setState(() => _isLoading = true);
    final isConn = await _printerService.isConnected();
    final paired = await _printerService.getPairedDevices();
    if (mounted) {
      setState(() {
        _isConnected = isConn;
        _devices = paired;
        _selectedDevice = _printerService.connectedDevice;
        _isLoading = false;
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    final success = await _printerService.connect(device);
    if (mounted) {
      setState(() {
        _isConnected = success;
        _selectedDevice = success ? device : null;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Connected to ${device.name}' : 'Failed to connect to ${device.name}'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await _printerService.disconnect();
    if (mounted) {
      setState(() {
        _isConnected = false;
        _selectedDevice = null;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer disconnected')),
      );
    }
  }

  Future<void> _testPrint() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect a thermal printer first!')),
      );
      return;
    }

    final dummy = VehicleParked(
      sessionId: 'TEST-SESSION-DEMO-001',
      vehicleNumber: 'TEST-123',
      vehicleType: 'Car',
      entryTimestamp: DateTime.now(),
      attendantIdEntry: 'Demo Attendant',
    );

    final bytes = await _printerService.generateEntryReceiptBytes(
      vehicle: dummy,
      parkingLotName: 'SMARTPARKING POCKET TEST',
      contactPhone: '+92 300 1234567',
    );

    final printed = await _printerService.printBytes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(printed ? 'Test print sent!' : 'Print command failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Thermal Printer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh devices',
            onPressed: _checkStatusAndLoad,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: _isConnected ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isConnected ? 'PRINTER CONNECTED' : 'NO PRINTER CONNECTED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isConnected ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _isConnected && _selectedDevice != null
                                    ? '${_selectedDevice!.name ?? "Unknown"} (${_selectedDevice!.address})'
                                    : 'Select a paired 58mm ESC/POS printer below',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        if (_isConnected)
                          OutlinedButton(
                            onPressed: _disconnect,
                            child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Test Print Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print 58mm Test Receipt & QR'),
                    onPressed: _testPrint,
                  ),
                  const SizedBox(height: 24),

                  // Paired Devices List
                  const Text('Paired Bluetooth Devices:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _devices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text(
                                  'No paired Bluetooth devices found.\nPair your thermal printer in Android Bluetooth settings first.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _checkStatusAndLoad,
                                  child: const Text('Scan Again'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _devices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final d = _devices[index];
                              final isThisConnected = _isConnected && _selectedDevice?.address == d.address;

                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: const Icon(Icons.print, color: Color(0xFF1E3A8A)),
                                  title: Text(d.name ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(d.address ?? 'MAC Address'),
                                  trailing: isThisConnected
                                      ? const Chip(
                                          label: Text('Connected', style: TextStyle(color: Colors.white, fontSize: 11)),
                                          backgroundColor: Color(0xFF16A34A),
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _connect(d),
                                          child: const Text('Connect'),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
