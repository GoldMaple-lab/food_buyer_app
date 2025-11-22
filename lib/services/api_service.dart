import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:food_buyer_app/services/cart_service.dart';

class ApiService {
  // [!!!!] แก้ IP นี้ให้ตรงกับ .env 
  static const String _baseUrl = 'http://192.168.1.5:3000/api';
  
  // --- Token Management (เหมือนเดิม) ---
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  // [!!] 1. ฟังก์ชันเก็บข้อมูล User ลงเครื่อง (Private)
  Future<void> _saveUserProfile(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_userId', user['userId']);
    await prefs.setString('saved_name', user['name'] ?? '');
    await prefs.setString('saved_role', user['role']);
  }

  // [!!] 2. ฟังก์ชันดึงข้อมูล User จากเครื่อง (เพื่อเช็คว่าเคยล็อคอินไหม)
  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getInt('saved_userId');
    
    // ถ้าไม่มี Token หรือไม่มี ID แปลว่าไม่ได้ล็อคอิน
    if (token == null || userId == null) return null;

    return {
      'userId': userId,
      'name': prefs.getString('saved_name'),
      'role': prefs.getString('saved_role'),
    };
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  // [!!] 3. อัปเดตฟังก์ชัน login ให้เรียก _saveUserProfile
  Future<Map<String, dynamic>?> login(String email, String password) async {
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['token']);
      await _saveUserProfile(data);
      return data; // [!!] คืนค่าข้อมูล User
    }
      return null;
    } catch (e) {
      return null;
    }
  }

  // [!!] 4. อัปเดต logout ให้ล้างข้อมูลทั้งหมด
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ล้างเกลี้ยง (Token + Profile)
  }


  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': 'buyer', // กำหนด role เป็น 'buyer' โดยตรง
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- 2. Buyer Functions (ใหม่!) ---

  // ดึงร้านค้าทั้งหมด
  Future<List<dynamic>> getStores() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/stores'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Get Stores Error: $e");
      return [];
    }
  }

  // ดึงเมนูทั้งหมดของร้านค้า
  Future<List<dynamic>> getMenusForStore(int storeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stores/$storeId/menus')
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Get Menus Error: $e");
      return [];
    }
  }
  // สร้างคำสั่งซื้อใหม่

// --- 3. Order Functions ---
  Future<Map<String, dynamic>?> createOrder(int storeId, double totalPrice, List<CartItem> items) async {
    try {
      // [!!] ---- จุดแก้ไข: เพิ่ม title และ calories ในข้อมูลที่จะส่ง ----
      final orderItems = items.map((item) => {
        'menu_id': item.menu['menu_id'],
        'quantity': item.quantity,
        'price_at_time': item.menu['price'],
        // [!] เพิ่ม 2 ค่านี้
        'title': item.menu['title'], 
        'calories': item.menu['calories'] ?? 0, 
      }).toList();
      // [!!] ---------------------------------------------------

      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'store_id': storeId,
          'total_price': totalPrice,
          'items': orderItems,
        }),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Create Order Error: $e");
      return null;
    }
  }

Future<List<dynamic>> getMyOrders() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/my-orders'),
      headers: await _getAuthHeaders(), // [!] ต้องใช้ Token
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  } catch (e) {
    print("Get My Orders Error: $e");
    return [];
  }
}

// --- 4. Smart Advisor Functions ---
  
  Future<Map<String, dynamic>> getWeather() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/weather'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'condition': 'unknown'};
    } catch (e) {
      return {'condition': 'unknown'};
    }
  }

  Future<List<dynamic>> searchMenus({
    List<int>? tagIds,
    List<int>? moodIds,
    String type = 'all', // 'all', 'order', 'recipe'
  }) async {
    try {
      // สร้าง Query String
      final Map<String, dynamic> queryParams = {'type': type};
      if (tagIds != null && tagIds.isNotEmpty) {
        queryParams['tags'] = tagIds.join(','); // "1,5"
      }
      if (moodIds != null && moodIds.isNotEmpty) {
        queryParams['moods'] = moodIds.join(','); // "2"
      }
      
      final uri = Uri.parse('$_baseUrl/menus/search').replace(queryParameters: queryParams);
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Search Menus Error: $e");
      return [];
    }
  }
  
  Future<List<dynamic>> getFoodLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/food-log'),
        headers: await _getAuthHeaders(), // [!] ต้องใช้ Token
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addFoodLog({
    String? title,
    String? mealTime,
    int? calories,
    int? menuId,
  }) async {
    try {
      final body = {
        'title': title,
        'meal_time': mealTime,
        'calories': calories,
        'menu_id': menuId,
        'eaten_at': DateTime.now().toIso8601String(),
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/food-log'),
        headers: await _getAuthHeaders(),
        body: jsonEncode(body),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
  Future<List<dynamic>> getTags() async {
    try {
      // (API นี้เราสร้างไว้ใน Backend แล้ว)
      final response = await http.get(Uri.parse('$_baseUrl/tags'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getMoods() async {
    try {
      // (API นี้เราสร้างไว้ใน Backend แล้ว)
      final response = await http.get(Uri.parse('$_baseUrl/moods'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}