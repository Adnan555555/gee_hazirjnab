import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'package:dio/dio.dart';

class BookingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Booking> _inProcess = [];
  List<Booking> _completed = [];
  bool _isLoading = false;
  String? _error;

  List<Booking> get inProcess => _inProcess;
  List<Booking> get completed => _completed;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchBookings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(AppConfig.customerBookings);
      
      if (response.statusCode == 200 && response.data['status'] == true) {
        final data = response.data['data'];
        
        _inProcess = (data['in_process'] as List)
            .map((item) => Booking.fromJson(item))
            .toList();
            
        _completed = (data['completed'] as List)
            .map((item) => Booking.fromJson(item))
            .toList();
      } else {
        _error = response.data['message'] ?? 'Failed to load bookings';
      }
    } catch (e) {
      if (e is NoInternetException || (e is DioException && e.error is NoInternetException)) {
        _error = 'No internet connection. Please check your network.';
      } else {
        _error = 'Something went wrong. Please try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel the entire booking (all services)
  Future<bool> cancelBooking(int bookingId, {String? reason}) async {
    try {
      final response = await _apiService.post(
        '${AppConfig.customerBookings}/$bookingId/cancel',
        data: {'reason': reason ?? 'Cancelled by customer'},
      );

      if (response.statusCode == 200 && response.data['status'] == true) {
        await fetchBookings();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cancel a single service item from a booking
  Future<bool> cancelItem(int bookingId, int itemId) async {
    try {
      final response = await _apiService.post(
        '${AppConfig.customerBookings}/$bookingId/items/$itemId/cancel',
      );

      if (response.statusCode == 200 && response.data['status'] == true) {
        await fetchBookings();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
