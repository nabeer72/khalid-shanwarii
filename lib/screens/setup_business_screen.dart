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
    return Scaffold(
      body: theme.glassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              'Business Setup',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure your business environment.',
                              style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Currency Section
                            _sectionTitle('CURRENCY SELECTION', Icons.payments_rounded),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _currencySearchCtrl,
                              onChanged: _filterCurrencies,
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
                              decoration: theme.glassInputDecoration('Search currency...', Icons.search_rounded),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 70,
                              child: _filteredCurrencies.isEmpty 
                                ? Center(child: Text('No currencies found', style: TextStyle(color: theme.textSecondary)))
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _filteredCurrencies.length,
                                    itemBuilder: (context, index) {
                                      final currency = _filteredCurrencies[index];
                                      final isSelected = _selectedCurrencySymbol == currency.symbol;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedCurrencySymbol = currency.symbol),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 60,
                                          margin: const EdgeInsets.only(right: 10, bottom: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? theme.highlight : theme.whiteAlpha(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? theme.highlight : theme.whiteAlpha(0.1),
                                              width: 2,
                                            ),
                                            boxShadow: isSelected ? [
                                              BoxShadow(color: theme.highlight.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))
                                            ] : null,
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                currency.symbol,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : theme.textPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
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
                            
                            const SizedBox(height: 40),
                            
                            // Units Section
                            _sectionTitle('UNIT MANAGEMENT', Icons.straighten_rounded),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _unitSearchCtrl,
                              onChanged: _filterUnits,
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
                              decoration: theme.glassInputDecoration('Search units...', Icons.search_rounded),
                            ),
                            const SizedBox(height: 20),
                            _filteredUnits.isEmpty 
                              ? Center(child: Text('No units found', style: TextStyle(color: theme.textSecondary)))
                              : Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _filteredUnits.map((unit) {
                                    final originalIndex = _availableUnits.indexWhere((u) => u['name'] == unit['name']);
                                    final isSelected = _selectedUnitIndices.contains(originalIndex);
                                    return FilterChip(
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
                                      backgroundColor: theme.whiteAlpha(0.08),
                                      selectedColor: theme.highlight,
                                      checkmarkColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : theme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: isSelected ? theme.highlight : theme.whiteAlpha(0.1),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom Action
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44, // Reduced from 64
                        child: ElevatedButton(
                          onPressed: _loading ? null : _finishSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.highlight,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: theme.highlight.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                          ),
                          child: _loading 
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('GET STARTED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                                  SizedBox(width: 12),
                                  Icon(Icons.rocket_launch_rounded, size: 20),
                                ],
                              ),
                        ),
                      ),
                  ),
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
