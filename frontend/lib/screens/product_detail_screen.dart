import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/catalog_provider.dart';
import 'login_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String sku;
  const ProductDetailsScreen({super.key, required this.sku});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductDetails();
    });
  }

  Future<void> _loadProductDetails() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);

    final locationId = cartProvider.selectedLocation?['id'];
    final zipCode = authProvider.isGuest ? authProvider.guestZipCode : null;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final data = await catalogProvider.fetchProductDetail(
      widget.sku,
      locationId: locationId,
      zipCode: zipCode,
    );

    if (mounted) {
      setState(() {
        if (data != null) {
          _product = data;
        } else {
          _error = 'Failed to load product details. Please check your network connection.';
        }
        _isLoading = false;
      });
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.canvas,
        appBar: AppBar(
          backgroundColor: themeProvider.surface,
          title: const Text('Loading details...'),
        ),
        body: Center(
          child: CircularProgressIndicator(color: themeProvider.primaryAccent),
        ),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        backgroundColor: themeProvider.canvas,
        appBar: AppBar(
          backgroundColor: themeProvider.surface,
          title: const Text('Error'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.error_outline, size: 64, color: themeProvider.errorColor),
              const SizedBox(height: 16),
              Text(
                _error ?? 'An unexpected lookup error occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(color: themeProvider.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProductDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryAccent,
                  foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                ),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    final prod = _product!;
    final basePrice = double.tryParse(prod['base_price']?.toString() ?? '0.0') ?? 0.0;
    final calcPrice = double.tryParse(prod['calculated_price']?.toString() ?? '0.0') ?? 0.0;
    final isDiscounted = calcPrice < basePrice;
    
    double discountPercent = 0;
    if (basePrice > 0 && isDiscounted) {
      discountPercent = ((basePrice - calcPrice) / basePrice) * 100;
    }

    final qtyInCart = cartProvider.items[prod['sku']] ?? 0;
    final stockLimit = prod['stock_quantity'] ?? 0;
    final uom = prod['unit_of_measure'] ?? 'item';
    final desc = prod['description']?.toString().trim();
    final descriptionText = (desc != null && desc.isNotEmpty)
        ? desc
        : "No detailed description has been registered for this item yet. For chemical compositions, bulk weights, safety data sheets, or logistic certifications, contact ZEEE support.";

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: Text(
          prod['name'] ?? 'Product Details',
          style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeProvider.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: themeProvider.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Large Hero Visual Section
                  Hero(
                    tag: widget.sku,
                    child: Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: themeProvider.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
                        image: prod['image_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(prod['image_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: prod['image_url'] == null
                          ? Icon(
                              Icons.image_outlined,
                              color: themeProvider.textSecondary.withOpacity(0.3),
                              size: 80,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Classifications Badges
                  Row(
                    children: [
                      if (prod['category'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeProvider.primaryAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: themeProvider.primaryAccent.withOpacity(0.4), width: 0.5),
                          ),
                          child: Text(
                            (prod['category']['name'] as String).toUpperCase(),
                            style: TextStyle(
                              color: themeProvider.primaryAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeProvider.textSecondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: themeProvider.textSecondary.withOpacity(0.3), width: 0.5),
                        ),
                        child: Text(
                          'SKU: ${prod['sku']}',
                          style: TextStyle(
                            color: themeProvider.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. Name & UOM Title block
                  Text(
                    prod['name'] ?? '',
                    style: TextStyle(
                      color: themeProvider.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unit size: $uom',
                    style: TextStyle(
                      color: themeProvider.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Contract Pricing Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeProvider.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: themeProvider.textSecondary.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.isGuest ? 'GUEST RETAIL PRICE' : 'YOUR NEGOTIATED B2B RATE',
                          style: TextStyle(
                            color: themeProvider.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$${calcPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: themeProvider.primaryAccent,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ unit',
                              style: TextStyle(
                                color: themeProvider.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (isDiscounted) ...[
                              const Spacer(),
                              Text(
                                '\$${basePrice.toStringAsFixed(2)} MSRP',
                                style: TextStyle(
                                  color: themeProvider.textSecondary,
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Save ${discountPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Stock Status Indicator
                  Row(
                    children: [
                      Icon(
                        stockLimit > 0 ? Icons.check_circle_outline : Icons.error_outline,
                        color: stockLimit > 0 ? (themeProvider.isDark ? themeProvider.primaryAccent : Colors.green) : themeProvider.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stockLimit > 0 
                            ? 'In Stock ($stockLimit units available)' 
                            : 'Out of Stock (Zero warehouse allocation)',
                        style: TextStyle(
                          color: stockLimit > 0 ? themeProvider.textPrimary : themeProvider.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 6. Detailed product description
                  Text(
                    'PRODUCT SPECIFICATION & INFO',
                    style: TextStyle(
                      color: themeProvider.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    descriptionText,
                    style: TextStyle(
                      color: themeProvider.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 7. Sticky Bottom Cart Controller Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: themeProvider.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        color: themeProvider.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${(calcPrice * (qtyInCart > 0 ? qtyInCart : 1)).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: themeProvider.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                stockLimit == 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: themeProvider.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: themeProvider.errorColor),
                        ),
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(color: themeProvider.errorColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      )
                    : qtyInCart > 0 && !authProvider.isGuest
                        ? Container(
                            decoration: BoxDecoration(
                              color: themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove, color: themeProvider.primaryAccent),
                                  onPressed: () {
                                    if (_checkGuestAction()) return;
                                    cartProvider.removeFromCart(prod['sku']);
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    '$qtyInCart',
                                    style: TextStyle(
                                      color: themeProvider.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add, color: themeProvider.primaryAccent),
                                  onPressed: () {
                                    if (_checkGuestAction()) return;
                                    cartProvider.addToCart(prod['sku'], calcPrice, stockLimit);
                                  },
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              if (_checkGuestAction()) return;
                              cartProvider.addToCart(prod['sku'], calcPrice, stockLimit);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.primaryAccent,
                              foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'ADD TO CART',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
