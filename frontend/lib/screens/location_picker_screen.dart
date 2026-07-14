import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'catalog_screen.dart';

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
        MaterialPageRoute(builder: (context) => const CatalogScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Select Shipping Hub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: cartProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : cartProvider.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading facility targets: ${cartProvider.errorMessage}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => cartProvider.fetchLocations(),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          child: const Text('RETRY CONNECTION', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                )
              : cartProvider.locations.isEmpty
                  ? const Center(
                      child: Text(
                        'No physical branch facilities found for your company.',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: const Color(0xFF1E293B),
                          child: const Text(
                            'Please select the shipping hub for this order session. Your regional wholesale contracts and tax exemptions will be loaded automatically.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
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
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
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
                                        const Icon(Icons.place, color: Color(0xFF38BDF8), size: 36),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                loc['location_name'] ?? 'Facility',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                loc['delivery_address'] ?? '',
                                                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'ZIP: ${loc['zip_code'] ?? ''}',
                                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Tax ID: ${loc['sales_tax_id'] ?? ''}',
                                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
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
    );
  }
}
