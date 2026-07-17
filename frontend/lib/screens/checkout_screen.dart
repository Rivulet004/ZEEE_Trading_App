import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class CheckoutScreen extends StatefulWidget {
  final VoidCallback? onCheckoutSuccess;
  const CheckoutScreen({super.key, this.onCheckoutSuccess});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();

  final _achBankController = TextEditingController();
  final _achRoutingController = TextEditingController();
  final _achAccountController = TextEditingController();

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    
    _achBankController.dispose();
    _achRoutingController.dispose();
    _achAccountController.dispose();
    super.dispose();
  }

  void _processOrderPlacement(BuildContext context, CartProvider cartProvider, ThemeProvider themeProvider) async {
    if (cartProvider.selectedPaymentMethod != 'NET_30') {
      if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
        return;
      }
    }

    final success = await cartProvider.checkout();

    if (success && context.mounted) {
      _cardNameController.clear();
      _cardNumberController.clear();
      _cardExpiryController.clear();
      _cardCvvController.clear();
      
      _achBankController.clear();
      _achRoutingController.clear();
      _achAccountController.clear();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: themeProvider.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: themeProvider.isDark ? themeProvider.primaryAccent : Colors.green, size: 30),
              const SizedBox(width: 12),
              Text(
                'PO Authorized', 
                style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Your purchase order has been successfully locked in and committed. Your ZEEE Trading tax-exempt PDF invoice has been compiled and emailed to your primary contact inbox.',
            style: TextStyle(color: themeProvider.textSecondary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Pop back to CartTab
                if (widget.onCheckoutSuccess != null) {
                  widget.onCheckoutSuccess!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryAccent,
                foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  Widget _buildPaymentMethodCard({
    required BuildContext context,
    required String method,
    required String label,
    required IconData icon,
    required CartProvider cartProvider,
    required ThemeProvider themeProvider,
  }) {
    final isSelected = cartProvider.selectedPaymentMethod == method;
    return InkWell(
      onTap: () {
        cartProvider.setSelectedPaymentMethod(method);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? (themeProvider.isDark ? themeProvider.primaryAccent.withOpacity(0.08) : Colors.blue.withOpacity(0.08))
              : Colors.transparent,
          border: Border.all(
            color: isSelected 
                ? (themeProvider.isDark ? themeProvider.primaryAccent : Colors.blue) 
                : themeProvider.textSecondary.withOpacity(0.2),
            width: isSelected ? 1.8 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected 
                  ? (themeProvider.isDark ? themeProvider.primaryAccent : Colors.blue) 
                  : themeProvider.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected 
                    ? (themeProvider.isDark ? themeProvider.primaryAccent : Colors.blue) 
                    : themeProvider.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, ThemeProvider themeProvider) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: themeProvider.textSecondary.withOpacity(0.5), fontSize: 13),
      filled: true,
      fillColor: themeProvider.isDark ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: themeProvider.textSecondary.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: themeProvider.textSecondary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: themeProvider.primaryAccent),
      ),
      errorStyle: const TextStyle(fontSize: 10, height: 0.8),
    );
  }

  Widget _buildCreditCardForm(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CREDIT / DEBIT CARD DETAILS', style: TextStyle(color: themeProvider.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardNameController,
              decoration: _buildInputDecoration('Cardholder Name', themeProvider),
              style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _cardNumberController,
              decoration: _buildInputDecoration('Card Number (16-digits)', themeProvider),
              keyboardType: TextInputType.number,
              style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
              validator: (v) => v == null || v.trim().length != 16 ? 'Enter 16 digit number' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardExpiryController,
                    decoration: _buildInputDecoration('MM/YY', themeProvider),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
                    validator: (v) => v == null || !v.contains('/') ? 'MM/YY required' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _cardCvvController,
                    decoration: _buildInputDecoration('CVV', themeProvider),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
                    validator: (v) => v == null || v.trim().length < 3 ? '3 digits' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchForm(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACH TRANSFER ROUTING MATRIX', style: TextStyle(color: themeProvider.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _achBankController,
              decoration: _buildInputDecoration('Bank Name', themeProvider),
              style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _achRoutingController,
                    decoration: _buildInputDecoration('Routing Number', themeProvider),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
                    validator: (v) => v == null || v.trim().length != 9 ? 'Enter 9 digits' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _achAccountController,
                    decoration: _buildInputDecoration('Account Number', themeProvider),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: themeProvider.textPrimary, fontSize: 13),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Credit Utilization calculations
    final creditLimit = double.tryParse(authProvider.userProfile?['credit_limit']?.toString() ?? '0.0') ?? 0.0;
    final outstandingBalance = double.tryParse(authProvider.userProfile?['outstanding_balance']?.toString() ?? '0.0') ?? 0.0;
    final availableCredit = creditLimit - outstandingBalance;
    final isOverLimit = !authProvider.isGuest && cartProvider.total > availableCredit;

    // Fast inline validations
    bool isPaymentFormValid = true;
    if (cartProvider.selectedPaymentMethod == 'CREDIT_CARD') {
      isPaymentFormValid = _cardNameController.text.trim().isNotEmpty &&
          _cardNumberController.text.trim().length == 16 &&
          _cardExpiryController.text.contains('/') &&
          _cardCvvController.text.trim().length >= 3;
    } else if (cartProvider.selectedPaymentMethod == 'ACH') {
      isPaymentFormValid = _achBankController.text.trim().isNotEmpty &&
          _achRoutingController.text.trim().length == 9 &&
          _achAccountController.text.trim().isNotEmpty;
    }

    final isCheckoutDisabled = (cartProvider.selectedPaymentMethod == 'NET_30' && isOverLimit) ||
                               (cartProvider.selectedPaymentMethod != 'NET_30' && !isPaymentFormValid);

    final dateStr = cartProvider.selectedDeliveryDate != null
        ? "${cartProvider.selectedDeliveryDate!.year}-${cartProvider.selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${cartProvider.selectedDeliveryDate!.day.toString().padLeft(2, '0')}"
        : "Not Chosen";

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: Text(
          'Checkout', 
          style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: themeProvider.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: themeProvider.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DELIVERY DETAILS',
                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: themeProvider.primaryAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartProvider.selectedLocation?['location_name'] ?? 'Facility',
                              style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              cartProvider.selectedLocation?['delivery_address'] ?? '',
                              style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, color: themeProvider.primaryAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduled Route Date: ',
                        style: TextStyle(color: themeProvider.textSecondary, fontSize: 13),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Options Selector Title
            Text(
              'PAYMENT OPTION',
              style: TextStyle(color: themeProvider.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            
            // Payment selector buttons
            Row(
              children: [
                if (!authProvider.isGuest)
                  Expanded(
                    child: _buildPaymentMethodCard(
                      context: context,
                      method: 'NET_30',
                      label: 'Net 30 Terms',
                      icon: Icons.business,
                      cartProvider: cartProvider,
                      themeProvider: themeProvider,
                    ),
                  ),
                if (!authProvider.isGuest) const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentMethodCard(
                    context: context,
                    method: 'CREDIT_CARD',
                    label: 'Credit Card',
                    icon: Icons.credit_card,
                    cartProvider: cartProvider,
                    themeProvider: themeProvider,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentMethodCard(
                    context: context,
                    method: 'ACH',
                    label: 'ACH E-Check',
                    icon: Icons.account_balance,
                    cartProvider: cartProvider,
                    themeProvider: themeProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Conditional billing section
            if (!authProvider.isGuest && cartProvider.selectedPaymentMethod == 'NET_30') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Credit Line Utilization', style: TextStyle(color: themeProvider.textSecondary, fontSize: 12)),
                        Text(
                          '\$${(outstandingBalance + cartProvider.total).toStringAsFixed(2)} / \$${creditLimit.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isOverLimit ? themeProvider.errorColor : themeProvider.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: creditLimit > 0 ? ((outstandingBalance + cartProvider.total) / creditLimit).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverLimit ? themeProvider.errorColor : themeProvider.primaryAccent,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Debt: \$${outstandingBalance.toStringAsFixed(2)}',
                          style: TextStyle(color: themeProvider.textSecondary, fontSize: 11),
                        ),
                        Text(
                          'Available Credit: \$${availableCredit.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isOverLimit ? themeProvider.errorColor : (themeProvider.isDark ? themeProvider.primaryAccent : Colors.green),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (cartProvider.selectedPaymentMethod == 'CREDIT_CARD') ...[
              _buildCreditCardForm(themeProvider),
              const SizedBox(height: 20),
            ] else if (cartProvider.selectedPaymentMethod == 'ACH') ...[
              _buildAchForm(themeProvider),
              const SizedBox(height: 20),
            ],

            // Checkout warnings
            if (cartProvider.selectedPaymentMethod == 'NET_30' && isOverLimit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeProvider.errorColor.withOpacity(0.1),
                  border: Border.all(color: themeProvider.errorColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Warning: Order total exceeds your available commercial credit limit of \$${availableCredit.toStringAsFixed(2)}. Please reduce your cart size or switch to Card/ACH payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: themeProvider.errorColor, fontSize: 13, height: 1.3, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (cartProvider.errorMessage != null) ...[
              Text(
                cartProvider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: themeProvider.errorColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],

            // Pricing totals card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.textSecondary.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Grand Total',
                    style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '\$${cartProvider.total.toStringAsFixed(2)}',
                    style: TextStyle(color: themeProvider.primaryAccent, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            cartProvider.isLoading
                ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
                : ElevatedButton(
                    onPressed: isCheckoutDisabled 
                        ? null 
                        : () => _processOrderPlacement(context, cartProvider, themeProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckoutDisabled 
                          ? (themeProvider.isDark ? const Color(0xFF2E2E33) : const Color(0xFFE2E8F0))
                          : themeProvider.primaryAccent,
                      foregroundColor: isCheckoutDisabled 
                          ? themeProvider.textSecondary
                          : (themeProvider.isDark ? Colors.black : Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: isCheckoutDisabled ? 0 : 2,
                    ),
                    child: Text(
                      cartProvider.selectedPaymentMethod == 'NET_30'
                          ? 'AUTHORIZE PURCHASE ORDER'
                          : 'PLACE & PAY ORDER',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
