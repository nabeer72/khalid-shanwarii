import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/mock_data.dart';

// Gift Card Store
class GiftCardStore {
  static final GiftCardStore instance = GiftCardStore._();
  GiftCardStore._();
  
  final List<GiftCard> cards = [
    GiftCard(id: 1, code: 'GIFT-1000-ABCD', balance: 25.00, initialAmount: 25.00, createdAt: DateTime.now().subtract(const Duration(days: 5))),
    GiftCard(id: 2, code: 'GIFT-2000-EFGH', balance: 50.00, initialAmount: 50.00, createdAt: DateTime.now().subtract(const Duration(days: 2))),
    GiftCard(id: 3, code: 'GIFT-3000-IJKL', balance: 12.50, initialAmount: 100.00, createdAt: DateTime.now().subtract(const Duration(days: 30))),
  ];
}

class GiftCard {
  final int id;
  final String code;
  double balance;
  final double initialAmount;
  final DateTime createdAt;
  bool isActive;

  GiftCard({required this.id, required this.code, required this.balance, required this.initialAmount, required this.createdAt, this.isActive = true});
}

class GiftCardsScreen extends StatefulWidget {
  final bool selectMode;
  const GiftCardsScreen({super.key, this.selectMode = false});

  @override
  State<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends State<GiftCardsScreen> {
  final theme = ThemeProvider.instance;

  void _createGiftCard() {
    final amounts = [10.0, 25.0, 50.0, 100.0];
    double selectedAmount = 25.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(24),
            decoration: theme.glassDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFE91E63).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFE91E63), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('New Gift Card', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 24),
                Text('SELECT PRESET AMOUNT', 
                  style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: amounts.map((amt) => GestureDetector(
                    onTap: () => setDialogState(() => selectedAmount = amt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedAmount == amt ? const Color(0xFFE91E63) : theme.whiteAlpha(0.05),
                        borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                        border: Border.all(color: selectedAmount == amt ? const Color(0xFFE91E63) : theme.whiteAlpha(0.1), width: 1.5),
                        boxShadow: selectedAmount == amt ? [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                      ),
                      child: Text(
                        '${BusinessConfig.instance.currency}. ${amt.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: selectedAmount == amt ? Colors.white : theme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('CANCEL', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final code = 'GIFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-${DateTime.now().microsecond.toString().padLeft(4, '0')}';
                          GiftCardStore.instance.cards.add(GiftCard(
                            id: GiftCardStore.instance.cards.length + 1,
                            code: code,
                            balance: selectedAmount,
                            initialAmount: selectedAmount,
                            createdAt: DateTime.now(),
                          ));
                          Navigator.pop(ctx);
                          setState(() {});
                          _showNewCardDialog(code, selectedAmount);
                        },
                        child: const Text('GENERATE', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNewCardDialog(String code, double amount) {
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ThemeProvider.success.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, color: ThemeProvider.success, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Generation Success!', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFFF5722)]),
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
                  boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    Text(code, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Monospace')),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(ThemeProvider.radiusList)), child: Text('BALANCE', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    const SizedBox(height: 4),
                    Text('${BusinessConfig.instance.currency}. ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Record this code for the customer', textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeProvider.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('FINISH', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkBalance() {
    final codeCtrl = TextEditingController();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: theme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.account_balance_wallet_rounded, color: theme.highlight, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Balance Check', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: theme.glassDecoration.copyWith(
                  borderRadius: BorderRadius.circular(ThemeProvider.radiusList),
                  color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                ),
                child: TextField(
                  controller: codeCtrl,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'CARD SERIAL / CODE',
                    labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                    prefixIcon: Icon(Icons.qr_code_rounded, color: theme.highlight),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('CLOSE', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.highlight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final card = GiftCardStore.instance.cards.firstWhere(
                          (c) => c.code == codeCtrl.text,
                          orElse: () => GiftCard(id: 0, code: '', balance: 0, initialAmount: 0, createdAt: DateTime.now()),
                        );
                        Navigator.pop(ctx);
                        if (card.id != 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Balance: ${BusinessConfig.instance.currency}. ${card.balance.toStringAsFixed(2)}'), 
                              backgroundColor: ThemeProvider.success,
                              behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Invalid Gift Card Code'), 
                              backgroundColor: ThemeProvider.error,
                              behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                            ),
                          );
                        }
                      },
                      child: const Text('SEARCH', style: TextStyle(fontWeight: FontWeight.w900)),
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
    final cards = GiftCardStore.instance.cards;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.selectMode ? 'Select Gift Card' : 'Gift Catalog',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: theme.iconColor), 
            onPressed: _checkBalance, 
            tooltip: 'Check Balance'
          ),
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor), 
            onPressed: () => setState(() => theme.toggleTheme())
          ),
        ],
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: theme.glassCircleDecoration,
                        child: const Icon(Icons.card_giftcard_rounded, size: 60, color: Color(0xFFE91E63)),
                      ),
                      const SizedBox(height: 20),
                      Text('No Active Gift Cards', 
                        style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('Generate a new card to get started', 
                        style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _createGiftCard,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('GENERATE CARD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeProvider.radiusList)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _GiftCardTile(
                      card: card,
                      onTap: widget.selectMode ? () => Navigator.pop(context, card) : null,
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGiftCard,
        backgroundColor: const Color(0xFFE91E63),
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

class _GiftCardTile extends StatelessWidget {
  final GiftCard card;
  final VoidCallback? onTap;

  const _GiftCardTile({required this.card, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final isDepleted = card.balance <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: theme.glassDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(card.code, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Monospace', letterSpacing: 1)),
            ),
            Text('ID: ${card.id}', 
                style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Text(
                'ISSUED: ${card.createdAt.day}/${card.createdAt.month}/${card.createdAt.year}',
                style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                'VAL: ${BusinessConfig.instance.currency}. ${card.initialAmount.toStringAsFixed(0)}',
                style: TextStyle(color: theme.textHint, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${BusinessConfig.instance.currency}. ${card.balance.toStringAsFixed(2)}',
              style: TextStyle(
                color: isDepleted ? ThemeProvider.error : const Color(0xFFE91E63), 
                fontWeight: FontWeight.w900, 
                fontSize: 14,
              ),
            ),
            Text(
              isDepleted ? 'DEPLETED' : 'BALANCE',
              style: TextStyle(color: theme.textHint, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
