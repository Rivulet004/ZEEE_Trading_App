import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';

class OrderGuideTab extends StatefulWidget {
  const OrderGuideTab({super.key});

  @override
  State<OrderGuideTab> createState() => _OrderGuideTabState();
}

class _OrderGuideTabState extends State<OrderGuideTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final locationId = cartProvider.selectedLocation?['id'];
      Provider.of<CatalogProvider>(context, listen: false).fetchOrderGuide(locationId: locationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return catalogProvider.isLoading
        ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
        : catalogProvider.orderGuide.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: themeProvider.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No Routine Orders Found',
                        style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your custom Tuesday Order Guide lists products you order frequently. Check out standard items from the catalog first to build your order history!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: themeProvider.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: themeProvider.surface,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: themeProvider.primaryAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Chef\'s Shopping List: Running down this dense page adds items directly to your cart session. Tap your Tuesday counts below to checkout in seconds.',
                            style: TextStyle(color: themeProvider.textSecondary, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: catalogProvider.orderGuide.length,
                      itemBuilder: (context, index) {
                        final prod = catalogProvider.orderGuide[index];
                        final calcPrice = double.tryParse(prod['calculated_price'] ?? '0.0') ?? 0.0;
                        final basePrice = double.tryParse(prod['base_price'] ?? '0.0') ?? 0.0;
                        final isDiscounted = calcPrice < basePrice;

                        final qtyInCart = cartProvider.items[prod['sku']] ?? 0;
                        final stockLimit = prod['stock_quantity'] ?? 0;
                        final frequency = prod['frequency_count'] ?? 1;

                        return Card(
                          color: themeProvider.surface,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prod['name'] ?? 'Product',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: themeProvider.primaryAccent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: themeProvider.primaryAccent.withOpacity(0.4), width: 0.5),
                                            ),
                                            child: Text(
                                              'Ordered $frequency times',
                                              style: TextStyle(color: themeProvider.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SKU: ${prod['sku']} | UOM: ${prod['unit_of_measure']}',
                                        style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            '\$${calcPrice.toStringAsFixed(2)}',
                                            style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (isDiscounted) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '\$${basePrice.toStringAsFixed(2)}',
                                              style: TextStyle(color: themeProvider.textSecondary, fontSize: 11, decoration: TextDecoration.lineThrough),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: themeProvider.textSecondary),
                                      onPressed: () {
                                        cartProvider.removeFromCart(prod['sku']);
                                      },
                                    ),
                                    Text(
                                      '$qtyInCart',
                                      style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline, color: themeProvider.primaryAccent),
                                      onPressed: () {
                                        cartProvider.addToCart(prod['sku'], calcPrice, stockLimit);
                                      },
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
                ],
              );
  }
}
