import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'location_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Account Admin Fields
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Company Details
  final _companyNameController = TextEditingController();
  final _corporateEmailController = TextEditingController();

  // Primary Location details
  final _locationNameController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _salesTaxIdController = TextEditingController();

  int _currentStep = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _corporateEmailController.dispose();
    _locationNameController.dispose();
    _deliveryAddressController.dispose();
    _zipCodeController.dispose();
    _salesTaxIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      email: _emailController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      companyName: _companyNameController.text.trim(),
      corporateEmail: _corporateEmailController.text.trim(),
      locationName: _locationNameController.text.trim().isNotEmpty 
          ? _locationNameController.text.trim() 
          : "Primary Facility",
      deliveryAddress: _deliveryAddressController.text.trim(),
      zipCode: _zipCodeController.text.trim(),
      salesTaxId: _salesTaxIdController.text.trim(),
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
      appBar: AppBar(
        title: const Text('Register ZEEE Trading Firm'),
      ),
      body: Form(
        key: _formKey,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: themeProvider.primaryAccent,
              onPrimary: themeProvider.isDark ? Colors.black : Colors.white,
              surface: themeProvider.surface,
              onSurface: themeProvider.textPrimary,
            ),
          ),
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              }
            },
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _submit();
              }
            },
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              final isLastStep = _currentStep == 2;
              return Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: authProvider.isLoading
                          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                          : ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeProvider.primaryAccent,
                                foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Text(
                                isLastStep ? 'INITIALIZE PORTAL' : 'CONTINUE',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: themeProvider.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text('BACK', style: TextStyle(color: themeProvider.textSecondary)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // STEP 1: Corporate Entity Details
              Step(
                title: Text('Corporate Entity Details', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.editing,
                content: Column(
                  children: [
                    _buildTextField(
                      controller: _companyNameController,
                      label: 'Legal Company Name',
                      icon: Icons.business_outlined,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter legal company name' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _corporateEmailController,
                      label: 'Corporate Contact Email',
                      icon: Icons.alternate_email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || !val.contains('@')) ? 'Enter valid email' : null,
                    ),
                  ],
                ),
              ),
              // STEP 2: Shipping Facility Location
              Step(
                title: Text('Primary Shipping Facility', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.editing,
                content: Column(
                  children: [
                    _buildTextField(
                      controller: _locationNameController,
                      label: 'Facility Display Name (e.g. Main Kitchen)',
                      icon: Icons.place_outlined,
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _deliveryAddressController,
                      label: 'Exact Shipping Address',
                      icon: Icons.local_shipping_outlined,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter shipping address' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _zipCodeController,
                      label: 'Regional Zip Code (for pricing grids)',
                      icon: Icons.map_outlined,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter zip code' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _salesTaxIdController,
                      label: 'Sales Tax Certificate ID (exempt audit)',
                      icon: Icons.assignment_turned_in_outlined,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Wholesale Tax ID required' : null,
                    ),
                  ],
                ),
              ),
              // STEP 3: Admin user Credentials
              Step(
                title: Text('Admin Agent Credentials', style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold)),
                isActive: _currentStep >= 2,
                state: _currentStep == 2 ? StepState.editing : StepState.indexed,
                content: Column(
                  children: [
                    if (authProvider.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
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
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Administrator Username',
                      icon: Icons.person_outline,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter admin username' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Agent Account Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || !val.contains('@')) ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.badge_outlined,
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.badge_outlined,
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Primary Contact Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Cryptographic Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      themeProvider: themeProvider,
                      validator: (val) => (val == null || val.length < 6) ? 'Password must be 6+ chars' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeProvider themeProvider,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: themeProvider.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: themeProvider.textSecondary),
        prefixIcon: Icon(icon, color: themeProvider.textSecondary),
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
      validator: validator,
    );
  }
}
