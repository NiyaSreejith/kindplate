import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../models/user_model.dart';
import '../models/seller_model.dart';
import '../models/food_listing_model.dart';
import '../models/order_model.dart';
import '../models/delivery_task_model.dart';
import '../models/reward_model.dart';
import '../models/notification_model.dart';
import '../models/ai_models.dart';
import '../models/bulk_request_model.dart';
import '../models/currency_model.dart';
import '../screens/onboarding/auth_screen.dart';
import '../services/firebase_auth_service.dart';
import '../services/mongo_api_service.dart';
import '../data/seed_data.dart';

class AppState extends ChangeNotifier {
  final _uuid = const Uuid();

  // Live GPS delivery location state from food buyer cart
  LatLng? liveDeliveryLocation;
  String? liveDeliveryAddress;

  void setLiveDeliveryLocation(LatLng location, String address) {
    liveDeliveryLocation = location;
    liveDeliveryAddress = address;
    notifyListeners();
  }

  // Navigation & Onboarding Flow
  // 0: Poster Splash
  // 1: Onboarding Carousel
  // 2: Netflix Profile Selection Screen (Choose role before signup)
  // 3: Auth Screen (Login / Signup)
  // 4: In-app Role Selection Screen
  // 5+: Main Authenticated Experience
  int onboardingStep = 0;
  bool isWebDevicePreviewMode = false; // Toggles sleek mobile phone frame on desktop web
  UserRole? targetSignupRole;
  AuthMode targetAuthMode = AuthMode.signUp;

  // Current Authentication & Role
  late UserProfile currentUser;
  List<UserProfile> availableUsers = [];
  
  // App Data
  List<FoodListing> listings = [];
  List<SellerProfile> sellers = [];
  List<OrderItem> cart = [];
  List<Order> orders = [];
  List<DeliveryTask> deliveryTasks = [];
  List<BulkFoodRequest> bulkRequests = [];
  List<RewardItem> rewards = [];
  List<CommunityChallenge> challenges = [];
  List<AppNotification> notifications = [];
  AppNotification? activeBannerNotification;
  List<TokenTransaction> tokenLedger = [];
  ImpactMetrics impact = ImpactMetrics();
  
  // AI State
  List<AIChatMessage> aiChatMessages = [];
  bool isAILoading = false;
  
  // Filters for Discovery
  String searchQuery = '';
  FoodCategory? selectedCategory;
  bool filterOnlyFree = false;
  bool filterOnlyDiscounted = false;
  bool filterUrgentOnly = false;

  // Buyer Preferred Currency (for international currency switching in cart & checkout)
  AppCurrency buyerCurrency = AppCurrency.supportedCurrencies.first;

  void setBuyerCurrency(AppCurrency currency) {
    buyerCurrency = currency;
    notifyListeners();
  }

  AppState() {
    _initializeData();
    _loadCachedSession();
  }

  void _loadCachedSession() async {
    final restored = await FirebaseAuthService().restoreSessionUser();
    if (restored != null) {
      currentUser = restored;
      notifyListeners();
    }
  }

  void _initializeData() {
    availableUsers = SeedData.demoUsers;
    currentUser = availableUsers.first; // Alex Rivera (Buyer)
    listings = SeedData.demoListings;
    sellers = SeedData.demoSellers;
    rewards = SeedData.demoRewards;
    challenges = SeedData.demoChallenges;
    deliveryTasks = SeedData.demoDeliveryTasks;
    bulkRequests = List.from(SeedData.demoBulkRequests);
    notifications = SeedData.demoNotifications;
    orders = List.from(SeedData.demoOrders);

    // Sync all orders and NGO requests into DeliveryTasks for the Delivery Partner account
    _syncDeliveryTasks();

    // Pre-populate Rescue Bag with 2 popular surplus items so the bag is ready to use
    populateStarterBag(notify: false);

    tokenLedger = [
      TokenTransaction(id: 'tx_1', title: 'Welcome Community Bonus', amount: 50, type: 'community_bonus'),
      TokenTransaction(id: 'tx_2', title: 'Rescued Fresh Sourdough Loaf', amount: 25, type: 'earned_rescue'),
      TokenTransaction(id: 'tx_3', title: 'Weekend Sprint Milestone', amount: 35, type: 'community_bonus'),
    ];

    aiChatMessages = [
      AIChatMessage(
        text: "Hello! I am KindPlate AI, your leaf-powered companion. 🌿 How can I help you save food, find a free meal, or reduce kitchen surplus today?",
        isUser: false,
        actionSuggestions: [
          "Find vegan bakery surplus near me",
          "Where can I get free food donations?",
          "How do Green Tokens work?",
          "Help me predict tonight's surplus"
        ],
      )
    ];

    // Restore any user-entered server address first, then begin syncing.
    MongoApiService().loadSavedHost().then((_) => startLiveSync());
  }

  // MongoDB Atlas live synchronization methods
  Future<void> loadListingsFromMongo() async {
    try {
      final mongoListings = await MongoApiService().getListings();
      if (mongoListings.isNotEmpty) {
        // Skip the rebuild when the payload is identical to what we already
        // hold — polling every few seconds must not churn the whole tree.
        final unchanged = listings.length == mongoListings.length &&
            List.generate(listings.length, (i) => i)
                .every((i) => listings[i].id == mongoListings[i].id &&
                    listings[i].quantityRemaining ==
                        mongoListings[i].quantityRemaining);
        listings = mongoListings;
        if (unchanged) return;
        notifyListeners();
        debugPrint('🌿 [MongoDB Atlas] Synchronized ${mongoListings.length} listings');
      }
    } catch (e) {
      debugPrint('ℹ️ [MongoDB Atlas] Listings sync note: $e');
    }
  }

  Future<void> loadUserOrdersFromMongo(String userId) async {
    try {
      final mongoOrders = await MongoApiService().getUserOrders(userId);
      if (mongoOrders.isNotEmpty) {
        var changed = false;
        for (final order in mongoOrders) {
          final idx = orders.indexWhere((o) => o.id == order.id);
          if (idx >= 0) {
            if (orders[idx].status != order.status) {
              orders[idx] = order;
              changed = true;
            }
          } else {
            orders.insert(0, order);
            changed = true;
          }
        }
        if (!changed) return;
        notifyListeners();
        debugPrint('🌿 [MongoDB Atlas] Synchronized ${mongoOrders.length} orders for user $userId');
      }
    } catch (e) {
      debugPrint('ℹ️ [MongoDB Atlas] Orders sync note: $e');
    }
  }

  /// Pulls orders addressed to this seller/donor so a booking made on another
  /// device shows up here. Mirrors [loadUserOrdersFromMongo] but seller-scoped.
  Future<void> loadSellerOrdersFromMongo(String sellerId) async {
    try {
      final mongoOrders = await MongoApiService().getSellerOrders(sellerId);
      if (mongoOrders.isEmpty) return;

      var changed = false;
      for (final order in mongoOrders) {
        final idx = orders.indexWhere((o) => o.id == order.id);
        if (idx >= 0) {
          if (orders[idx].status != order.status) {
            orders[idx] = order;
            changed = true;
          }
        } else {
          orders.insert(0, order);
          changed = true;
          _onIncomingOrder(order);
        }
      }
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('ℹ️ [MongoDB Atlas] Seller orders sync note: $e');
    }
  }

  /// Raises an in-app notification when an order arrives from another device.
  void _onIncomingOrder(Order order) {
    notifications.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        title: 'New Order Received!',
        message:
            '${order.userName} requested ${order.items.length} item(s). Handover code: ${order.handoverCode}',
        type: 'order',
        orderId: order.id,
      ),
    );
    debugPrint('🔔 [MongoDB Atlas] Incoming order ${order.id} from ${order.userName}');
  }

  // ---------------------------------------------------------------------
  // Live cross-device sync
  // ---------------------------------------------------------------------

  Timer? _syncTimer;
  bool _syncInFlight = false;

  /// Polls MongoDB Atlas so orders placed on one device appear on another.
  /// Safe to call repeatedly; it restarts the existing timer.
  void startLiveSync({Duration interval = const Duration(seconds: 8)}) {
    _syncTimer?.cancel();
    syncNow();
    _syncTimer = Timer.periodic(interval, (_) => syncNow());
    debugPrint('🔄 [MongoDB Atlas] Live sync started (${interval.inSeconds}s)');
  }

  void stopLiveSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// One sync pass, scoped to whatever role the current user holds.
  Future<void> syncNow() async {
    if (_syncInFlight) return;
    // Don't poll during splash / onboarding / auth. There is nothing to sync
    // before sign-in, and the rebuilds it triggers disturb the auth form.
    if (onboardingStep < 5) return;
    _syncInFlight = true;
    try {
      await loadListingsFromMongo();
      await loadUserOrdersFromMongo(currentUser.id);

      const sellerRoles = {
        UserRole.seller,
        UserRole.homeBaker,
        UserRole.ngo,
        UserRole.volunteer,
        UserRole.admin,
      };
      if (sellerRoles.contains(currentUser.role)) {
        await loadSellerOrdersFromMongo(currentUser.id);
      }
    } finally {
      _syncInFlight = false;
    }
  }

  @override
  void dispose() {
    stopLiveSync();
    super.dispose();
  }

  void populateStarterBag({bool notify = true}) {
    if (listings.length >= 2) {
      cart = [
        OrderItem(
          listingId: listings[0].id,
          title: listings[0].title,
          imageUrl: listings[0].imageUrl,
          price: listings[0].discountedPrice,
          quantity: 1,
          isFreeDonation: listings[0].isFreeDonation,
          sellerId: listings[0].sellerId,
          sellerName: listings[0].sellerName,
          currencyCode: listings[0].currencyCode,
          currencySymbol: listings[0].currencySymbol,
        ),
        OrderItem(
          listingId: listings[1].id,
          title: listings[1].title,
          imageUrl: listings[1].imageUrl,
          price: listings[1].discountedPrice,
          quantity: 1,
          isFreeDonation: listings[1].isFreeDonation,
          sellerId: listings[1].sellerId,
          sellerName: listings[1].sellerName,
          currencyCode: listings[1].currencyCode,
          currencySymbol: listings[1].currencySymbol,
        ),
      ];
      if (notify) notifyListeners();
    }
  }

  // Onboarding controls
  void setOnboardingStep(int step) {
    onboardingStep = step;
    notifyListeners();
  }

  void selectRoleAndProceedToSignup(UserRole role) {
    targetSignupRole = role;
    targetAuthMode = AuthMode.signUp;
    switchUserRole(role);
    onboardingStep = 3; // Step 3 is AuthScreen (Sign Up mode)
    notifyListeners();
  }

  void proceedToLogin() {
    targetAuthMode = AuthMode.logIn;
    onboardingStep = 3; // Step 3 is AuthScreen (Log In mode)
    notifyListeners();
  }

  void enterMainDashboard() {
    onboardingStep = 5; // Step 5+ is MainNavigationShell
    notifyListeners();
  }

  void toggleWebDevicePreview() {
    isWebDevicePreviewMode = !isWebDevicePreviewMode;
    notifyListeners();
  }

  // Role & User Switching (Dynamic for real logged-in users and demo users)
  void switchUserRole(UserRole role) {
    if (!currentUser.isDemo) {
      // Keep logged in user's profile and update role dynamically
      currentUser = currentUser.copyWith(role: role);
      FirebaseAuthService().saveUserProfileToFirestore(currentUser);
      FirebaseAuthService().cacheUserLocally(currentUser);
      MongoApiService().syncUserProfile(currentUser);
    } else {
      final matched = availableUsers.firstWhere(
        (u) => u.role == role,
        orElse: () => currentUser.copyWith(role: role),
      );
      currentUser = matched;
    }
    notifyListeners();
  }

  void switchUser(UserProfile user) {
    currentUser = user;
    if (!user.isDemo) {
      FirebaseAuthService().saveUserProfileToFirestore(user);
      FirebaseAuthService().cacheUserLocally(user);
      MongoApiService().syncUserProfile(user);
    }
    notifyListeners();
  }

  void updateCurrentUser(UserProfile updated) {
    currentUser = updated;
    if (!updated.isDemo) {
      FirebaseAuthService().saveUserProfileToFirestore(updated);
      FirebaseAuthService().cacheUserLocally(updated);
      MongoApiService().syncUserProfile(updated);
    }
    notifyListeners();
  }

  void updateUserProfileAvatar(String avatarUrl) {
    final updated = currentUser.copyWith(avatarUrl: avatarUrl);
    updateCurrentUser(updated);
  }

  // Discovery Filter Actions
  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setSelectedCategory(FoodCategory? category) {
    if (selectedCategory == category) {
      selectedCategory = null;
    } else {
      selectedCategory = category;
    }
    notifyListeners();
  }

  void setFilterType({bool? onlyFree, bool? onlyDiscounted, bool? onlyUrgent}) {
    if (onlyFree != null) filterOnlyFree = onlyFree;
    if (onlyDiscounted != null) filterOnlyDiscounted = onlyDiscounted;
    if (onlyUrgent != null) filterUrgentOnly = onlyUrgent;
    notifyListeners();
  }

  List<FoodListing> get filteredListings {
    return listings.where((item) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final match = item.title.toLowerCase().contains(q) ||
            item.sellerName.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (selectedCategory != null && item.category != selectedCategory) {
        return false;
      }
      if (filterOnlyFree && !item.isFreeDonation) return false;
      if (filterOnlyDiscounted && item.isFreeDonation) return false;
      if (filterUrgentOnly && item.urgencyLevel == UrgencyLevel.normal) return false;
      return true;
    }).toList();
  }

  // Cart Management
  void addToCart(FoodListing listing, int quantity) {
    final existingIndex = cart.indexWhere((c) => c.listingId == listing.id);
    if (existingIndex >= 0) {
      final existing = cart[existingIndex];
      cart[existingIndex] = OrderItem(
        listingId: existing.listingId,
        title: existing.title,
        imageUrl: existing.imageUrl,
        price: existing.price,
        quantity: existing.quantity + quantity,
        isFreeDonation: existing.isFreeDonation,
        sellerId: existing.sellerId,
        sellerName: existing.sellerName,
        currencyCode: existing.currencyCode,
        currencySymbol: existing.currencySymbol,
      );
    } else {
      cart.add(OrderItem(
        listingId: listing.id,
        title: listing.title,
        imageUrl: listing.imageUrl,
        price: listing.discountedPrice,
        quantity: quantity,
        isFreeDonation: listing.isFreeDonation,
        sellerId: listing.sellerId,
        sellerName: listing.sellerName,
        currencyCode: listing.currencyCode,
        currencySymbol: listing.currencySymbol,
      ));
    }
    notifyListeners();
  }

  void updateCartQuantity(String listingId, int delta) {
    final index = cart.indexWhere((c) => c.listingId == listingId);
    if (index < 0) return;
    final current = cart[index];
    final nextQty = current.quantity + delta;
    if (nextQty <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = OrderItem(
        listingId: current.listingId,
        title: current.title,
        imageUrl: current.imageUrl,
        price: current.price,
        quantity: nextQty,
        isFreeDonation: current.isFreeDonation,
        sellerId: current.sellerId,
        sellerName: current.sellerName,
        currencyCode: current.currencyCode,
        currencySymbol: current.currencySymbol,
      );
    }
    notifyListeners();
  }

  void removeFromCart(String listingId) {
    cart.removeWhere((c) => c.listingId == listingId);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  double get cartSubtotal {
    return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Calculates cart subtotal converted to the target country/currency
  double getConvertedCartSubtotal([AppCurrency? targetCurrency]) {
    final cur = targetCurrency ?? buyerCurrency;
    return cart.fold(0.0, (sum, item) {
      final itemTotalInTarget = AppCurrency.convert(
        item.totalPrice,
        fromCode: item.currencyCode,
        toCode: cur.code,
      );
      return sum + itemTotalInTarget;
    });
  }

  int get cartCount {
    return cart.fold(0, (sum, item) => sum + item.quantity);
  }

  // Order Placement & Free Donation Requests
  Order placeOrder({
    required FulfilmentMethod fulfilmentMethod,
    String? deliveryAddress,
    String? dietaryNotes,
    bool redeemTokens = false,
    AppCurrency? selectedCurrency,
    LatLng? deliveryLocation,
  }) {
    if (deliveryLocation != null) {
      liveDeliveryLocation = deliveryLocation;
    }
    if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
      liveDeliveryAddress = deliveryAddress;
    }
    final activeCurrency = selectedCurrency ?? buyerCurrency;
    final orderNum = 'KP-${(1000 + orders.length + 1)}';
    final isFree = cart.isNotEmpty && cart.every((c) => c.isFreeDonation);
    final subtotal = isFree ? 0.0 : getConvertedCartSubtotal(activeCurrency);
    final baseDeliveryFeeUSD = (fulfilmentMethod == FulfilmentMethod.delivery && !isFree) ? 2.50 : 0.0;
    final deliveryFee = AppCurrency.convert(baseDeliveryFeeUSD, fromCode: 'USD', toCode: activeCurrency.code);
    
    double tokenDiscount = 0.0;
    if (redeemTokens && currentUser.greenTokenBalance >= 50 && !isFree) {
      tokenDiscount = AppCurrency.convert(2.00, fromCode: 'USD', toCode: activeCurrency.code);
      currentUser = currentUser.copyWith(
        greenTokenBalance: currentUser.greenTokenBalance - 50,
      );
      tokenLedger.insert(0, TokenTransaction(
        id: _uuid.v4(),
        title: 'Redeemed 50 Tokens on Order #$orderNum',
        amount: -50,
        type: 'redeemed_reward',
      ));
    }

    final finalTotal = (subtotal + deliveryFee - tokenDiscount).clamp(0.0, double.infinity);
    final tokensEarned = isFree ? 15 : 25;
    final String currencyCode = activeCurrency.code;
    final String currencySymbol = activeCurrency.symbol;
    final secureOtp = '${1000 + (DateTime.now().microsecondsSinceEpoch % 9000)}';

    // Decrement stock in listings
    for (var item in cart) {
      final index = listings.indexWhere((l) => l.id == item.listingId);
      if (index >= 0) {
        final currentListing = listings[index];
        final remaining = (currentListing.quantityRemaining - item.quantity).clamp(0, 999);
        currentListing.quantityRemaining = remaining;
      }
    }

    // Convert items into the selected buyer currency for accurate billing & receipt
    final convertedItems = cart.map((item) {
      final convertedPrice = AppCurrency.convert(
        item.price,
        fromCode: item.currencyCode,
        toCode: activeCurrency.code,
      );
      return OrderItem(
        listingId: item.listingId,
        title: item.title,
        imageUrl: item.imageUrl,
        price: convertedPrice,
        quantity: item.quantity,
        isFreeDonation: item.isFreeDonation,
        sellerId: item.sellerId,
        sellerName: item.sellerName,
        currencyCode: activeCurrency.code,
        currencySymbol: activeCurrency.symbol,
      );
    }).toList();

    final newOrder = Order(
      id: _uuid.v4(),
      orderNumber: orderNum,
      userId: currentUser.id,
      userName: currentUser.name,
      sellerId: cart.isNotEmpty ? cart.first.sellerId : 'seller_greencrust',
      sellerName: cart.isNotEmpty ? cart.first.sellerName : 'Green Crust Bakery',
      isFreeDonation: isFree,
      items: convertedItems,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      tokenDiscount: tokenDiscount,
      finalTotal: finalTotal,
      tokensEarned: tokensEarned,
      fulfilmentMethod: fulfilmentMethod,
      deliveryAddress: deliveryAddress ?? currentUser.address,
      contactPhone: currentUser.phone ?? '+1 (555) 234-5678',
      dietaryNotes: dietaryNotes,
      status: OrderStatus.confirmed,
      handoverCode: secureOtp,
      deliveryOtp: secureOtp,
      isOtpVerified: false,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );

    orders.insert(0, newOrder);

    // Save booking details in Firebase Firestore & MongoDB Atlas & local persistence (Requirement D1)
    FirebaseAuthService().saveBookingToFirestore(newOrder);
    MongoApiService().saveOrder(newOrder);

    // Award tokens and impact metrics to user
    final totalPortions = cart.fold<int>(0, (sum, item) => sum + item.quantity);
    currentUser = currentUser.copyWith(
      greenTokenBalance: currentUser.greenTokenBalance + tokensEarned,
      impactScore: currentUser.impactScore + tokensEarned,
      foodRescuedKg: currentUser.foodRescuedKg + (totalPortions * 0.6),
      mealsDonated: isFree ? currentUser.mealsDonated + totalPortions : currentUser.mealsDonated,
      co2AvoidedKg: currentUser.co2AvoidedKg + (totalPortions * 1.2),
    );
    if (!currentUser.isDemo) {
      FirebaseAuthService().cacheUserLocally(currentUser);
      FirebaseAuthService().saveUserProfileToFirestore(currentUser);
    }
    tokenLedger.insert(0, TokenTransaction(
      id: _uuid.v4(),
      title: isFree ? 'A Little Care Given: #$orderNum' : 'Rescued Meal: #$orderNum',
      amount: tokensEarned,
      type: isFree ? 'earned_donation' : 'earned_rescue',
    ));

    // Automatically create an eligible delivery task for the Delivery Boy account!
    final deliveryTask = DeliveryTask(
      id: _uuid.v4(),
      orderId: newOrder.id,
      orderNumber: newOrder.orderNumber,
      isFreeDonation: isFree,
      isNgoRequest: false,
      donorName: newOrder.sellerName,
      donorAddress: '108 Artisan Alley, Old Town',
      customerName: newOrder.userName,
      customerAddress: newOrder.deliveryAddress ?? (fulfilmentMethod == FulfilmentMethod.delivery ? '742 Evergreen Terrace' : 'Store Pickup (${newOrder.sellerName})'),
      customerPhone: newOrder.contactPhone,
      itemsSummary: newOrder.itemsSummary,
      totalAmountFormatted: newOrder.formattedTotal,
      pickupCode: '${2000 + (orders.length * 19) % 8000}',
      handoverCode: secureOtp,
      distanceKm: 2.5,
      rewardTokens: isFree ? 45 : 35,
      notes: isFree
          ? 'Community Care Meal (Priority Free Handover).'
          : 'Food Buyer Order: ${newOrder.itemsSummary}.',
    );
    deliveryTasks.insert(0, deliveryTask);

    final confirmedNotification = AppNotification(
      id: _uuid.v4(),
      title: isFree
          ? '💚 Care Booking Confirmed (#${newOrder.orderNumber})'
          : '🎉 Booking Confirmed (#${newOrder.orderNumber})',
      message:
          '${newOrder.itemsSummary} from ${newOrder.sellerName} reserved (${isFree ? 'FREE' : '$currencySymbol${newOrder.finalTotal.toStringAsFixed(2)}'}). Handover OTP: $secureOtp.',
      type: 'order',
      orderId: newOrder.id,
      orderNumber: newOrder.orderNumber,
    );

    notifications.insert(0, confirmedNotification);
    activeBannerNotification = confirmedNotification;
    FirebaseAuthService().saveNotificationToFirestore(confirmedNotification, currentUser.id);

    clearCart();
    notifyListeners();
    return newOrder;
  }

  /// Trigger a Booking Pickup / Delivery Reminder notification on the mobile device (Requirement D2)
  AppNotification sendBookingReminder([Order? targetOrder]) {
    final order = targetOrder ??
        (orders.isNotEmpty
            ? orders.firstWhere(
                (o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.completed,
                orElse: () => orders.first,
              )
            : null);

    final orderNum = order?.orderNumber ?? 'KP-1002';
    final seller = order?.sellerName ?? 'Green Crust Bakery';
    final code = order?.handoverCode ?? '1073';
    final method = order?.fulfilmentMethod == FulfilmentMethod.delivery
        ? 'Volunteer Delivery arriving in ~12 mins'
        : 'Counter Pickup ready before 8:30 PM';

    final reminder = AppNotification(
      id: _uuid.v4(),
      title: '⏰ Booking Reminder • Order #$orderNum',
      message: 'Reminder: Your rescue order from $seller ($method). Present handover code $code.',
      type: 'reminder',
      orderId: order?.id,
      orderNumber: orderNum,
    );

    notifications.insert(0, reminder);
    activeBannerNotification = reminder;
    FirebaseAuthService().saveNotificationToFirestore(reminder, currentUser.id);
    notifyListeners();
    return reminder;
  }

  void dismissBannerNotification() {
    if (activeBannerNotification != null) {
      activeBannerNotification = null;
      notifyListeners();
    }
  }

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  /// Cancel an active booking / order and restore stock & tokens
  bool cancelOrder(String orderId, {String? reason}) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return false;

    final order = orders[idx];
    if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
      return false;
    }

    order.status = OrderStatus.cancelled;
    FirebaseAuthService().updateBookingStatusInFirestore(
      order.id,
      order.userId,
      OrderStatus.cancelled,
    );

    // Restore stock in listings
    for (final item in order.items) {
      final listingIdx = listings.indexWhere((l) => l.id == item.listingId);
      if (listingIdx >= 0) {
        listings[listingIdx].quantityRemaining += item.quantity;
      }
    }

    // Remove any pending volunteer delivery task for this order
    deliveryTasks.removeWhere((t) => t.orderId == order.id && t.status != DeliveryStatus.delivered);

    // Adjust tokens (refund redeemed tokens if any, reverse earned tokens)
    final redeemedRefund = order.tokenDiscount > 0 ? 50 : 0;
    final netTokenAdjustment = redeemedRefund - order.tokensEarned;
    currentUser = currentUser.copyWith(
      greenTokenBalance: (currentUser.greenTokenBalance + netTokenAdjustment).clamp(0, 999999),
    );
    if (!currentUser.isDemo) {
      FirebaseAuthService().cacheUserLocally(currentUser);
      FirebaseAuthService().saveUserProfileToFirestore(currentUser);
    }

    final cancelNotif = AppNotification(
      id: _uuid.v4(),
      title: '❌ Booking Cancelled (#${order.orderNumber})',
      message: 'Order #${order.orderNumber} from ${order.sellerName} was cancelled and portions returned to inventory.',
      type: 'order',
      orderId: order.id,
      orderNumber: order.orderNumber,
    );
    notifications.insert(0, cancelNotif);
    activeBannerNotification = cancelNotif;

    notifyListeners();
    return true;
  }

  // Seller Actions
  void addListing(FoodListing newListing) {
    listings.insert(0, newListing);
    MongoApiService().saveListing(newListing);
    notifications.insert(0, AppNotification(
      id: _uuid.v4(),
      title: '🌿 New Listing Active',
      message: '${newListing.title} is now visible to food rescue heroes!',
      type: 'info',
    ));
    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      orders[idx].status = status;
      MongoApiService().updateOrderStatus(orderId, status.name);
      notifyListeners();
    }
  }

  void updateListingQuantity(String listingId, int delta) {
    final idx = listings.indexWhere((l) => l.id == listingId);
    if (idx >= 0) {
      final updated = (listings[idx].quantityRemaining + delta).clamp(0, 999);
      listings[idx].quantityRemaining = updated;
      MongoApiService().saveListing(listings[idx]);
      notifyListeners();
    }
  }

  void toggleListingFreeDonation(String listingId) {
    final idx = listings.indexWhere((l) => l.id == listingId);
    if (idx >= 0) {
      final current = listings[idx];
      final newIsFree = !current.isFreeDonation;
      listings[idx] = current.copyWith(
        isFreeDonation: newIsFree,
        discountedPrice: newIsFree ? 0.0 : (current.originalPrice * 0.45),
      );
      MongoApiService().saveListing(listings[idx]);
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: newIsFree ? '💚 Care Food Donation Active' : '🏷️ Listing Set to Discounted Surplus',
        message: newIsFree 
            ? '${current.title} is now 100% free for community care pickup!'
            : '${current.title} is now listed at surplus discounted pricing.',
        type: 'info',
      ));
      notifyListeners();
    }
  }

  void removeListing(String listingId) {
    listings.removeWhere((l) => l.id == listingId);
    MongoApiService().deleteListing(listingId);
    notifications.insert(0, AppNotification(
      id: _uuid.v4(),
      title: '🗑️ Listing Archived',
      message: 'Item has been removed from active customer visibility.',
      type: 'info',
    ));
    notifyListeners();
  }

  void extendListingDeadline(String listingId, Duration duration) {
    final idx = listings.indexWhere((l) => l.id == listingId);
    if (idx >= 0) {
      final current = listings[idx];
      final newDeadline = current.collectionDeadline.add(duration);
      listings[idx] = current.copyWith(
        collectionDeadline: newDeadline,
      );
      notifyListeners();
    }
  }

  void toggleListingPause(String listingId) {
    final idx = listings.indexWhere((l) => l.id == listingId);
    if (idx >= 0) {
      listings[idx].isPaused = !listings[idx].isPaused;
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: listings[idx].isPaused ? '⏸️ Listing Paused' : '▶️ Listing Resumed',
        message: '${listings[idx].title} is now ${listings[idx].isPaused ? "hidden from buyers" : "active and visible"}.',
        type: 'info',
      ));
      notifyListeners();
    }
  }

  void updateListing(FoodListing updated) {
    final idx = listings.indexWhere((l) => l.id == updated.id);
    if (idx >= 0) {
      listings[idx] = updated;
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: '✏️ Listing Updated',
        message: '${updated.title} details have been updated.',
        type: 'info',
      ));
      notifyListeners();
    }
  }

  SellerProfile get currentSellerProfile {
    return sellers.firstWhere(
      (s) => s.userId == currentUser.id || s.id == 'seller_greenleaf',
      orElse: () => sellers.first,
    );
  }

  void addRestaurantFoodImage(String sellerId, String imageUrl) {
    final idx = sellers.indexWhere((s) => s.id == sellerId);
    if (idx >= 0) {
      final s = sellers[idx];
      final updatedImages = List<String>.from(s.foodImages)..add(imageUrl);
      sellers[idx] = s.copyWith(foodImages: updatedImages);
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: '📸 New Food Image Added',
        message: 'Added fresh food image to ${s.businessName} gallery!',
        type: 'info',
      ));
      notifyListeners();
    }
  }

  void removeRestaurantFoodImage(String sellerId, int imageIndex) {
    final idx = sellers.indexWhere((s) => s.id == sellerId);
    if (idx >= 0) {
      final s = sellers[idx];
      if (imageIndex >= 0 && imageIndex < s.foodImages.length) {
        final updatedImages = List<String>.from(s.foodImages)..removeAt(imageIndex);
        sellers[idx] = s.copyWith(foodImages: updatedImages);
        notifyListeners();
      }
    }
  }

  void updateRestaurantCoverImage(String sellerId, String imageUrl) {
    final idx = sellers.indexWhere((s) => s.id == sellerId);
    if (idx >= 0) {
      sellers[idx] = sellers[idx].copyWith(coverImageUrl: imageUrl);
      notifyListeners();
    }
  }

  void updateSellerProfile(SellerProfile updated) {
    final idx = sellers.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      sellers[idx] = updated;
      notifyListeners();
    }
  }

  bool verifyOrderHandoverCode(String orderId, String inputCode) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      final order = orders[idx];
      if (order.handoverCode.trim() == inputCode.trim()) {
        order.status = OrderStatus.completed;
        // Award donor tokens
        currentUser = currentUser.copyWith(
          greenTokenBalance: currentUser.greenTokenBalance + 30,
        );
        tokenLedger.insert(0, TokenTransaction(
          id: _uuid.v4(),
          title: 'Rescued Handover Verified: #${order.orderNumber}',
          amount: 30,
          type: 'earned_rescue',
        ));
        notifications.insert(0, AppNotification(
          id: _uuid.v4(),
          title: '🎉 Order Handover Complete!',
          message: 'Order #${order.orderNumber} successfully handed to ${order.userName}. +30 Green Tokens awarded!',
          type: 'order',
        ));
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  FoodListing autoListAIPrediction() {
    final predictionItem = FoodListing(
      id: _uuid.v4(),
      sellerId: 'seller_greencrust',
      sellerName: 'Green Crust Bakery',
      sellerType: 'Artisan Bakery & Patisserie',
      title: 'Artisan Baguettes & Almond Croissant Rescue Pack',
      description: 'Golden crust sourdough baguettes and double-baked almond croissants baked fresh today.',
      category: FoodCategory.bakery,
      imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=1200&q=85',
      originalPrice: 16.00,
      discountedPrice: 7.20,
      isFreeDonation: false,
      quantityRemaining: 11,
      portionSize: '11 portions (Pack of 3 baguettes + 2 croissants)',
      ingredients: const ['French unbleached flour', 'Levain starter', 'Normandy butter', 'Almonds', 'Sea salt'],
      allergens: const ['Gluten', 'Nuts', 'Dairy'],
      dietaryTags: const [DietaryTag.vegetarian],
      collectionTimeWindow: 'Today, 5:30 PM - 8:00 PM',
      collectionDeadline: DateTime.now().add(const Duration(hours: 3)),
      pickupAddress: '108 Artisan Alley, Old Town',
      urgencyLevel: UrgencyLevel.urgentRescue,
    );

    listings.insert(0, predictionItem);
    notifications.insert(0, AppNotification(
      id: _uuid.v4(),
      title: '✨ AI Prediction Auto-Listed!',
      message: '11 items of Baguettes & Almond Croissants are live at 55% off (5:30 PM - 8:00 PM window).',
      type: 'info',
    ));
    notifyListeners();
    return predictionItem;
  }

  void dispatchBulkNGO({
    required String shelterName,
    required int mealCount,
    required String foodDescription,
  }) {
    final taskId = _uuid.v4();
    final taskNum = 'BULK-${100 + deliveryTasks.length + 1}';
    final newTask = DeliveryTask(
      id: taskId,
      orderId: _uuid.v4(),
      orderNumber: taskNum,
      isFreeDonation: true,
      donorName: 'Green Crust Bakery',
      donorAddress: '108 Artisan Alley, Old Town',
      customerName: shelterName,
      customerAddress: '$shelterName Community Center',
      pickupCode: '${3000 + (deliveryTasks.length * 27) % 6000}',
      handoverCode: '${4000 + (deliveryTasks.length * 31) % 5000}',
      distanceKm: 1.8,
      rewardTokens: 50,
      notes: 'BULK SHELTER DISPATCH: $mealCount portions of $foodDescription.',
    );

    deliveryTasks.insert(0, newTask);
    currentUser = currentUser.copyWith(
      greenTokenBalance: currentUser.greenTokenBalance + 40,
    );
    tokenLedger.insert(0, TokenTransaction(
      id: _uuid.v4(),
      title: 'Bulk Shelter Redistribution: $shelterName',
      amount: 40,
      type: 'earned_donation',
    ));
    notifications.insert(0, AppNotification(
      id: _uuid.v4(),
      title: '🤝 Bulk Shelter Dispatch Created!',
      message: '$mealCount portions dispatched to $shelterName. Volunteer courier alert broadcasted!',
      type: 'info',
    ));
    notifyListeners();
  }

  // NGO Community Hub Actions (Inside Food Donor Account)
  void submitBulkRequest(BulkFoodRequest request) {
    bulkRequests.insert(0, request);

    // Automatically create an NGO delivery task for the Delivery Boy account!
    final bulkTask = DeliveryTask(
      id: _uuid.v4(),
      orderId: request.id,
      orderNumber: 'NGO-${request.id.substring(request.id.length > 4 ? request.id.length - 4 : 0).toUpperCase()}',
      isFreeDonation: true,
      isNgoRequest: true,
      donorName: request.donorName ?? 'Green Crust Bakery',
      donorAddress: '108 Artisan Alley, Old Town',
      customerName: request.organizationName ?? request.requesterName,
      customerAddress: request.destinationAddress,
      customerPhone: '+1 (555) 789-0123',
      itemsSummary: '${request.quantity} portions of ${request.foodType}',
      totalAmountFormatted: 'FREE (NGO Care)',
      pickupCode: '${3000 + (deliveryTasks.length * 27) % 6000}',
      handoverCode: '${4000 + (deliveryTasks.length * 31) % 5000}',
      distanceKm: 2.8,
      rewardTokens: 50,
      notes: 'NGO Community Care Request: ${request.quantity} portions for ${request.numberOfPeople} people. ${request.notes ?? ""}',
    );
    deliveryTasks.insert(0, bulkTask);

    final notif = AppNotification(
      id: _uuid.v4(),
      title: '📦 New Care Community Request',
      message: '${request.requesterName} requested ${request.quantity} portions of ${request.foodType}.',
      type: 'donation',
    );
    notifications.insert(0, notif);
    activeBannerNotification = notif;
    notifyListeners();
  }

  void acceptBulkRequest(String requestId) {
    final idx = bulkRequests.indexWhere((r) => r.id == requestId);
    if (idx >= 0) {
      final req = bulkRequests[idx];
      req.status = BulkRequestStatus.accepted;

      // If delivery is needed, dispatch task to delivery partners
      if (req.isDelivery) {
        deliveryTasks.insert(0, DeliveryTask(
          id: _uuid.v4(),
          orderId: req.id,
          orderNumber: 'BULK-${req.id.substring(req.id.length > 4 ? req.id.length - 4 : 0).toUpperCase()}',
          isFreeDonation: true,
          donorName: req.donorName ?? 'Green Crust Bakery',
          donorAddress: '108 Artisan Alley, Old Town',
          customerName: req.organizationName ?? req.requesterName,
          customerAddress: req.destinationAddress,
          pickupCode: '${3000 + (deliveryTasks.length * 27) % 6000}',
          handoverCode: '${4000 + (deliveryTasks.length * 31) % 5000}',
          distanceKm: 2.8,
          rewardTokens: 50,
          notes: 'NGO Community Hub bulk delivery: ${req.quantity} portions for ${req.numberOfPeople} people.',
        ));
      }

      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: '✅ Care Community Request Accepted',
        message: 'You accepted ${req.quantity} portions for ${req.organizationName ?? req.requesterName}.',
        type: 'donation',
      ));
      notifyListeners();
    }
  }

  void rejectBulkRequest(String requestId, [String? reason]) {
    final idx = bulkRequests.indexWhere((r) => r.id == requestId);
    if (idx >= 0) {
      final req = bulkRequests[idx];
      req.status = BulkRequestStatus.rejected;
      req.rejectionReason = reason ?? 'Capacity reached for requested time';
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: 'Request Declined',
        message: 'Request from ${req.requesterName} has been declined.',
        type: 'info',
      ));
      notifyListeners();
    }
  }

  // Volunteer Actions
  void acceptDeliveryTask(String taskId) {
    final idx = deliveryTasks.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      deliveryTasks[idx].status = DeliveryStatus.accepted;
      deliveryTasks[idx].courierId = currentUser.id;
      deliveryTasks[idx].courierName = currentUser.name;
      notifyListeners();
    }
  }

  void updateDeliveryStatus(String taskId, DeliveryStatus status) {
    final idx = deliveryTasks.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      deliveryTasks[idx].status = status;
      if (status == DeliveryStatus.delivered) {
        // Award volunteer tokens
        currentUser = currentUser.copyWith(
          greenTokenBalance: currentUser.greenTokenBalance + deliveryTasks[idx].rewardTokens,
        );
        tokenLedger.insert(0, TokenTransaction(
          id: _uuid.v4(),
          title: 'Delivery completed: #${deliveryTasks[idx].orderNumber}',
          amount: deliveryTasks[idx].rewardTokens,
          type: 'earned_delivery',
        ));
      }
      notifyListeners();
    }
  }

  bool verifyDeliveryOtp(String taskId, String enteredOtp) {
    final tIdx = deliveryTasks.indexWhere((t) => t.id == taskId);
    if (tIdx < 0) return false;
    final task = deliveryTasks[tIdx];

    if (task.handoverCode.trim() == enteredOtp.trim()) {
      task.status = DeliveryStatus.delivered;

      // Update related order
      final oIdx = orders.indexWhere((o) => o.id == task.orderId || o.orderNumber == task.orderNumber);
      if (oIdx >= 0) {
        orders[oIdx].status = OrderStatus.completed;
        orders[oIdx].isOtpVerified = true;
      }

      currentUser = currentUser.copyWith(
        greenTokenBalance: currentUser.greenTokenBalance + task.rewardTokens,
      );
      tokenLedger.insert(0, TokenTransaction(
        id: _uuid.v4(),
        title: 'Delivery Handover OTP Verified: #${task.orderNumber}',
        amount: task.rewardTokens,
        type: 'earned_delivery',
      ));
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: '🎉 Delivery Completed & Verified!',
        message: 'Order #${task.orderNumber} successfully delivered to ${task.customerName}. +${task.rewardTokens} Green Tokens awarded! Customer rating prompt is active.',
        type: 'delivery',
      ));
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Rates a delivery partner for an order
  void rateDeliveryPartner({
    required String orderId,
    required double rating,
    required String feedback,
    List<String> tags = const [],
  }) {
    // 1. Update Order
    final oIdx = orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (oIdx >= 0) {
      orders[oIdx].courierRating = rating;
      orders[oIdx].courierFeedback = feedback;
      orders[oIdx].courierRatingTags = tags;
      orders[oIdx].isCourierRated = true;
    }

    // 2. Update Delivery Task
    final tIdx = deliveryTasks.indexWhere((t) => t.orderId == orderId || t.orderNumber == orderId);
    if (tIdx >= 0) {
      deliveryTasks[tIdx].customerRating = rating;
      deliveryTasks[tIdx].customerFeedback = feedback;
      deliveryTasks[tIdx].ratingTags = tags;
      deliveryTasks[tIdx].isRatingSubmitted = true;
    }

    notifications.insert(0, AppNotification(
      id: _uuid.v4(),
      title: '⭐ Delivery Boy Rated: ${rating.toStringAsFixed(1)} Stars!',
      message: 'Customer submitted rating: "$feedback" ${tags.isNotEmpty ? "(${tags.join(", ")})" : ""}',
      type: 'reward',
    ));
    notifyListeners();
  }

  void _syncDeliveryTasks() {
    // Sync buyer orders
    for (final order in orders) {
      final exists = deliveryTasks.any((t) => t.orderId == order.id || t.orderNumber == order.orderNumber);
      if (!exists) {
        deliveryTasks.add(DeliveryTask(
          id: _uuid.v4(),
          orderId: order.id,
          orderNumber: order.orderNumber,
          isFreeDonation: order.isFreeDonation,
          isNgoRequest: false,
          donorName: order.sellerName,
          donorAddress: '108 Artisan Alley, Old Town',
          customerName: order.userName,
          customerAddress: order.deliveryAddress ?? '742 Evergreen Terrace',
          customerPhone: order.contactPhone,
          itemsSummary: order.itemsSummary,
          totalAmountFormatted: order.formattedTotal,
          pickupCode: '8491',
          handoverCode: order.handoverCode,
          distanceKm: 2.4,
          rewardTokens: 35,
          status: order.status == OrderStatus.completed ? DeliveryStatus.delivered : DeliveryStatus.available,
          notes: 'Food Buyer Order: ${order.itemsSummary}',
        ));
      }
    }

    // Sync NGO bulk requests
    for (final req in bulkRequests) {
      final exists = deliveryTasks.any((t) => t.orderId == req.id);
      if (!exists) {
        deliveryTasks.add(DeliveryTask(
          id: _uuid.v4(),
          orderId: req.id,
          orderNumber: 'NGO-${req.id.substring(req.id.length > 4 ? req.id.length - 4 : 0).toUpperCase()}',
          isFreeDonation: true,
          isNgoRequest: true,
          donorName: req.donorName ?? 'Green Crust Bakery',
          donorAddress: '108 Artisan Alley, Old Town',
          customerName: req.organizationName ?? req.requesterName,
          customerAddress: req.destinationAddress,
          customerPhone: '+1 (555) 789-0123',
          itemsSummary: '${req.quantity} portions of ${req.foodType}',
          totalAmountFormatted: 'FREE (NGO Care)',
          pickupCode: '3128',
          handoverCode: '4920',
          distanceKm: 2.8,
          rewardTokens: 50,
          status: req.status == BulkRequestStatus.completed ? DeliveryStatus.delivered : DeliveryStatus.available,
          notes: 'NGO Community Care Request: ${req.quantity} portions for ${req.numberOfPeople} people.',
        ));
      }
    }
  }

  void updateVolunteerLocation(String taskId, double lat, double lng) {
    final idx = deliveryTasks.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      deliveryTasks[idx].currentLat = lat;
      deliveryTasks[idx].currentLng = lng;
      deliveryTasks[idx].lastLocationUpdate = DateTime.now();
      notifyListeners();
    }
  }

  // Rewards Redemption
  bool redeemReward(RewardItem reward) {
    if (currentUser.greenTokenBalance >= reward.tokenCost) {
      currentUser = currentUser.copyWith(
        greenTokenBalance: currentUser.greenTokenBalance - reward.tokenCost,
      );
      tokenLedger.insert(0, TokenTransaction(
        id: _uuid.v4(),
        title: 'Redeemed: ${reward.title}',
        amount: -reward.tokenCost,
        type: 'redeemed_reward',
      ));
      notifications.insert(0, AppNotification(
        id: _uuid.v4(),
        title: '🎁 Reward Redeemed!',
        message: 'Your voucher code for ${reward.title} is KP-GIFT-${(1000 + DateTime.now().millisecond)}',
        type: 'reward',
      ));
      notifyListeners();
      return true;
    }
    return false;
  }

  // AI Assistant Chat Interaction
  Future<void> sendAIMessage(String text) async {
    aiChatMessages.add(AIChatMessage(text: text, isUser: true));
    isAILoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 650));

    String reply = '';
    List<String> suggestions = [
      "Find surplus bakery deals",
      "Where can I get free food donations?",
      "How do Green Tokens work?",
      "Zero-waste recipe from leftovers",
    ];

    final lower = text.toLowerCase();
    if (lower.contains('free') || lower.contains('donation') || lower.contains('need') || lower.contains('hungry')) {
      reply = "KindPlate provides 100% free food donations with \$0 cost and zero tokens required. Right now we have organic fresh produce crates from Sunbeam Community Farm and warm lentil bowls from Harvest Hope Kitchen available! You can choose pickup or volunteer delivery.";
      suggestions = ["Request free produce crate", "View warm lentil bowls", "How volunteer delivery works"];
    } else if (lower.contains('recipe') || lower.contains('leftover') || lower.contains('cook') || lower.contains('make')) {
      reply = "Chef Leaf's Zero-Waste Kitchen Tips 🌿:\n1. Stale Sourdough: Toss with olive oil, garlic & tomatoes for an Italian Panzanella salad!\n2. Soft Bananas: Mash into cinnamon oat pancakes or freeze for creamy smoothies.\n3. Vegetable Scraps: Simmer celery, onion peels & carrot tops for a rich golden veggie broth!\nWhat ingredients are in your fridge?";
      suggestions = ["Recipes for ripe fruit", "What to do with day-old bread", "Vegetable stock guide"];
    } else if (lower.contains('volunteer') || lower.contains('courier') || lower.contains('deliver') || lower.contains('drive')) {
      reply = "KindPlate Volunteer Couriers bridge the gap between food donors and vulnerable neighbors! When you accept and complete a delivery task, you earn +35 to +50 Green Tokens per run, plus carbon offset badges. You can choose walking, bicycle, or car routes.";
      suggestions = ["View available delivery tasks", "How to become a verified courier", "Check Green Token rewards"];
    } else if (lower.contains('vegan') || lower.contains('bakery') || lower.contains('croissant') || lower.contains('bread') || lower.contains('cake')) {
      reply = "I found Green Crust Bakery nearby! They have an Artisan Sourdough & Almond Croissant Basket at 64% off (\$6.50 down from \$18.00). It's ending in under 3 hours, so rescue it quickly!";
      suggestions = ["View Green Crust Bakery deals", "Check dietary filters", "Explore urgent rescue radar"];
    } else if (lower.contains('predict') || lower.contains('surplus') || lower.contains('waste') || lower.contains('radar')) {
      reply = "Our Surplus Prediction algorithm calculates that bakeries in your area face a 52% surplus spike on Friday evenings due to customer commute patterns. We recommend listing 10-12 portions by 5:15 PM at 50% discount to achieve a 95% rescue rate.";
      suggestions = ["1-Tap Auto-List prediction", "View surplus trends chart", "How confidence score works"];
    } else if (lower.contains('token') || lower.contains('reward') || lower.contains('green') || lower.contains('point')) {
      final bal = currentUser.greenTokenBalance;
      reply = "You currently have $bal Green Tokens! 🌿 You earn tokens with every surplus meal rescued (+25), free donation given (+15), or volunteer delivery (+35). Tokens unlock free delivery passes, discounts, organic merch, and real tree planting with Eden Reforestation!";
      suggestions = ["Redeem a tree planting", "Get \$2 order discount voucher", "Explore Green Rewards shop"];
    } else if (lower.contains('ngo') || lower.contains('shelter') || lower.contains('charity') || lower.contains('bulk')) {
      reply = "NGO & Community Kitchens receive priority bulk dispatches from restaurants and supermarkets. You can schedule recurring pickups, accept pallet-sized donations, and assign volunteer drivers directly through the Partner Portal.";
      suggestions = ["Schedule shelter batch pickup", "View registered charities", "Request bulk bakery surplus"];
    } else {
      reply = "KindPlate connects surplus food from local restaurants and home bakers to hungry neighbors and communities. Whether you're looking for discounted deals, requesting free care meals, or helping deliver food, every bite saved helps the planet! What would you like to explore next?";
    }

    aiChatMessages.add(AIChatMessage(
      text: reply,
      isUser: false,
      actionSuggestions: suggestions,
    ));
    isAILoading = false;
    notifyListeners();
  }

  void clearAIChat() {
    aiChatMessages = [
      AIChatMessage(
        text: "Hello! I am KindPlate AI, your leaf-powered companion. 🌿 How can I help you save food, find a free meal, or reduce kitchen surplus today?",
        isUser: false,
        actionSuggestions: [
          "Find vegan bakery surplus near me",
          "Where can I get free food donations?",
          "How do Green Tokens work?",
          "Zero-waste recipe from leftovers",
        ],
      )
    ];
    notifyListeners();
  }
}
