import 'package:flutter/material.dart';
import 'package:food_buyer_app/pages/login_page.dart'; // [!] Import หน้า Login
import 'package:food_buyer_app/models/user_provider.dart';  // [!] Import
import 'package:food_buyer_app/services/cart_service.dart'; // [!] Import
import 'package:food_buyer_app/services/socket_service.dart';// [!] Import
import 'package:provider/provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:food_buyer_app/pages/main_nav_page.dart'; // [!] Import MainNavigationPage

void main() {
  runApp(
    // [!!] ใช้ MultiProvider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => CartService()),
        ChangeNotifierProvider(create: (context) => SocketService()),
      ],
      child: const BuyerApp(),
    ),
  );
}
class BuyerApp extends StatelessWidget {
  const BuyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
    child:  MaterialApp(
      title: 'Smart Food Advisor',
      theme: ThemeData(
        // [!] เราใช้สีหลักเป็นสีฟ้าสำหรับแอปผู้ซื้อ (แอปผู้ขายเป็นสีส้ม)
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
          secondary: Colors.blue.shade400,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        
        // [!] กำหนด Theme ปุ่ม (เหมือนแอปผู้ขาย)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),

        // [!] กำหนด Theme AppBar (เหมือนแอปผู้ขาย)
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87
          ),
        ),
      ),
      
      // [!] จุดเริ่มต้นของแอปคือหน้า Login
      home: AuthWrapper(), 
    )
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final apiService = ApiService();
    // ดึงข้อมูลที่เซฟไว้
    final userData = await apiService.getUserProfile();

    if (userData != null && mounted) {
      // [!] ถ้ามีข้อมูล -> ยัดใส่ Provider เพื่อให้แอปใช้งานต่อได้เลย
      Provider.of<UserProvider>(context, listen: false).setUser(userData);
      setState(() {
        _isLoggedIn = true;
      });
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. กำลังเช็ค... ให้หมุนติ้วๆ ไปก่อน
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. เช็คเสร็จแล้ว
    if (_isLoggedIn) {
      // [!!] ถ้าเป็น Seller App ให้ไป HomePage()
      // [!!] ถ้าเป็น Buyer App ให้ไป MainNavigationPage()
      // (เลือกบรรทัดที่ตรงกับแอปที่คุณกำลังแก้อยู่)
      return MainNavigationPage(); // สำหรับ Seller App
      // return const MainNavigationPage(); // สำหรับ Buyer App
    } else {
      // 3. ถ้ายังไม่ล็อคอิน ไปหน้า Login
      return const LoginPage();
    }
  }
}