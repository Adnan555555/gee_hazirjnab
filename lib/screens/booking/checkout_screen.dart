import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../models/cart_item.dart';
import '../../config/theme.dart';
import '../profile/add_address_screen.dart';
import '../auth/map_address_screen.dart';
import '../../config/app_config.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../home/home_screen.dart';

// Strip HTML tags
String stripHtml(String? html) {
  if (html == null || html.isEmpty) return '';
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('\\\\', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Checkout Screen - Date/time, address, payment, order summary
class CheckoutScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CheckoutScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesController = TextEditingController();
  File? _problemImage;
  final ImagePicker _picker = ImagePicker();

  // Track which cart items have expanded descriptions
  final Set<int> _expandedItems = {};

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _problemImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '9:00 AM';
  CustomerAddress? _selectedAddress;
  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  bool _isImmediately = false;

  final List<String> _timeSlots = [
    '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
    '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM', '5:00 PM', '5:30 PM',
    '6:00 PM', '6:30 PM', '7:00 PM', '7:30 PM', '8:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customer = context.read<AuthProvider>().customer;
      if (customer != null && customer.addresses.isNotEmpty) {
        setState(() {
          _selectedAddress = customer.defaultAddress ?? customer.addresses.first;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CustomAppBar(title: 'Checkout'),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final cartItems = cartProvider.currentCart;
          final total = cartProvider.currentCartTotal;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // Schedule Type Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isImmediately ? Icons.flash_on_rounded : Icons.schedule_rounded,
                              color: _isImmediately ? Colors.orange : AppTheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isImmediately ? 'Book Immediately' : 'Schedule for later',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _isImmediately
                                        ? 'Service provider will arrive ASAP'
                                        : 'Pick a date and time',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isImmediately = !_isImmediately),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 60,
                                height: 32,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: _isImmediately
                                      ? const LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  )
                                      : null,
                                  color: _isImmediately ? null : AppTheme.surface,
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  alignment: _isImmediately
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isImmediately ? Icons.flash_on : Icons.schedule,
                                      size: 14,
                                      color: _isImmediately ? Colors.orange : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isImmediately)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'We will assign the nearest available service provider',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Date/Time Section
                if (!_isImmediately) ...[
                  _buildSectionTitle('Selected schedule'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${_selectedTime}, ${_formatDate(_selectedDate)}',
                      style: const TextStyle(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 14,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        final isSelected = _isSameDay(date, _selectedDate);
                        return _buildDateCard(date, isSelected);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _timeSlots.length,
                      itemBuilder: (context, index) {
                        final time = _timeSlots[index];
                        final isSelected = time == _selectedTime;
                        return _buildTimeCard(time, isSelected);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Address Section
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final customer = authProvider.customer;
                    final displayAddress = _selectedAddress ??
                        customer?.defaultAddress ??
                        (customer?.addresses.isNotEmpty == true ? customer!.addresses.first : null);

                    return _buildCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayAddress?.addressType ?? 'Address',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  displayAddress?.address ?? 'No address selected. Please add one in Profile.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showAddressSelection,
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── Services List ──────────────────────────────
                _buildSectionTitle('Services list'),
                ...cartItems.map((item) {
                  final desc = stripHtml(item.description);
                  final isExpanded = _expandedItems.contains(item.serviceId);
                  final hasLongDesc = desc.length > 60;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.surface),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.build, color: AppTheme.textSecondary, size: 22),
                          ),
                          const SizedBox(width: 12),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name
                                Text(
                                  item.serviceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    // maxLines:1,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Description — 1 line + See more
                                if (desc.isNotEmpty) ...[
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: isExpanded ? 10 : 1,
                                    overflow: isExpanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                  ),
                                  if (hasLongDesc)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedItems.remove(item.serviceId);
                                          } else {
                                            _expandedItems.add(item.serviceId);
                                          }
                                        });
                                      },
                                      child: Text(
                                        isExpanded ? 'See less' : 'See more',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],

                                const SizedBox(height: 6),

                                // Price row
                                Row(
                                  children: [
                                    Text(
                                      'Rs.${item.regularPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Rs.${item.salePrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Quantity control
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => cartProvider.removeFromCart(item.serviceId),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.remove, color: Colors.white, size: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => cartProvider.incrementCartItem(item.serviceId),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.add, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Payment Method
                _buildCard(
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment method',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.money, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  _paymentMethod,
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Price Summary
                _buildCard(
                  child: Column(
                    children: [
                      ...cartItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.serviceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('Rs.${item.salePrice.toStringAsFixed(0)} x ${item.quantity}'),
                          ],
                        ),
                      )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Price',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Rs.${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Additional Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Additional Information',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Text(
                              '(optional)',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Your message',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Problem Picture',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Text(
                            '(optional)',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.3)),
                                image: _problemImage != null
                                    ? DecorationImage(
                                  image: FileImage(_problemImage!),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: _problemImage == null
                                  ? const Icon(Icons.add_a_photo_outlined, color: AppTheme.textSecondary)
                                  : Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _problemImage = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Place Order Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PrimaryButton(
                    text: 'Place Order',
                    isLoading: _isLoading,
                    onPressed: _placeOrder,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.surface),
        ),
        child: child,
      ),
    );
  }

  Widget _buildDateCard(DateTime date, bool isSelected) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            Text(
              monthNames[date.month - 1],
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            Text(
              dayNames[date.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(String time, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day}-${monthNames[date.month - 1]}-${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final mobile = authProvider.customer?.mobile;
    debugPrint('Placing order for mobile: $mobile');

    final finalAddress = _selectedAddress ??
        authProvider.customer?.defaultAddress ??
        (authProvider.customer?.addresses.isNotEmpty == true
            ? authProvider.customer!.addresses.first
            : null);

    if (finalAddress == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an address')),
        );
      }
      return;
    }

    try {
      final Map<String, dynamic> data = {
        'category_id': cartProvider.currentCategoryId,
        'booking_date': _selectedDate.toIso8601String(),
        'customer_address_id': finalAddress.id,
        'notes': _notesController.text,
      };

      for (int i = 0; i < cartProvider.currentCart.length; i++) {
        final item = cartProvider.currentCart[i];
        data['items[$i][service_id]'] = item.serviceId;
        data['items[$i][quantity]'] = item.quantity;
      }

      final formData = FormData.fromMap(data);

      if (_problemImage != null) {
        formData.files.add(MapEntry(
          'problem_image',
          await MultipartFile.fromFile(_problemImage!.path),
        ));
      }

      final apiService = ApiService();
      final response = await apiService.postMultipart(AppConfig.customerBookings, formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        cartProvider.clearCurrentCart();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: AppTheme.success, size: 60),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Order Placed!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your order has been placed successfully.\nWe will contact you soon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Back to Home',
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                              (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to place order: ${response.statusMessage}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddressSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Address',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final addresses = auth.customer?.addresses ?? [];
                  if (addresses.isEmpty) {
                    return const Center(child: Text('No addresses found'));
                  }
                  return ListView.separated(
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      bool isSelected = false;
                      if (_selectedAddress?.id != null && address.id != null) {
                        isSelected = _selectedAddress!.id == address.id;
                      } else {
                        isSelected = _selectedAddress?.address == address.address &&
                            _selectedAddress?.addressType == address.addressType;
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: isSelected ? AppTheme.primary : Colors.grey,
                          ),
                        ),
                        title: Text(
                          address.addressType ?? 'Address',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(address.address),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setState(() => _selectedAddress = address);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Add New Address',
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapAddressScreen(isSavingResult: true)),
                );
                if (result == true) {
                  if (mounted) {
                    final auth = context.read<AuthProvider>();
                    await auth.fetchProfile();
                    final updatedCustomer = context.read<AuthProvider>().customer;
                    if (updatedCustomer != null && updatedCustomer.addresses.isNotEmpty) {
                      setState(() {
                        _selectedAddress = updatedCustomer.addresses.last;
                      });
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}