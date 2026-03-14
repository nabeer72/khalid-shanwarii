import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/controllers/add_customer_controller.dart';
import 'package:mobile_app/models/branch.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  bool _isLoading = false;
  List<Branch> _branches = [];
  String? _selectedBranchId;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameCtrl.text = widget.customer!.name;
      _phoneCtrl.text = widget.customer!.phone ?? '';
      _emailCtrl.text = widget.customer!.email ?? '';
      _notesCtrl.text = widget.customer!.notes ?? '';
      _discountCtrl.text = widget.customer!.discount.toString();
      _selectedBranchId = widget.customer!.branchId?.toLowerCase();
    } else {
      _selectedBranchId = BusinessConfig.instance.branchId?.toLowerCase();
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final db = DatabaseHelper.instance;
      final data = await db.getBranches();
      if (mounted) {
        setState(() {
          _branches = data.map((b) => Branch.fromMap(b)).toList();
          // Ensure we have a selection if none exists
          if (_selectedBranchId == null && _branches.isNotEmpty) {
            _selectedBranchId = _branches.first.id.toLowerCase();
          }
        });
      }
    } catch (e) {
      print('Error loading branches: $e');
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await CustomerFormHelper.prepareAndSaveCustomer(
      existingCustomer: widget.customer,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text,
      notes: _notesCtrl.text,
      discountText: _discountCtrl.text,
      branchId: _selectedBranchId,
      context: context,           // only passed in case you want to show dialog later
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result == null) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: ThemeProvider.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: ThemeProvider.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.customer == null ? 'New Customer' : 'Edit Profile',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: theme.background,
          border: Border(top: BorderSide(color: theme.whiteAlpha(0.1))),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.highlight,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _saveCustomer,
          child: Text(
            widget.customer == null ? 'CREATE CUSTOMER' : 'UPDATE CUSTOMER',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
          ),
        ),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.highlight))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Basic Identity'),
                        const SizedBox(height: 12),
                        _buildCard([
                          LayoutBuilder(builder: (context, constraints) {
                            final isWide = ThemeProvider.isWideScreen(context);
                            return Column(
                              children: [
                                if (isWide) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _nameCtrl,
                                          label: 'FULL NAME',
                                          icon: Icons.person_rounded,
                                          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _phoneCtrl,
                                          label: 'MOBILE NUMBER',
                                          icon: Icons.phone_android_rounded,
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _emailCtrl,
                                    label: 'EMAIL ADDRESS',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ] else ...[
                                  _buildTextField(
                                    controller: _nameCtrl,
                                    label: 'FULL NAME',
                                    icon: Icons.person_rounded,
                                    validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _phoneCtrl,
                                    label: 'MOBILE NUMBER',
                                    icon: Icons.phone_android_rounded,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _emailCtrl,
                                    label: 'EMAIL ADDRESS',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ],
                              ],
                            );
                          }),
                        ]),
                        if (BusinessConfig.instance.staffId == null && _branches.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('Branch Assignment'),
                          const SizedBox(height: 12),
                          _buildCard([
                             DropdownButtonFormField<String>(
                              value: _selectedBranchId,
                              dropdownColor: theme.surface,
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                              decoration: theme.glassInputDecoration('ASSIGN TO BRANCH', Icons.store_rounded),
                              items: _branches
                                  .map((b) => DropdownMenuItem<String>(value: b.id.toLowerCase(), child: Text(b.branchTitle)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedBranchId = val),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 32),
                        _buildSectionHeader('Account Preferences'),
                        const SizedBox(height: 12),
                        _buildCard([
                          LayoutBuilder(builder: (context, constraints) {
                            final isWide = ThemeProvider.isWideScreen(context);
                            return Column(
                              children: [
                                if (isWide) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _discountCtrl,
                                          label: 'DEFAULT DISCOUNT (%)',
                                          icon: Icons.percent_rounded,
                                          keyboardType: TextInputType.number,
                                          hint: '0.0',
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Spacer(), // Notes is multiline, keeps it standalone or beside?
                                      // Actually let's keep notes full width or side by side if wide enough
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _notesCtrl,
                                    label: 'ADDRESS / NOTES',
                                    icon: Icons.location_on_rounded,
                                    maxLines: 3,
                                  ),
                                ] else ...[
                                  _buildTextField(
                                    controller: _discountCtrl,
                                    label: 'DEFAULT DISCOUNT (%)',
                                    icon: Icons.percent_rounded,
                                    keyboardType: TextInputType.number,
                                    hint: '0.0',
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _notesCtrl,
                                    label: 'ADDRESS / NOTES',
                                    icon: Icons.location_on_rounded,
                                    maxLines: 3,
                                  ),
                                ],
                              ],
                            );
                          }),
                        ]),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Everything below this line is 100% unchanged from your original
  // ──────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: theme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.textHint.withOpacity(0.5)),
            prefixIcon: Icon(icon, color: theme.highlight, size: 20),
            filled: true,
            fillColor: theme.whiteAlpha(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.isDark ? Colors.transparent : Colors.black.withOpacity(0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.isDark ? theme.whiteAlpha(0.1) : Colors.black.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.isDark ? theme.highlight.withOpacity(0.5) : Colors.black.withOpacity(0.6))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}