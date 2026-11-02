import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartparking_pocket.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Vehicles_Parked (Active Parking Sessions - Live Only)
    await db.execute('''
      CREATE TABLE Vehicles_Parked (
        session_id TEXT PRIMARY KEY,
        vehicle_number TEXT NOT NULL,
        vehicle_type TEXT NOT NULL,
        entry_timestamp TEXT NOT NULL,
        attendant_id_entry TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PARKED'
      )
    ''');
    await db.execute('CREATE INDEX idx_parked_vehicle ON Vehicles_Parked(vehicle_number)');

    // 2. Parking_History (Permanent Ledger for Analytics)
    await db.execute('''
      CREATE TABLE Parking_History (
        history_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        vehicle_number TEXT NOT NULL,
        vehicle_type TEXT NOT NULL,
        entry_timestamp TEXT NOT NULL,
        exit_timestamp TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        fee_charged REAL NOT NULL,
        payment_mode TEXT NOT NULL,
        attendant_id_exit TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_history_vehicle ON Parking_History(vehicle_number)');
    await db.execute('CREATE INDEX idx_history_exit ON Parking_History(exit_timestamp)');

    // 3. Stolen_Hotlist (Theft Detection List)
    await db.execute('''
      CREATE TABLE Stolen_Hotlist (
        stolen_id TEXT PRIMARY KEY,
        vehicle_number TEXT NOT NULL UNIQUE,
        fir_number TEXT,
        owner_contact TEXT,
        date_added TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_hotlist_vehicle ON Stolen_Hotlist(vehicle_number)');

    // 4. Attendant_Shifts (Reconciliation)
    await db.execute('''
      CREATE TABLE Attendant_Shifts (
        shift_id TEXT PRIMARY KEY,
        attendant_name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        cash_collected REAL NOT NULL DEFAULT 0.0,
        digital_collected REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'ACTIVE'
      )
    ''');

    // 5. Rates_Config (App Settings)
    await db.execute('''
      CREATE TABLE Rates_Config (
        vehicle_type TEXT PRIMARY KEY,
        base_fee REAL NOT NULL,
        pricing_model TEXT NOT NULL,
        grace_period_mins INTEGER NOT NULL DEFAULT 10
      )
    ''');

    // Seed default rates
    await db.insert('Rates_Config', {
      'vehicle_type': 'Bike',
      'base_fee': 20.0,
      'pricing_model': 'Flat_Rate',
      'grace_period_mins': 10,
    });
    await db.insert('Rates_Config', {
      'vehicle_type': 'Car',
      'base_fee': 50.0,
      'pricing_model': 'Hourly_Slab',
      'grace_period_mins': 10,
    });
    await db.insert('Rates_Config', {
      'vehicle_type': 'Other',
      'base_fee': 70.0,
      'pricing_model': 'Hourly_Slab',
      'grace_period_mins': 10,
    });

    // Seed a couple of sample stolen vehicles for immediate testing
    await db.insert('Stolen_Hotlist', {
      'stolen_id': 'stolen_sample_1',
      'vehicle_number': 'ABC1234',
      'fir_number': 'FIR-2026/9021',
      'owner_contact': '+1234567890',
      'date_added': DateTime.now().toIso8601String(),
      'is_active': 1,
    });
    await db.insert('Stolen_Hotlist', {
      'stolen_id': 'stolen_sample_2',
      'vehicle_number': 'LEA5544',
      'fir_number': 'FIR-2026/8112',
      'owner_contact': '+923001234567',
      'date_added': DateTime.now().toIso8601String(),
      'is_active': 1,
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
