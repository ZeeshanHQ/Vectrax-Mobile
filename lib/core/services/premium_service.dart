import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supa_app/core/config/app_config.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  bool _isInitialized = false;

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Skip initialization if key is still a placeholder
      if (AppConfig.revenueCatApiKey.startsWith('goog_placeholder')) {
        debugPrint('[PremiumService] RevenueCat is using placeholder key. Skipping native SDK init.');
        return;
      }

      await Purchases.setLogLevel(LogLevel.debug);
      PurchasesConfiguration configuration = PurchasesConfiguration(AppConfig.revenueCatApiKey);
      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('[PremiumService] RevenueCat native SDK initialized successfully');
    } catch (e) {
      debugPrint('[PremiumService] Native SDK initialization error: $e');
    }
  }

  /// Check active entitlements via RevenueCat, sync database state
  Future<bool> checkPremiumStatus() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) return false;

      // If placeholder config, read status purely from Supabase profile
      if (AppConfig.revenueCatApiKey.startsWith('goog_placeholder')) {
        final profile = await AuthService().getUserProfile();
        return profile?['isPremium'] as bool? ?? false;
      }

      await init();
      if (!_isInitialized) return false;

      // Sync User ID to link transactions
      LogInResult result = await Purchases.logIn(user.id);
      CustomerInfo customerInfo = result.customerInfo;

      // Check if "premium" entitlement is active
      bool isPremiumActive = customerInfo.entitlements.all["premium"]?.isActive ?? false;

      // Sync Supabase database representation
      await AuthService().updatePremiumStatus(isPremiumActive);

      return isPremiumActive;
    } catch (e) {
      debugPrint('[PremiumService] Error checking premium status: $e');
      return false;
    }
  }

  /// Trigger In-App Purchase Flow
  Future<bool> purchasePremium(BuildContext context) async {
    final user = AuthService().currentUser;
    if (user == null) return false;

    // Check if configuration is a placeholder to trigger developer mock purchase bypass
    if (AppConfig.revenueCatApiKey.startsWith('goog_placeholder')) {
      bool mockSuccess = await _showMockCheckoutDialog(context);
      if (mockSuccess) {
        bool dbSuccess = await AuthService().updatePremiumStatus(true);
        return dbSuccess;
      }
      return false;
    }

    try {
      await init();
      if (!_isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('RevenueCat SDK was not initialized. Check your API keys.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }

      // Sync User ID
      await Purchases.logIn(user.id);

      // Fetch active offerings
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        // Purchase first available package (e.g. monthly)
        Package package = offerings.current!.availablePackages.first;
        PurchaseResult purchaseResult = await Purchases.purchasePackage(package);
        CustomerInfo customerInfo = purchaseResult.customerInfo;
        
        bool isPremiumActive = customerInfo.entitlements.all["premium"]?.isActive ?? false;
        if (isPremiumActive) {
          await AuthService().updatePremiumStatus(true);
          return true;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active offerings/products configured in RevenueCat console.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return false;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[PremiumService] Purchase cancelled by user');
      } else {
        debugPrint('[PremiumService] Purchase platform error: $e');
      }
      return false;
    } catch (e) {
      debugPrint('[PremiumService] Unexpected purchase error: $e');
      return false;
    }
  }

  /// Beautiful Neon-Themed Developer Mock checkout dialog
  Future<bool> _showMockCheckoutDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: const Color(0xFF0F0F0F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppTheme.accent, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  const Center(
                    child: Icon(
                      Icons.developer_mode_rounded,
                      color: AppTheme.accent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'DEVELOPER BYPASS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  Text(
                    'Your configuration is using the placeholder RevenueCat API key. Would you like to mock a successful Google Play billing purchase to instantly unlock Pro features for this account?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'MOCK BUY',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ) ??
        false;
  }
}
