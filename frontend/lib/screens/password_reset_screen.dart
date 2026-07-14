import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPassword(_emailController.text.trim());

    if (success) {
      setState(() => _isSubmitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: const Text('Reset Access Key'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isSubmitted
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 80, color: themeProvider.primaryAccent),
                    const SizedBox(height: 24),
                    Text(
                      'Link Dispatched!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeProvider.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'If this email matches a registered corporate client, check your inbox (or backend terminal output) for the cryptographic link to select a new password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: themeProvider.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.primaryAccent,
                        foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('RETURN TO LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_reset_outlined, size: 80, color: themeProvider.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Forgot Password?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeProvider.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Input your registered agent email below to receive a secure recovery signature.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: themeProvider.textSecondary),
                      ),
                      const SizedBox(height: 40),

                      if (authProvider.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: themeProvider.errorColor.withOpacity(0.1),
                            border: Border.all(color: themeProvider.errorColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            authProvider.errorMessage!,
                            style: TextStyle(color: themeProvider.isDark ? const Color(0xFFFCA5A5) : themeProvider.errorColor, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: themeProvider.textPrimary),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Registered Agent Email',
                          labelStyle: TextStyle(color: themeProvider.textSecondary),
                          prefixIcon: Icon(Icons.email_outlined, color: themeProvider.textSecondary),
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
                        validator: (value) => (value == null || !value.contains('@'))
                            ? 'Please enter a valid email address'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      authProvider.isLoading
                          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeProvider.primaryAccent,
                                foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('DISPATCH LINK', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
