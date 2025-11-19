import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:food_buyer_app/pages/login_page.dart';
import 'package:food_buyer_app/pages/menu_list_page.dart'; // [!] Import หน้าใหม่
import 'package:cached_network_image/cached_network_image.dart'; // [!] Import
import 'package:food_buyer_app/pages/cart_page.dart'; // [!] Import หน้าใหม่
import 'package:food_buyer_app/pages/order_history_page.dart'; // [!] Import หน้าใหม่
import 'package:provider/provider.dart';
import 'package:food_buyer_app/models/user_provider.dart';
import 'package:food_buyer_app/services/cart_service.dart';
import 'package:food_buyer_app/services/socket_service.dart';
import 'package:food_buyer_app/pages/menu_detail_page.dart';


class StoreListPage extends StatefulWidget {
  StoreListPage({super.key});

  @override
  State<StoreListPage> createState() => _StoreListPageState();
}

class _StoreListPageState extends State<StoreListPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _apiService.getStores(); // [!] โหลดร้านค้าตอนเปิด
    _connectToSocket();
  }
  void _connectToSocket() {
    final userId = Provider.of<UserProvider>(context, listen: false).user?.userId;
    if (userId != null) {
      Provider.of<SocketService>(context, listen: false).connect(userId);
    } else {
      print("Socket Error: Buyer UserID is null.");
    }
  }
  @override
  void dispose() {
    Provider.of<SocketService>(context, listen: false).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Stack(
        children: [ 
      FutureBuilder<List<dynamic>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('ไม่พบร้านค้าในระบบ'));
          }

          final stores = snapshot.data!;
          
          // [!] ใช้ ListView.builder แสดง Card
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              
              // [!] ใช้ Card (เหมือนแอปผู้ขาย) เพื่อความสวยงาม
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                clipBehavior: Clip.antiAlias,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => MenuListPage(
                                storeId: store['store_id'],
                                storeName: store['store_name'],
                              ),
                            ),
                          );
                        },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- รูปหน้าร้าน ---
                      if (store['store_image_url'] != null)
                        CachedNetworkImage(
                          imageUrl: store['store_image_url'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(height: 150, child: Center(child: CircularProgressIndicator())),
                          errorWidget: (context, url, error) => Container(height: 150, child: Center(child: Icon(Icons.store_mall_directory, color: Colors.grey))),
                        )
                      else
                        Container(height: 150, child: Center(child: Icon(Icons.store_mall_directory, color: Colors.grey, size: 60))),
                      
                      // --- ชื่อร้าน ---
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          store['store_name'],
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      Consumer<SocketService>(
          builder: (context, socket, child) {
            // [!] ถ้าไม่มีสถานะล่าสุด หรือสถานะไม่ใช่ 'ready_for_pickup'
            if (socket.lastOrderUpdate == null || socket.lastOrderUpdate!['status'] != 'ready_for_pickup') {
              return SizedBox.shrink(); // [!] ไม่ต้องแสดงอะไร
            }

            // [!] ถ้าสถานะคือ "พร้อมรับ" ให้แสดง Banner นี้!
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildReadyToPickupBanner(context, socket.lastOrderUpdate!),
            );
          },
        ),
      ],
    ),
  );
}
  }
// 1. Widget สำหรับ Banner แจ้งเตือน
Widget _buildReadyToPickupBanner(BuildContext context, Map<String, dynamic> orderData) {
  return Card(
    margin: EdgeInsets.all(12),
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    color: Colors.purple.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.shopping_bag, color: Colors.purple, size: 40),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'อาหารพร้อมรับแล้ว!', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)
                ),
                Text('Order ID: #${orderData['orderId']} พร้อมให้คุณไปรับแล้ว'),
              ],
            ),
          ),
          // [!] ปุ่มกด "รับทราบ" (เพื่อซ่อน Banner นี้)
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              Provider.of<SocketService>(context, listen: false).clearLastOrderUpdate();
            },
          )
        ],
      ),
    ),
  );
}

// 2. Widget ไอคอนตะกร้า (อันนี้คุณมีอยู่แล้ว แค่ย้ายมาไว้ที่นี่)
Widget _buildCartIcon() {
  return Consumer<CartService>(
    builder: (context, cart, child) {
      if (cart.totalItems == 0) {
        return Icon(Icons.shopping_cart_outlined);
      }
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shopping_cart),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                cart.totalItems.toString(),
                style: TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    },
  );
}
