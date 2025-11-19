import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:provider/provider.dart'; // [!] Import
import 'package:food_buyer_app/services/cart_service.dart'; // [!] Import
import 'package:food_buyer_app/pages/menu_detail_page.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final ApiService _apiService = ApiService();

  // --- States สำหรับ UI ---
  String _weatherCondition = '...';
  final TextEditingController _chatController = TextEditingController();
  
  // --- States สำหรับเก็บข้อมูลที่โหลดมา ---
  late Future<List<dynamic>> _tagsFuture;
  late Future<List<dynamic>> _moodsFuture;
  List<dynamic> _allTags = []; // เก็บ Tags ที่โหลดเสร็จ
  List<dynamic> _allMoods = []; // เก็บ Moods ที่โหลดเสร็จ

  // --- States สำหรับการค้นหา ---
  List<dynamic> _suggestions = []; // ผลลัพธ์การค้นหา
  bool _isLoading = false;
  String _currentSearchType = 'all'; // 'all', 'order' (สั่งกิน), 'recipe' (ทำเอง)
  Set<int> _selectedTagIds = {};
  Set<int> _selectedMoodIds = {};
  String _moodText = ""; // จาก Chat Box

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // 1. โหลด Tags & Moods
    _tagsFuture = _apiService.getTags();
    _moodsFuture = _apiService.getMoods();
    _allTags = await _tagsFuture;
    _allMoods = await _moodsFuture;

    // 2. โหลดสภาพอากาศ
    final weatherData = await _apiService.getWeather();
    _weatherCondition = weatherData['description'] ?? 'ไม่ทราบ';

    setState(() => _isLoading = false);
    
    // 3. (Optional) รันค้นหาครั้งแรก (อาจจะค้นหาตามสภาพอากาศ)
    _runRecommend();
  }

  // [!!] ---- Logic การค้นหาใหม่ทั้งหมด ----
  Future<void> _runRecommend() async {
    setState(() => _isLoading = true);
    
    // --- (Optional) แปลง Mood Text เป็น ID ---
    // (โค้ดส่วนนี้คือ "AI" เล็กๆ ที่เรานำกลับมา)
    Set<int> moodIdsFromText = {};
    if (_moodText.isNotEmpty) {
      final detectedMood = _detectMood(_moodText); // (ฟังก์ชัน helper อยู่ด้านล่าง)
      if (detectedMood != 'neutral') {
        final foundMood = _allMoods.firstWhere(
          (m) => m['mood_name'] == detectedMood, 
          orElse: () => null
        );
        if (foundMood != null) {
          moodIdsFromText.add(foundMood['mood_id']);
        }
      }
    }

    // --- รวม ID ทั้งหมด ---
    final allMoodIds = _selectedMoodIds.union(moodIdsFromText).toList();
    final allTagIds = _selectedTagIds.toList();

    // --- ยิง API "Smart Search" ---
    try {
      final results = await _apiService.searchMenus(
        type: _currentSearchType,
        tagIds: allTagIds,
        moodIds: allMoodIds,
      );
      setState(() {
        _suggestions = results;
      });
    } catch (e) {
      print("Search Error: $e");
    }
    
    setState(() => _isLoading = false);
  }

  // --- UI Builders (นำมาจากโค้ดต้นฉบับ) ---
  @override
  Widget build(BuildContext context) {
    // [!] เราใช้ CustomScrollView (แบบแอปต้นฉบับ)
    return CustomScrollView(
      slivers: [
        // --- 1. ส่วน Controls ทั้งหมด ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeatherCard(),
                SizedBox(height: 12),
                _buildChatBox(),
                SizedBox(height: 12),
                _buildTypeSelector(), // [!] UI ใหม่: เลือก สั่ง/ทำเอง
                SizedBox(height: 12),
                _buildFilterSection('หมวดหมู่ (Tags)', _tagsFuture, _allTags, _selectedTagIds, 'tag_id', 'tag_name'),
                SizedBox(height: 12),
                _buildFilterSection('อารมณ์ (Moods)', _moodsFuture, _allMoods, _selectedMoodIds, 'mood_id', 'mood_name'),
              ],
            ),
          ),
        ),
        
        // --- 2. หัวข้อ "เมนูแนะนำ" ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Text(
              'เมนูแนะนำสำหรับคุณ', 
              style: Theme.of(context).textTheme.headlineSmall
            ),
          ),
        ),

        // --- 3. รายการผลลัพธ์ ---
        _buildSliverSuggestionsList(),
      ],
    );
  }

  // (Widget ย่อยๆ)

  Widget _buildWeatherCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.wb_sunny_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text('สภาพอากาศ จ.ตรัง: $_weatherCondition'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatBox() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณรู้สึกอย่างไร?', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            TextField(
              controller: _chatController,
              decoration: InputDecoration(
                labelText: 'เช่น "ร้อนจัง", "อยากกินอะไรเบาๆ"...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    setState(() {
                      _moodText = _chatController.text;
                    });
                    _runRecommend(); // [!] ค้นหาใหม่
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              onSubmitted: (text) {
                 setState(() { _moodText = text; });
                _runRecommend();
              },
            ),
            if (_moodText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Chip(
                  label: Text('ฟิลเตอร์: "$_moodText"'),
                  onDeleted: () {
                    setState(() => _moodText = '');
                    _chatController.clear();
                    _runRecommend();
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
  
  // [!] UI ใหม่: เลือกประเภท
  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการ...', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text('ทั้งหมด')),
                ButtonSegment(value: 'order', label: Text('สั่งกิน'), icon: Icon(Icons.delivery_dining)),
                ButtonSegment(value: 'recipe', label: Text('ทำเอง'), icon: Icon(Icons.soup_kitchen)),
              ],
              selected: {_currentSearchType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _currentSearchType = newSelection.first;
                });
                _runRecommend();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // [!] UI ที่ Re-use ได้สำหรับ Tags และ Moods
  Widget _buildFilterSection(String title, Future<List<dynamic>> future, List<dynamic> allItems, Set<int> selectedIds, String idKey, String nameKey) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('ไม่มีข้อมูล');
                }
                
                return Wrap(
                  spacing: 8.0,
                  children: allItems.map((item) {
                    final int id = item[idKey];
                    final String name = item[nameKey];
                    final bool isSelected = selectedIds.contains(id);
                    
                    return FilterChip(
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) selectedIds.add(id);
                          else selectedIds.remove(id);
                        });
                        _runRecommend();
                      },
                    );
                  }).toList(),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  // [!] UI แสดงผลลัพธ์
  Widget _buildSliverSuggestionsList() {
    if (_isLoading) {
      return SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }
    if (_suggestions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('ไม่พบเมนูที่ตรงเงื่อนไข 😥\nลองเปลี่ยนฟิลเตอร์ดู', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, idx) {
          final menu = _suggestions[idx];
          bool isForOrder = menu['store_id'] != null; // [!] เช็คว่าสั่งได้ไหม
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
                    onTap: () {
                        // [!!] เปิด MenuDetailPage
                      Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => MenuDetailPage(menu: menu),
                            ),
                          );
                        },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- รูปเมนู ---
                  if (menu['image_url'] != null)
                    Image.network(
                      menu['image_url'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(height: 180, child: Center(child: Icon(Icons.fastfood, size: 60))),
                  
                  // --- รายละเอียด ---
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                menu['title'], 
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                              ),
                              if (isForOrder) // [!] ถ้าสั่งได้
                                Text(
                                  '${menu['price']} บาท • 🛒 ${menu['store_name']}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                                )
                              else // [!] ถ้าเป็นสูตร
                                Text(
                                  'สูตรทำอาหาร • ${menu['calories']} kcal',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        
                        // [!] ปุ่ม (สั่ง หรือ ดูสูตร)
                        if (isForOrder)
                          IconButton(
                            icon: Icon(Icons.add_shopping_cart, color: Theme.of(context).primaryColor, size: 30),
                            onPressed: () {
                              final cart = Provider.of<CartService>(context, listen: false);
                              cart.addItem(menu);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('เพิ่ม "${menu['title']}" ลงตะกร้า'), duration: Duration(seconds: 1)),
                              );
                            },
                          )
                        else
                          Icon(Icons.menu_book, color: Colors.green, size: 30), // (ปุ่มดูสูตร)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: _suggestions.length,
      ),
    );
  }

  // [!!] ---- Helper Function (จากโค้ดต้นฉบับ) ----
  String _detectMood(String text) {
    final t = text.toLowerCase();
    if (t.contains('เหนื่อย') || t.contains('ไม่สบาย') || t.contains('เบื่อ')) return 'tired';
    if (t.contains('ร้อน') || t.contains('ร้อนจัง') || t.contains('สดชื่น')) return 'refresh';
    if (t.contains('หนาว')) return 'hungry'; // (อาจจะอยากกินของร้อนๆ = hungry)
    if (t.contains('ฉลอง') || t.contains('ดีใจ') || t.contains('สังสรรค์')) return 'celebrate';
    if (t.contains('ลดน้ำหนัก') || t.contains('คุมอาหาร') || t.contains('เบาๆ')) return 'health';
    if (t.contains('หิว') || t.contains('อยากกินจัง')) return 'hungry';
    if (t.contains('เครียด') || t.contains('กังวล')) return 'stress';
    if (t.contains('ไทย')) return 'ThaiFood';
    return 'neutral';
  }
}