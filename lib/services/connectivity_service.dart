import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Service to monitor internet connectivity
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal() {
    _init();
  }
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  void _init() {
    // Check initial connectivity
    _checkConnectivity();
    
    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results);
    });
  }
  
  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
  }
  
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = results.isNotEmpty && 
                   !results.contains(ConnectivityResult.none);
    
    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }
  
  /// Force check connectivity
  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return _isConnected;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
