import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/food_listing_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

/// Service for interacting with the KindPlate Node.js + MongoDB Atlas backend
class MongoApiService {
  static final MongoApiService _instance = MongoApiService._internal();
  factory MongoApiService() => _instance;
  MongoApiService._internal();

  /// Resolve API base URL based on platform
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5001/api';
      default:
        return 'http://localhost:5001/api';
    }
  }

  /// Check backend and MongoDB Atlas connectivity status
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'status': 'error',
        'message': 'HTTP error ${response.statusCode}',
        'database': {'connected': false},
      };
    } catch (e) {
      return {
        'status': 'offline',
        'message': 'Backend server not reachable at $baseUrl ($e)',
        'database': {'connected': false},
      };
    }
  }

  /// Upsert user profile in MongoDB Atlas (CRUD: Create/Update)
  Future<bool> syncUserProfile(UserProfile user) async {
    try {
      final payload = {
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'role': user.role.name,
        'phone': user.phone,
        'avatarUrl': user.avatarUrl,
        'address': user.address,
        'city': user.city,
        'badgeLevel': user.badgeLevel.name,
        'impactScore': user.impactScore,
        'foodRescuedKg': user.foodRescuedKg,
        'mealsDonated': user.mealsDonated,
        'co2AvoidedKg': user.co2AvoidedKg,
        'greenTokenBalance': user.greenTokenBalance,
        'dietaryPreferences': user.dietaryPreferences,
        'allergensDeclared': user.allergensDeclared,
        'verified': user.verified,
        'isDemo': user.isDemo,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] User sync note: $e');
      return false;
    }
  }

  /// Fetch user profile from MongoDB Atlas (CRUD: Read)
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/users/$userId'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data != null) {
          return UserProfile(
            id: data['id'] ?? userId,
            email: data['email'] ?? '',
            name: data['name'] ?? '',
            role: UserRole.values.firstWhere(
              (r) => r.name == data['role'],
              orElse: () => UserRole.buyer,
            ),
            phone: data['phone'],
            avatarUrl: data['avatarUrl'],
            address: data['address'],
            city: data['city'],
            badgeLevel: BadgeLevel.values.firstWhere(
              (b) => b.name == data['badgeLevel'],
              orElse: () => BadgeLevel.sprout,
            ),
            impactScore: (data['impactScore'] as num?)?.toInt() ?? 0,
            foodRescuedKg: (data['foodRescuedKg'] as num?)?.toDouble() ?? 0.0,
            mealsDonated: (data['mealsDonated'] as num?)?.toInt() ?? 0,
            co2AvoidedKg: (data['co2AvoidedKg'] as num?)?.toDouble() ?? 0.0,
            greenTokenBalance: (data['greenTokenBalance'] as num?)?.toInt() ?? 50,
            dietaryPreferences: (data['dietaryPreferences'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            allergensDeclared: (data['allergensDeclared'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            verified: data['verified'] == true,
            isDemo: data['isDemo'] == true,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Get user note: $e');
      return null;
    }
  }

  /// Fetch public food listings from MongoDB Atlas (CRUD: Read - Accessible to all users)
  Future<List<FoodListing>> getListings({
    String? category,
    bool? isFreeDonation,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (isFreeDonation != null) {
        queryParams['isFreeDonation'] = isFreeDonation.toString();
      }
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/listings').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final List items = decoded['data'] ?? [];
        return items
            .map((item) => FoodListing.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Fetch listings note: $e');
      return [];
    }
  }

  /// Save or update a food listing in MongoDB Atlas (CRUD: Create/Update)
  Future<bool> saveListing(FoodListing listing) async {
    try {
      final payload = listing.toMap();

      final response = await http
          .post(
            Uri.parse('$baseUrl/listings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Save listing note: $e');
      return false;
    }
  }

  /// Delete a food listing from MongoDB Atlas (CRUD: Delete)
  Future<bool> deleteListing(String listingId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/listings/$listingId'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Delete listing note: $e');
      return false;
    }
  }

  /// Save a new order / booking in MongoDB Atlas (CRUD: Create)
  Future<bool> saveOrder(Order order) async {
    try {
      final payload = order.toMap();

      final response = await http
          .post(
            Uri.parse('$baseUrl/orders'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Save order note: $e');
      return false;
    }
  }

  /// Fetch user-scoped orders (CRUD: Read - Unique to the buyer/recipient)
  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final uri = Uri.parse('$baseUrl/orders').replace(queryParameters: {'userId': userId});
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final List items = decoded['data'] ?? [];
        return items
            .map((item) => Order.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Fetch user orders note: $e');
      return [];
    }
  }

  /// Fetch seller-scoped orders (CRUD: Read - Unique to the restaurant/baker)
  Future<List<Order>> getSellerOrders(String sellerId) async {
    try {
      final uri = Uri.parse('$baseUrl/orders').replace(queryParameters: {'sellerId': sellerId});
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final List items = decoded['data'] ?? [];
        return items
            .map((item) => Order.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Fetch seller orders note: $e');
      return [];
    }
  }

  /// Update order status in MongoDB Atlas (CRUD: Update)
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/orders/$orderId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Update order status note: $e');
      return false;
    }
  }

  /// Verify 4-digit handover verification code in MongoDB Atlas (CRUD: Update)
  Future<bool> verifyHandover(String orderId, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/$orderId/verify-handover'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Verify handover note: $e');
      return false;
    }
  }

  /// Trigger database seeding in MongoDB Atlas
  Future<bool> triggerSeed() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/seed'))
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ℹ️ [MongoApiService] Trigger seed note: $e');
      return false;
    }
  }
}
