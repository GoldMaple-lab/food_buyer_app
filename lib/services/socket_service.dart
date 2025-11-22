import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:food_buyer_app/widgets/notification_banner.dart';
import 'package:food_buyer_app/services/audio_service.dart';

class SocketService extends ChangeNotifier {
  static const String _serverUrl = 'http://192.168.1.100:3000'; // [!] แก้ IP
  IO.Socket? _socket;

  // Stream สำหรับการอัปเดตสถานะออเดอร์
  final _orderUpdateController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get orderUpdateEvents => _orderUpdateController.stream;

  Map<String, dynamic>? _lastOrderUpdate;
  Map<String, dynamic>? get lastOrderUpdate => _lastOrderUpdate;

  void connect(int userId) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'], 'autoConnect': true,
    });
    _socket!.connect();
    
    _socket!.onConnect((_) {
      print('Socket Connected (Buyer)');
      // [!] เข้าร่วมห้องส่วนตัว (ID ของผู้ซื้อ)
      _socket!.emit('join_room', userId.toString()); 
    });
    
    // [!!!!] นี่คือจุดที่ต่าง!!!!
    // [!] ฟัง Event 'order_update' ที่ Server ยิงมา
    _socket!.on('order_update', (data) {
      print('ORDER UPDATE RECEIVED: $data');
      
      _lastOrderUpdate = data; 
        _orderUpdateController.add(data);
        notifyListeners();
        // [!!] จัดการข้อความตามสถานะ
      String title = 'อัปเดตสถานะคำสั่งซื้อ';
      String message = 'สถานะออเดอร์ #${data['orderId']} เปลี่ยนแปลง';
      IconData icon = Icons.notifications;
      Color color = Colors.blue;
      String? soundFile;

      if (data['status'] == 'accepted') {
        title = 'ร้านรับออเดอร์แล้ว! 👨‍🍳';
        message = 'กำลังเริ่มปรุงอาหารให้อร่อยสุดฝีมือ';
        icon = Icons.soup_kitchen;
        color: Colors.blue;
        soundFile = 'audio/order_ready_alert.mp3'; // (ใช้เสียงเดียวไปก่อน หรือหาเพิ่ม)
      } 
      else if (data['status'] == 'ready_for_pickup') {
        title = 'อาหารพร้อมแล้ว! 🛵';
        message = 'ไปรับที่ร้านได้เลย หรือรอพี่ไรเดอร์สักครู่';
        icon = Icons.delivery_dining;
        color: Colors.purple;
        soundFile = 'audio/order_ready_alert.mp3';
      }
      else if (data['status'] == 'completed') {
        title = 'ขอบคุณที่ใช้บริการ 🙏';
        message = 'ออเดอร์เสร็จสิ้น ทานให้อร่อยนะครับ';
        icon = Icons.check_circle;
        color: Colors.green;
      }
      else if (data['status'] == 'cancelled') {
        title = 'ออเดอร์ถูกยกเลิก ❌';
        message = 'เสียใจด้วย ออเดอร์นี้ถูกยกเลิก';
        icon = Icons.cancel;
        color: Colors.red;
      }

      // 1. แสดง Banner (ทุกกรณี)
      showFacebookStyleNotification(
        title: title,
        message: message,
        icon: icon,
        color: color,
      );
        // 2. เล่นเสียง (ถ้ามี)
      if (soundFile != null) {
        AudioService.playNotificationSound(soundFile);
      }
    });
    
    _socket!.onDisconnect((_) => print('Socket Disconnected (Buyer)'));
  }

  void clearLastOrderUpdate() {
    _lastOrderUpdate = null;
    notifyListeners();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
  
  @override
  void dispose() {
    _orderUpdateController.close();
    disconnect();
    super.dispose();
  }
}