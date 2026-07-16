import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'order_guide_screen.dart';
import 'catalog_screen.dart';
import 'cart_screen.dart';
import 'tabs/profile_tab.dart';
import 'login_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 2; // Default starting point is Tab 2: Catalog

  void _changeTab(int index) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Guest Interceptor: Guests are only allowed on Catalog Tab (Index 2)
    if (authProvider.isGuest && index != 2) {
      _showAuthPrompt();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
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

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Velocity Dashboard';
      case 1:
        return 'Tuesday Order Guide';
      case 2:
        return 'Wholesale Catalog';
      case 3:
        return 'Review Order Cart';
      case 4:
        return 'Profile Settings';
      default:
        return 'ZEEE Trading';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final cartItemsCount = cartProvider.items.values.fold<int>(0, (sum, qty) => sum + qty);

    final List<Widget> tabs = [
      DashboardTab(onTabSwitch: _changeTab),
      const OrderGuideTab(),
      const CatalogTab(),
      CartTab(onCheckoutSuccess: () => _changeTab(0)), // Return to Dashboard on successful checkout
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Global Theme Switcher
          IconButton(
            icon: Icon(
              themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          
          // Shopping Cart Header Badge (hidden on Cart tab itself)
          if (_currentIndex != 3)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => _changeTab(3),
                ),
                if (cartItemsCount > 0 && !authProvider.isGuest)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: themeProvider.isDark ? themeProvider.errorColor : themeProvider.secondaryAccent,
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
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changeTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: themeProvider.surface,
        selectedItemColor: themeProvider.primaryAccent,
        unselectedItemColor: themeProvider.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), // Ghost Slate
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Order Guide',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            activeIcon: Icon(Icons.business),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
