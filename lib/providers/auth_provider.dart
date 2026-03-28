import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../services/notification_service.dart';
import 'package:dio/dio.dart';

/// Auth Provider - Manages authentication state
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  Customer? _customer;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _onboardingComplete = false;
  
  Customer? get customer => _customer;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  bool get onboardingComplete => _onboardingComplete;
  
  // Initialize - check stored auth state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingComplete = prefs.getBool(AppConfig.onboardingKey) ?? false;
    
    final token = await _api.getToken();
    if (token != null) {
      final userData = prefs.getString(AppConfig.userKey);
      if (userData != null) {
        _customer = Customer.fromJson(jsonDecode(userData));
        _isLoggedIn = true;
      }
    }
    notifyListeners();
  }
  
  // Mark onboarding complete
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.onboardingKey, true);
    _onboardingComplete = true;
    notifyListeners();
  }
  
  // Check if customer exists (by phone)
  // API returns: is_profile_complete, customer_type, token, customer_id
  Future<Map<String, dynamic>> checkCustomer(String mobile) async {
    _setLoading(true);
    try {
      final response = await _api.post(
        AppConfig.authCheckCustomer,
        data: {'mobile': mobile},
      );
      
      // Store token if returned (for existing users)
      if (response.data['token'] != null) {
        await _api.setToken(response.data['token']);
      }
      
      // Always store customer_id for use in profile update
      if (response.data['customer_id'] != null) {
        _customer = Customer(
          id: response.data['customer_id'],
          mobile: mobile,
        );
      }
      
      // If profile is complete, store full customer data
      if (response.data['is_profile_complete'] == true && 
          response.data['customer_data'] != null) {
        _customer = Customer.fromJson(response.data['customer_data']);
        _customer = _customer!.copyWith(token: response.data['token']);
        await _saveUser();
        _isLoggedIn = true;
        // Send FCM device token now that user is authenticated
        NotificationService().sendTokenToServer();
      }
      
      _setLoading(false);
      return response.data;
    } catch (e) {
      final msg = _userFriendlyError(e);
      _setError(msg);
      return {'error': true, 'message': msg};
    }
  }
  
  // Send OTP to mobile number
  Future<Map<String, dynamic>> sendOtp(String mobile) async {
    _setLoading(true);
    try {
      final response = await _api.post(
        AppConfig.authSendOtp,
        data: {'mobile': mobile},
      );
      
      _setLoading(false);
      return response.data;
    } catch (e) {
      final msg = _userFriendlyError(e);
      _setError(msg);
      return {'error': true, 'message': msg};
    }
  }
  
  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp(String mobile, String otp) async {
    _setLoading(true);
    try {
      final response = await _api.post(
        AppConfig.authVerifyOtp,  // Use verify-otp endpoint
        data: {'mobile': mobile, 'otp': otp},
      );
      
      if (response.data['success'] == true) {
        // Store token
        if (response.data['token'] != null) {
          await _api.setToken(response.data['token']);
        }
        
        // Always store customer_id from response (for new users who need registration)
        final customerId = response.data['customer_id'];
        
        // If customer data returned (existing user with profile), use it
        if (response.data['customer'] != null) {
          _customer = Customer.fromJson(response.data['customer']);
          _customer = _customer!.copyWith(token: response.data['token']);
          await _saveUser();
          _isLoggedIn = true;
          // Send FCM device token now that user is authenticated
          NotificationService().sendTokenToServer();
        } else if (customerId != null) {
          // New user - store customer_id and mobile for registration
          _customer = Customer(
            id: customerId,
            mobile: mobile,
          );
          print('DEBUG: Stored customer_id for new user: $customerId');
        }
      }
      
      _setLoading(false);
      return response.data;
    } catch (e) {
      final msg = _userFriendlyError(e);
      _setError(msg);
      return {'error': true, 'message': msg};
    }
  }

  // Fetch/Refresh Profile Data
  Future<void> fetchProfile() async {
    try {
      final response = await _api.get(AppConfig.customerProfile); // Ensure this endpoint exists in AppConfig
      
      if (response.data['success'] == true && response.data['data'] != null) {
        _customer = Customer.fromJson(response.data['data']);
        await _saveUser();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }
  
  // Update profile (registration)
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String gender,
  }) async {
    _setLoading(true);
    try {
      // Check if customer_id exists
      if (_customer?.id == null) {
        _setError('Customer ID not found. Please restart registration.');
        return {'error': true, 'message': 'Customer ID not found. Please restart registration.'};
      }
      
      print('DEBUG: Sending updateProfile - customer_id: ${_customer?.id}, firstName: $firstName, lastName: $lastName, email: $email, gender: ${gender.toLowerCase()}');
      
      final response = await _api.post(
        AppConfig.authUpdateProfile,
        data: {
          'customer_id': _customer!.id,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'gender': gender.toLowerCase(),
        },
      );
      
      if (response.data['success'] == true && response.data['customer'] != null) {
        _customer = Customer.fromJson(response.data['customer']);
        if (response.data['token'] != null) {
          _customer = _customer!.copyWith(token: response.data['token']);
          await _api.setToken(response.data['token']);
        }
        await _saveUser();
        // Send FCM device token now that user is authenticated
        NotificationService().sendTokenToServer();
      }
      
      _setLoading(false);
      return response.data;
    } catch (e) {
      print('DEBUG: updateProfile error - $e');
      final msg = _userFriendlyError(e);
      _setError(msg);
      return {'error': true, 'message': msg};
    }
  }

  // Add Address
  Future<Map<String, dynamic>> addAddress(CustomerAddress address) async {
    _setLoading(true);
    try {
      // Use 1/0 for is_default as expected by some backends, or boolean if supported.
      // Based on MyAddressesScreen logic, existing impl sent boolean.
      // But let's check what serialization does.
      final data = address.toJson();
      // Ensure 'is_default' is sent if true
      if (address.isDefault) {
        data['is_default'] = true;
      }
      
      final response = await _api.post(
        AppConfig.customerAddresses,
        data: data,
      );
      
      if (response.data['success'] == true || response.statusCode == 200 || response.statusCode == 201) {
        await fetchProfile(); // Refresh profile to get updated list
        _setLoading(false);
        return {'success': true};
      } else {
        _setError(response.data['message'] ?? 'Failed to add address');
        return {'error': true, 'message': response.data['message']};
      }
    } catch (e) {
      _setError(e.toString());
      return {'error': true, 'message': e.toString()};
    }
  }

  // Delete Address
  Future<Map<String, dynamic>> deleteAddress(int id) async {
    _setLoading(true);
    try {
      final response = await _api.delete('${AppConfig.customerAddresses}/$id');
      
      if (response.data['success'] == true) {
        // Optimistically remove from local list
        if (_customer != null) {
           final updatedAddresses = _customer!.addresses.where((a) => a.id != id).toList();
           _customer = _customer!.copyWith(addresses: updatedAddresses);
           await _saveUser();
        }
        notifyListeners();
        
        // Also fetch profile to be sure
        fetchProfile();
        
        _setLoading(false);
        return {'success': true};
      } else {
        _setError(response.data['message'] ?? 'Failed to delete address');
        return {'error': true, 'message': response.data['message']};
      }
    } catch (e) {
      _setError(e.toString());
      return {'error': true, 'message': e.toString()};
    }
  }

  // Set Default Address
  Future<Map<String, dynamic>> setDefaultAddress(int id) async {
    _setLoading(true);
    try {
      final response = await _api.post('${AppConfig.customerAddresses}/$id/set-default');
      
      if (response.data['success'] == true) {
        await fetchProfile();
        _setLoading(false);
        return {'success': true};
      } else {
         _setError(response.data['message'] ?? 'Failed to update default address');
         return {'error': true, 'message': response.data['message']};
      }
    } catch (e) {
      _setError(e.toString());
      return {'error': true, 'message': e.toString()};
    }
  }
  
  // Logout
  Future<void> logout() async {
    await _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.userKey);
    _customer = null;
    _isLoggedIn = false;
    notifyListeners();
  }
  
  // Helper methods
  Future<void> _saveUser() async {
    if (_customer != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.userKey, jsonEncode(_customer!.toJson()));
    }
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    _error = null;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  /// Convert exceptions to user-friendly messages
  String _userFriendlyError(dynamic e) {
    if (e is NoInternetException) {
      return e.message;
    }
    if (e is AppException) {
      return e.message;
    }
    // Check if DioException wraps our custom exceptions
    if (e is DioException && e.error is NoInternetException) {
      return (e.error as NoInternetException).message;
    }
    if (e is DioException && e.error is AppException) {
      return (e.error as AppException).message;
    }
    return 'Something went wrong. Please try again.';
  }
}
