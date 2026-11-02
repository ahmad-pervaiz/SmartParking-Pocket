import 'package:flutter/foundation.dart';

@immutable
class VehicleParked {
  final String sessionId;
  final String vehicleNumber;
  final String vehicleType; // 'Bike', 'Car', 'Other'
  final DateTime entryTimestamp;
  final String attendantIdEntry;
  final String status; // 'PARKED'

  const VehicleParked({
    required this.sessionId,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.entryTimestamp,
    required this.attendantIdEntry,
    this.status = 'PARKED',
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'entry_timestamp': entryTimestamp.toIso8601String(),
      'attendant_id_entry': attendantIdEntry,
      'status': status,
    };
  }

  factory VehicleParked.fromMap(Map<String, dynamic> map) {
    return VehicleParked(
      sessionId: map['session_id'] as String,
      vehicleNumber: map['vehicle_number'] as String,
      vehicleType: map['vehicle_type'] as String,
      entryTimestamp: DateTime.parse(map['entry_timestamp'] as String),
      attendantIdEntry: map['attendant_id_entry'] as String,
      status: map['status'] as String? ?? 'PARKED',
    );
  }

  VehicleParked copyWith({
    String? sessionId,
    String? vehicleNumber,
    String? vehicleType,
    DateTime? entryTimestamp,
    String? attendantIdEntry,
    String? status,
  }) {
    return VehicleParked(
      sessionId: sessionId ?? this.sessionId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      entryTimestamp: entryTimestamp ?? this.entryTimestamp,
      attendantIdEntry: attendantIdEntry ?? this.attendantIdEntry,
      status: status ?? this.status,
    );
  }
}
