import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import 'main_navigation_container.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).fetchLocations();
    });
  }

  void _selectLocation(Map<String, dynamic> location) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.selectLocation(location);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationContainer()),
      );
    }
  }

  void _showAddLocationDialog() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final zipController = TextEditingController();
    final taxIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: themeProvider.surface,
          title: Text(
            'Register New Shipping Hub',
            style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartProvider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: themeProvider.errorColor.withOpacity(0.1),
                        border: Border.all(color: themeProvider.errorColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cartProvider.errorMessage!,
                        style: TextStyle(color: themeProvider.errorColor, fontSize: 12),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: themeProvider.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Hub / Branch Name',
                      labelStyle: TextStyle(color: themeProvider.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.textSecondary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.primaryAccent)),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    style: TextStyle(color: themeProvider.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Delivery Street Address',
                      labelStyle: TextStyle(color: themeProvider.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.textSecondary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.primaryAccent)),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter address' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: zipController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    style: TextStyle(color: themeProvider.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'ZIP Code',
                      labelStyle: TextStyle(color: themeProvider.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.textSecondary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.primaryAccent)),
                    ),
                    validator: (val) => (val == null || val.length != 5 || int.tryParse(val) == null)
                        ? 'Please enter valid 5-digit ZIP'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: taxIdController,
                    style: TextStyle(color: themeProvider.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Sales Tax ID',
                      labelStyle: TextStyle(color: themeProvider.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.textSecondary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.primaryAccent)),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter tax ID' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: themeProvider.textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await cartProvider.addLocation(
                    locationName: nameController.text.trim(),
                    deliveryAddress: addressController.text.trim(),
                    zipCode: zipController.text.trim(),
                    salesTaxId: taxIdController.text.trim(),
                  );
                  if (success) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } else {
                    setState(() {}); // refresh dialog error message
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryAccent,
                foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
              ),
              child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: const Text('Select Shipping Hub'),
      ),
      body: cartProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
          : cartProvider.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: themeProvider.errorColor),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading facility targets: ${cartProvider.errorMessage}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: themeProvider.textPrimary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => cartProvider.fetchLocations(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.primaryAccent,
                            foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                          ),
                          child: const Text('RETRY CONNECTION', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                )
              : cartProvider.locations.isEmpty
                  ? Center(
                      child: Text(
                        'No physical branch facilities found for your company.',
                        style: TextStyle(color: themeProvider.textPrimary),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: themeProvider.surface,
                          child: Text(
                            'Please select the shipping hub for this order session. Your regional wholesale contracts and tax exemptions will be loaded automatically.',
                            style: TextStyle(color: themeProvider.textSecondary, fontSize: 13, height: 1.4),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: cartProvider.locations.length,
                            itemBuilder: (context, index) {
                              final loc = cartProvider.locations[index];
                              final isSelected = cartProvider.selectedLocation?['id'] == loc['id'];

                              return Card(
                                color: themeProvider.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected ? themeProvider.primaryAccent : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _selectLocation(loc),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.place, color: themeProvider.primaryAccent, size: 36),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                loc['location_name'] ?? 'Facility',
                                                style: TextStyle(
                                                  color: themeProvider.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                loc['delivery_address'] ?? '',
                                                style: TextStyle(color: themeProvider.textPrimary.withOpacity(0.8), fontSize: 13),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'ZIP: ${loc['zip_code'] ?? ''}',
                                                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Tax ID: ${loc['sales_tax_id'] ?? ''}',
                                                    style: TextStyle(color: themeProvider.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right, color: themeProvider.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLocationDialog,
        backgroundColor: themeProvider.primaryAccent,
        foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('ADD NEW HUB', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
