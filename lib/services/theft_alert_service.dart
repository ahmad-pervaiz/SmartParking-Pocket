import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stolen_hotlist.dart';
import '../data/repositories/hotlist_repository.dart';

class TheftAlertService {
  final HotlistRepository _hotlistRepository = HotlistRepository();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;

  bool get isAlarmPlaying => _isAlarmPlaying;

  /// Check whether vehicle is present on the stolen hotlist
  Future<StolenHotlist?> verifyVehicle(String vehicleNumber) async {
    return await _hotlistRepository.checkPlate(vehicleNumber);
  }

  /// Trigger emergency alert: Vibration + Sound Alarm
  Future<void> triggerTheftAlert(StolenHotlist stolenInfo) async {
    _isAlarmPlaying = true;

    // 1. Phone Vibration (Emergency pattern: 500ms vibrate, 200ms pause, repeated)
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [500, 200, 500, 200, 500, 200, 1000],
          intensities: [255, 0, 255, 0, 255, 0, 255],
          repeat: 0, // loop until stopped
        );
      }
    } catch (_) {}

    // 2. Play Alarm Sound
    try {
      // Set to high volume and loop siren
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/theft_alarm.mp3'));
    } catch (_) {
      // Audio fallback handled gracefully if asset not yet bundled
    }
  }

  /// Stop emergency alarm and vibration
  Future<void> stopAlert() async {
    _isAlarmPlaying = false;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Send immediate SMS notification to vehicle owner or police/supervisor
  Future<bool> sendOwnerEmergencySms({
    required StolenHotlist stolenInfo,
    required String attendantName,
    String? lotLocation,
  }) async {
    final contact = stolenInfo.ownerContact.trim();
    if (contact.isEmpty) return false;

    final locationText = lotLocation ?? 'Local Parking Lot Station';
    final message = Uri.encodeComponent(
      '🚨 THEFT ALERT: Stolen vehicle ${stolenInfo.vehicleNumber} (FIR: ${stolenInfo.firNumber}) '
      'was just detected attempting parking at $locationText by Attendant $attendantName on ${DateTime.now().toString().substring(0, 16)}. Immediate action advised.',
    );

    final smsUri = Uri.parse('sms:$contact?body=$message');
    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      }
    } catch (_) {}
    return false;
  }

  void dispose() {
    stopAlert();
    _audioPlayer.dispose();
  }
}
