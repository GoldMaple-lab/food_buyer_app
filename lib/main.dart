import 'package:flutter/material.dart';
import 'package:food_buyer_app/pages/login_page.dart'; // [!] Import หน้า Login
import 'package:food_buyer_app/models/user_provider.dart';  // [!] Import
import 'package:food_buyer_app/services/cart_service.dart'; // [!] Import
import 'package:food_buyer_app/services/socket_service.dart';// [!] Import
import 'package:provider/provider.dart';

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
    return MaterialApp(
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
      home: LoginPage(), 
    );
  }
}