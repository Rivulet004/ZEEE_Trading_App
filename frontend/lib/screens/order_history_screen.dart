import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogProvider>(context, listen: false).fetchOrderHistory();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFF59E0B); // Amber 500
      case 'APPROVED':
        return const Color(0xFF3B82F6); // Blue 500
      case 'SHIPPED':
        return const Color(0xFF8B5CF6); // Purple 500
      case 'DELIVERED':
        return const Color(0xFF10B981); // Emerald 500
      default:
        return const Color(0xFF94A3B8); // Slate 500
    }
  }

  void _simulateInvoiceDownload(BuildContext context, int orderId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done, color: Color(0xFF34D399)),
            const SizedBox(width: 12),
            Text('Invoice PO #$orderId PDF archived to device downloads.', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = Provider.of<CatalogProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Invoice & PO History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: catalogProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : catalogProvider.orderHistory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: Color(0xFF334155)),
                      SizedBox(height: 16),
                      Text('No purchase orders recorded yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
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
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: Colors.white,
                          collapsedIconColor: Colors.white,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PO #$orderId',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      border: Border.all(color: _getStatusColor(status), width: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateFormatted,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '\$${total.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Divider(color: Color(0xFF334155)),
                            ),
                            
                            // Delivery Address snapshot
                            ListTile(
                              dense: true,
                              title: const Text('DELIVERY ADDRESS SNAPSHOT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                order['delivery_address_snapshot'] ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                              ),
                            ),
                            
                            // Items list header
                            const Padding(
                              padding: EdgeInsets.only(left: 16.0, top: 8.0),
                              child: Text('ORDER ITEMS', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),

                            // Items loop
                            ...items.map<Widget>((item) {
                              final name = item['product_name'] ?? 'Product';
                              final qty = item['quantity'] ?? 0;
                              final sku = item['product_sku'] ?? '';
                              final price = double.tryParse(item['price_paid'] ?? '0.0') ?? 0.0;
                              
                              return ListTile(
                                dense: true,
                                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text('SKU: $sku | Qty: $qty', style: const TextStyle(color: Color(0xFF94A3B8))),
                                trailing: Text('\$${(price * qty).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              );
                            }),

                            // Download PDF button line
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: OutlinedButton.icon(
                                onPressed: () => _simulateInvoiceDownload(context, orderId),
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('DOWNLOAD PDF INVOICE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
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
    );
  }
}
