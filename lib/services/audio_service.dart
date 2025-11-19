import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // [!] เราใช้ AudioCache เพราะมันถูกออกแบบมาสำหรับเล่นเสียงสั้นๆ
  // [!] และมันจะโหลดไฟล์เก็บไว้ใน Cache ทำให้เล่นครั้งต่อไปได้ทันที
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound(String assetPath) async {
    try {
      // AudioCache ถูกรวมเข้ากับ AudioPlayer แล้ว
      // เราใช้ Source.asset
      await _player.play(AssetSource(assetPath));
      print("Played sound: $assetPath");
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  // (Optional) เผื่อต้องหยุดเสียง
  static void stop() {
    _player.stop();
  }
}