import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/service.dart';
import '../config/app_config.dart';

/// Cart Provider - Category-wise cart management
/// Each category has its own separate cart for easy handyman assignment
class CartProvider extends ChangeNotifier {
  // Map of categoryId -> list of cart items
  Map<int, List<CartItem>> _categoryWiseCarts = {};
  
  // Current active category
  int _currentCategoryId = 0;
  
  int get currentCategoryId => _currentCategoryId;
  
  // Get cart for current category
  List<CartItem> get currentCart => _categoryWiseCarts[_currentCategoryId] ?? [];
  
  // Get cart item count for current category
  int get currentCartItemCount => currentCart.fold(0, (sum, item) => sum + item.quantity);
  
  // Get cart total for current category
  double get currentCartTotal => currentCart.fold(0, (sum, item) => sum + item.totalPrice);
  
  // Set current category
  void setCurrentCategory(int categoryId) {
    _currentCategoryId = categoryId;
    notifyListeners();
  }
  
  // Check if service is in current cart
  bool isInCart(int serviceId) {
    return currentCart.any((item) => item.serviceId == serviceId);
  }
  
  // Get quantity of service in current cart
  int getQuantity(int serviceId) {
    final item = currentCart.firstWhere(
      (item) => item.serviceId == serviceId,
      orElse: () => CartItem(
        serviceId: 0,
        serviceName: '',
        regularPrice: 0,
        salePrice: 0,
      ),
    );
    return item.serviceId != 0 ? item.quantity : 0;
  }
  
  // Add service to current category cart
  void addToCart(Service service) {
    if (_categoryWiseCarts[_currentCategoryId] == null) {
      _categoryWiseCarts[_currentCategoryId] = [];
    }
    
    final existingIndex = _categoryWiseCarts[_currentCategoryId]!
        .indexWhere((item) => item.serviceId == service.id);
    
    if (existingIndex >= 0) {
      // Increase quantity
      final existing = _categoryWiseCarts[_currentCategoryId]![existingIndex];
      _categoryWiseCarts[_currentCategoryId]![existingIndex] = 
          existing.copyWith(quantity: existing.quantity + 1);
    } else {
      // Add new item
      _categoryWiseCarts[_currentCategoryId]!.add(CartItem(
        serviceId: service.id,
        serviceName: service.name,
        serviceImage: service.image,
        description: service.description,
        regularPrice: service.regularPrice,
        salePrice: service.salePrice ?? service.regularPrice,
        rating: service.rating,
        quantity: 1,
      ));
    }
    
    _saveToStorage();
    notifyListeners();
  }
  
  // Remove one quantity from cart
  void removeFromCart(int serviceId) {
    if (_categoryWiseCarts[_currentCategoryId] == null) return;
    
    final existingIndex = _categoryWiseCarts[_currentCategoryId]!
        .indexWhere((item) => item.serviceId == serviceId);
    
    if (existingIndex >= 0) {
      final existing = _categoryWiseCarts[_currentCategoryId]![existingIndex];
      if (existing.quantity > 1) {
        _categoryWiseCarts[_currentCategoryId]![existingIndex] = 
            existing.copyWith(quantity: existing.quantity - 1);
      } else {
        _categoryWiseCarts[_currentCategoryId]!.removeAt(existingIndex);
      }
    }
    
    _saveToStorage();
    notifyListeners();
  }
  
  // Increment quantity of existing cart item
  void incrementCartItem(int serviceId) {
    if (_categoryWiseCarts[_currentCategoryId] == null) return;
    
    final existingIndex = _categoryWiseCarts[_currentCategoryId]!
        .indexWhere((item) => item.serviceId == serviceId);
    
    if (existingIndex >= 0) {
      final existing = _categoryWiseCarts[_currentCategoryId]![existingIndex];
      _categoryWiseCarts[_currentCategoryId]![existingIndex] = 
          existing.copyWith(quantity: existing.quantity + 1);
      
      _saveToStorage();
      notifyListeners();
    }
  }
  
  // Clear current category cart
  void clearCurrentCart() {
    _categoryWiseCarts[_currentCategoryId] = [];
    _saveToStorage();
    notifyListeners();
  }
  
  // Clear all carts
  void clearAllCarts() {
    _categoryWiseCarts = {};
    _saveToStorage();
    notifyListeners();
  }
  
  // Load from storage
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(AppConfig.cartKey);
    if (data != null) {
      final Map<String, dynamic> decoded = jsonDecode(data);
      _categoryWiseCarts = decoded.map((key, value) {
        return MapEntry(
          int.parse(key),
          (value as List).map((item) => CartItem.fromJson(item)).toList(),
        );
      });
      notifyListeners();
    }
  }
  
  // Save to storage
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _categoryWiseCarts.map((key, value) {
      return MapEntry(key.toString(), value.map((item) => item.toJson()).toList());
    });
    await prefs.setString(AppConfig.cartKey, jsonEncode(data));
  }
}
