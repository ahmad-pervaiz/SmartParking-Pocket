import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const String _keyLotName = 'parking_lot_name';
  static const String _keyLotCapacity = 'parking_lot_capacity';
  static const String _keyOwnerPhone = 'owner_whatsapp_phone';
  static const String _keyCurrentAttendant = 'current_attendant_name';

  static Future<String> getLotName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLotName) ?? 'CITY CENTRAL PARKING';
  }

  static Future<void> setLotName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLotName, name);
  }

  static Future<int> getLotCapacity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLotCapacity) ?? 150;
  }

  static Future<void> setLotCapacity(int capacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLotCapacity, capacity);
  }

  static Future<String> getOwnerPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOwnerPhone) ?? '+923001234567';
  }

  static Future<void> setOwnerPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOwnerPhone, phone);
  }

  static Future<String> getAttendantName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentAttendant) ?? 'Guard Ali';
  }

  static Future<void> setAttendantName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentAttendant, name);
  }
}
