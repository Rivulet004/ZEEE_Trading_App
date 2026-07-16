import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
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
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationId = cartProvider.selectedLocation?['id'];
    final zipCode = authProvider.isGuest ? authProvider.guestZipCode : null;

    final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);
    catalogProvider.fetchCategories();
    catalogProvider.fetchCatalog(
      locationId: locationId,
      zipCode: zipCode,
      refresh: true,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationId = cartProvider.selectedLocation?['id'];
      final zipCode = authProvider.isGuest ? authProvider.guestZipCode : null;

      Provider.of<CatalogProvider>(context, listen: false).loadNextPage(
        locationId: locationId,
        zipCode: zipCode,
      );
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

  bool _checkGuestAction() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isGuest) {
      _showAuthPrompt();
      return true; // Action blocked
    }
    return false; // Action allowed
  }

  void _showAuthPrompt() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.surface,
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: themeProvider.primaryAccent),
            const SizedBox(width: 12),
            Text(
              'Authentication Required',
              style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Please sign in or register to place orders, access order guides, switch location hubs, or view your corporate profile records.',
          style: TextStyle(color: themeProvider.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: themeProvider.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.primaryAccent,
              foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
            ),
            child: const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = Provider.of<CatalogProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selectedLoc = cartProvider.selectedLocation;

    final List<Map<String, String?>> categories = [
      {'name': 'All items', 'slug': null},
      ...catalogProvider.categories.map((cat) => {
        'name': cat['name'] as String?,
        'slug': cat['slug'] as String?,
      })
    ];

    return Column(
        children: [
          // 1. Search Bar Input
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: themeProvider.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search SKU or name...',
                hintStyle: TextStyle(color: themeProvider.textSecondary),
                prefixIcon: Icon(Icons.search, color: themeProvider.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: themeProvider.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          final locId = authProvider.isGuest ? null : selectedLoc?['id'];
                          catalogProvider.updateSearchQuery('', locId);
                        },
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeProvider.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeProvider.primaryAccent, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: themeProvider.surface,
              ),
              onChanged: (val) {
                final locId = authProvider.isGuest ? null : selectedLoc?['id'];
                catalogProvider.updateSearchQuery(val, locId);
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
                      final locId = authProvider.isGuest ? null : selectedLoc?['id'];
                      catalogProvider.updateCategoryFilter(cat['slug'], locId);
                    },
                    selectedColor: themeProvider.primaryAccent,
                    backgroundColor: themeProvider.surface,
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? (themeProvider.isDark ? Colors.black : Colors.white) 
                          : themeProvider.textSecondary,
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
                ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                : catalogProvider.errorMessage != null
                    ? Center(child: Text('Error: ${catalogProvider.errorMessage}', style: TextStyle(color: themeProvider.errorColor)))
                    : catalogProvider.products.isEmpty
                        ? Center(child: Text('No wholesale products match your query.', style: TextStyle(color: themeProvider.textSecondary)))
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
                                color: themeProvider.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Image Placeholder / Image
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                          image: prod['image_url'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(prod['image_url']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: prod['image_url'] == null
                                            ? Icon(Icons.image_outlined, color: themeProvider.textSecondary.withOpacity(0.3), size: 40)
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
                                            style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'SKU: ${prod['sku']}',
                                            style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                                          ),
                                          const SizedBox(height: 6),
                                          
                                          // Price visual structures
                                          Row(
                                            children: [
                                              Text(
                                                '\$${calcPrice.toStringAsFixed(2)}',
                                                style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(width: 6),
                                              if (isDiscounted) ...[
                                                Text(
                                                  '\$${basePrice.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: themeProvider.textSecondary,
                                                    decoration: TextDecoration.lineThrough,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.bolt, color: themeProvider.isDark ? const Color(0xFF00FFC2) : const Color(0xFFF97316), size: 14),
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Unit: ${prod['unit_of_measure']}',
                                            style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                                          ),
                                          const SizedBox(height: 8),

                                          // Cart Controllers / Incrementors
                                          stockLimit == 0
                                              ? Center(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                    child: Text(
                                                      'OUT OF STOCK',
                                                      style: TextStyle(color: themeProvider.errorColor, fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                  ),
                                                )
                                              : qtyInCart > 0 && !authProvider.isGuest
                                                  ? Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(Icons.remove_circle_outline, color: themeProvider.primaryAccent, size: 28),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () {
                                                            if (_checkGuestAction()) return;
                                                            cartProvider.removeFromCart(prod['sku']);
                                                          },
                                                        ),
                                                        Text('$qtyInCart', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                                                        IconButton(
                                                          icon: Icon(Icons.add_circle_outline, color: themeProvider.primaryAccent, size: 28),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () {
                                                            if (_checkGuestAction()) return;
                                                            cartProvider.addToCart(prod['sku'], calcPrice, stockLimit);
                                                          },
                                                        ),
                                                      ],
                                                    )
                                                  : SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () {
                                                          if (_checkGuestAction()) return;
                                                          cartProvider.addToCart(prod['sku'], calcPrice, stockLimit);
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0),
                                                          foregroundColor: themeProvider.textPrimary,
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                          elevation: 0,
                                                        ),
                                                        child: const Text('Add to Cart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
      );
  }
}
