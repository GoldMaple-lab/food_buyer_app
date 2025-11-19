import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'dart:convert';

class MenuDetailPage extends StatefulWidget {
  final Map<String, dynamic> menu;

  const MenuDetailPage({super.key, required this.menu});

  @override
  State<MenuDetailPage> createState() => _MenuDetailPageState();
}

class _MenuDetailPageState extends State<MenuDetailPage> {
  // [!] State สำหรับ Food Log
  String _selectedMealTime = 'lunch'; // ค่าเริ่มต้น
  final ApiService _apiService = ApiService();

  // [!] เช็คว่าเป็นเมนูสำหรับ "สั่ง" หรือ "ทำเอง"
  bool get isForOrder => widget.menu['store_id'] != null;

  // [!] แปลง String JSON กลับเป็น Map (เหมือนใน Seller App)
  Map<String, dynamic>? get _recipe {
    if (widget.menu['recipe'] == null) return null;
    try {
      if (widget.menu['recipe'] is String) {
        return jsonDecode(widget.menu['recipe']);
      }
      return widget.menu['recipe']; // ถ้าเป็น Map อยู่แล้ว
    } catch (e) {
      print("Error decoding recipe: $e");
      return null;
    }
  }

  // [!] ฟังก์ชันบันทึก Food Log
  Future<void> _logFood() async {
    final bool success = await _apiService.addFoodLog(
      menuId: widget.menu['menu_id'],
      title: widget.menu['title'],
      mealTime: _selectedMealTime,
      calories: widget.menu['calories'] ?? 0,
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกการกินสำเร็จ!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกการกินไม่สำเร็จ'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.menu['title']),
        actions: [
          // [!] ปุ่มเพิ่มลงตะกร้า (ถ้าเป็นเมนูสั่ง)
          if (isForOrder)
            Consumer<CartService>(
              builder: (context, cart, child) {
                return IconButton(
                  icon: Icon(Icons.add_shopping_cart),
                  onPressed: () {
                    cart.addItem(widget.menu);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เพิ่ม "${widget.menu['title']}" ลงตะกร้า'), duration: Duration(seconds: 1)),
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- รูปภาพเมนู ---
            if (widget.menu['image_url'] != null)
              Hero( // [!] ใช้ Hero Animation เพื่อความสวยงาม
                tag: 'menu_image_${widget.menu['menu_id']}', 
                child: Image.network(
                  widget.menu['image_url'],
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 250,
                color: Colors.grey[200],
                child: Center(child: Icon(Icons.fastfood, size: 80, color: Colors.grey[600])),
              ),
            
            // --- รายละเอียดหลัก ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.menu['title'],
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  if (isForOrder)
                    Text(
                      'ราคา: ${widget.menu['price']} บาท',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor),
                    )
                  else
                    Text(
                      'ประเภท: สูตรทำอาหาร',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green),
                    ),
                  SizedBox(height: 8),
                  if (widget.menu['description'] != null && widget.menu['description'].isNotEmpty)
                    Text(
                      widget.menu['description'],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  SizedBox(height: 8),
                  Text(
                    'แคลอรี่: ${widget.menu['calories'] ?? 'ไม่ระบุ'} kcal',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isForOrder)
                    Text(
                      'ร้านค้า: ${widget.menu['store_name']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  Divider(height: 32),

                  // [!!] 1. ส่วน Moods (ที่หายไป)
                  _buildChipList('เหมาะสำหรับอารมณ์:', widget.menu['moods'], Icons.mood, Colors.purple),

                  // [!!] 2. ส่วน Tags (ที่หายไป)
                  _buildChipList('หมวดหมู่:', widget.menu['tags'], Icons.label, Colors.blue),

                  // [!!] 3. ส่วน Recipe (ที่เพิ่งอัปเกรด)
                  if (_recipe != null && (_recipe!['ingredients']?.isNotEmpty == true || _recipe!['steps']?.isNotEmpty == true))
                    Container(
                      margin: const EdgeInsets.only(top: 8.0), // [!] เพิ่มระยะห่างด้านบน
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        // [!] ใช้สี Primary ของ Theme มาทำเป็นสีพื้นหลังอ่อนๆ
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          // --- 1. ส่วนผสม (แบบ ListTile) ---
                          if (_recipe!['ingredients']?.isNotEmpty == true)
                            ...[ // ใช้ ... (spread) เพื่อแทรก List
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.kitchen_outlined, color: Theme.of(context).primaryColor),
                                title: Text('ส่วนผสม', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              // วน Loop สร้าง ListTile
                              ...(_recipe!['ingredients'] as List<dynamic>).map((ing) => ListTile(
                                    dense: true,
                                    leading: Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                    title: Text(ing, style: Theme.of(context).textTheme.bodyMedium),
                                  )).toList(),
                              SizedBox(height: 16),
                            ],

                          // --- 2. วิธีทำ (แบบ ListTile) ---
                          if (_recipe!['steps']?.isNotEmpty == true)
                            ...[ // ใช้ ... (spread)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.soup_kitchen_outlined, color: Theme.of(context).primaryColor),
                                title: Text('วิธีทำ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              // วน Loop สร้าง ListTile
                              ...(_recipe!['steps'] as List<dynamic>).asMap().entries.map((entry) {
                                int index = entry.key + 1; // [!] สร้างเลขข้อ
                                String step = entry.value;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar( // [!] ใช้วงกลมตัวเลข
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    radius: 14,
                                    child: Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(step, style: Theme.of(context).textTheme.bodyMedium),
                                );
                              }).toList(),
                            ],
                        ],
                      ),
                    ),
                  
                  // [!!] ---- จบส่วน Container ----

                  Divider(height: 32), // [!] Divider นี้น่าจะยังอยู่ (หรือถ้าซ้ำก็ลบออก)

                  // [!] ---- ส่วน Log Food ----
                  if (!isForOrder)
                    _buildLogFoodSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // [!] Widget สำหรับบันทึกการกิน
  Widget _buildLogFoodSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('บันทึกการกิน', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedMealTime,
          decoration: InputDecoration(
            labelText: 'มื้ออาหาร',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'breakfast', child: Text('มื้อเช้า')),
            DropdownMenuItem(value: 'lunch', child: Text('มื้อกลางวัน')),
            DropdownMenuItem(value: 'dinner', child: Text('มื้อเย็น')),
            DropdownMenuItem(value: 'snack', child: Text('ของว่าง')),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedMealTime = newValue;
              });
            }
          },
        ),
        SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _logFood,
          icon: Icon(Icons.add_task),
          label: Text('บันทึกเมนูนี้'),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
  // (ใน class _MenuDetailPageState)

  // [!!] ---- เพิ่ม Widget นี้ ----
  // Helper สำหรับสร้าง Chip List
  Widget _buildChipList(String title, String? data, IconData icon, Color color) {
    // 1. เช็คว่า data ไม่ null และไม่ว่าง
    if (data == null || data.isEmpty) {
      return SizedBox.shrink(); // ไม่ต้องแสดงอะไร
    }

    // 2. แปลง "spicy,thai" เป็น List ["spicy", "thai"]
    final items = data.split(',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: items.map((item) => Chip(
            avatar: Icon(icon, color: color, size: 20),
            label: Text(item),
            backgroundColor: color.withOpacity(0.1),
            shape: StadiumBorder(side: BorderSide(color: color.withOpacity(0.3))),
          )).toList(),
        ),
        Divider(height: 32),
      ],
    );
  }
}