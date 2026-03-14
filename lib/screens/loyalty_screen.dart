import 'package:flutter/material.dart';
import 'package:mobile_app/models/customer.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/providers/theme_provider.dart';

// Loyalty Store
class LoyaltyStore {
  static final LoyaltyStore instance = LoyaltyStore._();
  LoyaltyStore._();
  
  // Points per dollar spent
  int pointsPerDollar = 10;
  
  // Rewards available
  final List<LoyaltyReward> rewards = [
    LoyaltyReward(id: 'r1', name: '${BusinessConfig.instance.currency}5 Off', description: 'Get ${BusinessConfig.instance.currency}5 off your next purchase', pointsCost: 500),
    LoyaltyReward(id: 'r2', name: '${BusinessConfig.instance.currency}10 Off', description: 'Get ${BusinessConfig.instance.currency}10 off your next purchase', pointsCost: 900),
    LoyaltyReward(id: 'r3', name: 'Free Accessory', description: 'Free accessory up to ${BusinessConfig.instance.currency}15', pointsCost: 1500),
    LoyaltyReward(id: 'r4', name: '20% Off', description: '20% off entire order', pointsCost: 2000),
  ];

  // Customer points (linked by customer ID)
  final Map<dynamic, int> customerPoints = {
    'c1': 1250, // John Smith
    'c2': 350,  // Sarah Johnson
    'c3': 2800, // Mike Wilson
    'c4': 100,  // Emily Brown
    'c5': 5500, // David Lee
  };

  int getPoints(dynamic customerId) => customerPoints[customerId] ?? 0;
  
  void addPoints(dynamic customerId, int points) {
    customerPoints[customerId] = (customerPoints[customerId] ?? 0) + points;
  }

  bool redeemReward(dynamic customerId, LoyaltyReward reward) {
    final current = customerPoints[customerId] ?? 0;
    if (current >= reward.pointsCost) {
      customerPoints[customerId] = current - reward.pointsCost;
      return true;
    }
    return false;
  }
}

class LoyaltyReward {
  final String id;
  final String name;
  final String description;
  final int pointsCost;

  LoyaltyReward({required this.id, required this.name, required this.description, required this.pointsCost});
}

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> with SingleTickerProviderStateMixin {
  final theme = ThemeProvider.instance;
  late TabController _tabController;
  List<Customer> _customers = [];
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await DatabaseHelper.instance.getCustomers();
      if (mounted) {
        setState(() {
          _customers = data.map((c) => Customer.fromMap(c)).toList();
        });
      }
    } catch (e) {
      print('Error loading customers for loyalty: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Loyalty Program',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        leading: BackButton(color: theme.textPrimary),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: theme.iconColor),
            onPressed: () => setState(() => theme.toggleTheme()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.highlight,
          indicatorWeight: 3,
          labelColor: theme.textPrimary,
          unselectedLabelColor: theme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'MEMBERS', icon: Icon(Icons.people_alt_rounded, size: 20)),
            Tab(text: 'REWARDS', icon: Icon(Icons.card_giftcard_rounded, size: 20)),
          ],
        ),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMembersTab(),
              _buildRewardsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    final loyaltyStore = LoyaltyStore.instance;

    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: theme.glassCircleDecoration,
              child: Icon(Icons.people_outline_rounded, size: 60, color: theme.iconColor),
            ),
            const SizedBox(height: 16),
            Text('No loyalty members', 
              style: TextStyle(fontSize: 18, color: theme.textPrimary, fontWeight: FontWeight.w800)),
            Text('Registered customers will appear here', 
              style: TextStyle(fontSize: 14, color: theme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        final points = loyaltyStore.getPoints(customer.id);
        final tier = _getTier(points);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: theme.glassDecoration,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showCustomerLoyalty(customer, points),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [tier.color, tier.color.withOpacity(0.6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(color: tier.color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Center(
                              child: Text(customer.name[0], 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: tier.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.isDark ? Colors.black : Colors.white, width: 2),
                              ),
                              child: Icon(tier.icon, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name, 
                              style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tier.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: tier.color.withOpacity(0.3)),
                                  ),
                                  child: Text(tier.name.toUpperCase(), 
                                    style: TextStyle(color: tier.color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                ),
                                const SizedBox(width: 10),
                                Text('${BusinessConfig.instance.currency}. ${customer.totalSpent.toStringAsFixed(0)} spent', 
                                  style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: theme.highlight, size: 18),
                              const SizedBox(width: 6),
                              Text('$points', 
                                style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            ],
                          ),
                          Text('POINTS', 
                            style: TextStyle(color: theme.textHint, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardsTab() {
    final rewards = LoyaltyStore.instance.rewards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: theme.glassDecoration.copyWith(
              color: theme.whiteAlpha(0.05),
              border: Border.all(color: theme.highlight.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: theme.highlight, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Earn ${LoyaltyStore.instance.pointsPerDollar} points for every ${BusinessConfig.instance.currency}1 spent',
                    style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: theme.glassDecoration.copyWith(
                    gradient: LinearGradient(
                      colors: [theme.highlight, theme.highlight.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reward.name, 
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              const SizedBox(height: 2),
                              Text(reward.description, 
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: theme.highlight, size: 16),
                              const SizedBox(width: 6),
                              Text('${reward.pointsCost}', 
                                style: TextStyle(color: theme.highlight, fontWeight: FontWeight.w900, fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _LoyaltyTier _getTier(int points) {
    if (points >= 5000) return _LoyaltyTier('Platinum', const Color(0xFF9E9E9E), Icons.diamond);
    if (points >= 2000) return _LoyaltyTier('Gold', const Color(0xFFFFD700), Icons.star);
    if (points >= 500) return _LoyaltyTier('Silver', const Color(0xFFC0C0C0), Icons.star_half);
    return _LoyaltyTier('Bronze', const Color(0xFFCD7F32), Icons.star_border);
  }

  void _showCustomerLoyalty(Customer customer, int points) {
    final rewardsForPoints = LoyaltyStore.instance.rewards.where((r) => r.pointsCost <= points).toList();
    final tier = _getTier(points);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: theme.glassDecoration.copyWith(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: theme.whiteAlpha(0.2), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [tier.color, tier.color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(customer.name[0], 
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, 
                        style: TextStyle(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: tier.color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(tier.name.toUpperCase(), 
                          style: TextStyle(color: tier.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$points', 
                      style: TextStyle(color: theme.highlight, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    Text('AVAILABLE POINTS', 
                      style: TextStyle(color: theme.textHint, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
            const Divider(height: 40, thickness: 1),
            if (rewardsForPoints.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('REDEEMABLE REWARDS', 
                  style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 16),
              ...rewardsForPoints.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.whiteAlpha(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.whiteAlpha(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, 
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('${r.pointsCost} points', 
                              style: TextStyle(color: theme.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (LoyaltyStore.instance.redeemReward(customer.id, r)) {
                            Navigator.pop(ctx);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${r.name} successfully redeemed!'), 
                                backgroundColor: ThemeProvider.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              )
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.highlight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('REDEEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              )),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 48, color: theme.iconColor.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text('Keep earning to unlock rewards!', 
                      style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoyaltyTier {
  final String name;
  final Color color;
  final IconData icon;

  _LoyaltyTier(this.name, this.color, this.icon);
}
