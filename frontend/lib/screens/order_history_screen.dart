import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/theme_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogProvider>(context, listen: false).fetchOrderHistory();
      
      // Keep state synced with the warehouse dispatcher updates in real-time
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          Provider.of<CatalogProvider>(context, listen: false).fetchOrderHistory(showLoading: false);
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Color _getStatusColor(String status, ThemeProvider theme) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFF59E0B); // Amber 500
      case 'APPROVED':
        return theme.isDark ? const Color(0xFF00FFC2) : const Color(0xFF1E3A8A);
      case 'SHIPPED':
        return const Color(0xFF8B5CF6); // Purple 500
      case 'DELIVERED':
        return const Color(0xFF10B981); // Emerald 500
      default:
        return theme.textSecondary;
    }
  }

  void _simulateInvoiceDownload(BuildContext context, int orderId, ThemeProvider themeProvider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download_done, color: themeProvider.isDark ? themeProvider.primaryAccent : Colors.green),
            const SizedBox(width: 12),
            Text(
              'Invoice PO #$orderId PDF archived to device downloads.', 
              style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.textPrimary),
            ),
          ],
        ),
        backgroundColor: themeProvider.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: const Text('Invoice & PO History'),
      ),
      body: catalogProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
          : RefreshIndicator(
              onRefresh: () => catalogProvider.fetchOrderHistory(),
              color: themeProvider.primaryAccent,
              backgroundColor: themeProvider.surface,
              child: catalogProvider.orderHistory.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 64, color: themeProvider.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('No purchase orders recorded yet.', style: TextStyle(color: themeProvider.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: catalogProvider.orderHistory.length,
                      itemBuilder: (context, index) {
                        final order = catalogProvider.orderHistory[index];
                        final orderId = order['order_id'] ?? 0;
                        final total = double.tryParse(order['total_amount'] ?? '0.0') ?? 0.0;
                        final status = order['status'] ?? 'PENDING';
                        final dateStr = order['created_at'] ?? '';
                        final deliveryTarget = order['delivery_target'] ?? 'Facility';
                        
                        DateTime? dateParsed;
                        try {
                          dateParsed = DateTime.parse(dateStr).toLocal();
                        } catch (_) {}
                        
                        final dateFormatted = dateParsed != null
                            ? DateFormat('MMMM dd, yyyy - hh:mm a').format(dateParsed)
                            : dateStr;

                        final List<dynamic> items = order['items'] ?? [];

                        return Card(
                          color: themeProvider.surface,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              colorScheme: ColorScheme.dark(
                                primary: themeProvider.textPrimary,
                              ),
                            ),
                            child: ExpansionTile(
                              iconColor: themeProvider.textPrimary,
                              collapsedIconColor: themeProvider.textPrimary,
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'PO #$orderId',
                                        style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status, themeProvider).withOpacity(0.1),
                                          border: Border.all(color: _getStatusColor(status, themeProvider), width: 0.5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(color: _getStatusColor(status, themeProvider), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dateFormatted,
                                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Hub: $deliveryTarget',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: themeProvider.textPrimary.withOpacity(0.8), fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '\$${total.toStringAsFixed(2)}',
                                      style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: themeProvider.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                
                                // Delivery Address snapshot
                                ListTile(
                                  dense: true,
                                  title: Text('DELIVERY ADDRESS SNAPSHOT', style: TextStyle(color: themeProvider.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    order['delivery_address_snapshot'] ?? '',
                                    style: TextStyle(color: themeProvider.textPrimary.withOpacity(0.9), fontSize: 13, height: 1.3),
                                  ),
                                ),
                                
                                // Items list header
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                                  child: Text('ORDER ITEMS', style: TextStyle(color: themeProvider.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),

                                // Items loop
                                ...items.map<Widget>((item) {
                                  final name = item['product_name'] ?? 'Product';
                                  final qty = item['quantity'] ?? 0;
                                  final sku = item['product_sku'] ?? '';
                                  final price = double.tryParse(item['price_paid'] ?? '0.0') ?? 0.0;
                                  
                                  return ListTile(
                                    dense: true,
                                    title: Text(name, style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold)),
                                    subtitle: Text('SKU: $sku | Qty: $qty', style: TextStyle(color: themeProvider.textSecondary)),
                                    trailing: Text('\$${(price * qty).toStringAsFixed(2)}', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.w600)),
                                  );
                                }),

                                // Download PDF button line
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _simulateInvoiceDownload(context, orderId, themeProvider),
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text('DOWNLOAD PDF INVOICE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: themeProvider.primaryAccent,
                                      side: BorderSide(color: themeProvider.primaryAccent),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
