import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'register_screen.dart';
import 'password_reset_screen.dart';
import 'location_picker_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            // Top-right Theme Toggle Button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: themeProvider.textPrimary,
                ),
                onPressed: () => themeProvider.toggleTheme(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Corporate Logo Asset with Fallback Icon
                      Image.asset(
                        'assets/logo-dark.webp',
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.storefront_outlined,
                          size: 80,
                          color: themeProvider.primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ZEEE Trading',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Commercial Wholesale Client Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Error message banner
                      if (authProvider.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: themeProvider.errorColor.withOpacity(0.1),
                            border: Border.all(color: themeProvider.errorColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            authProvider.errorMessage!,
                            style: TextStyle(
                              color: themeProvider.isDark ? const Color(0xFFFCA5A5) : themeProvider.errorColor, 
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Username Input Field
                      TextFormField(
                        controller: _usernameController,
                        style: TextStyle(color: themeProvider.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Username or Corporate Agent Key',
                          labelStyle: TextStyle(color: themeProvider.textSecondary),
                          prefixIcon: Icon(Icons.person_outline, color: themeProvider.textSecondary),
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
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? 'Please enter your username' : null,
                      ),
                      const SizedBox(height: 20),

                      // Password Input Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: themeProvider.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Cryptographic Password',
                          labelStyle: TextStyle(color: themeProvider.textSecondary),
                          prefixIcon: Icon(Icons.lock_outline, color: themeProvider.textSecondary),
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
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Please enter your password' : null,
                      ),
                      const SizedBox(height: 12),

                      // Forgot password trigger
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PasswordResetScreen()),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      authProvider.isLoading
                          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeProvider.primaryAccent,
                                foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'AUTHORIZE LOGIN',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                      const SizedBox(height: 24),

                      // Registration navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New commercial buyer? ',
                            style: TextStyle(color: themeProvider.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: Text(
                              'Register Firm',
                              style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
