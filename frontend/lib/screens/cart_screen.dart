import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

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

  void _processCheckout(BuildContext context, CartProvider cartProvider, ThemeProvider themeProvider) async {
    if (cartProvider.selectedDeliveryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a scheduled delivery date to authorize checkout.'),
          backgroundColor: themeProvider.errorColor,
        ),
      );
      return;
    }
    final success = await cartProvider.checkout();

    if (success && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: themeProvider.surface,
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: themeProvider.isDark ? themeProvider.primaryAccent : Colors.green, size: 30),
              const SizedBox(width: 12),
              Text(
                'PO Authorized', 
                style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Your purchase order has been successfully locked in and committed. Your ZEEE Trading tax-exempt PDF invoice has been compiled and emailed to your primary contact inbox.',
            style: TextStyle(color: themeProvider.textSecondary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                if (widget.onCheckoutSuccess != null) {
                  widget.onCheckoutSuccess!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryAccent,
                foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartSKUs = cartProvider.items.keys.toList();

    // Net Terms Credit Parameters
    final creditLimit = double.tryParse(authProvider.userProfile?['credit_limit']?.toString() ?? '0.0') ?? 0.0;
    final outstandingBalance = double.tryParse(authProvider.userProfile?['outstanding_balance']?.toString() ?? '0.0') ?? 0.0;
    final availableCredit = creditLimit - outstandingBalance;
    final isOverLimit = !authProvider.isGuest && cartProvider.total > availableCredit;
    final isCheckoutDisabled = isOverLimit;

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
                    
                    // Credit Utilization progress indicator
                    if (!authProvider.isGuest) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Credit Utilization', style: TextStyle(color: themeProvider.textSecondary, fontSize: 12)),
                          Text(
                            '\$${(outstandingBalance + cartProvider.total).toStringAsFixed(2)} / \$${creditLimit.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isOverLimit ? themeProvider.errorColor : themeProvider.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: creditLimit > 0 ? ((outstandingBalance + cartProvider.total) / creditLimit).clamp(0.0, 1.0) : 0.0,
                          backgroundColor: themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverLimit ? themeProvider.errorColor : themeProvider.primaryAccent,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Debt: \$${outstandingBalance.toStringAsFixed(2)}',
                            style: TextStyle(color: themeProvider.textSecondary, fontSize: 10),
                          ),
                          Text(
                            'Available: \$${availableCredit.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isOverLimit ? themeProvider.errorColor : (themeProvider.isDark ? themeProvider.primaryAccent : Colors.green),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],

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
                                // Natively check if the day of week matches delivery schedule (1=Monday, 7=Sunday)
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

                    if (isOverLimit) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeProvider.errorColor.withOpacity(0.1),
                          border: Border.all(color: themeProvider.errorColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Warning: Order total exceeds your available commercial credit limit of \$${availableCredit.toStringAsFixed(2)}. Please reduce your cart size to checkout.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: themeProvider.errorColor, fontSize: 12, height: 1.3, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (cartProvider.errorMessage != null) ...[
                      Text(
                        cartProvider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: themeProvider.errorColor, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Submit button
                    cartProvider.isLoading
                        ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                        : ElevatedButton(
                            onPressed: isCheckoutDisabled ? null : () => _processCheckout(context, cartProvider, themeProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCheckoutDisabled 
                                  ? (themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0))
                                  : themeProvider.primaryAccent,
                              foregroundColor: isCheckoutDisabled 
                                  ? themeProvider.textSecondary
                                  : (themeProvider.isDark ? Colors.black : Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'AUTHORIZE PURCHASE ORDER',
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
