import 'package:flutter/material.dart';
import 'package:mobile_app/controllers/add_product_controller.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/services/sync_service.dart';

/// Logout entry point: multi-business users pick another business or sign out.
class LogoutHelper {
  static final _theme = ThemeProvider.instance;
  static final _syncService = SyncService();

  static String _businessTypeIcon(String? type) {
    if (type == 'garments') return '👕';
    if (type == 'produce') return '🥬';
    if (type == 'restaurant') return '🍽️';
    if (type == 'electronics') return '📱';
    return '🏪';
  }

  /// FIXED: Business selection only for admins, not employees
  static Future<void> handleLogout(BuildContext context) async {
    final db = DatabaseHelper.instance;
    final userId = BusinessConfig.instance.userId;
    final staffId = BusinessConfig.instance.staffId;
    var businesses = <Map<String, dynamic>>[];

    // Staff should not see business selector
    if (staffId != null) {
      print('👷 [LOGOUT] Staff user detected - direct sign out');
      await _confirmAndSignOut(context);
      return;
    }

    if (userId != null) {
      businesses = await db.getBusinessesForUser(userId);
    }

    if (businesses.length > 1) {
      final choice = await _showBusinessOrSignOutDialog(context, businesses);
      if (choice == null || !context.mounted) return;

      if (choice is Map<String, dynamic>) {
        await _switchBusiness(context, choice);
        return;
      }
    }

    await _confirmAndSignOut(context);
  }

  static Future<void> _switchBusiness(
    BuildContext context,
    Map<String, dynamic> business,
  ) async {
    final currentId = BusinessConfig.instance.businessId;
    final targetId = business['id'];
    if (currentId != null && targetId != null && currentId == targetId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already on this business'),
            backgroundColor: ThemeProvider.success,
          ),
        );
      }
      return;
    }

    try {
      await DatabaseHelper.instance.activateBusiness(
        business,
        userId: BusinessConfig.instance.userId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch business: $e'),
            backgroundColor: ThemeProvider.error,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${business['name'] ?? 'business'}'),
        backgroundColor: ThemeProvider.success,
      ),
    );
  }

  static Future<void> _confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign out', style: TextStyle(color: _theme.textPrimary)),
        content: Text(
          'Are you sure you want to sign out? Your local data stays on this device.',
          style: TextStyle(color: _theme.textSecondary),
        ),
        backgroundColor: _theme.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _theme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SIGN OUT',
              style: TextStyle(
                color: ThemeProvider.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _performSignOut(context);
  }

  static Future<void> _performSignOut(BuildContext context) async {
    try {
      await _syncService.logout();
      AddProductController.clearGlobalState();
      MockDataStore.instance.clear();
      await DatabaseHelper.instance.clearSessionContext();

      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out error: $e'),
          backgroundColor: ThemeProvider.error,
        ),
      );
    }
  }

  /// Returns a business map to switch to, or the string `'logout'` to sign out.
  static Future<dynamic> _showBusinessOrSignOutDialog(
    BuildContext context,
    List<Map<String, dynamic>> businesses,
  ) {
    final currentId = BusinessConfig.instance.businessId;

    return showDialog<dynamic>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThemeProvider.radiusCard),
          ),
          width: 450,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Switch business',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open another business, or sign out completely.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final b = businesses[index];
                    final id = b['id'];
                    final isCurrent =
                        currentId != null && id != null && currentId == id;
                    final type = b['business_type_id']?.toString() ?? '1';
                    final icon = _businessTypeIcon(type);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _theme.highlight.withOpacity(0.05)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrent
                                ? _theme.highlight.withOpacity(0.3)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: ListTile(
                          onTap: isCurrent
                              ? null
                              : () => Navigator.pop(ctx, b),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? _theme.highlight
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(icon, style: const TextStyle(fontSize: 18)),
                          ),
                          title: Text(
                            b['name'] ?? 'Unnamed Business',
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isCurrent
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: ThemeProvider.success,
                                  size: 20,
                                )
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: _theme.highlight,
                                  size: 22,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'logout'),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'SIGN OUT',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThemeProvider.error,
                    side: const BorderSide(color: ThemeProvider.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ThemeProvider.radiusList),
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
}