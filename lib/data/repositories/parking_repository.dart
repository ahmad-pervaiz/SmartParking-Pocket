import 'package:sqflite/sqflite.dart';
import '../datasources/local_db.dart';
import '../models/vehicle_parked.dart';
import '../models/parking_history.dart';

class ParkingRepository {
  final LocalDatabase _dbProvider = LocalDatabase.instance;

  // Active parking session entry
  Future<void> parkVehicle(VehicleParked vehicle) async {
    final db = await _dbProvider.database;
    await db.insert(
      'Vehicles_Parked',
      vehicle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Find active vehicle by exact or normalized plate
  Future<VehicleParked?> getParkedVehicleByPlate(String vehicleNumber) async {
    final db = await _dbProvider.database;
    final normalized = vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final results = await db.query(
      'Vehicles_Parked',
      where: 'vehicle_number = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return VehicleParked.fromMap(results.first);
    }
    return null;
  }

  // Search active parking sessions (e.g. for lost ticket search)
  Future<List<VehicleParked>> searchParkedVehicles(String query) async {
    final db = await _dbProvider.database;
    final normalized = query.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final results = await db.query(
      'Vehicles_Parked',
      where: 'vehicle_number LIKE ?',
      whereArgs: ['%$normalized%'],
      orderBy: 'entry_timestamp DESC',
    );
    return results.map((e) => VehicleParked.fromMap(e)).toList();
  }

  // Get all currently parked vehicles
  Future<List<VehicleParked>> getAllParkedVehicles() async {
    final db = await _dbProvider.database;
    final results = await db.query(
      'Vehicles_Parked',
      orderBy: 'entry_timestamp DESC',
    );
    return results.map((e) => VehicleParked.fromMap(e)).toList();
  }

  // Live Occupancy Counters
  Future<int> getOccupancyCount(String vehicleType) async {
    final db = await _dbProvider.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM Vehicles_Parked WHERE vehicle_type = ?',
        [vehicleType],
      ),
    );
    return count ?? 0;
  }

  Future<int> getTotalOccupancyCount() async {
    final db = await _dbProvider.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Vehicles_Parked'),
    );
    return count ?? 0;
  }

  // Checkout vehicle: Transaction to write history and purge from active parked
  Future<void> checkoutVehicle(ParkingHistory history) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      // 1. Insert into Parking_History permanent ledger
      await txn.insert(
        'Parking_History',
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Purge from Vehicles_Parked
      await txn.delete(
        'Vehicles_Parked',
        where: 'session_id = ?',
        whereArgs: [history.sessionId],
      );
    });
  }

  // Get Parking History
  Future<List<ParkingHistory>> getHistory({DateTime? from, DateTime? to}) async {
    final db = await _dbProvider.database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (from != null && to != null) {
      whereClause = 'exit_timestamp BETWEEN ? AND ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    } else if (from != null) {
      whereClause = 'exit_timestamp >= ?';
      whereArgs = [from.toIso8601String()];
    }

    final results = await db.query(
      'Parking_History',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'exit_timestamp DESC',
    );
    return results.map((e) => ParkingHistory.fromMap(e)).toList();
  }

  // Financial Analytics & Metrics
  Future<Map<String, dynamic>> getAnalyticsMetrics({String period = 'daily'}) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();
    DateTime filterStart;

    if (period == 'weekly') {
      filterStart = now.subtract(const Duration(days: 7));
    } else if (period == 'monthly') {
      filterStart = now.subtract(const Duration(days: 30));
    } else {
      // daily (today starting 00:00:00)
      filterStart = DateTime(now.year, now.month, now.day);
    }

    final isoFilter = filterStart.toIso8601String();

    // Cash earnings
    final cashResult = await db.rawQuery('''
      SELECT SUM(fee_charged) as total, COUNT(*) as count 
      FROM Parking_History 
      WHERE payment_mode = 'Cash' AND exit_timestamp >= ?
    ''', [isoFilter]);

    // Digital earnings
    final digitalResult = await db.rawQuery('''
      SELECT SUM(fee_charged) as total, COUNT(*) as count 
      FROM Parking_History 
      WHERE payment_mode = 'Digital_QR' AND exit_timestamp >= ?
    ''', [isoFilter]);

    // Breakdown by vehicle type
    final typeResult = await db.rawQuery('''
      SELECT vehicle_type, COUNT(*) as count, SUM(fee_charged) as total
      FROM Parking_History 
      WHERE exit_timestamp >= ?
      GROUP BY vehicle_type
    ''', [isoFilter]);

    // Hourly distribution for peak traffic visualization (0-23 hours)
    final hourlyResult = await db.rawQuery('''
      SELECT strftime('%H', exit_timestamp) as hour, COUNT(*) as count
      FROM Parking_History
      WHERE exit_timestamp >= ?
      GROUP BY hour
      ORDER BY hour ASC
    ''', [isoFilter]);

    double cashTotal = (cashResult.first['total'] as num?)?.toDouble() ?? 0.0;
    int cashCount = (cashResult.first['count'] as num?)?.toInt() ?? 0;

    double digitalTotal = (digitalResult.first['total'] as num?)?.toDouble() ?? 0.0;
    int digitalCount = (digitalResult.first['count'] as num?)?.toInt() ?? 0;

    return {
      'period': period,
      'cashTotal': cashTotal,
      'cashCount': cashCount,
      'digitalTotal': digitalTotal,
      'digitalCount': digitalCount,
      'grandTotal': cashTotal + digitalTotal,
      'totalVehiclesProcessed': cashCount + digitalCount,
      'typeBreakdown': typeResult,
      'hourlyDistribution': hourlyResult,
    };
  }
}
