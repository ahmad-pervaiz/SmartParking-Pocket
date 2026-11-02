import 'package:flutter/foundation.dart';

@immutable
class RatesConfig {
  final String vehicleType; // 'Bike', 'Car', 'Other'
  final double baseFee;
  final String pricingModel; // 'Flat_Rate', 'Hourly_Slab'
  final int gracePeriodMins;

  const RatesConfig({
    required this.vehicleType,
    required this.baseFee,
    required this.pricingModel,
    this.gracePeriodMins = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'vehicle_type': vehicleType,
      'base_fee': baseFee,
      'pricing_model': pricingModel,
      'grace_period_mins': gracePeriodMins,
    };
  }

  factory RatesConfig.fromMap(Map<String, dynamic> map) {
    return RatesConfig(
      vehicleType: map['vehicle_type'] as String,
      baseFee: (map['base_fee'] as num).toDouble(),
      pricingModel: map['pricing_model'] as String,
      gracePeriodMins: (map['grace_period_mins'] as num?)?.toInt() ?? 10,
    );
  }

  RatesConfig copyWith({
    String? vehicleType,
    double? baseFee,
    String? pricingModel,
    int? gracePeriodMins,
  }) {
    return RatesConfig(
      vehicleType: vehicleType ?? this.vehicleType,
      baseFee: baseFee ?? this.baseFee,
      pricingModel: pricingModel ?? this.pricingModel,
      gracePeriodMins: gracePeriodMins ?? this.gracePeriodMins,
    );
  }
}
