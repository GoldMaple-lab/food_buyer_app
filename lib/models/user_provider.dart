import 'package:flutter/material.dart';

// [!] Model สำหรับเก็บข้อมูลผู้ใช้
class UserModel {
  final int userId;
  final String name;
  final String role;
  UserModel({required this.userId, required this.name, required this.role});
}

// [!] ตัวจัดการ State
class UserProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  void setUser(Map<String, dynamic> userData) {
    _user = UserModel(
      userId: userData['userId'], 
      name: userData['name'], 
      role: userData['role']
    );
    notifyListeners(); // แจ้งเตือน Widget ที่ฟังอยู่
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}