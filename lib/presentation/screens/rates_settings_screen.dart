import 'package:flutter/material.dart';
import '../../data/models/rates_config.dart';
import '../../data/repositories/rates_repository.dart';
import '../../core/utils/app_prefs.dart';

class RatesSettingsScreen extends StatefulWidget {
  const RatesSettingsScreen({super.key});

  @override
  State<RatesSettingsScreen> createState() => _RatesSettingsScreenState();
}

class _RatesSettingsScreenState extends State<RatesSettingsScreen> {
  final RatesRepository _ratesRepo = RatesRepository();
  List<RatesConfig> _rates = [];
  bool _isLoading = false;

  final TextEditingController _lotNameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _ownerPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final rates = await _ratesRepo.getAllRates();
    final lot = await AppPrefs.getLotName();
    final cap = await AppPrefs.getLotCapacity();
    final phone = await AppPrefs.getOwnerPhone();

    _lotNameController.text = lot;
    _capacityController.text = cap.toString();
    _ownerPhoneController.text = phone;

    if (mounted) {
      setState(() {
        _rates = rates;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLotDetails() async {
    await AppPrefs.setLotName(_lotNameController.text.trim());
    final cap = int.tryParse(_capacityController.text.trim()) ?? 150;
    await AppPrefs.setLotCapacity(cap);
    await AppPrefs.setOwnerPhone(_ownerPhoneController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lot settings saved!')),
      );
    }
  }

  Future<void> _editRate(RatesConfig current) async {
    final feeController = TextEditingController(text: current.baseFee.toStringAsFixed(0));
    final graceController = TextEditingController(text: current.gracePeriodMins.toString());
    String model = current.pricingModel;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Configure ${current.vehicleType} Rates'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: feeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Base Rate / Hourly Rate (Rs.)',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: graceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Grace Period (Minutes)',
                    suffixText: 'mins',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pricing Model:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: model,
                  items: const [
                    DropdownMenuItem(value: 'Flat_Rate', child: Text('Flat Rate (Fixed per entry)')),
                    DropdownMenuItem(value: 'Hourly_Slab', child: Text('Hourly Slab (Billed per hour)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => model = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final fee = double.tryParse(feeController.text.trim()) ?? current.baseFee;
                final grace = int.tryParse(graceController.text.trim()) ?? current.gracePeriodMins;

                final updated = current.copyWith(
                  baseFee: fee,
                  gracePeriodMins: grace,
                  pricingModel: model,
                );
                await _ratesRepo.updateRates(updated);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadSettings();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lotNameController.dispose();
    _capacityController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking Rates & Lot Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lot Profile Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Parking Lot Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _lotNameController,
                            decoration: const InputDecoration(labelText: 'Parking Lot Name on Receipts'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _capacityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Total Parking Capacity (Spots)'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _ownerPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Owner WhatsApp Number for Handover Reports'),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _saveLotDetails,
                            child: const Text('Save Profile Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Rates Configurations
                  const Text('Vehicle Tariff Rates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._rates.map(
                    (rate) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEFF6FF),
                          foregroundColor: const Color(0xFF1E3A8A),
                          child: Icon(
                            rate.vehicleType == 'Bike'
                                ? Icons.two_wheeler_rounded
                                : rate.vehicleType == 'Car'
                                    ? Icons.directions_car_rounded
                                    : Icons.local_shipping_rounded,
                          ),
                        ),
                        title: Text(rate.vehicleType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          'Rs. ${rate.baseFee.toStringAsFixed(0)} (${rate.pricingModel.replaceAll('_', ' ')}) | ${rate.gracePeriodMins}m Grace',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editRate(rate),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
