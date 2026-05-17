import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/data/currency_list.dart';
import 'home_screen.dart';

class SetupBusinessScreen extends StatefulWidget {
  const SetupBusinessScreen({super.key});

  @override
  State<SetupBusinessScreen> createState() => _SetupBusinessScreenState();
}

class _SetupBusinessScreenState extends State<SetupBusinessScreen> {
  final theme = ThemeProvider.instance;
  String? _selectedCurrencySymbol;
  final List<Map<String, String>> _availableUnits = [
    {'name': 'Piece', 'short_name': 'pc'},
    {'name': 'Pack', 'short_name': 'pk'},
    {'name': 'Box', 'short_name': 'bx'},
    {'name': 'Kilogram', 'short_name': 'kg'},
    {'name': 'Gram', 'short_name': 'g'},
    {'name': 'Liter', 'short_name': 'L'},
    {'name': 'Carton', 'short_name': 'ctn'},
    {'name': 'Dozen', 'short_name': 'doz'},
    {'name': 'Bag', 'short_name': 'bag'},
    {'name': 'Bottle', 'short_name': 'btl'},
    {'name': 'Foot', 'short_name': 'ft'},
    {'name': 'Meter', 'short_name': 'm'},
    {'name': 'Yard', 'short_name': 'yd'},
  ];
  
  final Set<int> _selectedUnitIndices = {};
  bool _loading = false;
  
  final _currencySearchCtrl = TextEditingController();
  final _unitSearchCtrl = TextEditingController();
  
  final _currencyScrollCtrl = ScrollController();
  final _unitScrollCtrl = ScrollController();
  
  List<Currency> _filteredCurrencies = [];
  List<Map<String, String>> _filteredUnits = [];

  @override
  void initState() {
    super.initState();
    _selectedCurrencySymbol = BusinessConfig.instance.currency;
    _filteredCurrencies = currencyList;
    _filteredUnits = _availableUnits;
    
    // Pre-select some common units if empty
    if (_selectedUnitIndices.isEmpty) {
       for (int i = 0; i < 4 && i < _availableUnits.length; i++) {
        _selectedUnitIndices.add(i);
      }
    }
  }

  void _filterCurrencies(String query) {
    setState(() {
      _filteredCurrencies = currencyList.where((c) => 
        c.name.toLowerCase().contains(query.toLowerCase()) || 
        c.code.toLowerCase().contains(query.toLowerCase()) || 
        c.symbol.contains(query)
      ).toList();
    });
  }

  void _scrollList(ScrollController controller, double offset) {
    if (controller.hasClients) {
      final newOffset = (controller.offset + offset).clamp(0.0, controller.position.maxScrollExtent);
      controller.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _currencySearchCtrl.dispose();
    _unitSearchCtrl.dispose();
    _currencyScrollCtrl.dispose();
    _unitScrollCtrl.dispose();
    super.dispose();
  }

  void _filterUnits(String query) {
    setState(() {
      _filteredUnits = _availableUnits.where((u) => 
        u['name']!.toLowerCase().contains(query.toLowerCase()) || 
        u['short_name']!.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _finishSetup() async {
    if (_selectedCurrencySymbol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a currency'), backgroundColor: ThemeProvider.error),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final db = DatabaseHelper.instance;
      final bid = BusinessConfig.instance.businessId;
      final uid = BusinessConfig.instance.userId;

      await db.saveCurrency(_selectedCurrencySymbol!);

      for (var index in _selectedUnitIndices) {
        final unit = _availableUnits[index];
        await db.insertUnit({
          'business_id': bid,
          'user_id': uid,
          'name': unit['name'],
          'short_name': unit['short_name'],
          'status': 1,
        });
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: ThemeProvider.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: theme.glassBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: theme.isDark ? theme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Premium Header
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: ThemeProvider.gradientOcean.map((c) => c.withOpacity(0.2)).toList(),
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(color: theme.highlight.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Icon(Icons.business_rounded, size: 28, color: theme.highlight),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'BUSINESS SETUP',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Configure your business environment',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Currency Section
                          _sectionTitle('CURRENCY SELECTION', Icons.payments_rounded),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _currencySearchCtrl,
                              onChanged: _filterCurrencies,
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Search currency...',
                                labelStyle: const TextStyle(fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded, color: theme.textSecondary, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.divider)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.divider)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.highlight)),
                                filled: true,
                                fillColor: theme.isDark ? theme.background : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 50,
                            child: _filteredCurrencies.isEmpty 
                              ? Center(child: Text('No currencies found', style: TextStyle(color: theme.textSecondary, fontSize: 12)))
                              : Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _scrollList(_currencyScrollCtrl, -100),
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Icon(Icons.chevron_left_rounded, color: theme.textSecondary, size: 24),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _currencyScrollCtrl,
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _filteredCurrencies.length,
                                        itemBuilder: (context, index) {
                                          final currency = _filteredCurrencies[index];
                                          final isSelected = _selectedCurrencySymbol == currency.symbol;
                                          return GestureDetector(
                                            onTap: () => setState(() => _selectedCurrencySymbol = currency.symbol),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 50,
                                              margin: const EdgeInsets.only(right: 8, bottom: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected ? theme.highlight : (theme.isDark ? theme.background : Colors.grey[100]),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected ? theme.highlight : theme.divider,
                                                  width: 1.5,
                                                ),
                                                boxShadow: isSelected ? [
                                                  BoxShadow(color: theme.highlight.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                                                ] : null,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    currency.symbol,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white : theme.textPrimary,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                  Text(
                                                    currency.code,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white.withOpacity(0.8) : theme.textSecondary,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _scrollList(_currencyScrollCtrl, 100),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4.0),
                                        child: Icon(Icons.chevron_right_rounded, color: theme.textSecondary, size: 24),
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Units Section
                          _sectionTitle('UNIT MANAGEMENT', Icons.straighten_rounded),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _unitSearchCtrl,
                              onChanged: _filterUnits,
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Search units...',
                                labelStyle: const TextStyle(fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded, color: theme.textSecondary, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.divider)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.divider)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.highlight)),
                                filled: true,
                                fillColor: theme.isDark ? theme.background : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 36,
                            child: _filteredUnits.isEmpty 
                              ? Center(child: Text('No units found', style: TextStyle(color: theme.textSecondary, fontSize: 12)))
                              : Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _scrollList(_unitScrollCtrl, -100),
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Icon(Icons.chevron_left_rounded, color: theme.textSecondary, size: 24),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _unitScrollCtrl,
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _filteredUnits.length,
                                        itemBuilder: (context, index) {
                                          final unit = _filteredUnits[index];
                                          final originalIndex = _availableUnits.indexWhere((u) => u['name'] == unit['name']);
                                          final isSelected = _selectedUnitIndices.contains(originalIndex);
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: FilterChip(
                                              label: Text(unit['name']!),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  if (selected) {
                                                    _selectedUnitIndices.add(originalIndex);
                                                  } else {
                                                    _selectedUnitIndices.remove(originalIndex);
                                                  }
                                                });
                                              },
                                              backgroundColor: theme.isDark ? theme.background : Colors.grey[100],
                                              selectedColor: theme.highlight,
                                              checkmarkColor: Colors.white,
                                              labelStyle: TextStyle(
                                                color: isSelected ? Colors.white : theme.textPrimary,
                                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                side: BorderSide(
                                                  color: isSelected ? theme.highlight : theme.divider,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _scrollList(_unitScrollCtrl, 100),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4.0),
                                        child: Icon(Icons.chevron_right_rounded, color: theme.textSecondary, size: 24),
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _finishSetup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.highlight,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _loading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text('GET STARTED', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                      SizedBox(width: 8),
                                      Icon(Icons.rocket_launch_rounded, size: 18),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  child: Text('SKIP', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.highlight, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
