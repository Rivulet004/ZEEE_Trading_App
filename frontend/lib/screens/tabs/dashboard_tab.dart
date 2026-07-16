import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/theme_provider.dart';

class DashboardTab extends StatefulWidget {
  final Function(int)? onTabSwitch;
  const DashboardTab({super.key, this.onTabSwitch});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Timer? _timer;
  String _countdownText = "Loading route schedule...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    // Update the live countdown every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _updateCountdown();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);

    catalogProvider.fetchAlerts();

    if (cartProvider.selectedLocation != null) {
      cartProvider.fetchDeliverySchedule(cartProvider.selectedLocation!['zip_code']).then((_) {
        _updateCountdown();
      });
    }

    if (!authProvider.isGuest) {
      catalogProvider.fetchOrderHistory();
    }
  }

  void _updateCountdown() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final schedule = cartProvider.deliverySchedule;
    if (schedule == null) {
      setState(() => _countdownText = "No schedule found for active ZIP.");
      return;
    }

    final nextAvailStr = schedule['next_available_date'];
    final cutoffStr = schedule['cutoff_time'] ?? '16:00:00';

    if (nextAvailStr == null) {
      setState(() => _countdownText = "Active schedule loaded.");
      return;
    }

    try {
      final now = DateTime.now();
      
      // Parse cutoff time e.g., "16:00:00" -> Hour: 16, Minute: 0
      final parts = cutoffStr.split(':');
      final cutoffHour = int.parse(parts[0]);
      final cutoffMin = int.parse(parts[1]);

      // Target cutoff is 4 PM (or dynamic time) on the next available delivery date
      final nextAvailDate = DateTime.parse(nextAvailStr);
      final cutoffTarget = DateTime(
        nextAvailDate.year,
        nextAvailDate.month,
        nextAvailDate.day,
        cutoffHour,
        cutoffMin,
      );

      final difference = cutoffTarget.difference(now);
      if (difference.isNegative) {
        setState(() => _countdownText = "Warehouse Cut-off Passed");
        return;
      }

      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;

      String display = "Order within ";
      if (days > 0) display += "${days}d ";
      if (hours > 0 || days > 0) display += "${hours}h ";
      display += "${minutes}m for next delivery";

      setState(() => _countdownText = display);
    } catch (e) {
      setState(() => _countdownText = "Scheduling system offline");
    }
  }

  void _duplicateOrder(Map<String, dynamic> order) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);

    cartProvider.clearCart();
    final items = order['items'] as List?;
    if (items != null) {
      for (var item in items) {
        final sku = item['product_sku'];
        final qty = item['quantity'] ?? 1;

        if (sku == null) continue;

        // Resolve product baseline details from local catalog
        final prod = catalogProvider.products.firstWhere(
          (p) => p['sku'] == sku,
          orElse: () => null,
        );

        final price = double.tryParse(prod?['calculated_price'] ?? item['price_paid']?.toString() ?? '0.0') ?? 0.0;
        final stock = prod?['stock_quantity'] ?? 999;

        for (int i = 0; i < qty; i++) {
          cartProvider.addToCart(sku, price, stock);
        }
      }
    }

    // Switch tab to Cart (Index 3)
    widget.onTabSwitch?.call(3);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Get last 3 successful orders
    final lastOrders = catalogProvider.orderHistory.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Live Countdown Card
          Card(
            color: themeProvider.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, color: themeProvider.primaryAccent, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'LOGISTICS COUNTDOWN',
                        style: TextStyle(
                          color: themeProvider.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _countdownText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themeProvider.primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order before the daily 4:00 PM warehouse cutoff to lock in your next scheduled delivery route.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Active Delay Alerts Banner
          if (catalogProvider.alerts.isNotEmpty) ...[
            Text(
              'ACTIVE SYSTEM ALERTS',
              style: TextStyle(color: themeProvider.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            ...catalogProvider.alerts.map((alert) {
              final severity = alert['severity'] ?? 'WARNING';
              final message = alert['message'] ?? '';
              
              Color alertColor;
              IconData alertIcon;
              if (severity == 'CRITICAL') {
                alertColor = themeProvider.errorColor;
                alertIcon = Icons.error_outline;
              } else if (severity == 'INFO') {
                alertColor = themeProvider.primaryAccent;
                alertIcon = Icons.info_outline;
              } else {
                alertColor = themeProvider.isDark ? const Color(0xFFF59E0B) : Colors.orange; // Warning/Amber
                alertIcon = Icons.warning_amber_outlined;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.08),
                  border: Border.all(color: alertColor.withOpacity(0.4), width: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(alertIcon, color: alertColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(color: themeProvider.textPrimary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // 3. Quick Reorder Panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUICK REORDER FEED',
                style: TextStyle(color: themeProvider.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
              ),
              if (!authProvider.isGuest && lastOrders.isNotEmpty)
                Text(
                  'Last 3 Purchase Orders',
                  style: TextStyle(color: themeProvider.primaryAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (authProvider.isGuest)
            _buildEmptyStateCard(
              'Sign In to Reorder',
              'Quick reorders allow one-tap cart duplications of your last three completed purchase orders.',
              Icons.lock_outline,
              themeProvider,
            )
          else if (catalogProvider.orderHistory.isEmpty)
            _buildEmptyStateCard(
              'No Past Invoices Found',
              'Once you place your first corporate PO checkout, details will populate here for rapid duplication.',
              Icons.history,
              themeProvider,
            )
          else
            Column(
              children: lastOrders.map((order) {
                final id = order['id'];
                final dateStr = order['created_at']?.split('T')?.first ?? 'Unknown';
                final totalVal = double.tryParse(order['total']?.toString() ?? '0.0') ?? 0.0;
                final itemsCount = (order['items'] as List?)?.length ?? 0;

                return Card(
                  color: themeProvider.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PO ID: #$id',
                                style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Placed: $dateStr | Items: $itemsCount',
                                style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${totalVal.toStringAsFixed(2)}',
                                style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _duplicateOrder(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0),
                            foregroundColor: themeProvider.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('DUPLICATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, String description, IconData icon, ThemeProvider themeProvider) {
    return Card(
      color: themeProvider.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, color: themeProvider.textSecondary.withOpacity(0.3), size: 40),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: themeProvider.textSecondary, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
