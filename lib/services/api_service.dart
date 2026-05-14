import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Replace with your actual IP address for emulator (e.g., 10.0.2.2 for Android)
  // or your machine's LAN IP if running on physical device (e.g., 192.168.1.X).
  // Current IP: 192.168.137.202 (from ipconfig - Wi-Fi adapter)
  static const String baseUrl = 'http://192.168.137.1:8080/api';

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
      }
      return response;
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data['message'] ?? e.response?.data['errors']?.toString() ?? e.message;
        print('Login Error Details: $message');
      }
      rethrow;
    }
  }

  Future<Response?> signup({
    required String email,
    required String password,
    required String businessName,
    required String businessType,
    String? pin,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await _dio.post(
        '/register',
        data: {
          'email': cleanEmail,
          'password': password,
          'password_confirmation': password,
          'name': businessName,
          'business_name': businessName,
          'business_type': businessType,
          'device_name': 'mobile_app',
          if (pin != null) 'pin': pin,
        },
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
        print('Signup Error Details: $message');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user');
    _dio.options.headers.remove('Authorization');
    print('🔑 [API] Token and user data removed from storage and headers');
  }

  Future<Response?> updatePin(String pin) async {
    try {
      return await _dio.post('/user/update-pin', data: {'pin': pin});
    } catch (e) {
      print('❌ [API] Failed to update PIN: $e');
      rethrow;
    }
  }

  Future<Response?> updateProfile(Map<String, dynamic> data) async {
    try {
      return await _dio.post('/user/update-profile', data: data);
    } catch (e) {
      print('❌ [API] Failed to update profile: $e');
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
      print('✅ [API] deleteBankAccount($id) → ${response.statusCode} ${response.data}');
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      print('❌ [API] deleteBankAccount($id) failed → status: ${e.response?.statusCode}, body: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw '404'; // Special case for UI
      }
      return false;
    } catch (e) {
      print('❌ [API] deleteBankAccount($id) unexpected error: $e');
      rethrow;
    }
  }

  Future<bool> updateBankAccount(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/bank-accounts/$id', data: data);
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('❌ [API] updateBankAccount failed: $e');
      return false;
    }
  }
}
