import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../datasources/local_db.dart';
import '../models/attendant_shift.dart';

class ShiftRepository {
  final LocalDatabase _dbProvider = LocalDatabase.instance;
  final Uuid _uuid = const Uuid();

  // Get current active shift if exists
  Future<AttendantShift?> getActiveShift() async {
    final db = await _dbProvider.database;
    final results = await db.query(
      'Attendant_Shifts',
      where: "status = 'ACTIVE'",
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      return AttendantShift.fromMap(results.first);
    }
    return null;
  }

  // Start new attendant shift
  Future<AttendantShift> startShift(String attendantName) async {
    final db = await _dbProvider.database;
    // Auto-close any prior active shift
    await db.update(
      'Attendant_Shifts',
      {
        'status': 'CLOSED',
        'end_time': DateTime.now().toIso8601String(),
      },
      where: "status = 'ACTIVE'",
    );

    final newShift = AttendantShift(
      shiftId: _uuid.v4(),
      attendantName: attendantName.trim().isEmpty ? 'Attendant 1' : attendantName.trim(),
      startTime: DateTime.now(),
      status: 'ACTIVE',
    );

    await db.insert('Attendant_Shifts', newShift.toMap());
    return newShift;
  }

  // Increment collected amount for current active shift
  Future<void> recordPayment({required double amount, required bool isCash}) async {
    final db = await _dbProvider.database;
    final activeShift = await getActiveShift();
    if (activeShift == null) return;

    if (isCash) {
      await db.rawUpdate('''
        UPDATE Attendant_Shifts 
        SET cash_collected = cash_collected + ? 
        WHERE shift_id = ?
      ''', [amount, activeShift.shiftId]);
    } else {
      await db.rawUpdate('''
        UPDATE Attendant_Shifts 
        SET digital_collected = digital_collected + ? 
        WHERE shift_id = ?
      ''', [amount, activeShift.shiftId]);
    }
  }

  // Close active shift
  Future<AttendantShift?> closeShift(String shiftId) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();

    await db.update(
      'Attendant_Shifts',
      {
        'status': 'CLOSED',
        'end_time': now.toIso8601String(),
      },
      where: 'shift_id = ?',
      whereArgs: [shiftId],
    );

    final results = await db.query(
      'Attendant_Shifts',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return AttendantShift.fromMap(results.first);
    }
    return null;
  }

  // Get all shifts (history)
  Future<List<AttendantShift>> getAllShifts() async {
    final db = await _dbProvider.database;
    final results = await db.query(
      'Attendant_Shifts',
      orderBy: 'start_time DESC',
    );
    return results.map((e) => AttendantShift.fromMap(e)).toList();
  }
}
