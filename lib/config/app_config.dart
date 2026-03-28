/// App Configuration - Centralized config for API and app settings
class AppConfig {
  // API Configuration
  static const String baseUrl = 'https://app.hazirjnab.com';
  static const String apiUrl = '$baseUrl/api';
  
  // API Endpoints
  static const String publicCategories = '/public/categories';
  static const String publicFeaturedCategories = '/public/categories/featured';
  static const String publicCategoryServices = '/public/categories'; // /{id}/services
  static const String publicHome = '/public/home';
  static const String publicFeatureBanners = '/public/feature-banners';
  
  static const String authCheckCustomer = '/auth/check-customer';
  static const String authSendOtp = '/auth/send-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authUpdateProfile = '/auth/update-profile';
  static const String authAddAddress = '/auth/add-address';
  
  static const String customerProfile = '/customer/profile';
  static const String customerAddresses = '/customer/addresses';
  static const String customerBookings = '/customer/bookings';
  
  // App Info
  static const String appName = 'Gee Hazirjnab';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String onboardingKey = 'onboarding_complete';
  static const String cartKey = 'category_carts';
}
