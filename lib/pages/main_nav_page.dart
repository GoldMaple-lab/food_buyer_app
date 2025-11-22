import 'package:flutter/material.dart';
import 'package:food_buyer_app/pages/recommendation_page.dart'; 
import 'package:food_buyer_app/pages/food_log_calendar_page.dart';
import 'package:food_buyer_app/pages/order_history_page.dart';
import 'package:food_buyer_app/pages/store_list_page.dart';
import 'package:food_buyer_app/pages/login_page.dart';
import 'package:provider/provider.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:food_buyer_app/services/cart_service.dart';
import 'package:food_buyer_app/services/socket_service.dart';
import 'package:food_buyer_app/models/user_provider.dart';
import 'package:food_buyer_app/pages/cart_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0; // [!] หน้าเริ่มต้นคือ แนะนำ (index 0)

  // [!] รายการหน้าทั้งหมดของเรา
  static final List<Widget> _pages = <Widget>[
  // [!] หน้า "แนะนำ" (ของจริง)
  RecommendationPage(), 

  // [!] หน้า "ร้านค้า"
  StoreListPage(), 

  // [!] หน้า "ปฏิทิน" (ของจริง)
  FoodLogCalendarPage(), 

  // [!] หน้า "ประวัติ/โปรไฟล์"
  OrderHistoryPage(),
];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [!] เราจะใช้ AppBar กลาง (ยกเว้นหน้า Profile)
      appBar: _selectedIndex == 3 // ถ้าเป็นหน้า Profile
    ? null // (เพราะ OrderHistoryPage มี AppBar ของตัวเอง)
    : AppBar(
        title: Text(['Smart Advisor', 'ร้านค้า', 'บันทึกการกิน'][_selectedIndex]),
        // [!!] ---- ย้ายปุ่มมาไว้ที่นี่ ----
        actions: [
          IconButton(
            icon: _buildCartIcon(), // [!] ใช้ Widget (เราจะก๊อปมา)
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => CartPage()));
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              // [!] โค้ด Logout
              final apiService = ApiService();
              await apiService.logout();
              Provider.of<SocketService>(context, listen: false).disconnect();
              Provider.of<UserProvider>(context, listen: false).clearUser();
              Provider.of<CartService>(context, listen: false).clearCart();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (ctx) => LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      
      // [!] แสดงหน้าที่เลือก
      body: _pages.elementAt(_selectedIndex), 
      
      // [!] แถบเมนูด้านล่าง
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.recommend),
            label: 'แนะนำ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'ร้านค้า',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'บันทึก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        
        // [!] ทำให้แถบเมนูสวยงาม
        type: BottomNavigationBarType.fixed, // [!] สำคัญมาก
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
// [!] สร้าง Widget สำหรับไอคอนตะกร้าสินค้า
Widget _buildCartIcon() {
  return Consumer<CartService>( // "ฟัง" CartService
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