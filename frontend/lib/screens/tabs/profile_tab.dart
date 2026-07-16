import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/theme_provider.dart';
import '../team_management_screen.dart';
import '../login_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _locNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();

  // Tracks expanded state for order cards
  final Map<int, bool> _expandedOrders = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _locNameCtrl.dispose();
    _addressCtrl.dispose();
    _zipCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);

    if (!authProvider.isGuest) {
      cartProvider.fetchLocations();
      catalogProvider.fetchOrderHistory();
    }
  }

  void _showAddLocationDialog(BuildContext context, CartProvider cartProvider, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: themeProvider.surface,
              title: Row(
                children: [
                  Icon(Icons.add_business_outlined, color: themeProvider.primaryAccent),
                  const SizedBox(width: 12),
                  Text(
                    'Add Shipping Branch',
                    style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cartProvider.errorMessage != null) ...[
                      Text(
                        cartProvider.errorMessage!,
                        style: TextStyle(color: themeProvider.errorColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller: _locNameCtrl,
                      style: TextStyle(color: themeProvider.textPrimary),
                      decoration: _dialogInputDecoration('Location Name (e.g. North Hub)', themeProvider),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter location name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      style: TextStyle(color: themeProvider.textPrimary),
                      decoration: _dialogInputDecoration('Delivery Address', themeProvider),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _zipCtrl,
                      style: TextStyle(color: themeProvider.textPrimary),
                      decoration: _dialogInputDecoration('Zip Code', themeProvider),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter zip code' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxIdCtrl,
                      style: TextStyle(color: themeProvider.textPrimary),
                      decoration: _dialogInputDecoration('Sales Tax Exempt ID', themeProvider),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter wholesale Tax ID' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearDialogControllers();
                    Navigator.pop(context);
                  },
                  child: Text('CANCEL', style: TextStyle(color: themeProvider.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: cartProvider.isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          final success = await cartProvider.addLocation(
                            locationName: _locNameCtrl.text.trim(),
                            deliveryAddress: _addressCtrl.text.trim(),
                            zipCode: _zipCtrl.text.trim(),
                            salesTaxId: _taxIdCtrl.text.trim(),
                          );
                          if (success && context.mounted) {
                            _clearDialogControllers();
                            cartProvider.fetchLocations(); // Refresh list
                            Navigator.pop(context);
                          } else {
                            setDialogState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primaryAccent,
                    foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                  ),
                  child: cartProvider.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('REGISTER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearDialogControllers() {
    _locNameCtrl.clear();
    _addressCtrl.clear();
    _zipCtrl.clear();
    _taxIdCtrl.clear();
  }

  InputDecoration _dialogInputDecoration(String label, ThemeProvider themeProvider) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: themeProvider.textSecondary, fontSize: 13),
      filled: true,
      fillColor: themeProvider.isDark ? const Color(0xFF0F0F11) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
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
              style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.textPrimary, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: themeProvider.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTimelineStepper(String currentStatus, ThemeProvider themeProvider) {
    final List<String> statuses = ['PENDING', 'APPROVED', 'SHIPPED', 'DELIVERED'];
    final List<String> labels = ['Placed', 'Approved', 'Shipped', 'Delivered'];
    
    int activeIndex = statuses.indexOf(currentStatus.toUpperCase());
    if (activeIndex == -1) activeIndex = 0; // fallback

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          Row(
            children: List.generate(4, (index) {
              final isDone = index <= activeIndex;
              final isLast = index == 3;
              final color = isDone ? themeProvider.primaryAccent : (themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0));

              return Expanded(
                flex: isLast ? 0 : 1,
                child: Row(
                  children: [
                    // Dot
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDone ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: isDone
                          ? Icon(Icons.check, size: 10, color: themeProvider.isDark ? Colors.black : Colors.white)
                          : null,
                    ),
                    // Connector line
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < activeIndex
                              ? themeProvider.primaryAccent
                              : (themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final isDone = index <= activeIndex;
              return Text(
                labels[index],
                style: TextStyle(
                  color: isDone ? themeProvider.textPrimary : themeProvider.textSecondary,
                  fontSize: 10,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Guest Landing view
    if (authProvider.isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_outlined, size: 72, color: themeProvider.textSecondary.withOpacity(0.3)),
              const SizedBox(height: 20),
              Text(
                'Corporate Hub Settings',
                style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in or self-register your company portal to set up multi-branch shipping, authorize purchase orders, track route delivery timelines, and download invoice PDFs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: themeProvider.textSecondary, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryAccent,
                  foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('LOG IN / REGISTER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final profile = authProvider.userProfile;
    final role = profile?['role'] ?? 'BUYER';
    final isAdmin = role == 'ADMIN';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. User profile banner
          Card(
            color: themeProvider.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: themeProvider.primaryAccent.withOpacity(0.1),
                    child: Icon(Icons.business, color: themeProvider.primaryAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?['company_name'] ?? 'Company Name',
                          style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile?['username'] ?? 'username'} (${role == 'ADMIN' ? 'Admin' : role == 'BUYER' ? 'Buyer' : 'Observer'})',
                          style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                        ),
                        if (profile?['phone_number'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Phone: ${profile?['phone_number']}',
                            style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                          ),
                        ]
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Shipping Facility Switcher Card
          Text(
            'ACTIVE DELIVERY FACILITY',
            style: TextStyle(color: themeProvider.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Card(
            color: themeProvider.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: themeProvider.primaryAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        dropdownColor: themeProvider.surface,
                        value: cartProvider.selectedLocation != null && cartProvider.locations.isNotEmpty
                            ? cartProvider.locations.firstWhere(
                                (loc) => loc['id'] == cartProvider.selectedLocation!['id'],
                                orElse: () => cartProvider.locations.first,
                              )
                            : null,
                        hint: Text('Select Shipping Branch', style: TextStyle(color: themeProvider.textSecondary)),
                        items: cartProvider.locations.map((loc) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: loc as Map<String, dynamic>,
                            child: Text(
                              loc['location_name'] ?? 'Facility',
                              style: TextStyle(color: themeProvider.textPrimary, fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (newLoc) {
                          if (newLoc != null) {
                            cartProvider.selectLocation(newLoc);
                            // Refresh catalog dynamically for pricing overrides
                            final catalog = Provider.of<CatalogProvider>(context, listen: false);
                            catalog.fetchCatalog(locationId: newLoc['id'], refresh: true);
                            catalog.fetchOrderGuide(locationId: newLoc['id']);
                          }
                        },
                      ),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: Icon(Icons.add_business_outlined, color: themeProvider.primaryAccent, size: 22),
                      onPressed: () => _showAddLocationDialog(context, cartProvider, themeProvider),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Admin Roster tile row
          if (isAdmin) ...[
            Text(
              'ADMINISTRATIVE TOOLS',
              style: TextStyle(color: themeProvider.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Card(
              color: themeProvider.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: Icon(Icons.people_outline, color: themeProvider.primaryAccent),
                title: Text('Manage Corporate Team Roster', style: TextStyle(color: themeProvider.textPrimary, fontSize: 14)),
                trailing: Icon(Icons.chevron_right, color: themeProvider.textSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 4. Expandable Order History timeline
          Text(
            'INVOICE & PO HISTORY TIMELINE',
            style: TextStyle(color: themeProvider.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          
          if (catalogProvider.orderHistory.isEmpty)
            Card(
              color: themeProvider.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.history, color: themeProvider.textSecondary.withOpacity(0.3), size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No Previous Orders Found',
                      style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: catalogProvider.orderHistory.map((order) {
                final int orderId = order['order_id'] ?? 0;
                final isExpanded = _expandedOrders[orderId] ?? false;
                final status = order['status'] ?? 'PENDING';
                final dateStr = order['created_at']?.split('T')?.first ?? 'Unknown';
                final totalVal = double.tryParse(order['total_amount']?.toString() ?? '0.0') ?? 0.0;
                final itemsCount = (order['items'] as List?)?.length ?? 0;

                return Card(
                  color: themeProvider.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('PO #$orderId | $dateStr', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Items: $itemsCount | Total: \$${totalVal.toStringAsFixed(2)}', style: TextStyle(color: themeProvider.textSecondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.download_for_offline_outlined, color: themeProvider.primaryAccent),
                              onPressed: () => _simulateInvoiceDownload(context, orderId, themeProvider),
                            ),
                            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: themeProvider.textSecondary),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _expandedOrders[orderId] = !isExpanded;
                          });
                        },
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Shipping Target: ${order['delivery_address_snapshot'] ?? ''}',
                                style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Exempt Tax ID: ${order['sales_tax_id_snapshot'] ?? 'EXEMPT'}',
                                style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Delivery Schedule Tracking:',
                                style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              _buildTimelineStepper(status, themeProvider),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9),
              foregroundColor: themeProvider.errorColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: themeProvider.errorColor.withOpacity(0.3), width: 0.5),
              elevation: 0,
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text(
              'SIGN OUT SESSION',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
