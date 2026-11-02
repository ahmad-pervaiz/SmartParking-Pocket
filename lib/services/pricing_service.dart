import '../models/rates_config.dart';

class PricingCalculationResult {
  final int durationMinutes;
  final double feeCharged;
  final bool isGracePeriodApplied;
  final String durationDescription;

  const PricingCalculationResult({
    required this.durationMinutes,
    required this.feeCharged,
    required this.isGracePeriodApplied,
    required this.durationDescription,
  });
}

class PricingService {
  /// Calculate fee based on entry and exit time, adhering to RatesConfig
  static PricingCalculationResult calculateFee({
    required DateTime entryTime,
    required DateTime exitTime,
    required RatesConfig rateConfig,
  }) {
    final diff = exitTime.difference(entryTime);
    final totalMinutes = diff.inMinutes < 0 ? 0 : diff.inMinutes;

    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final durationDesc = hours > 0 ? '$hours hr $mins min' : '$mins min';

    // 1. Check Grace Period
    if (totalMinutes <= rateConfig.gracePeriodMins) {
      return PricingCalculationResult(
        durationMinutes: totalMinutes,
        feeCharged: 0.0,
        isGracePeriodApplied: true,
        durationDescription: durationDesc,
      );
    }

    // 2. Pricing Models
    double calculatedFee;
    if (rateConfig.pricingModel == 'Flat_Rate') {
      calculatedFee = rateConfig.baseFee;
    } else {
      // 'Hourly_Slab'
      // Minimum 1 hour billed if beyond grace period, ceiling to next full hour
      int billedHours = (totalMinutes / 60.0).ceil();
      if (billedHours < 1) billedHours = 1;
      calculatedFee = billedHours * rateConfig.baseFee;
    }

    return PricingCalculationResult(
      durationMinutes: totalMinutes,
      feeCharged: calculatedFee,
      isGracePeriodApplied: false,
      durationDescription: durationDesc,
    );
  }
}
