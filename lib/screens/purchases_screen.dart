import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/widgets/empty_state_icon.dart';
import 'package:mobile_app/controllers/add_purchase_controller.dart';
import 'package:mobile_app/controllers/add_supplier_controller.dart';
import 'package:mobile_app/services/sync_service.dart';
import 'package:mobile_app/screens/add_supplier_screen.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final theme = ThemeProvider.instance;
  List<Purchase> _purchases = [];
  bool _isLoading = true;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final SyncService _syncService = SyncService();
  bool _isOnlineSearch = false;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final localData = await DatabaseHelper.instance.getPurchases();
      List<Map<String, dynamic>> finalData = localData;

      if (_query.isNotEmpty && !_isOnlineSearch) {
        final q = _query.toLowerCase();
        final localFiltered = localData.where((p) {
          final supplier = (p['supplier_name'] ?? '').toString().toLowerCase();
          final id = p['id'].toString();
          final date = (p['purchase_date'] ?? '').toString().toLowerCase();
          return supplier.contains(q) || id.contains(q) || date.contains(q);
        }).toList();

        if (localFiltered.isEmpty) {
          final onlineData =
              await _syncService.searchOnline(_query, 'purchases');
          if (onlineData.isNotEmpty) {
            finalData = onlineData;
            _isOnlineSearch = true;
          }
        }
      } else if (_isOnlineSearch) {
        finalData = await _syncService.searchOnline(_query, 'purchases');
      }

      if (mounted) {
        setState(() {
          _purchases = finalData.map((e) => Purchase.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading purchases: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(Purchase purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: theme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: ThemeProvider.error, size: 48),
              const SizedBox(height: 16),
              Text('Delete Purchase?',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Are you sure you want to delete this purchase memory?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('CANCEL',
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                ThemeProvider.radiusList)),
                      ),
                      onPressed: () async {
                        await DatabaseHelper.instance
                            .deletePurchase(purchase.id ?? 0);
                        await _loadPurchases();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Purchase record deleted'),
                                backgroundColor: ThemeProvider.error),
                          );
                        }
                      },
                      child: const Text('DELETE',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void _openAddPurchaseScreen([Purchase? purchase]) {
    _showPurchaseFormDialog(purchase);
  }

  void _showPurchaseFormDialog([Purchase? purchase]) {
    final controller = AddPurchaseController();
    // In this simplified version, we only support NEW purchases as the original screen seemed focused on that.
    // If edit is needed, the controller would need adjustment for Purchase model vs Map.

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          controller.addListener(() {
            if (ctx.mounted) setDialogState(() {});
          });

          if (controller.isLoading) {
            return AlertDialog(
              backgroundColor: theme.surface,
              content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
            );
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Purchase',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.red, size: 20),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogSectionHeader('Supplier & Date'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            context: ctx,
                            value: (controller.selectedSupplierId != null &&
                                    controller.suppliers.any((s) =>
                                        s.id == controller.selectedSupplierId))
                                ? controller.selectedSupplierId
                                : null,
                            label: 'Supplier',
                            icon: Icons.business_rounded,
                            searchable: true,
                            items: controller.suppliers
                                .map((s) => <String, dynamic>{
                                      'value': s.id,
                                      'label': s.name
                                    })
                                .toList(),
                            onChanged: (v) {
                              controller.setSupplier(v);
                              setDialogState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded,
                              color: theme.highlight, size: 24),
                          onPressed: () async {
                            await _showAddSupplierDialog(ctx, controller);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: controller.purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null)
                                controller.setPurchaseDate(picked);
                            },
                            child: InputDecorator(
                              decoration: theme
                                  .glassInputDecoration(
                                      'Date', Icons.calendar_today_rounded)
                                  .copyWith(isDense: true),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                    DateFormat('yyyy-MM-dd')
                                        .format(controller.purchaseDate),
                                    maxLines: 1,
                                    style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: controller.invoiceCtrl,
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                            decoration: theme
                                .glassInputDecoration(
                                    'Invoice #', Icons.receipt_rounded)
                                .copyWith(isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDialogSectionHeader('Items'),
                    if (controller.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.background.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: theme.textHint.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            const EmptyStateIcon(
                              icon: Icons.inventory_2_outlined,
                              size: 30,
                              padding: 12,
                            ),
                            const SizedBox(height: 8),
                            Text('No items added',
                                style: TextStyle(
                                    color: theme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ...controller.items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: theme.glassDecoration
                              .copyWith(color: theme.whiteAlpha(0.05)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['product_name'],
                                        style: TextStyle(
                                            color: theme.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12)),
                                    Text(
                                        '${item['quantity']} @ ${BusinessConfig.instance.currency}${item['purchase_price']}',
                                        style: TextStyle(
                                            color: theme.textSecondary,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                              Text(
                                  '${BusinessConfig.instance.currency}${item['subtotal'].toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: theme.highlight,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12)),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded,
                                    color: ThemeProvider.error.withOpacity(0.7),
                                    size: 18),
                                onPressed: () => controller.removeItem(idx),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showAddItemDialog(ctx, controller),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('ADD PURCHASE ITEM',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 11)),
                        style: TextButton.styleFrom(
                            foregroundColor: theme.highlight),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDialogSectionHeader('Payment Details'),
                    _buildDropdownField(
                      context: ctx,
                      value: controller.paymentType,
                      label: 'Payment Type',
                      icon: Icons.payment_rounded,
                      items: controller.paymentTypes
                          .map((t) => <String, dynamic>{'value': t, 'label': t})
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          controller.setPaymentType(v);
                          setDialogState(() {});
                        }
                      },
                    ),
                    if (controller.paymentType == 'Cheque') ...[
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                          controller: controller.chequeNoCtrl,
                          label: 'Cheque Number',
                          icon: Icons.confirmation_number_rounded),
                    ] else if (controller.paymentType == 'Bank Transfer') ...[
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                          controller: controller.bankNameCtrl,
                          label: 'Bank Name',
                          icon: Icons.account_balance_rounded),
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                          controller: controller.transRefCtrl,
                          label: 'Transaction Reference',
                          icon: Icons.receipt_long_rounded),
                    ] else if (controller.paymentType == 'Credit Card') ...[
                      const SizedBox(height: 12),
                      _buildDialogTextField(
                          controller: controller.cardAuthCtrl,
                          label: 'Auth Code',
                          icon: Icons.security_rounded),
                    ] else if (controller.paymentType == 'Partial') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller.paidAmountCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setDialogState(() {}),
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration(
                                'Paid Amount', Icons.payments_rounded)
                            .copyWith(isDense: true),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.whiteAlpha(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.whiteAlpha(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET TOTAL:',
                              style: TextStyle(
                                  color: theme.textSecondary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11)),
                          Text(controller.formattedTotal,
                              style: TextStyle(
                                  color: theme.highlight,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL',
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: controller.canSave
                    ? () async {
                        await controller.savePurchase();
                        if (controller.successMessage != null && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadPurchases();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(controller.successMessage!),
                                backgroundColor: ThemeProvider.success),
                          );
                        } else if (controller.errorMessage != null &&
                            ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text(controller.errorMessage!),
                                backgroundColor: ThemeProvider.error),
                          );
                        }
                      }
                    : null,
                child: const Text('SAVE PURCHASE',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddSupplierDialog(
      BuildContext parentCtx, AddPurchaseController purchaseController) async {
    final _formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    bool isLoading = false;

    final result = await showDialog<bool>(
      context: parentCtx,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoading) {
            return AlertDialog(
              backgroundColor: theme.surface,
              content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
            );
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Supplier',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.red, size: 20),
                ),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogSectionHeader('Business Information'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        keyboardType: TextInputType.text,
                        maxLines: 1,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration(
                                'Supplier Name', Icons.business_rounded)
                            .copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contactCtrl,
                        keyboardType: TextInputType.text,
                        maxLines: 1,
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration(
                                'Contact Person', Icons.person_rounded)
                            .copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                      ),
                      const SizedBox(height: 20),
                      _buildDialogSectionHeader('Contact Details'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.number,
                        maxLines: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Phone is required';
                          if (!RegExp(r'^[0-9]+$').hasMatch(v.trim()))
                            return 'Must be an integer';
                          return null;
                        },
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration(
                                'Phone Number', Icons.phone_rounded)
                            .copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        maxLines: 1,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(v.trim())) {
                              return 'Invalid email format';
                            }
                          }
                          return null;
                        },
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration(
                                'Email Address', Icons.email_rounded)
                            .copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        keyboardType: TextInputType.text,
                        maxLines: 3,
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration(
                                'Address', Icons.location_on_rounded)
                            .copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                      ),
                      const SizedBox(height: 20),
                      _buildDialogSectionHeader('Account Balance'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: balanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        maxLines: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (double.tryParse(v.trim()) == null)
                            return 'Must be a valid number';
                          return null;
                        },
                        style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        decoration: theme
                            .glassInputDecoration('Running Balance (Owed)',
                                Icons.account_balance_wallet_rounded)
                            .copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL',
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.highlight,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  setDialogState(() {
                    isLoading = true;
                  });

                  try {
                    final openingAmount =
                        double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                    final supplierData = {
                      'name': nameCtrl.text.trim(),
                      'contact_person': contactCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'opening_amount': openingAmount,
                      'credit_balance': openingAmount,
                      'status': 1,
                      'created_at': DateTime.now().toIso8601String(),
                      'updated_at': DateTime.now().toIso8601String(),
                    };

                    await DatabaseHelper.instance.insertSupplier(supplierData);

                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Error saving supplier: $e'),
                          backgroundColor: ThemeProvider.error,
                        ),
                      );
                    }
                    setDialogState(() {
                      isLoading = false;
                    });
                  }
                },
                child: const Text('SAVE SUPPLIER',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5)),
              ),
            ],
          );
        },
      ),
    );

    nameCtrl.dispose();
    contactCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    balanceCtrl.dispose();

    if (result == true) {
      await purchaseController.reloadSuppliers();
    }
  }

  void _showAddItemDialog(
      BuildContext parentCtx, AddPurchaseController controller) {
    int? selectedProductId;
    int? selectedCategoryId;
    int? selectedUnitId;
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    final wholesaleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final piecesCtrl = TextEditingController(text: '1');

    double cost = 0, ws = 0, sp = 0, stk = 0;
    bool isBoxUnit = false;

    final searchCtrl = TextEditingController();
    bool isScannerOpen = false;
    bool isDropdownOpen = false;
    MobileScannerController? scannerController;
    AudioPlayer? audioPlayer;
    DateTime? lastScanTime;
    List<Map<String, dynamic>> queuedItems = [];
    final filteredProducts = controller.products;

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        audioPlayer = AudioPlayer();
      }
    } catch (_) {}

    String? dialogError;
    int? editingIndex;
    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void clearInputs() {
            setDialogState(() {
              selectedProductId = null;
              editingIndex = null;
              searchCtrl.clear();
              qtyCtrl.text = '1';
              costCtrl.text = '0.00';
              wholesaleCtrl.text = '0.00';
              priceCtrl.text = '0.00';
              stk = 0;
            });
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeProvider.radiusCard)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Item',
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.highlight,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text) ?? 0;
                    final pieces = double.tryParse(piecesCtrl.text) ?? 1.0;
                    if (selectedProductId != null && qty > 0) {
                      final isDuplicate = controller.items.any((item) =>
                              item['product_id'] == selectedProductId) ||
                          (queuedItems.any((item) =>
                                  item['productId'] == selectedProductId) &&
                              (editingIndex == null ||
                                  queuedItems[editingIndex!]['productId'] !=
                                      selectedProductId));

                      if (isDuplicate) {
                        setDialogState(() {
                          dialogError = 'Item already added';
                        });
                        return;
                      }
                      final p = controller.products
                          .firstWhere((x) => x['id'] == selectedProductId);
                      setDialogState(() {
                        dialogError = null;
                        final itemData = {
                          'productId': selectedProductId!,
                          'productName': p['name'],
                          'barcode': p['barcode'],
                          'existingStock': stk,
                          'quantity': qty,
                          'purchasePrice': double.tryParse(costCtrl.text) ?? 0,
                          'wholesalePrice':
                              double.tryParse(wholesaleCtrl.text) ?? 0,
                          'sellingPrice': double.tryParse(priceCtrl.text) ?? 0,
                          'unitId': selectedUnitId,
                          'piecesPerBox': pieces,
                        };

                        if (editingIndex != null) {
                          queuedItems[editingIndex!] = itemData;
                        } else {
                          queuedItems.add(itemData);
                        }
                      });
                      clearInputs();
                    }
                  },
                  icon: Icon(
                      editingIndex != null
                          ? Icons.save_rounded
                          : Icons.add_rounded,
                      size: 16),
                  label: Text(editingIndex != null ? 'UPDATE' : 'ADD MORE',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isScannerOpen)
                          Container(
                            height: 180,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: theme.highlight.withOpacity(0.3)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (defaultTargetPlatform ==
                                        TargetPlatform.android ||
                                    defaultTargetPlatform == TargetPlatform.iOS)
                                ? MobileScanner(
                                    controller: scannerController ??=
                                        MobileScannerController(),
                                    onDetect: (capture) async {
                                      final List<Barcode> barcodes =
                                          capture.barcodes;
                                      if (barcodes.isNotEmpty) {
                                        final code = barcodes.first.rawValue;
                                        if (code != null) {
                                          final now = DateTime.now();
                                          if (lastScanTime == null ||
                                              now.difference(lastScanTime!) >
                                                  const Duration(seconds: 2)) {
                                            lastScanTime = now;
                                            try {
                                              audioPlayer?.play(
                                                  AssetSource('beep.mp3'));
                                            } catch (_) {}

                                            final p =
                                                controller.products.firstWhere(
                                              (x) =>
                                                  x['barcode']?.toString() ==
                                                  code,
                                              orElse: () => {},
                                            );
                                            if (p.isNotEmpty) {
                                              setDialogState(() {
                                                selectedProductId =
                                                    p['id'] as int;
                                                searchCtrl.text =
                                                    p['name'] as String;
                                                isScannerOpen = false;
                                                isDropdownOpen = false;
                                                dialogError = null;

                                                final stocks = p['stocks']
                                                        as List<dynamic>? ??
                                                    [];
                                                if (stocks.isNotEmpty) {
                                                  final last = stocks.last;
                                                  cost = (last['cost_price']
                                                              as num? ??
                                                          0)
                                                      .toDouble();
                                                  ws = (last['wholesale_price']
                                                              as num? ??
                                                          0)
                                                      .toDouble();
                                                  sp = (last['sale_price']
                                                              as num? ??
                                                          0)
                                                      .toDouble();
                                                  stk = (last['quantity']
                                                              as num? ??
                                                          0)
                                                      .toDouble();
                                                }
                                                costCtrl.text =
                                                    cost.toStringAsFixed(2);
                                                wholesaleCtrl.text =
                                                    ws.toStringAsFixed(2);
                                                priceCtrl.text =
                                                    sp.toStringAsFixed(2);
                                              });
                                            }
                                          }
                                        }
                                      }
                                    },
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_enhance_outlined,
                                            color: theme.textSecondary
                                                .withOpacity(0.5),
                                            size: 32),
                                        const SizedBox(height: 8),
                                        Text('Camera not available on desktop',
                                            style: TextStyle(
                                                color: theme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                          ),
                        TextFormField(
                          controller: searchCtrl,
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                          decoration: theme
                              .glassInputDecoration(
                                  'Search Product...', Icons.search_rounded)
                              .copyWith(
                                isDense: true,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (searchCtrl.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 18),
                                        onPressed: () {
                                          setDialogState(() {
                                            searchCtrl.clear();
                                            selectedProductId = null;
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                          isScannerOpen
                                              ? Icons.close_rounded
                                              : Icons.barcode_reader,
                                          color: theme.highlight,
                                          size: 20),
                                      onPressed: () {
                                        setDialogState(() {
                                          isScannerOpen = !isScannerOpen;
                                          if (!isScannerOpen)
                                            scannerController?.dispose();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                          isDropdownOpen
                                              ? Icons.arrow_drop_up_rounded
                                              : Icons.arrow_drop_down_rounded,
                                          color: theme.iconColor,
                                          size: 22),
                                      onPressed: () {
                                        setDialogState(() {
                                          isDropdownOpen = !isDropdownOpen;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                          onChanged: (v) => setDialogState(() {
                            if (v.isNotEmpty) isDropdownOpen = true;
                          }),
                          onTap: () => setDialogState(() {
                            if (selectedProductId != null) {
                              selectedProductId = null;
                              searchCtrl.clear();
                              isDropdownOpen = true;
                            }
                          }),
                        ),
                        if (isDropdownOpen && selectedProductId == null)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8),
                              ],
                              border: Border.all(
                                  color: theme.highlight.withOpacity(0.1)),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: controller.products
                                  .where((p) {
                                    final isAdded = controller.items.any(
                                            (item) =>
                                                item['product_id'] ==
                                                p['id']) ||
                                        (queuedItems.any((item) =>
                                                item['productId'] == p['id']) &&
                                            (editingIndex == null ||
                                                queuedItems[editingIndex!]
                                                        ['productId'] !=
                                                    p['id']));
                                    if (isAdded) return false;
                                    return searchCtrl.text.isEmpty ||
                                        p['name']
                                            .toString()
                                            .toLowerCase()
                                            .contains(searchCtrl.text
                                                .toLowerCase()) ||
                                        p['barcode']
                                            .toString()
                                            .contains(searchCtrl.text);
                                  })
                                  .map((p) => ListTile(
                                        title: Text(p['name'],
                                            style: TextStyle(
                                                color: theme.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        subtitle: (p['barcode'] == null ||
                                                p['barcode'].toString() ==
                                                    'null' ||
                                                p['barcode'].toString().isEmpty)
                                            ? null
                                            : Text('Barcode: ${p['barcode']}',
                                                style: TextStyle(
                                                    color: theme.textSecondary,
                                                    fontSize: 10)),
                                        dense: true,
                                        onTap: () {
                                          setDialogState(() {
                                            selectedProductId = p['id'] as int;
                                            searchCtrl.text =
                                                p['name'] as String;
                                            isDropdownOpen = false;
                                            dialogError = null;

                                            final stocks =
                                                p['stocks'] as List<dynamic>? ??
                                                    [];
                                            if (stocks.isNotEmpty) {
                                              final last = stocks.last;
                                              cost =
                                                  (last['cost_price'] as num? ??
                                                          0)
                                                      .toDouble();
                                              ws = (last['wholesale_price']
                                                          as num? ??
                                                      0)
                                                  .toDouble();
                                              sp =
                                                  (last['sale_price'] as num? ??
                                                          0)
                                                      .toDouble();
                                              stk = (last['quantity'] as num? ??
                                                      0)
                                                  .toDouble();
                                            }
                                            costCtrl.text =
                                                cost.toStringAsFixed(2);
                                            wholesaleCtrl.text =
                                                ws.toStringAsFixed(2);
                                            priceCtrl.text =
                                                sp.toStringAsFixed(2);
                                          });
                                        },
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            controller: qtyCtrl,
                            label: 'Stock Quantity',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildDialogTextField(
                                controller: costCtrl,
                                label: 'Cost Price',
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildDialogTextField(
                                controller: wholesaleCtrl,
                                label: 'Wholesale',
                                icon: Icons.business,
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildDialogTextField(
                                controller: priceCtrl,
                                label: 'Sale Price',
                                icon: Icons.sell,
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                              color: ThemeProvider.error,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (queuedItems.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('LISTED ITEMS (${queuedItems.length})',
                            style: TextStyle(
                                color: theme.highlight,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: queuedItems.length,
                          itemBuilder: (context, index) {
                            final item = queuedItems[index];
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  editingIndex = index;
                                  selectedProductId = item['productId'];
                                  searchCtrl.text = item['productName'];
                                  qtyCtrl.text =
                                      item['quantity'].toStringAsFixed(0);
                                  costCtrl.text = item['purchasePrice']
                                          ?.toStringAsFixed(2) ??
                                      '0.00';
                                  wholesaleCtrl.text = item['wholesalePrice']
                                          ?.toStringAsFixed(2) ??
                                      '0.00';
                                  priceCtrl.text = item['sellingPrice']
                                          ?.toStringAsFixed(2) ??
                                      '0.00';
                                  stk =
                                      item['existingStock']?.toDouble() ?? 0.0;
                                  selectedUnitId = item['unitId'];
                                  piecesCtrl.text = item['piecesPerBox']
                                          ?.toStringAsFixed(0) ??
                                      '1';
                                  dialogError = null;
                                  isDropdownOpen = false;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: theme.glassDecoration.copyWith(
                                  color: editingIndex == index
                                      ? theme.highlight.withOpacity(0.1)
                                      : theme.whiteAlpha(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: editingIndex == index
                                      ? Border.all(
                                          color: theme.highlight, width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['productName'],
                                            style: TextStyle(
                                                color: theme.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cost: ${BusinessConfig.instance.currency} ${item['purchasePrice']}',
                                            style: TextStyle(
                                                color: theme.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Quantity Controls
                                    Container(
                                      decoration: BoxDecoration(
                                        color: theme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: theme.highlight
                                                .withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.remove_rounded,
                                                size: 16,
                                                color: theme.highlight),
                                            onPressed: () {
                                              if (item['quantity'] > 1) {
                                                setDialogState(
                                                    () => item['quantity']--);
                                              }
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 32, minHeight: 32),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(
                                              item['quantity']
                                                  .toStringAsFixed(0),
                                              style: TextStyle(
                                                  color: theme.textPrimary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.add_rounded,
                                                size: 16,
                                                color: theme.highlight),
                                            onPressed: () => setDialogState(
                                                () => item['quantity']++),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 32, minHeight: 32),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: ThemeProvider.error,
                                          size: 20),
                                      onPressed: () => setDialogState(() {
                                        if (editingIndex == index) {
                                          selectedProductId = null;
                                          editingIndex = null;
                                          searchCtrl.clear();
                                        } else if (editingIndex != null &&
                                            editingIndex! > index) {
                                          editingIndex = editingIndex! - 1;
                                        }
                                        queuedItems.removeAt(index);
                                      }),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('CANCEL',
                      style: TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              if (queuedItems.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    for (var item in queuedItems) {
                      controller.addItem(
                        productId: item['productId'],
                        productName: item['productName'],
                        barcode: item['barcode'],
                        existingStock: item['existingStock'],
                        quantity: item['quantity'],
                        purchasePrice: item['purchasePrice'],
                        wholesalePrice: item['wholesalePrice'],
                        sellingPrice: item['sellingPrice'],
                        unitId: item['unitId'],
                        piecesPerBox: item['piecesPerBox'],
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('CONFIRM ALL',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required BuildContext context,
    required dynamic value,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required void Function(dynamic) onChanged,
    bool searchable = false,
  }) {
    final key = GlobalKey();
    final displayLabel = (items as List<Map<String, dynamic>>).firstWhere(
      (i) => i['value'] == value,
      orElse: () => <String, dynamic>{'label': label},
    )['label'] as String;

    return GestureDetector(
      key: key,
      onTap: () async {
        if (searchable) {
          _showSearchDialog(context, label, items, value, onChanged);
        } else {
          final box = key.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final pos = box.localToGlobal(Offset.zero);
          final size = box.size;

          final result = await showMenu<dynamic>(
            context: context,
            elevation: 8,
            color: theme.surface.withOpacity(0.9),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.whiteAlpha(0.1))),
            constraints:
                BoxConstraints(minWidth: size.width, maxWidth: size.width),
            position: RelativeRect.fromLTRB(pos.dx, pos.dy + size.height + 4,
                pos.dx + size.width, pos.dy + size.height + 304),
            items: items
                .map((item) => PopupMenuItem<dynamic>(
                      value: item['value'],
                      height: 40,
                      child: Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: item['value'] == value
                              ? theme.highlight
                              : theme.textPrimary,
                          fontSize: 13,
                          fontWeight: item['value'] == value
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          );
          if (result != null) onChanged(result);
        }
      },
      child: InputDecorator(
        decoration: theme.glassInputDecoration(label, icon).copyWith(
              suffixIcon:
                  Icon(Icons.arrow_drop_down_rounded, color: theme.iconColor),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
        child: Text(
          displayLabel,
          style: TextStyle(
            color: value != null ? theme.textPrimary : theme.textHint,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> items,
      dynamic currentValue,
      void Function(dynamic) onSelected) {
    showDialog(
        context: context,
        builder: (ctx) {
          String searchQuery = '';
          return StatefulBuilder(builder: (ctx, setDialogState) {
            final filteredItems = items
                .where((i) => i['label']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select Supplier',
                            style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.red, size: 20),
                            onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      style:
                          TextStyle(color: theme.textPrimary, fontSize: 13),
                      decoration: theme.glassInputDecoration('Search...', Icons.search_rounded),
                      onChanged: (v) => setDialogState(() => searchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = filteredItems[i];
                          final isSelected = item['value'] == currentValue;
                          return ListTile(
                            onTap: () {
                              onSelected(item['value']);
                              Navigator.pop(ctx);
                            },
                            title: Text(
                              item['label'],
                              style: TextStyle(
                                color: isSelected
                                    ? theme.highlight
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: theme.highlight, size: 18)
                                : null,
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
          color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
      decoration: theme.glassInputDecoration(label, icon).copyWith(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Purchases History',
          style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          if (_isOnlineSearch)
            TextButton(
              onPressed: () {
                setState(() {
                  _isOnlineSearch = false;
                  _query = '';
                  _searchCtrl.clear();
                  _loadPurchases();
                });
              },
              child: const Text('LOCAL',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: theme.glassDecoration,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _query = v;
                      if (v.isEmpty && _isOnlineSearch) {
                        setState(() => _isOnlineSearch = false);
                      }
                      _loadPurchases();
                    },
                    style: TextStyle(
                        color: theme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search purchases...',
                      hintStyle: TextStyle(color: theme.textHint),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: theme.highlight),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              if (_isOnlineSearch)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done_rounded,
                          color: theme.highlight, size: 14),
                      const SizedBox(width: 8),
                      Text('SHOWING RESULTS FROM SERVER',
                          style: TextStyle(
                              color: theme.highlight,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: theme.highlight))
                    : _purchases.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const EmptyStateIcon(icon: Icons.receipt_long_rounded),
                                const SizedBox(height: 24),
                                Text('No purchases yet',
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text('Restock your inventory to see them here',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: theme.textSecondary,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _purchases.length,
                            itemBuilder: (context, index) {
                              final purchase = _purchases[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: theme.glassListDecoration,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                  onTap: () => _openAddPurchaseScreen(purchase),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                            purchase.supplierName ??
                                                'Direct Purchase',
                                            style: TextStyle(
                                                color: theme.textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14)),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        DateFormat('MMM dd, yyyy | HH:mm')
                                            .format(purchase.purchaseDate),
                                        maxLines: 1,
                                        style: TextStyle(
                                            color: theme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${BusinessConfig.instance.currencyDisplay} ${purchase.totalAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                                color: theme.highlight,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13),
                                          ),
                                          if (_isOnlineSearch)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                  color: theme.highlight
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: Text('ONLINE',
                                                  style: TextStyle(
                                                      color: theme.highlight,
                                                      fontSize: 7,
                                                      fontWeight:
                                                          FontWeight.w900)),
                                            ),
                                          Text(
                                            'PURCHASE',
                                            style: TextStyle(
                                                color: theme.textHint,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded,
                                            color: ThemeProvider.error
                                                .withOpacity(0.5),
                                            size: 18),
                                        onPressed: () =>
                                            _confirmDelete(purchase),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
          boxShadow: [
            BoxShadow(
              color: theme.highlight.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openAddPurchaseScreen(),
          backgroundColor: theme.highlight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: const Text('NEW PURCHASE',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }
}
