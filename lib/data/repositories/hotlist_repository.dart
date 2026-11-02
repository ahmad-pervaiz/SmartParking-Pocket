import 'package:sqflite/sqflite.dart';
import '../datasources/local_db.dart';
import '../models/stolen_hotlist.dart';

class HotlistRepository {
  final LocalDatabase _dbProvider = LocalDatabase.instance;

  // Normalized plate text cleaner
  static String normalizePlate(String rawPlate) {
    return rawPlate.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  // Check if plate is on the active stolen hotlist
  Future<StolenHotlist?> checkPlate(String vehicleNumber) async {
    final db = await _dbProvider.database;
    final normalized = normalizePlate(vehicleNumber);

    if (normalized.isEmpty) return null;

    final results = await db.query(
      'Stolen_Hotlist',
      where: 'vehicle_number = ? AND is_active = 1',
      whereArgs: [normalized],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return StolenHotlist.fromMap(results.first);
    }
    return null;
  }

  // Get all stolen hotlist records
  Future<List<StolenHotlist>> getAllHotlist() async {
    final db = await _dbProvider.database;
    final results = await db.query(
      'Stolen_Hotlist',
      orderBy: 'date_added DESC',
    );
    return results.map((e) => StolenHotlist.fromMap(e)).toList();
  }

  // Add new vehicle to stolen hotlist
  Future<void> addStolenVehicle(StolenHotlist item) async {
    final db = await _dbProvider.database;
    final normalizedItem = item.copyWith(
      vehicleNumber: normalizePlate(item.vehicleNumber),
    );
    await db.insert(
      'Stolen_Hotlist',
      normalizedItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Remove vehicle from stolen hotlist
  Future<void> removeStolenVehicle(String stolenId) async {
    final db = await _dbProvider.database;
    await db.delete(
      'Stolen_Hotlist',
      where: 'stolen_id = ?',
      whereArgs: [stolenId],
    );
  }

  // Toggle active status
  Future<void> toggleStatus(String stolenId, bool isActive) async {
    final db = await _dbProvider.database;
    await db.update(
      'Stolen_Hotlist',
      {'is_active': isActive ? 1 : 0},
      where: 'stolen_id = ?',
      whereArgs: [stolenId],
    );
  }
}
