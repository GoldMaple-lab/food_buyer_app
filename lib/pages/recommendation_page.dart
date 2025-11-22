import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:provider/provider.dart'; // [!] Import
import 'package:food_buyer_app/services/cart_service.dart'; // [!] Import
import 'package:food_buyer_app/pages/menu_detail_page.dart';
import 'package:food_buyer_app/pages/menu_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ถ้าใช้ CachedNetworkImage

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final ApiService _apiService = ApiService();

  // --- States ---
  String _weatherCondition = '...';
  String _rawWeather = ''; // เก็บค่า weather ดิบๆ (เช่น 'rain', 'clear')
  final TextEditingController _chatController = TextEditingController();
  
  late Future<List<dynamic>> _tagsFuture;
  late Future<List<dynamic>> _moodsFuture;
  List<dynamic> _allTags = [];
  List<dynamic> _allMoods = [];

  List<dynamic> _suggestions = [];
  bool _isLoading = false;
  String _currentSearchType = 'all';
  Set<int> _selectedTagIds = {};
  Set<int> _selectedMoodIds = {};
  String _moodText = "";

  // [!!] คำค้นหาที่ต้องการให้ trigger ระบบแนะนำตามสภาพอากาศ
  final List<String> _triggerPhrases = [
    'ไม่มีไอเดียเลย',
    'กินอะไรดีวะ',
    'เย็นนี้กินอะไรดี',
    'วันนี้กินอะไรดี',
    'กินอะไรดี',
    'ไม่รู้จะกินอะไร'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      _tagsFuture = _apiService.getTags();
      _moodsFuture = _apiService.getMoods();
      _allTags = await _tagsFuture;
      _allMoods = await _moodsFuture;

      final weatherData = await _apiService.getWeather();
      _weatherCondition = weatherData['description'] ?? 'ไม่ทราบ';
      _rawWeather = weatherData['condition'] ?? 'clear'; // เก็บค่าดิบไว้ใช้คำนวณ

    } catch (e) {
      print("Init Error: $e");
    }

    setState(() => _isLoading = false);
    
    // [!!] รันครั้งแรก (Limit 3)
    _runRecommend(isInitialLoad: true);
  }

  // [!!] ---- Logic การค้นหาและแนะนำ (หัวใจหลัก) ----
  Future<void> _runRecommend({bool isInitialLoad = false}) async {
    setState(() => _isLoading = true);
    
    Set<int> moodIdsToSearch = Set.from(_selectedMoodIds);
    Set<int> tagIdsToSearch = Set.from(_selectedTagIds);
    int? limitResult; // จำกัดจำนวนผลลัพธ์

    // 1. เช็คว่าเป็น "คำค้นหาพิเศษ" หรือไม่?
    bool isTriggerPhrase = _triggerPhrases.any((phrase) => _moodText.contains(phrase));

    // [!!] Logic: ถ้าเป็น Initial Load (เปิดแอป) หรือ พิมพ์คำว่า "กินอะไรดี..."
    if (isInitialLoad || isTriggerPhrase) {
      
      // กำหนดจำนวนที่จะแสดง
      limitResult = isInitialLoad ? 3 : 5; 

      // เลือก Mood ตามสภาพอากาศ
      String targetMoodName = 'hungry'; // ค่า Default
      
      if (_rawWeather.contains('rain') || _rawWeather.contains('drizzle') || _rawWeather.contains('thunder')) {
        // ฝนตก -> แนะนำของอุ่นๆ หรือ อาหารไทย (แก้หนาว)
        targetMoodName = 'tired'; // (สมมติว่า Tired = อยากกินของ Comfort food)
        // หรือถ้าคุณมี mood 'warm' ใน DB ก็ใช้ 'warm'
      } else if (_rawWeather.contains('clear') || _rawWeather.contains('sun')) {
        // แดดออก/ร้อน -> แนะนำของสดชื่น
        targetMoodName = 'refresh';
      } else {
        // เมฆครึ้ม/อื่นๆ
        targetMoodName = 'hungry';
      }

      // หา ID ของ Mood นั้นจาก _allMoods
      final foundMood = _allMoods.firstWhere(
        (m) => m['mood_name'] == targetMoodName, 
        orElse: () => null
      );

      if (foundMood != null) {
        moodIdsToSearch.add(foundMood['mood_id']);
        print("Auto-selecting mood: $targetMoodName for weather: $_rawWeather");
      }
      
      // ถ้าเป็น Trigger Phrase ให้เคลียร์ข้อความค้นหา จะได้ไม่ไปกวนการค้นหาแบบ Text
      if (isTriggerPhrase) {
         // (เราไม่ลบ _moodText ออกจาก UI เพื่อให้ผู้ใช้เห็นว่าพิมพ์อะไรไป แต่เราไม่เอาไป search text)
      }

    } else if (_moodText.isNotEmpty) {
      // --- Logic เดิม: ค้นหาตามอารมณ์ที่พิมพ์ (AI เล็กๆ) ---
      final detectedMood = _detectMood(_moodText);
      if (detectedMood != 'neutral') {
        final foundMood = _allMoods.firstWhere(
          (m) => m['mood_name'] == detectedMood, 
          orElse: () => null
        );
        if (foundMood != null) {
          moodIdsToSearch.add(foundMood['mood_id']);
        }
      }
    }

    // --- ยิง API ---
    try {
      List<dynamic> results = await _apiService.searchMenus(
        type: _currentSearchType,
        tagIds: tagIdsToSearch.toList(),
        moodIds: moodIdsToSearch.toList(),
      );

      // [!!] ถ้ามีการจำกัดจำนวน (Limit)
      if (limitResult != null && results.length > limitResult) {
        // สุ่ม (Shuffle) ก่อนตัด เพื่อให้ไม่ซ้ำซาก
        results.shuffle(); 
        results = results.take(limitResult).toList();
      }

      setState(() {
        _suggestions = results;
      });
    } catch (e) {
      print("Search Error: $e");
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // --- 1. Controls ---
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
                _buildTypeSelector(),
                SizedBox(height: 12),
                _buildFilterSection('หมวดหมู่ (Tags)', _tagsFuture, _allTags, _selectedTagIds, 'tag_id', 'tag_name'),
                SizedBox(height: 12),
                _buildFilterSection('อารมณ์ (Moods)', _moodsFuture, _allMoods, _selectedMoodIds, 'mood_id', 'mood_name'),
              ],
            ),
          ),
        ),
        
        // --- 2. Header ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'เมนูแนะนำสำหรับคุณ', 
                  style: Theme.of(context).textTheme.headlineSmall
                ),
                Spacer(),
                // แสดงจำนวนผลลัพธ์
                if (!_isLoading)
                  Text('${_suggestions.length} รายการ', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),

        // --- 3. Result List ---
        _buildSliverSuggestionsList(),
      ],
    );
  }

  // ... (Keep _buildWeatherCard, _buildTypeSelector, _buildFilterSection as is) ...
  // (Widget ย่อยๆ เดิมของคุณ ไม่ต้องแก้ ยกเว้น _buildChatBox)

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
                labelText: 'เช่น "กินอะไรดี", "ร้อนจัง", "อยากกินเผ็ดๆ"...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    setState(() {
                      _moodText = _chatController.text;
                    });
                    _runRecommend(); // Trigger search
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              onSubmitted: (text) {
                 setState(() { _moodText = text; });
                _runRecommend();
              },
            ),
            // แสดง Chip ถ้ามีการพิมพ์ข้อความค้างไว้
            if (_moodText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Chip(
                  label: Text('ข้อความ: "$_moodText"'),
                  onDeleted: () {
                    setState(() {
                      _moodText = '';
                      _chatController.clear();
                    });
                    // พอลบข้อความ ก็รันแนะนำแบบ Initial Load (3 เมนู) ใหม่
                    _runRecommend(isInitialLoad: true); 
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  // ... (Keep _buildTypeSelector, _buildFilterSection) ...
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

  // ... (Keep _buildSliverSuggestionsList - copy from previous step but ensure imports) ...
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
          bool isForOrder = menu['store_id'] != null;
          
          return InkWell(
            onTap: () {
               // [!] อย่าลืม import MenuDetailPage
               Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => MenuDetailPage(menu: menu)));
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (menu['image_url'] != null)
                    Image.network(menu['image_url'], height: 180, width: double.infinity, fit: BoxFit.cover)
                  else
                    Container(height: 180, child: Center(child: Icon(Icons.fastfood, size: 60))),
                  
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(menu['title'], style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              if (isForOrder)
                                Text('${menu['price']} บาท • 🛒 ${menu['store_name']}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))
                              else
                                Text('สูตรทำอาหาร • ${menu['calories']} kcal', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (isForOrder)
                          IconButton(
                            icon: Icon(Icons.add_shopping_cart, color: Theme.of(context).primaryColor, size: 30),
                            onPressed: () {
                              final cart = Provider.of<CartService>(context, listen: false);
                              cart.addItem(menu);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่ม "${menu['title']}" ลงตะกร้า'), duration: Duration(seconds: 1)));
                            },
                          )
                        else
                          Icon(Icons.menu_book, color: Colors.green, size: 30),
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

  // [!] Helper เก่า
  String _detectMood(String text) {
    final t = text.toLowerCase();
    if (t.contains('เหนื่อย') || t.contains('ไม่สบาย') || t.contains('เบื่อ')) return 'tired';
    if (t.contains('ร้อน') || t.contains('ร้อนจัง') || t.contains('สดชื่น')) return 'refresh';
    if (t.contains('หนาว')) return 'hungry'; 
    if (t.contains('ฉลอง') || t.contains('ดีใจ') || t.contains('สังสรรค์')) return 'celebrate';
    if (t.contains('ลดน้ำหนัก') || t.contains('คุมอาหาร') || t.contains('เบาๆ')) return 'health';
    if (t.contains('หิว') || t.contains('อยากกินจัง')) return 'hungry';
    if (t.contains('เครียด') || t.contains('กังวล')) return 'stress';
    if (t.contains('ไทย')) return 'ThaiFood';
    return 'neutral';
  }
}