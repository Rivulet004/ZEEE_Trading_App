import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _processCheckout(BuildContext context, CartProvider cartProvider) async {
    final success = await cartProvider.checkout();

    if (success && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 30),
              SizedBox(width: 12),
              Text('PO Authorized', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your purchase order has been successfully locked in and committed. Your commercial tax-exempt PDF invoice has been compiled and emailed to your primary contact inbox.',
            style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to catalog
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final cartSKUs = cartProvider.items.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Review Order Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cartProvider.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF334155)),
                  SizedBox(height: 16),
                  Text('Your cart is currently empty.', style: TextStyle(color: Color(0xFF94A3B8))),
                ],
              ),
            )
          : Column(
              children: [
                // Delivery location info card
                if (cartProvider.selectedLocation != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shipping Target: ${cartProvider.selectedLocation!['location_name']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                cartProvider.selectedLocation!['delivery_address'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                // Cart items list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartSKUs.length,
                    itemBuilder: (context, index) {
                      final sku = cartSKUs[index];
                      final qty = cartProvider.items[sku]!;
                      
                      // Resolve details from local catalog cache
                      final prodDetails = catalogProvider.products.firstWhere(
                        (p) => p['sku'] == sku,
                        orElse: () => null,
                      );
                      
                      final name = prodDetails?['name'] ?? 'Product';
                      final price = double.tryParse(prodDetails?['calculated_price'] ?? '0.0') ?? 0.0;
                      final uom = prodDetails?['unit_of_measure'] ?? 'item';
                      final stockLimit = prodDetails?['stock_quantity'] ?? 999;

                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'SKU: $sku | Unit: $uom',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '\$${price.toStringAsFixed(2)} / unit',
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF94A3B8)),
                                    onPressed: () => cartProvider.removeFromCart(sku),
                                  ),
                                  Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8)),
                                    onPressed: () => cartProvider.addToCart(sku, price, stockLimit),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Financial summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtotal line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal Balance', style: TextStyle(color: Color(0xFF94A3B8))),
                          Text('\$${cartProvider.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // Tax line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Sales Tax', style: TextStyle(color: Color(0xFF94A3B8))),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('EXEMPT', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Text('\$0.00', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(color: Color(0xFF334155), height: 24),

                      // Grand total line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total PO',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '\$${cartProvider.total.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (cartProvider.errorMessage != null) ...[
                        Text(
                          cartProvider.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Submit button
                      cartProvider.isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                          : ElevatedButton(
                              onPressed: () => _processCheckout(context, cartProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'AUTHORIZE PURCHASE ORDER',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
