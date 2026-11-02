import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../data/models/stolen_hotlist.dart';
import '../../data/repositories/hotlist_repository.dart';
import '../../services/theft_alert_service.dart';
import '../../core/utils/app_prefs.dart';
import '../widgets/stolen_alert_dialog.dart';

class TheftHotlistScreen extends StatefulWidget {
  const TheftHotlistScreen({super.key});

  @override
  State<TheftHotlistScreen> createState() => _TheftHotlistScreenState();
}

class _TheftHotlistScreenState extends State<TheftHotlistScreen> {
  final HotlistRepository _hotlistRepo = HotlistRepository();
  final TheftAlertService _theftAlertService = TheftAlertService();
  final Uuid _uuid = const Uuid();

  List<StolenHotlist> _hotlist = [];
  bool _isLoading = false;
  String _attendantName = 'Guard';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final attendant = await AppPrefs.getAttendantName();
    final list = await _hotlistRepo.getAllHotlist();
    if (mounted) {
      setState(() {
        _attendantName = attendant;
        _hotlist = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddStolenDialog() async {
    final plateController = TextEditingController();
    final firController = TextEditingController();
    final contactController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stolen Vehicle to Hotlist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Plate *',
                  hintText: 'e.g. ABC1234',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firController,
                decoration: const InputDecoration(
                  labelText: 'Police FIR Number',
                  hintText: 'e.g. FIR-2026/102',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Owner / Police Phone Contact',
                  hintText: 'e.g. +923001234567',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final plate = HotlistRepository.normalizePlate(plateController.text);
              if (plate.isEmpty) return;

              final newItem = StolenHotlist(
                stolenId: _uuid.v4(),
                vehicleNumber: plate,
                firNumber: firController.text.trim().isEmpty ? 'FIR-PENDING' : firController.text.trim(),
                ownerContact: contactController.text.trim(),
                dateAdded: DateTime.now(),
                isActive: true,
              );

              await _hotlistRepo.addStolenVehicle(newItem);
              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadData();
            },
            child: const Text('Add to Hotlist'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAlertSimulation(StolenHotlist item) async {
    await _theftAlertService.triggerTheftAlert(item);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StolenAlertDialog(
          stolenInfo: item,
          alertService: _theftAlertService,
          attendantName: _attendantName,
        ),
      );
    }
  }

  @override
  void dispose() {
    _theftAlertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stolen Vehicle Hotlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Stolen Vehicle',
            onPressed: _showAddStolenDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hotlist.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 64, color: Colors.green),
                      const SizedBox(height: 12),
                      const Text('Hotlist is empty. No active theft records.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Test Record'),
                        onPressed: _showAddStolenDialog,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hotlist.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _hotlist[index];
                    return Card(
                      color: item.isActive ? const Color(0xFFFEF2F2) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: item.isActive ? const Color(0xFFF87171) : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.vehicleNumber,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: item.isActive,
                                  activeColor: const Color(0xFFDC2626),
                                  onChanged: (val) async {
                                    await _hotlistRepo.toggleStatus(item.stolenId, val);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('FIR: ${item.firNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (item.ownerContact.isNotEmpty)
                              Text('Owner Contact: ${item.ownerContact}', style: const TextStyle(color: Colors.black54)),
                            Text('Added: ${DateFormat('yyyy-MM-dd').format(item.dateAdded)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                                  label: const Text('Simulate Alert Siren'),
                                  onPressed: () => _testAlertSimulation(item),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () async {
                                    await _hotlistRepo.removeStolenVehicle(item.stolenId);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        onPressed: _showAddStolenDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
