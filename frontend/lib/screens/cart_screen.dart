import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'checkout_screen.dart';

class CartTab extends StatefulWidget {
  final VoidCallback? onCheckoutSuccess;
  const CartTab({super.key, this.onCheckoutSuccess});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      if (cartProvider.selectedLocation != null) {
        cartProvider.fetchDeliverySchedule(cartProvider.selectedLocation!['zip_code']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartSKUs = cartProvider.items.keys.toList();

    return cartProvider.items.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: themeProvider.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text('Your cart is currently empty.', style: TextStyle(color: themeProvider.textSecondary)),
              ],
            ),
          )
        : Column(
            children: [
              // Delivery location info card
              if (cartProvider.selectedLocation != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: themeProvider.surface,
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: themeProvider.primaryAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shipping Target: ${cartProvider.selectedLocation!['location_name']}',
                              style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              cartProvider.selectedLocation!['delivery_address'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
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
                      color: themeProvider.surface,
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
                                    style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU: $sku | Unit: $uom',
                                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '\$${price.toStringAsFixed(2)} / unit',
                                    style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: themeProvider.textSecondary),
                                  onPressed: () => cartProvider.removeFromCart(sku),
                                ),
                                Text('$qty', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: themeProvider.primaryAccent),
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
                decoration: BoxDecoration(
                  color: themeProvider.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Subtotal line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal Balance', style: TextStyle(color: themeProvider.textSecondary)),
                        Text('\$${cartProvider.subtotal.toStringAsFixed(2)}', style: TextStyle(color: themeProvider.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Tax line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('Sales Tax', style: TextStyle(color: themeProvider.textSecondary)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: (themeProvider.isDark ? themeProvider.primaryAccent : themeProvider.secondaryAccent).withOpacity(0.1),
                                  border: Border.all(color: themeProvider.isDark ? themeProvider.primaryAccent : themeProvider.secondaryAccent, width: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EXEMPT', 
                                style: TextStyle(
                                  color: themeProvider.isDark ? themeProvider.primaryAccent : themeProvider.secondaryAccent, 
                                  fontSize: 9, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text('\$0.00', style: TextStyle(color: themeProvider.isDark ? themeProvider.primaryAccent : themeProvider.secondaryAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),

                    // Scheduled Delivery Date Selector (Route delivery calendars & Warehouse cut-offs)
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Scheduled Delivery', style: TextStyle(color: themeProvider.textSecondary)),
                        InkWell(
                          onTap: () async {
                            final schedule = cartProvider.deliverySchedule;
                            final nextAvailStr = schedule?['next_available_date'];
                            final nextAvail = nextAvailStr != null ? DateTime.parse(nextAvailStr) : DateTime.now();
                            final deliveryDays = (schedule?['delivery_days'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];

                            final chosenDate = await showDatePicker(
                              context: context,
                              initialDate: cartProvider.selectedDeliveryDate ?? nextAvail,
                              firstDate: nextAvail,
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                              selectableDayPredicate: (date) {
                                return deliveryDays.contains(date.weekday);
                              },
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: themeProvider.primaryAccent,
                                      onPrimary: themeProvider.isDark ? Colors.black : Colors.white,
                                      surface: themeProvider.surface,
                                      onSurface: themeProvider.textPrimary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (chosenDate != null) {
                              cartProvider.setSelectedDeliveryDate(chosenDate);
                            }
                          },
                          child: Row(
                            children: [
                              Text(
                                cartProvider.selectedDeliveryDate != null
                                    ? "${cartProvider.selectedDeliveryDate!.year}-${cartProvider.selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${cartProvider.selectedDeliveryDate!.day.toString().padLeft(2, '0')}"
                                    : 'Select Date',
                                style: TextStyle(
                                  color: themeProvider.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.calendar_today_outlined, color: themeProvider.primaryAccent, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    Divider(color: themeProvider.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 24),

                    // Grand total line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Grand Total PO',
                          style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '\$${cartProvider.total.toStringAsFixed(2)}',
                          style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Proceed to checkout button
                    cartProvider.isLoading
                        ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                        : ElevatedButton(
                            onPressed: () {
                              if (cartProvider.selectedDeliveryDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please select a scheduled delivery date to proceed to checkout.'),
                                    backgroundColor: themeProvider.errorColor,
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(onCheckoutSuccess: widget.onCheckoutSuccess),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.primaryAccent,
                              foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'PROCEED TO CHECKOUT',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          );
  }
}
