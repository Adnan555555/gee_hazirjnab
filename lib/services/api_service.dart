import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Custom exception for no internet / network errors
class NoInternetException implements Exception {
  final String message;
  NoInternetException([this.message = 'No internet connection. Please check your network.']);
  @override
  String toString() => message;
}

/// Custom exception for generic app errors
class AppException implements Exception {
  final String message;
  AppException([this.message = 'Something went wrong. Please try again.']);
  @override
  String toString() => message;
}

/// API Service - Handles all HTTP requests with auth token management
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add interceptors for token and logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConfig.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // Differentiate network errors from server errors
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: NoInternetException(),
            type: error.type,
          ));
        }
        
        // Handle 401 unauthorized
        if (error.response?.statusCode == 401) {
          // Token expired - could trigger logout here
        }
        
        // For validation errors (422), pass through so the caller can read them
        if (error.response?.statusCode == 422) {
          return handler.next(error);
        }
        
        // For other server errors, wrap in user-friendly message
        return handler.reject(DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          error: AppException(),
          type: error.type,
        ));
      },
    ));
  }
  
  // Token Management
  Future<void> setToken(String token) async {
    await _storage.write(key: AppConfig.tokenKey, value: token);
  }
  
  Future<String?> getToken() async {
    return await _storage.read(key: AppConfig.tokenKey);
  }
  
  Future<void> clearToken() async {
    await _storage.delete(key: AppConfig.tokenKey);
  }
  
  // HTTP Methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _dio.get(path, queryParameters: queryParams);
  }
  
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }
  
  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }
  
  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
  
  // Multipart upload
  Future<Response> uploadFile(String path, String filePath, String fieldName) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    return await _dio.post(path, data: formData);
  }

  // Post Multipart Data
  Future<Response> postMultipart(String path, FormData formData) async {
    return await _dio.post(path, data: formData);
  }
}

