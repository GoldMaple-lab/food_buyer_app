import 'package:flutter/foundation.dart';

// [!] Model Item ในตะกร้า
class CartItem {
  final Map<String, dynamic> menu;
  int quantity;

  CartItem({required this.menu, this.quantity = 1});

  // [!!] ---- จุดแก้ไข ----
  double get itemTotalPrice {
    // แปลง String "60.00" ให้เป็น double 60.00
    final price = double.tryParse(menu['price'].toString()) ?? 0.0;
    return price * quantity;
  }
}

// [!] ตัวจัดการตะกร้า
class CartService extends ChangeNotifier {
  // Key คือ menu_id
  final Map<int, CartItem> _items = {};
  
  // [!] สั่งได้ทีละร้านเท่านั้น
  int? _currentStoreId;

  Map<int, CartItem> get items => _items;
  int? get currentStoreId => _currentStoreId;
  int get totalItems => _items.length;

  // ฟังก์ชันเพิ่มของ
  bool addItem(Map<String, dynamic> menuItem) {
    final menuId = menuItem['menu_id'];
    final storeId = menuItem['store_id'];

    // [!] ถ้าสั่งจากร้านใหม่, ให้ล้างตะกร้าเก่า
    if (_currentStoreId != null && _currentStoreId != storeId) {
      // (ควรจะขึ้น Dialog ถามผู้ใช้ก่อน)
      print("ล้างตะกร้าเก่า เพราะสั่งจากร้านใหม่");
      _items.clear();
      _currentStoreId = storeId;
    } else if (_currentStoreId == null) {
      _currentStoreId = storeId;
    }
    
    if (_items.containsKey(menuId)) {
      _items[menuId]!.quantity++;
    } else {
      _items[menuId] = CartItem(menu: menuItem);
    }
    
    notifyListeners(); // [!] แจ้งเตือน UI
    return true;
  }

  // ล้างตะกร้า
  void clearCart() {
    _items.clear();
    _currentStoreId = null;
    notifyListeners();
  }
  
  // คำนวณราคารวม
  double get totalPrice {
    double total = 0;
    _items.forEach((key, item) {
      total += item.itemTotalPrice;
    });
    return total;
  }
}