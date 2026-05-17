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
                            decoration: theme.glassDecoration.copyWith(
                              color: theme.isDark 
                                  ? theme.surface.withOpacity(0.4) 
                                  : Colors.white.withOpacity(0.85),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A73E8), // Solid blue matching screenshot
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 32),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Invoice Payment',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please pay the designated amount to activate your subscription.',
                                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                
                                // Amount Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.divider),
                                  ),
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
                                    color: const Color(0xFFD6F5F8), // Light cyan background
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(color: Color(0xFF0F5156), fontSize: 14, height: 1.4), // Darker cyan text
                                      children: [
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
                                        const Text(' *', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _pickReceipt,
                                      child: Container(
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFD1D5DB)), // Light gray border
                                        ),
                                        child: Row(
                                          children: [
                                            // Gray button area
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFE5E7EB), // Gray background
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  bottomLeft: Radius.circular(3),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text('Choose file', style: TextStyle(color: Color(0xFF374151), fontSize: 13)),
                                            ),
                                            // Divider
                                            Container(width: 1, color: const Color(0xFFD1D5DB)),
                                            // Text area
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _receipt == null ? 'No file chosen' : _receipt!.path.split('/').last,
                                                style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_receipt != null)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(Icons.check_circle, color: Colors.green, size: 16),
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
                                      backgroundColor: const Color(0xFF1A73E8), // Solid Blue
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
