import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

class ApiService {
  // Replace with your actual IP address for emulator (e.g., 10.0.2.2 for Android)
  // or your machine's LAN IP if running on physical device (e.g., 192.168.1.X).
  // Current IP: 192.168.18.47 (from ipconfig - Wi-Fi adapter)
  static const String baseUrl = 'https://pos.sata.pk/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
  ));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
      ),
    );
  }

  Future<Response?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await _dio.post(
        '/login',
        data: {
          'email': cleanEmail,
          'password': password,
          'pin': password,
          'device_name': 'mobile_app',
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(
          key: 'user',
          value: response.data['user'].toString(),
        );
        // Set header immediately for subsequent sync calls
        _dio.options.headers['Authorization'] = 'Bearer $token';
          
        // Pre-fetch terms in background
        getTermsAndConditions().catchError((_) => null);
      }
      return response;
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data['message'] ?? e.response?.data['errors']?.toString() ?? e.message;
        if (kDebugMode) debugPrint('Login Error Details: $message');
      }
      rethrow;
    }
  }

  Future<Response?> signup({
    required String email,
    required String password,
    required String businessName,
    required int businessTypeId,
    required int planId,
    String? name,
    String? phone,
    String? address,
    String? pin,
    File? receipt,
    bool termsAccepted = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      dynamic requestData;
      
      if (receipt != null) {
        requestData = FormData.fromMap({
          'email': cleanEmail,
          'password': password,
          'password_confirmation': password,
          'name': name ?? businessName,
          'business_name': businessName,
          'business_type_id': businessTypeId,
          'plan_id': planId,
          'device_name': 'mobile_app',
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (address != null && address.isNotEmpty) 'address': address,
          if (pin != null) 'pin': pin,
          'receipt': await MultipartFile.fromFile(receipt.path, filename: receipt.path.split('/').last),
          'terms': 1,
        });
      } else {
        requestData = {
          'email': cleanEmail,
          'password': password,
          'password_confirmation': password,
          'name': name ?? businessName,
          'business_name': businessName,
          'business_type_id': businessTypeId,
          'plan_id': planId,
          'device_name': 'mobile_app',
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (address != null && address.isNotEmpty) 'address': address,
          if (pin != null) 'pin': pin,
          'terms': 1,
        };
      }

      final response = await _dio.post(
        '/register',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = response.data['token'];
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(
          key: 'user',
          value: response.data['user'].toString(),
        );
        // Set header immediately for subsequent sync calls
        _dio.options.headers['Authorization'] = 'Bearer $token';
      }
      return response;
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data['message'] ?? e.response?.data['errors']?.toString() ?? e.message;
        if (kDebugMode) {
          debugPrint('Signup Error Details: $message');
          debugPrint('Signup Full Error Response: ${e.response?.data}');
          debugPrint('Signup Status Code: ${e.response?.statusCode}');
        }
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user');
    _dio.options.headers.remove('Authorization');
    if (kDebugMode) debugPrint('🔑 [API] Token and user data removed from storage and headers');
  }

  Future<Response?> updatePin(String pin) async {
    try {
      return await _dio.post('/user/update-pin', data: {'pin': pin});
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to update PIN: $e');
      rethrow;
    }
  }

  Future<Response?> updateProfile(Map<String, dynamic> data) async {
    try {
      return await _dio.post('/user/update-profile', data: data);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to update profile: $e');
      rethrow;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _dio.patch(path, data: data, queryParameters: queryParameters);
  }

  Future<bool> deleteBankAccount(int id) async {
    try {
      final response = await _dio.delete('/bank-accounts/$id');
      if (kDebugMode) debugPrint('✅ [API] deleteBankAccount($id) → ${response.statusCode} ${response.data}');
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('❌ [API] deleteBankAccount($id) failed → status: ${e.response?.statusCode}, body: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw '404'; // Special case for UI
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] deleteBankAccount($id) unexpected error: $e');
      rethrow;
    }
  }

  Future<bool> updateBankAccount(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/bank-accounts/$id', data: data);
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] updateBankAccount failed: $e');
      return false;
    }
  }

  Future<Response?> getBusinessTypes() async {
    try {
      return await _dio.get('/business-types');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to fetch business types: $e');
      return null;
    }
  }

  Future<Response?> uploadReceipt(int subscriptionId, File receipt) async {
    try {
      String fileName = receipt.path.split('/').last;
      FormData formData = FormData.fromMap({
        'receipt': await MultipartFile.fromFile(receipt.path, filename: fileName),
      });

      return await _dio.post('/user/subscription/$subscriptionId/upload-receipt', data: formData);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Receipt upload failed: $e');
      return null;
    }
  }

  Future<Response?> getSubscriptionPlans() async {
    try {
      return await _dio.get('/subscription-plans');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to fetch subscription plans: $e');
      return null;
    }
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      final response = await _dio.get('/user/check-subscription-status');
      return response.data['active'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to check subscription status: $e');
      return false;
    }
  }

  /// Businesses linked to the logged-in admin (user_businesses + owned).
  Future<Response?> getUserBusinesses() async {
    try {
      return await _dio.get('/user/businesses');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to fetch user businesses: $e');
      rethrow;
    }
  }

  Future<Response?> submitFeedback(String message, {String? email}) async {
    try {
      return await _dio.post('/feedback', data: {
        'message': message,
        if (email != null && email.isNotEmpty) 'email': email,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to submit feedback: $e');
      rethrow;
    }
  }

  Future<Response?> submitDeletionRequest(String reason) async {
    try {
      return await _dio.post('/user/deletion-request', data: {
        'type': 'profile',
        'reason': reason
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to submit deletion request: $e');
      rethrow;
    }
  }

  Future<Response?> getDeletionRequestStatus() async {
    try {
      return await _dio.get('/user/deletion-request/status');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to get deletion request status: $e');
      rethrow;
    }
  }

  Future<Response?> cancelDeletionRequest(int requestId) async {
    try {
      return await _dio.post('/user/deletion-request/cancel', data: {
        'request_id': requestId
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to cancel deletion request: $e');
      rethrow;
    }
  }

  static List<dynamic>? cachedTerms;

  Future<Response?> getTermsAndConditions() async {
    try {
      if (cachedTerms != null) {
        return Response(
          requestOptions: RequestOptions(path: '/terms-and-conditions'),
          data: {'data': cachedTerms},
          statusCode: 200,
        );
      }
      final res = await _dio.get('/terms-and-conditions');
      if (res.statusCode == 200) {
        cachedTerms = res.data['data'];
      }
      return res;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [API] Failed to fetch terms and conditions: $e');
      rethrow;
    }
  }
}
