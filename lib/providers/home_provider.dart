import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../models/service.dart';
import '../models/feature_banner.dart';

/// Home Provider - Manages home screen data from API
class HomeProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<FeatureBanner> _banners = [];
  List<ServiceCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<FeatureBanner> get banners => _banners;
  List<ServiceCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasBanners => _banners.isNotEmpty;
  
  /// Fetch home data (banners + featured categories) from API
  Future<void> fetchHomeData({bool forceRefresh = false}) async {
    // Don't refetch if already loaded unless forced
    if (_categories.isNotEmpty && !forceRefresh) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _api.get(AppConfig.publicHome);
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        // Parse banners
        final bannersJson = data['banners'] as List? ?? [];
        _banners = bannersJson
            .map((json) => FeatureBanner.fromJson(json))
            .toList();
        
        // Parse featured categories (max 6)
        final categoriesJson = data['featured_categories'] as List? ?? [];
        _categories = categoriesJson
            .take(6)
            .map((json) => ServiceCategory.fromJson(json))
            .toList();
        
        _error = null;
      } else {
        _error = response.data['message'] ?? 'Failed to fetch home data';
      }
    } catch (e) {
      _error = 'Network error. Please check your connection.';
      debugPrint('HomeProvider Error: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Legacy method for compatibility
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    return fetchHomeData(forceRefresh: forceRefresh);
  }
  
  /// Clear data (for logout)
  void clear() {
    _banners = [];
    _categories = [];
    _error = null;
    notifyListeners();
  }
}
