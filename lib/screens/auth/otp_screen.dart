import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../services/connectivity_service.dart';
import 'registration_screen.dart';
import 'map_address_screen.dart';
import '../home/home_screen.dart';

/// OTP Screen - 4-digit verification
class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String? testOtp; // For testing - REMOVE IN PRODUCTION
  
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.testOtp, // For testing - REMOVE IN PRODUCTION
  });
  
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _resendSeconds = 60;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
  }
  
  void _startTimer() {
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 70,
      height: 70,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppTheme.primary,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.3), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
    );
    
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.secondary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
    
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // WhatsApp Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25D366).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Title
              const Text(
                'OTP Verification',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'We\'ve sent a 4-digit OTP to your WhatsApp',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.phoneNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              
              
              // DEBUG: Show OTP for testing - REMOVE IN PRODUCTION
              if (widget.testOtp != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bug_report, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Test OTP: ${widget.testOtp}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // OTP Input
              Pinput(
                controller: _otpController,
                length: 4,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: defaultPinTheme,
                showCursor: true,
                cursor: Container(
                  width: 2,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                onCompleted: (pin) => _verifyOtp(),
              ),
              
              const SizedBox(height: 40),
              
              // Verify Button
              PrimaryButton(
                text: 'Verify',
                isLoading: _isLoading,
                onPressed: _verifyOtp,
              ),
              
              const SizedBox(height: 30),
              
              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  _resendSeconds > 0
                      ? Text(
                          'Resend in ${_resendSeconds}s',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resendOtp,
                          child: const Text(
                            'Resend',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter 4-digit code'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    // Check connectivity first
    if (!ConnectivityService().isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('No internet connection. Please check your network.'),
              ],
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }
    
    setState(() => _isLoading = true);
    
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.verifyOtp(
      widget.phoneNumber,
      _otpController.text,
    );
    
    setState(() => _isLoading = false);
    
    if (result['success'] == true && mounted) {
      // Get profile status from verifyOtp response
      final bool isProfileComplete = result['is_profile_complete'] ?? false;
      final bool hasName = result['has_name'] ?? false;
      final bool hasAddress = result['has_address'] ?? false;
      
      // 3-state routing:
      // 1. Profile complete (has name + address) → Go to Home
      // 2. Has name but no address → Go to Address page
      // 3. New user (no name) → Go to Registration
      if (isProfileComplete) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else if (hasName && !hasAddress) {
        // Has name but needs address
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapAddressScreen()),
        );
      } else {
        // New user - needs registration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Something went wrong. Please try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
  
  void _resendOtp() async {
    // Check connectivity first
    if (!ConnectivityService().isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('No internet connection. Please check your network.'),
              ],
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }
    
    _startTimer();
    final result = await context.read<AuthProvider>().sendOtp(widget.phoneNumber);
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP resent to your WhatsApp: ${result['OTP'] ?? 'Check WhatsApp'}'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Something went wrong. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }
}
