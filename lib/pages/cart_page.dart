import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:food_buyer_app/services/cart_service.dart';
import 'package:provider/provider.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // [!] ฟังก์ชันยืนยันการสั่งซื้อ
  Future<void> _checkout(CartService cart) async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _apiService.createOrder(
        cart.currentStoreId!, 
        cart.totalPrice, 
        cart.items.values.toList() // [!] ส่ง List<CartItem>
      );

      if (result != null && context.mounted) {
        // [!!] สั่งซื้อสำเร็จ!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สั่งซื้อสำเร็จ! Order ID: #${result['orderId']}'),
            backgroundColor: Colors.green,
          ),
        );
        cart.clearCart(); // ล้างตะกร้า
        Navigator.of(context).pop(); // กลับหน้า Home
      } else {
        throw Exception('Failed to create order');
      }

    } catch (e) {
      if(context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if(mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // [!] ใช้ Consumer เพื่อ "ฟัง" CartService
    return Consumer<CartService>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('ตะกร้าสินค้า'),
            actions: [
              IconButton(
                icon: Icon(Icons.delete_sweep),
                onPressed: cart.items.isEmpty ? null : () => cart.clearCart(),
              ),
            ],
          ),
          body: cart.items.isEmpty
              ? Center(child: Text('ตะกร้าว่างเปล่า'))
              : ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items.values.toList()[index];
                    return ListTile(
                      leading: Icon(Icons.fastfood),
                      title: Text(item.menu['title']),
                      subtitle: Text('${item.menu['price']} x ${item.quantity}'),
                      trailing: Text('${item.itemTotalPrice} บาท'),
                    );
                  },
                ),
          
          // [!] ส่วนสรุปราคา และปุ่ม Checkout
          bottomNavigationBar: cart.items.isEmpty
              ? null
              : Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ยอดรวม:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${cart.totalPrice} บาท', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('ชำระเงินปลายทาง (Cash on Delivery)', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 16),
                      if (_isLoading)
                        CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: () => _checkout(cart),
                          style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                          child: Text('ยืนยันการสั่งซื้อ'),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}