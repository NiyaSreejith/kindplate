import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/food_listing_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/mongo_api_service.dart';
import '../../state/app_state.dart';

class MongoDbStatusCard extends StatefulWidget {
  final AppState state;

  const MongoDbStatusCard({super.key, required this.state});

  @override
  State<MongoDbStatusCard> createState() => _MongoDbStatusCardState();
}

class _MongoDbStatusCardState extends State<MongoDbStatusCard> {
  final _api = MongoApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _healthData;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    final health = await _api.checkHealth();
    if (mounted) {
      setState(() {
        _healthData = health;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSeedData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🌱 Seeding MongoDB Atlas...';
    });

    final success = await _api.triggerSeed();
    if (success) {
      await widget.state.loadListingsFromMongo();
      await widget.state.loadUserOrdersFromMongo(widget.state.currentUser.id);
      await _fetchStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.forestGreen,
            content: Text('🎉 MongoDB Atlas populated with demo listings & test users!'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.coral,
            content: Text('Could not seed Atlas. Please ensure backend server is running.'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _handleCreateTestListing() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Writing new listing to MongoDB Atlas...';
    });

    final testId = 'listing_atlas_${DateTime.now().millisecondsSinceEpoch}';
    final newListing = FoodListing(
      id: testId,
      sellerId: 'seller_greenleaf',
      sellerName: 'Green Leaf Restaurant',
      sellerType: 'Surplus Bakes',
      title: 'Warm Herb Olive Focaccia (#${testId.substring(testId.length - 4)})',
      description: 'Artisanal rosemary and Kalamata olive focaccia baked fresh today.',
      category: FoodCategory.bakery,
      imageUrl: 'https://images.unsplash.com/photo-1589367920969-ab8e050bbb04?w=1200&auto=format&fit=crop&q=85',
      originalPrice: 8.50,
      discountedPrice: 2.80,
      isFreeDonation: false,
      quantityRemaining: 4,
      portionSize: '1 large focaccia square',
      distanceKm: 0.9,
      pickupAddress: '123 Green Lane, San Francisco',
      ingredients: ['Flour', 'Olive oil', 'Rosemary', 'Olives', 'Sea salt'],
      allergens: ['Gluten'],
      dietaryTags: [DietaryTag.vegan],
      collectionDeadline: DateTime.now().add(const Duration(hours: 5)),
    );

    final success = await _api.saveListing(newListing);
    if (success) {
      widget.state.addListing(newListing);
      await _fetchStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forestGreen,
            content: Text('✅ Added "${newListing.title}" to MongoDB Atlas! Visible to all buyers.'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _handleTestBuy() async {
    if (widget.state.listings.isEmpty) {
      await widget.state.loadListingsFromMongo();
    }
    if (widget.state.listings.isEmpty) return;

    final target = widget.state.listings.firstWhere(
      (l) => l.quantityRemaining > 0,
      orElse: () => widget.state.listings.first,
    );

    final prevQty = target.quantityRemaining;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Purchasing 1 portion of ${target.title}...';
    });

    widget.state.clearCart();
    widget.state.addToCart(target, 1);
    final order = widget.state.placeOrder(
      fulfilmentMethod: FulfilmentMethod.pickup,
      deliveryAddress: target.pickupAddress,
    );

    await _fetchStatus();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.forestGreen,
          duration: const Duration(seconds: 4),
          content: Text(
            '🛒 Bought 1x ${target.title}!\nStock decreased from $prevQty → ${target.quantityRemaining} in MongoDB Atlas!\nOrder #${order.orderNumber} created & notification dispatched.',
          ),
        ),
      );
    }
  }

  Future<void> _handleTestUserRegistration() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Registering new test account in MongoDB users table...';
    });

    final rand = DateTime.now().millisecondsSinceEpoch % 10000;
    final newUser = UserProfile(
      id: 'usr_atlas_$rand',
      email: 'eco.hero$rand@kindplate.org',
      name: 'Atlas Tester #$rand',
      role: UserRole.buyer,
      city: 'San Francisco, CA',
      badgeLevel: BadgeLevel.sprout,
      impactScore: 100,
      greenTokenBalance: 50,
      verified: true,
      isDemo: false,
    );

    final success = await _api.syncUserProfile(newUser);
    if (success) {
      widget.state.updateCurrentUser(newUser);
      await _fetchStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forestGreen,
            content: Text('👤 Created user "${newUser.name}" in MongoDB Atlas users table!'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbInfo = _healthData?['database'] as Map<String, dynamic>?;
    final isConnected = dbInfo?['connected'] == true;
    final collections = dbInfo?['collections'] as Map<String, dynamic>?;

    final listingsCount = collections?['listings'] ?? widget.state.listings.length;
    final usersCount = collections?['users'] ?? 11;
    final ordersCount = collections?['orders'] ?? widget.state.orders.length;
    final sellersCount = collections?['sellers'] ?? 3;
    final notificationsCount = collections?['notifications'] ?? widget.state.notifications.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isConnected ? const Color(0xFF00ED64).withValues(alpha: 0.6) : AppColors.borderLight,
          width: isConnected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected
                ? const Color(0xFF00ED64).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? const Color(0xFF00ED64) : AppColors.coral,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? const Color(0xFF00ED64) : AppColors.coral).withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MongoDB Atlas Database',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isConnected ? const Color(0xFFE8FDF0) : const Color(0xFFFEECEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isConnected ? const Color(0xFF00ED64) : AppColors.coral,
                            ),
                          ),
                          child: Text(
                            isConnected ? 'CONNECTED' : 'DISCONNECTED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isConnected ? const Color(0xFF00684A) : AppColors.coral,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isConnected
                          ? 'db: kindplate • cluster: ${dbInfo?['host'] ?? 'Atlas'}'
                          : 'Check server/.env & npm run dev',
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : () => _fetchStatus(),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.forestGreen),
                tooltip: 'Refresh Status',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Database CRUD Metrics Grid (All 5 MongoDB Atlas Collections)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBF9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('🥖 Listings', '$listingsCount', 'Public CRUD'),
                _buildDivider(),
                _buildMetricCol('👤 Users', '$usersCount', 'Profiles'),
                _buildDivider(),
                _buildMetricCol('📦 Orders', '$ordersCount', 'Orders'),
                _buildDivider(),
                _buildMetricCol('🏪 Sellers', '$sellersCount', 'Stores'),
                _buildDivider(),
                _buildMetricCol('🔔 Notifs', '$notificationsCount', 'Alerts'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Informative Permission Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.forestGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CRUD Access Control: Listings are public to all. Orders & User profiles are strictly isolated to authenticated accounts.',
                    style: TextStyle(fontSize: 11, color: AppColors.forestGreen, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Interactive Demo Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleTestUserRegistration,
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('+ Test User (CRUD: Create User)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forestGreen,
                  side: const BorderSide(color: AppColors.forestGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleCreateTestListing,
                icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                label: const Text('+ Add Food (CRUD: Create Food)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleTestBuy,
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('🛒 Test Buy (Decrease Stock in Atlas)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00684A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleSeedData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Re-Seed Atlas Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkText,
                  side: const BorderSide(color: AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.forestGreen),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String count, String sub) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkText)),
        Text(sub, style: const TextStyle(fontSize: 9.5, color: AppColors.mutedText)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 28,
      width: 1,
      color: AppColors.borderLight,
    );
  }
}
