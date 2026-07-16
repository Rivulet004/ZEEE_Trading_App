import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).fetchTeam();
    });
  }

  void _showAddMemberDialog(BuildContext context, AuthProvider authProvider, ThemeProvider themeProvider) {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'BUYER';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: themeProvider.surface,
              title: Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: themeProvider.primaryAccent),
                  const SizedBox(width: 12),
                  Text(
                    'Onboard Team Member',
                    style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (authProvider.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeProvider.errorColor.withOpacity(0.1),
                            border: Border.all(color: themeProvider.errorColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            authProvider.errorMessage!,
                            style: TextStyle(color: themeProvider.errorColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: usernameCtrl,
                        style: TextStyle(color: themeProvider.textPrimary),
                        decoration: _dialogInputDecoration('Username *', Icons.person_outline, themeProvider),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        style: TextStyle(color: themeProvider.textPrimary),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dialogInputDecoration('Email Address *', Icons.email_outlined, themeProvider),
                        validator: (val) => (val == null || !val.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        style: TextStyle(color: themeProvider.textPrimary),
                        obscureText: true,
                        decoration: _dialogInputDecoration('Cryptographic Password *', Icons.lock_outline, themeProvider),
                        validator: (val) => (val == null || val.length < 6) ? 'Password must be at least 6 chars' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: firstNameCtrl,
                        style: TextStyle(color: themeProvider.textPrimary),
                        decoration: _dialogInputDecoration('First Name', Icons.badge_outlined, themeProvider),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameCtrl,
                        style: TextStyle(color: themeProvider.textPrimary),
                        decoration: _dialogInputDecoration('Last Name', Icons.badge_outlined, themeProvider),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        style: TextStyle(color: themeProvider.textPrimary),
                        keyboardType: TextInputType.phone,
                        decoration: _dialogInputDecoration('Contact Phone', Icons.phone_outlined, themeProvider),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: themeProvider.surface,
                        initialValue: selectedRole,
                        decoration: _dialogInputDecoration('System Role', Icons.shield_outlined, themeProvider),
                        style: TextStyle(color: themeProvider.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'ADMIN', child: Text('Corporate Administrator')),
                          DropdownMenuItem(value: 'BUYER', child: Text('Standard Purchasing Agent')),
                          DropdownMenuItem(value: 'VIEWER', child: Text('Read-Only Observer')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Clear error when canceling
                    authProvider.fetchTeam();
                    Navigator.pop(context);
                  },
                  child: Text('CANCEL', style: TextStyle(color: themeProvider.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final success = await authProvider.addTeamMember(
                            username: usernameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text,
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            phoneNumber: phoneCtrl.text.trim(),
                            role: selectedRole,
                          );
                          if (success && context.mounted) {
                            Navigator.pop(context);
                          } else {
                            // Trigger setDialogState to refresh error messaging overlay
                            setDialogState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primaryAccent,
                    foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('ONBOARD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon, ThemeProvider themeProvider) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: themeProvider.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: themeProvider.textSecondary, size: 18),
      filled: true,
      fillColor: themeProvider.isDark ? const Color(0xFF0F0F11) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  void _confirmDeleteMember(BuildContext context, AuthProvider authProvider, ThemeProvider themeProvider, Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeProvider.surface,
          title: Text(
            'Confirm Roster Removal',
            style: TextStyle(color: themeProvider.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to permanently delete the login profile and terminate system access for team member "${member['username']}"?',
            style: TextStyle(color: themeProvider.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: themeProvider.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await authProvider.deleteTeamMember(member['id']);
                if (success && context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.errorColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUserId = authProvider.userProfile?['id'];

    return Scaffold(
      backgroundColor: themeProvider.canvas,
      appBar: AppBar(
        title: const Text('Corporate Team Roster'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemberDialog(context, authProvider, themeProvider),
        backgroundColor: themeProvider.primaryAccent,
        foregroundColor: themeProvider.isDark ? Colors.black : Colors.white,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: authProvider.isLoading && authProvider.teamMembers.isEmpty
          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryAccent))
          : authProvider.teamMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: themeProvider.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No team members found under your account.', style: TextStyle(color: themeProvider.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: authProvider.teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = authProvider.teamMembers[index] as Map<String, dynamic>;
                    final isSelf = member['id'] == currentUserId;
                    final role = member['role'] ?? 'BUYER';

                    // Role configurations
                    Color badgeColor;
                    String roleLabel;
                    if (role == 'ADMIN') {
                      badgeColor = themeProvider.primaryAccent;
                      roleLabel = 'Admin';
                    } else if (role == 'BUYER') {
                      badgeColor = themeProvider.isDark ? const Color(0xFF64748B) : const Color(0xFF3B82F6);
                      roleLabel = 'Purchasing Agent';
                    } else {
                      badgeColor = themeProvider.isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
                      roleLabel = 'Observer';
                    }

                    final String displayName = (member['first_name'] != null && member['first_name'].toString().isNotEmpty)
                        ? "${member['first_name']} ${member['last_name'] ?? ''}".trim()
                        : member['username'] ?? 'User';

                    return Card(
                      color: themeProvider.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          color: themeProvider.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (isSelf) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: themeProvider.primaryAccent.withOpacity(0.1),
                                            border: Border.all(color: themeProvider.primaryAccent, width: 0.5),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'YOU',
                                            style: TextStyle(
                                              color: themeProvider.primaryAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Username: @${member['username']}',
                                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Email: ${member['email']}',
                                    style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                                  ),
                                  if (member['phone_number'] != null && member['phone_number'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Phone: ${member['phone_number']}',
                                      style: TextStyle(color: themeProvider.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.1),
                                      border: Border.all(color: badgeColor, width: 0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      roleLabel,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isSelf)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: themeProvider.errorColor),
                                onPressed: () => _confirmDeleteMember(context, authProvider, themeProvider, member),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
