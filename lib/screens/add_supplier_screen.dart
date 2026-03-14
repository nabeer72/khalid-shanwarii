import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_supplier_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

class AddSupplierScreen extends StatefulWidget {
  final Supplier? supplier;

  const AddSupplierScreen({super.key, this.supplier});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  late AddSupplierController _controller;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = AddSupplierController(initialSupplier: widget.supplier);
    _controller.addListener(_updateUI);
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updateUI);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    await _controller.saveSupplier(context);
  }

  Future<void> _handleDelete() async {
    final confirmed = await _showDeleteConfirmDialog();
    if (confirmed == true) {
      await _controller.deleteSupplier(context);
    }
  }

  Future<bool?> _showDeleteConfirmDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: BoxConstraints(maxWidth: isTablet ? 500 : 400),
          padding: EdgeInsets.all(isTablet ? 28 : 24),
          decoration: theme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: ThemeProvider.error,
                size: isTablet ? 56 : 48,
              ),
              SizedBox(height: isTablet ? 20 : 16),
              Text(
                'Delete Supplier?',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: isTablet ? 10 : 8),
              Text(
                'Are you sure? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: isTablet ? 14 : 13,
                ),
              ),
              SizedBox(height: isTablet ? 28 : 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      ),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: isTablet ? 14 : 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(
                        'DELETE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: isTablet ? 14 : 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isWideScreen = ThemeProvider.isWideScreen(context);
    final isLargeTablet = screenWidth > 900;

    final horizontalPadding = isLargeTablet ? 48.0 : (isTablet ? 32.0 : 24.0);
    final verticalPadding = isTablet ? 24.0 : 20.0;
    final sectionSpacing = isTablet ? 40.0 : 32.0;
    final fieldSpacing = isTablet ? 24.0 : 20.0;

    final titleFontSize = isTablet ? 20.0 : 16.0;
    final buttonFontSize = isTablet ? 14.0 : 13.0;
    final maxContentWidth = isLargeTablet ? 800.0 : double.infinity;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _controller.screenTitle,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            fontSize: titleFontSize,
          ),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          if (_controller.isEdit)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: ThemeProvider.error,
                size: isTablet ? 26 : 24,
              ),
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        children: [
                          _buildSectionHeader('Business Information', isTablet),
                          SizedBox(height: isTablet ? 16 : 12),
                          if (isWideScreen) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.nameCtrl,
                                    label: 'Supplier Name',
                                    icon: Icons.business_rounded,
                                    required: true,
                                    isTablet: isTablet,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.contactCtrl,
                                    label: 'Contact Person',
                                    icon: Icons.person_rounded,
                                    isTablet: isTablet,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: sectionSpacing),
                            _buildSectionHeader('Contact Details', isTablet),
                            SizedBox(height: isTablet ? 16 : 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.phoneCtrl,
                                    label: 'Phone Number',
                                    icon: Icons.phone_rounded,
                                    type: TextInputType.phone,
                                    isTablet: isTablet,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _controller.emailCtrl,
                                    label: 'Email Address',
                                    icon: Icons.email_rounded,
                                    type: TextInputType.emailAddress,
                                    isTablet: isTablet,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildTextField(
                              controller: _controller.nameCtrl,
                              label: 'Supplier Name',
                              icon: Icons.business_rounded,
                              required: true,
                              isTablet: isTablet,
                            ),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              controller: _controller.contactCtrl,
                              label: 'Contact Person',
                              icon: Icons.person_rounded,
                              isTablet: isTablet,
                            ),
                            SizedBox(height: sectionSpacing),
                            _buildSectionHeader('Contact Details', isTablet),
                            SizedBox(height: isTablet ? 16 : 12),
                            _buildTextField(
                              controller: _controller.phoneCtrl,
                              label: 'Phone Number',
                              icon: Icons.phone_rounded,
                              type: TextInputType.phone,
                              isTablet: isTablet,
                            ),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              controller: _controller.emailCtrl,
                              label: 'Email Address',
                              icon: Icons.email_rounded,
                              type: TextInputType.emailAddress,
                              isTablet: isTablet,
                            ),
                          ],
                          SizedBox(height: fieldSpacing),
                          _buildTextField(
                            controller: _controller.addressCtrl,
                            label: 'Address',
                            icon: Icons.location_on_rounded,
                            maxLines: 3,
                            isTablet: isTablet,
                          ),
                          SizedBox(height: sectionSpacing),
                          _buildSectionHeader('Account Balance', isTablet),
                          SizedBox(height: isTablet ? 16 : 12),
                          _buildTextField(
                            controller: _controller.balanceCtrl,
                            label: 'Running Balance (Owed)',
                            icon: Icons.account_balance_wallet_rounded,
                            type: TextInputType.number,
                            isTablet: isTablet,
                          ),
                          SizedBox(height: verticalPadding),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                padding: EdgeInsets.all(horizontalPadding),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.whiteAlpha(0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: buttonFontSize,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _controller.isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.highlight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                          ),
                        ),
                        child: Text(
                          _controller.saveButtonLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: buttonFontSize,
                          ),
                        ),
                      ),
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

  Widget _buildSectionHeader(String title, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: isTablet ? 12 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    required bool isTablet,
  }) {
    final labelFontSize = isTablet ? 11.0 : 10.0;
    final textFontSize = isTablet ? 16.0 : 14.0;
    final iconSize = isTablet ? 22.0 : 20.0;
    final borderRadius = isTablet ? 18.0 : 16.0;
    final verticalPadding = isTablet ? 18.0 : 16.0;
    final horizontalPadding = isTablet ? 18.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (required ? '$label *' : label).toUpperCase(),
          style: TextStyle(
            color: theme.textHint,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isTablet ? 10 : 8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: textFontSize,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: theme.highlight, size: iconSize),
            filled: true,
            fillColor: theme.whiteAlpha(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: theme.isDark ? Colors.transparent : Colors.black.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: theme.isDark ? theme.whiteAlpha(0.1) : Colors.black.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: theme.isDark ? theme.highlight.withOpacity(0.5) : Colors.black.withOpacity(0.6),
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
          ),
        ),
      ],
    );
  }
}
