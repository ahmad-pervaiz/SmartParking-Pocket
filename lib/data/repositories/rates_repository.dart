import 'package:sqflite/sqflite.dart';
import '../datasources/local_db.dart';
import '../models/rates_config.dart';

class RatesRepository {
  final LocalDatabase _dbProvider = LocalDatabase.instance;

  // Default rates fallback
  static const Map<String, RatesConfig> defaultRates = {
    'Bike': RatesConfig(
      vehicleType: 'Bike',
      baseFee: 20.0,
      pricingModel: 'Flat_Rate',
      gracePeriodMins: 10,
    ),
    'Car': RatesConfig(
      vehicleType: 'Car',
      baseFee: 50.0,
      pricingModel: 'Hourly_Slab',
      gracePeriodMins: 10,
    ),
    'Other': RatesConfig(
      vehicleType: 'Other',
      baseFee: 70.0,
      pricingModel: 'Hourly_Slab',
      gracePeriodMins: 10,
    ),
  };

  // Get rates configuration for vehicle type
  Future<RatesConfig> getRatesFor(String vehicleType) async {
    final db = await _dbProvider.database;
    final results = await db.query(
      'Rates_Config',
      where: 'vehicle_type = ?',
      whereArgs: [vehicleType],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return RatesConfig.fromMap(results.first);
    }
    return defaultRates[vehicleType] ??
        const RatesConfig(
          vehicleType: 'Car',
          baseFee: 50.0,
          pricingModel: 'Hourly_Slab',
          gracePeriodMins: 10,
        );
  }

  // Get all rates
  Future<List<RatesConfig>> getAllRates() async {
    final db = await _dbProvider.database;
    final results = await db.query('Rates_Config');
    if (results.isEmpty) {
      return defaultRates.values.toList();
    }
    return results.map((e) => RatesConfig.fromMap(e)).toList();
  }

  // Update rates
  Future<void> updateRates(RatesConfig config) async {
    final db = await _dbProvider.database;
    await db.insert(
      'Rates_Config',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
