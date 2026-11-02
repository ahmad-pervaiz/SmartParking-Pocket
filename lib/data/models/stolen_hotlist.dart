import 'package:flutter/foundation.dart';

@immutable
class StolenHotlist {
  final String stolenId;
  final String vehicleNumber; // Normalized: uppercase, without spaces or hyphens
  final String firNumber;
  final String ownerContact;
  final DateTime dateAdded;
  final bool isActive;

  const StolenHotlist({
    required this.stolenId,
    required this.vehicleNumber,
    required this.firNumber,
    required this.ownerContact,
    required this.dateAdded,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'stolen_id': stolenId,
      'vehicle_number': vehicleNumber,
      'fir_number': firNumber,
      'owner_contact': ownerContact,
      'date_added': dateAdded.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory StolenHotlist.fromMap(Map<String, dynamic> map) {
    return StolenHotlist(
      stolenId: map['stolen_id'] as String,
      vehicleNumber: map['vehicle_number'] as String,
      firNumber: map['fir_number'] as String? ?? 'N/A',
      ownerContact: map['owner_contact'] as String? ?? '',
      dateAdded: DateTime.parse(map['date_added'] as String),
      isActive: (map['is_active'] as int) == 1,
    );
  }

  StolenHotlist copyWith({
    String? stolenId,
    String? vehicleNumber,
    String? firNumber,
    String? ownerContact,
    DateTime? dateAdded,
    bool? isActive,
  }) {
    return StolenHotlist(
      stolenId: stolenId ?? this.stolenId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      firNumber: firNumber ?? this.firNumber,
      ownerContact: ownerContact ?? this.ownerContact,
      dateAdded: dateAdded ?? this.dateAdded,
      isActive: isActive ?? this.isActive,
    );
  }
}
