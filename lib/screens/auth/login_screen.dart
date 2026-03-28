import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../services/connectivity_service.dart';
import 'otp_screen.dart';

/// Login Screen - Phone number input with country code
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Welcome Text
                  const Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gee Hazirjnab',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Enter your phone number to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // Phone Input - Clean design with flag inside
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                      color: AppTheme.textPrimary,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: '3XX XXXXXXX',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.5),
                        letterSpacing: 1,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: const BorderSide(color: AppTheme.secondary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: const BorderSide(color: AppTheme.error, width: 1),
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pakistan Flag Emoji
                            const Text(
                              '🇵🇰',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            // Country Code
                            const Text(
                              '+92',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Divider
                            Container(
                              height: 24,
                              width: 1,
                              color: AppTheme.textSecondary.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter valid phone number';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Continue Button
                  PrimaryButton(
                    text: 'Continue',
                    isLoading: _isLoading,
                    onPressed: _handleContinue,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Terms
                  Text(
                    'By continuing, you agree to our',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        ' and ',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 12,
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
        ),
      ),
    );
  }
  
  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    
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
    
    final phone = '+92${_phoneController.text}';
    final authProvider = context.read<AuthProvider>();
    
    // Only send OTP - customer check/creation happens during verifyOtp
    final otpResult = await authProvider.sendOtp(phone);
    
    setState(() => _isLoading = false);
    
    if (otpResult['success'] == true && mounted) {
      // Get OTP for testing (REMOVE IN PRODUCTION)
      final String? testOtp = otpResult['OTP']?.toString();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phoneNumber: phone,
            testOtp: testOtp, // For testing - REMOVE IN PRODUCTION
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(otpResult['message'] ?? 'Something went wrong. Please try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
