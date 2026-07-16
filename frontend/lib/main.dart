import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_container.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiClient = ApiClient();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(apiClient),
        ),
        ChangeNotifierProvider<CatalogProvider>(
          create: (context) => CatalogProvider(apiClient),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (context) => CartProvider(apiClient),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'ZEEE Trading Portal',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkAuthStatus();
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_checking) {
      return Scaffold(
        backgroundColor: themeProvider.canvas,
        body: Center(
          child: CircularProgressIndicator(color: themeProvider.primaryAccent),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuthenticated || authProvider.isGuest) {
      return const MainNavigationContainer();
    } else {
      return const LoginScreen();
    }
  }
}
