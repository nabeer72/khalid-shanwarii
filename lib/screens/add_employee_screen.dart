import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_employee_controller.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class AddEmployeeScreen extends StatefulWidget {
  final Employee? employee;

  const AddEmployeeScreen({super.key, this.employee});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  late AddEmployeeController _controller;
  final _formKey = GlobalKey<FormState>();
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = AddEmployeeController(initialEmployee: widget.employee);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _controller.save();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.isEditMode ? 'Employee updated successfully!' : 'Employee added successfully!'),
          backgroundColor: ThemeProvider.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
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
        foregroundColor: theme.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _controller.screenTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface.withOpacity(0.8),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _controller.isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.highlight,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _controller.buttonLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.bgGradient,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Account Information'),
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
                                    controller: _controller.name,
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                    validator: _controller.validateName,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.email,
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _controller.validateEmail,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.phone,
                                    label: 'Phone Number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.password,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    keyboardType: TextInputType.visiblePassword,
                                    validator: _controller.validatePassword,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildTextField(
                              controller: _controller.name,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: _controller.validateName,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _controller.email,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: _controller.validateEmail,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _controller.phone,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _controller.password,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              keyboardType: TextInputType.visiblePassword,
                              validator: _controller.validatePassword,
                            ),
                          ],
                        ],
                      );
                    }),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Role & Access'),
                  _buildCard([
                    DropdownButtonFormField<int?>(
                      value: _controller.roles.any((r) => r['id'] == _controller.selectedRoleId)
                          ? _controller.selectedRoleId
                          : null,
                      dropdownColor: theme.surface,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: theme.glassInputDecoration('Access Role', Icons.badge_outlined),
                      items: _controller.roles.map((r) => DropdownMenuItem<int?>(
                        value: r['id'] is int ? r['id'] : int.tryParse(r['id']?.toString() ?? ''),
                        child: Text(r['name']?.toString() ?? 'Unknown'),
                      )).toList(),
                      onChanged: _controller.setRole,
                    ),
                    if (_controller.branches.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int?>(
                        value: (_controller.selectedBranchId == null || _controller.branches.any((b) => b.id == _controller.selectedBranchId))
                            ? _controller.selectedBranchId
                            : null,
                        dropdownColor: theme.surface,
                        style: TextStyle(color: theme.textPrimary),
                        decoration: theme.glassInputDecoration('Assign to Branch', Icons.storefront_outlined),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Branches (Global)'),
                          ),
                          ..._controller.branches.map((b) => DropdownMenuItem<int?>(
                                value: b.id,
                                child: Text(b.branchTitle),
                              )),
                        ],
                        onChanged: _controller.setBranch,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.background.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.textHint.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _controller.statusIcon,
                                color: _controller.statusColor,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _controller.statusLabel,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _controller.status == 1,
                            activeColor: ThemeProvider.success,
                            onChanged: (val) => _controller.toggleStatus(val),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  // Permissions are now managed via Roles separately
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary.withOpacity(0.8),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: theme.glassDecoration,
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
      validator: validator,
      maxLength: maxLength,
      decoration: theme.glassInputDecoration(label, icon).copyWith(counterText: ""),
    );
  }
}
