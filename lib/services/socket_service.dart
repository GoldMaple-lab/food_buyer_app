import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
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
        // เล่นเสียงแจ้งเตือน
        if (data != null && data['status'] == 'ready_for_pickup') {
            AudioService.playNotificationSound('new_order_alert.mp3');
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