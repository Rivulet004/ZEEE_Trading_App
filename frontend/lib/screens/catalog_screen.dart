import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'location_picker_screen.dart';
import 'login_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCatalog();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadCatalog() {
    final locationId = Provider.of<CartProvider>(context, listen: false).selectedLocation?['id'];
    Provider.of<CatalogProvider>(context, listen: false).fetchCatalog(
      locationId: locationId,
      refresh: true,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final locationId = Provider.of<CartProvider>(context, listen: false).selectedLocation?['id'];
      Provider.of<CatalogProvider>(context, listen: false).loadNextPage(locationId: locationId);
    }
  }

  void _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final selectedLoc = cartProvider.selectedLocation;
    final cartItemsCount = cartProvider.items.values.fold<int>(0, (sum, qty) => sum + qty);

    // Common B2B wholesale categories
    final List<Map<String, String?>> categories = [
      {'name': 'All items', 'slug': null},
      {'name': 'Bakery', 'slug': 'bakery'},
      {'name': 'Pantry', 'slug': 'pantry'},
      {'name': 'Dairy', 'slug': 'dairy'},
      {'name': 'Produce', 'slug': 'produce'},
      {'name': 'Packaging', 'slug': 'packaging'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wholesale Catalog',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (selectedLoc != null)
              Text(
                'Shipping to: ${selectedLoc['location_name']}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
              ),
          ],
        ),
        actions: [
          // Cart notification badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
              if (cartItemsCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$cartItemsCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
            ],
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.business, color: Color(0xFF38BDF8), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    Provider.of<AuthProvider>(context).userProfile?['company_name'] ?? 'B2B Wholesale Portal',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    Provider.of<AuthProvider>(context).userProfile?['username'] ?? '',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storefront, color: Colors.white),
              title: const Text('Product Catalog', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined, color: Colors.white),
              title: const Text('Change Location Hub', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: Colors.white),
              title: const Text('Invoice & PO History', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: Color(0xFF334155)),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Color(0xFFFCA5A5)),
              title: const Text('Sign Out Session', style: TextStyle(color: Color(0xFFFCA5A5))),
              onTap: _logout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar Input
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search SKU or name...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          catalogProvider.updateSearchQuery('', selectedLoc?['id']);
                        },
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: const Color(0xFF1E293B),
              ),
              onChanged: (val) {
                catalogProvider.updateSearchQuery(val, selectedLoc?['id']);
              },
            ),
          ),

          // 2. Horizontal Category chips list
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = catalogProvider.selectedCategorySlug == cat['slug'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat['name']!),
                    selected: isSelected,
                    onSelected: (_) {
                      catalogProvider.updateCategoryFilter(cat['slug'], selectedLoc?['id']);
                    },
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 3. Main Catalog Grid
          Expanded(
            child: catalogProvider.isLoading && catalogProvider.products.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : catalogProvider.errorMessage != null
                    ? Center(child: Text('Error: ${catalogProvider.errorMessage}', style: const TextStyle(color: Colors.redAccent)))
                    : catalogProvider.products.isEmpty
                        ? const Center(child: Text('No wholesale products match your query.', style: TextStyle(color: Color(0xFF94A3B8))))
                        : GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: catalogProvider.products.length,
                            itemBuilder: (context, index) {
                              final prod = catalogProvider.products[index];
                              final basePrice = double.tryParse(prod['base_price']) ?? 0.0;
                              final calcPrice = double.tryParse(prod['calculated_price']) ?? 0.0;
                              final isDiscounted = calcPrice < basePrice;
                              
                              final qtyInCart = cartProvider.items[prod['sku']] ?? 0;
                              final stockLimit = prod['stock_quantity'] ?? 0;

                              return Card(
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Image Placeholder / Image
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF334155),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                          image: prod['image_url'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(prod['image_url']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: prod['image_url'] == null
                                            ? const Icon(Icons.image_outlined, color: Colors.white24, size: 40)
                                            : null,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prod['name'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'SKU: ${prod['sku']}',
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                          ),
                                          const SizedBox(height: 6),
                                          
                                          // Price visual structures
                                          Row(
                                            children: [
                                              Text(
                                                '\$${calcPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(width: 6),
                                              if (isDiscounted) ...[
                                                Text(
                                                  '\$${basePrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    decoration: TextDecoration.lineThrough,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.bolt, color: Color(0xFFEAB308), size: 14), // contract rate tag
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Unit: ${prod['unit_of_measure']}',
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                          ),
                                          const SizedBox(height: 8),

                                          // Cart Controllers / Incrementors
                                          stockLimit == 0
                                              ? const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                                    child: Text(
                                                      'OUT OF STOCK',
                                                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                  ),
                                                )
                                              : qtyInCart > 0
                                                  ? Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF38BDF8), size: 28),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () => cartProvider.removeFromCart(prod['sku']),
                                                        ),
                                                        Text('$qtyInCart', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                                        IconButton(
                                                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8), size: 28),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () => cartProvider.addToCart(prod['sku'], calcPrice, stockLimit),
                                                        ),
                                                      ],
                                                    )
                                                  : SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () => cartProvider.addToCart(prod['sku'], calcPrice, stockLimit),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF334155),
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                        ),
                                                        child: const Text('Add to Cart', style: TextStyle(color: Colors.white, fontSize: 12)),
                                                      ),
                                                    )
                                        ],
                                      ),
                                    )
                                  ],
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
