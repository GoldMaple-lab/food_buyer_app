import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:food_buyer_app/services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:food_buyer_app/services/cart_service.dart';
import 'package:food_buyer_app/pages/cart_page.dart';
import 'package:food_buyer_app/pages/menu_detail_page.dart';

class MenuListPage extends StatefulWidget {
  final int storeId;
  final String storeName;

  const MenuListPage({
    super.key, 
    required this.storeId, 
    required this.storeName
  });

  @override
  State<MenuListPage> createState() => _MenuListPageState();
}
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
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
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

class _MenuListPageState extends State<MenuListPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _menusFuture;

  @override
  void initState() {
    super.initState();
    // [!] โหลดเมนูของร้านนี้
    _menusFuture = _apiService.getMenusForStore(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        actions: [
          // [!!] ปุ่มตะกร้า
          IconButton(
            icon: _buildCartIcon(), // [!] ใช้ Widget ใหม่
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => CartPage()));
            },
          ),        ],
      ),
      
      body: FutureBuilder<List<dynamic>>(
        future: _menusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('ร้านนี้ยังไม่มีเมนู'));
          }

          final menus = snapshot.data!;
          
          return ListView.builder(
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index];
              
              // [!!] ---- START OF CHANGE ----
              // 1. Wrap your Card with an InkWell
              return InkWell(
                onTap: () {
                  // 2. Add the navigation logic here
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => MenuDetailPage(menu: menu),
                    ),
                  );
                },
                // [!!] ---- END OF CHANGE ----

                child: Card( // 3. Your original Card code is now the child
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  clipBehavior: Clip.antiAlias,
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- รูปเมนู ---
                      if (menu['image_url'] != null)
                        CachedNetworkImage(
                          imageUrl: menu['image_url'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(height: 150, child: Center(child: CircularProgressIndicator())),
                          errorWidget: (context, url, error) => Container(height: 150, child: Center(child: Icon(Icons.fastfood, color: Colors.grey))),
                        )
                      else
                        Container(height: 150, child: Center(child: Icon(Icons.fastfood, color: Colors.grey, size: 60))),
                      
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
                                  Text(
                                    '${menu['price']} บาท',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                                  ),
                                  if (menu['description'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        menu['description'], 
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // [!] ปุ่มสำหรับ Phase 4
                            IconButton(
                              icon: Icon(Icons.add_shopping_cart, color: Theme.of(context).primaryColor, size: 30),
                              onPressed: () {
                                // [!!] เรียก CartService
                                final cart = Provider.of<CartService>(context, listen: false);
                                bool success = cart.addItem(menu);

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('เพิ่ม "${menu['title']}" ลงตะกร้าแล้ว'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                } else {
                                  // This else part is from your original code, but cart.addItem should be updated to handle errors
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('ไม่สามารถเพิ่ม "${menu['title']}" ลงตะกร้าได้'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}