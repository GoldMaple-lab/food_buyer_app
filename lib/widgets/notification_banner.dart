import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const NotificationBanner({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 50, left: 10, right: 10, bottom: 10),
      color: Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(message),
        trailing: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            OverlaySupportEntry.of(context)?.dismiss(); // ปิดแจ้งเตือน
          },
        ),
      ),
    );
  }
}

// ฟังก์ชันเรียกใช้แบบง่ายๆ
void showFacebookStyleNotification({
  required String title,
  required String message,
  IconData icon = Icons.notifications,
  Color color = Colors.blue,
}) {
  showOverlayNotification((context) {
    return NotificationBanner(
      title: title,
      message: message,
      icon: icon,
      color: color,
    );
  }, duration: Duration(seconds: 4)); // แสดง 4 วินาทีแล้วหายไป
}