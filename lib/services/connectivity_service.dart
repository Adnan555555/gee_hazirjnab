import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription; // ← no generic type

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  void _init() {
    _checkConnectivity();

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionStatus([result as ConnectivityResult]);
    });
  }
  Future<void> _checkConnectivity() async {
    final ConnectivityResult result = await _connectivity.checkConnectivity();
    _updateConnectionStatus([result]);
  }  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;

    _isConnected =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

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