import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/screens/payment_processing_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PaymentInvoiceScreen extends StatefulWidget {
  final int subscriptionId;
  final Map<String, dynamic> plan;

  const PaymentInvoiceScreen({
    super.key, 
    required this.subscriptionId, 
    required this.plan
  });

  @override
  State<PaymentInvoiceScreen> createState() => _PaymentInvoiceScreenState();
}

class _PaymentInvoiceScreenState extends State<PaymentInvoiceScreen> {
  final ApiService _api = ApiService();
  File? _receipt;
  bool _loading = false;

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _receipt = File(pickedFile.path));
    }
  }

  Future<void> _submitReceipt() async {
    if (_receipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a receipt image'), backgroundColor: ThemeProvider.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _api.uploadReceipt(widget.subscriptionId, _receipt!);
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PaymentProcessingScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload receipt'), backgroundColor: ThemeProvider.error),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: ThemeProvider.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;

    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          theme.glassBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 500,
                            minWidth: MediaQuery.of(context).size.width > 532 ? 500 : MediaQuery.of(context).size.width - 32,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: theme.glassDecoration,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: theme.highlight, // Theme highlight
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 32),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Invoice Payment',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please pay the designated amount to activate your subscription.',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                
                                // Amount Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: theme.glassListDecoration,
                                  child: Column(
                                    children: [
                                      Text('AMOUNT DUE', 
                                        style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                      const SizedBox(height: 8),
                                      Text('\$${widget.plan['price']}', 
                                        style: TextStyle(color: theme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text('Plan: ${widget.plan['name']}', 
                                        style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Instructions
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.highlight.withOpacity(0.1), // Highlight background
                                    borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(color: theme.textPrimary, fontSize: 14, height: 1.4), // Darker cyan text
                                      children: const [
                                        TextSpan(text: 'Payment Instructions: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: 'Please wire transfer the amount to '),
                                        TextSpan(text: 'SATA INC Bank, A/C: 1000-2000-3000', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: '.\nOnce transferred, upload the bank receipt below.'),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Upload Section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('Upload Payment Receipt', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                                        Text(' *', style: TextStyle(color: theme.highlight)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _pickReceipt,
                                      child: Container(
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: theme.surface,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: theme.divider), // Light gray border
                                        ),
                                        child: Row(
                                          children: [
                                            // Gray button area
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: theme.background, // Gray background
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  bottomLeft: Radius.circular(3),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text('Choose file', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                                            ),
                                            // Divider
                                            Container(width: 1, color: theme.divider),
                                            // Text area
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _receipt == null ? 'No file chosen' : _receipt!.path.split('/').last,
                                                style: TextStyle(color: theme.textSecondary, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_receipt != null)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8),
                                                child: Icon(Icons.check_circle, color: ThemeProvider.success, size: 16),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 28),
                                
                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submitReceipt,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.highlight, // Theme highlight
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
                                      elevation: 0,
                                    ),
                                    child: _loading 
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Submit Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
