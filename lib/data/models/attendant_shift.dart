import 'package:flutter/foundation.dart';

@immutable
class AttendantShift {
  final String shiftId;
  final String attendantName;
  final DateTime startTime;
  final DateTime? endTime;
  final double cashCollected;
  final double digitalCollected;
  final String status; // 'ACTIVE', 'CLOSED'

  const AttendantShift({
    required this.shiftId,
    required this.attendantName,
    required this.startTime,
    this.endTime,
    this.cashCollected = 0.0,
    this.digitalCollected = 0.0,
    this.status = 'ACTIVE',
  });

  double get totalRevenue => cashCollected + digitalCollected;

  Map<String, dynamic> toMap() {
    return {
      'shift_id': shiftId,
      'attendant_name': attendantName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'cash_collected': cashCollected,
      'digital_collected': digitalCollected,
      'status': status,
    };
  }

  factory AttendantShift.fromMap(Map<String, dynamic> map) {
    return AttendantShift(
      shiftId: map['shift_id'] as String,
      attendantName: map['attendant_name'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      cashCollected: (map['cash_collected'] as num?)?.toDouble() ?? 0.0,
      digitalCollected: (map['digital_collected'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'ACTIVE',
    );
  }

  AttendantShift copyWith({
    String? shiftId,
    String? attendantName,
    DateTime? startTime,
    DateTime? endTime,
    double? cashCollected,
    double? digitalCollected,
    String? status,
  }) {
    return AttendantShift(
      shiftId: shiftId ?? this.shiftId,
      attendantName: attendantName ?? this.attendantName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      cashCollected: cashCollected ?? this.cashCollected,
      digitalCollected: digitalCollected ?? this.digitalCollected,
      status: status ?? this.status,
    );
  }
}
