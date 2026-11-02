import 'package:flutter/foundation.dart';

@immutable
class ParkingHistory {
  final String historyId;
  final String sessionId;
  final String vehicleNumber;
  final String vehicleType; // 'Bike', 'Car', 'Other'
  final DateTime entryTimestamp;
  final DateTime exitTimestamp;
  final int durationMinutes;
  final double feeCharged;
  final String paymentMode; // 'Cash', 'Digital_QR'
  final String attendantIdExit;

  const ParkingHistory({
    required this.historyId,
    required this.sessionId,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.entryTimestamp,
    required this.exitTimestamp,
    required this.durationMinutes,
    required this.feeCharged,
    required this.paymentMode,
    required this.attendantIdExit,
  });

  Map<String, dynamic> toMap() {
    return {
      'history_id': historyId,
      'session_id': sessionId,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'entry_timestamp': entryTimestamp.toIso8601String(),
      'exit_timestamp': exitTimestamp.toIso8601String(),
      'duration_minutes': durationMinutes,
      'fee_charged': feeCharged,
      'payment_mode': paymentMode,
      'attendant_id_exit': attendantIdExit,
    };
  }

  factory ParkingHistory.fromMap(Map<String, dynamic> map) {
    return ParkingHistory(
      historyId: map['history_id'] as String,
      sessionId: map['session_id'] as String,
      vehicleNumber: map['vehicle_number'] as String,
      vehicleType: map['vehicle_type'] as String,
      entryTimestamp: DateTime.parse(map['entry_timestamp'] as String),
      exitTimestamp: DateTime.parse(map['exit_timestamp'] as String),
      durationMinutes: (map['duration_minutes'] as num).toInt(),
      feeCharged: (map['fee_charged'] as num).toDouble(),
      paymentMode: map['payment_mode'] as String,
      attendantIdExit: map['attendant_id_exit'] as String,
    );
  }
}
