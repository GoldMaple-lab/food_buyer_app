import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:food_buyer_app/services/socket_service.dart';
import 'package:provider/provider.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});
  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _ordersFuture;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _listenToSocket();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _apiService.getMyOrders(); // [!] เรียก API ของผู้ซื้อ
    });
  }

  void _listenToSocket() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    // [!] ฟัง Event 'order_update'
    _orderSubscription = socketService.orderUpdateEvents.listen((data) {
      print("History Page refreshing due to socket event!");
      _loadOrders(); // [!] โหลดใหม่เมื่อสถานะเปลี่ยน
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ประวัติการสั่งซื้อ'),
        actions: [IconButton(onPressed: _loadOrders, icon: Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('ยังไม่มีประวัติการสั่งซื้อ'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order); // [!] ใช้ Card
            },
          );
        },
      ),
    );
  }
  
  // [!] Widget สำหรับแสดง Card (เหมือนแอปผู้ขาย)
  // (ใน lib/pages/order_history_page.dart)

Widget _buildOrderCard(Map<String, dynamic> order) {
  final status = order['status'];
  Color statusColor = Colors.grey;
  String statusText = status.toString().toUpperCase();

  // [!!] ---- จุดแก้ไข: เพิ่มสถานะใหม่ ----
  if (status == 'pending') {
    statusColor = Colors.orange;
    statusText = 'รอการยืนยัน';
  } else if (status == 'accepted') {
    statusColor = Colors.blue;
    statusText = 'กำลังเตรียมอาหาร';
  } else if (status == 'ready_for_pickup') { // [!] เพิ่มสถานะนี้
    statusColor = Colors.purple;
    statusText = 'อาหารพร้อมรับ';
  } else if (status == 'completed') {
    statusColor = Colors.green;
    statusText = 'สำเร็จแล้ว';
  } else if (status == 'cancelled') {
    statusColor = Colors.red;
    statusText = 'ยกเลิกแล้ว';
  }

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... (แถวบน: ID และ สถานะ - เหมือนเดิม) ...
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ID: #${order['order_id']}', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText, 
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          Divider(height: 20),
          Text('ราคารวม: ${order['total_price']} บาท'),
          Text('สั่งเมื่อ: ${order['created_at']}'),
          
          // [!!] ---- จุดแก้ไข: เพิ่มข้อความแจ้งเตือน ----
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('กำลังรอร้านค้าตอบรับ...', style: TextStyle(color: Colors.orange)),
            ),

          if (status == 'ready_for_pickup')
            Container( // [!] เพิ่มกรอบให้เด่น
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple)
              ),
              child: Text(
                '🔔 อาหารพร้อมแล้ว! ไปรับได้เลย', 
                style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
        ],
      ),
    ),
  );
}
}