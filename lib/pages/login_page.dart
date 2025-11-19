import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'store_list_page.dart'; 
import 'package:provider/provider.dart'; // [!] Import
import 'package:food_buyer_app/models/user_provider.dart'; // [!] Import
import 'package:food_buyer_app/pages/main_nav_page.dart'; // [!!] Import

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginMode = true; 
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  void _showError(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);

  try {
    Map<String, dynamic>? loginData;
    bool registerSuccess = false;

    if (_isLoginMode) {
      // --- โหมด Login ---
      loginData = await _apiService.login(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      // --- โหมด Register ---
      registerSuccess = await _apiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
      );
    }

    if (loginData != null && context.mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(loginData);
          Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => MainNavigationPage()), // [!!] ไปที่หน้า Wrapper ใหม่
          );
    } else if (registerSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สมัครสมาชิกสำเร็จ! กรุณาล็อคอิน')),
      );
      setState(() { _isLoginMode = true; });
    } else if (context.mounted) {
        _showError(_isLoginMode ? 'ล็อคอินล้มเหลว' : 'สมัครสมาชิกล้มเหลว');
    }
  } catch (e) {
    _showError('เกิดข้อผิดพลาด: $e');
  }
  if (mounted) { setState(() => _isLoading = false); }
}
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [!] 1. เปลี่ยนพื้นหลังให้มีสีเทาจางๆ
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2), 
      body: Center( // [!] 2. ใช้ Center เพื่อจัดทุกอย่างไว้ตรงกลาง
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox( // [!] 3. จำกัดความกว้างไม่ให้ฟอร์มใหญ่เกินไป
            constraints: BoxConstraints(maxWidth: 500),
            
            // [!] 4. นี่คือ "กรอบ" (Card) ที่คุณต้องการ
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0), // [!] เพิ่มช่องว่างภายใน Card
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- 5. เพิ่ม Logo หรือ Icon ด้านบน ---
                      Icon(
                        Icons.storefront_outlined, 
                        size: 64, 
                        color: Theme.of(context).primaryColor
                      ),
                      SizedBox(height: 16),
                      Text(
                        _isLoginMode ? 'Seller Login' : 'Seller Register',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text('เข้าสู่ระบบสำหรับผู้ขาย'),
                      SizedBox(height: 24),

                      // --- ช่อง "Name" ---
                      if (!_isLoginMode)
                        TextFormField(
                          controller: _nameController,
                          // [!] 6. ใช้ InputDecoration ที่เราทำไว้
                          decoration: InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                      
                      SizedBox(height: 16),

                      // --- ช่อง "Email" ---
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      // --- ช่อง "Password" ---
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.length < 3) {
                            return 'Password must be at least 3 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24),

                      // --- ปุ่ม Submit / Loading ---
                      if (_isLoading)
                        CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: _submitForm,
                          // [!] 7. ทำให้ปุ่มมันเต็มความกว้าง
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50)
                          ),
                          child: Text(_isLoginMode ? 'Login' : 'Register'),
                        ),

                      // --- ปุ่มสลับโหมด ---
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                        child: Text(
                          _isLoginMode 
                          ? 'Create an account (Register)' 
                          : 'Already have an account? (Login)'
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}