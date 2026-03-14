import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/controllers/add_expense_controller.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  late AddExpenseController _controller;
  final theme = ThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _controller = AddExpenseController(initialExpense: widget.expense);
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final success = await _controller.save(context);
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.highlight)),
      );
    }

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Expense Details'),
                      _buildCard([
                        if (BusinessConfig.instance.staffId == null && _controller.branches.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: _controller.selectedBranchId,
                            dropdownColor: theme.surface,
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                            decoration: theme.glassInputDecoration('Store Branch', Icons.store_rounded),
                            items: _controller.branches
                                .map((b) => DropdownMenuItem<String>(value: b.id.toLowerCase(), child: Text(b.branchTitle)))
                                .toList(),
                            onChanged: _controller.setBranch,
                          ),
                          const SizedBox(height: 16),
                        ],
                        DropdownButtonFormField<String>(
                          value: _controller.selectedHeadId,
                          dropdownColor: theme.surface,
                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                          decoration: theme.glassInputDecoration('Expense Category', Icons.category_rounded),
                          items: _controller.expenseHeads
                              .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name)))
                              .toList(),
                          onChanged: _controller.setCategory,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _controller.amountCtrl,
                          label: 'Amount',
                          icon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _controller.descCtrl,
                          label: 'Description',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _controller.selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) _controller.setDate(picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.whiteAlpha(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.whiteAlpha(0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, color: theme.highlight, size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EXPENSE DATE',
                                      style: TextStyle(
                                        color: theme.textHint,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMMM dd, yyyy').format(_controller.selectedDate),
                                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.highlight,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: Text(
                          _controller.saveButtonLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      decoration: theme.glassInputDecoration(label, icon),
    );
  }
}
