import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../models/service.dart';
import '../../services/api_service.dart';
import '../../providers/cart_provider.dart';
import 'package:dio/dio.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/service_quick_add_sheet.dart';
import '../booking/checkout_screen.dart';

// Strip HTML tags from text
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

/// Category Services Screen - List of services in a category + cart
class CategoryServicesScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryServicesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryServicesScreen> createState() => _CategoryServicesScreenState();
}

class _CategoryServicesScreenState extends State<CategoryServicesScreen> {
  final _searchController = TextEditingController();
  final ApiService _api = ApiService();

  List<Service> _services = [];
  List<Service> _filteredServices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredServices = _services.where((s) =>
      s.name.toLowerCase().contains(query) ||
          stripHtml(s.description).toLowerCase().contains(query)
      ).toList();
    });
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.get(
          '${AppConfig.publicCategoryServices}/${widget.categoryId}/services'
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final servicesJson = data['services'] as List? ?? [];

        setState(() {
          _services = servicesJson
              .map((json) => Service.fromJson(json))
              .toList();
          _filteredServices = _services;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load services';
          _isLoading = false;
        });
      }
    } catch (e) {
      String errorMsg = 'Something went wrong. Please try again.';
      if (e is NoInternetException || (e is DioException && e.error is NoInternetException)) {
        errorMsg = 'No internet connection. Please check your network.';
      }
      setState(() {
        _error = errorMsg;
        _isLoading = false;
      });
      debugPrint('Error loading services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(title: widget.categoryName),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),

              // Label
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Choose from below',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Services List with pull to refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadServices,
                  color: AppTheme.secondary,
                  child: _isLoading
                      ? _buildLoading()
                      : _error != null
                      ? _buildError()
                      : _filteredServices.isEmpty
                      ? _buildEmpty()
                      : _buildServicesList(),
                ),
              ),
            ],
          ),

          // Cart Button
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.currentCartItemCount == 0) return const SizedBox();

              return Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          categoryId: widget.categoryId,
                          categoryName: widget.categoryName,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${cartProvider.currentCartItemCount}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primary),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 50),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_repair_service_outlined, color: AppTheme.textSecondary, size: 50),
            SizedBox(height: 16),
            Text(
              'No services available in this category',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesList() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 70),
          itemCount: _filteredServices.length,
          itemBuilder: (context, index) {
            final service = _filteredServices[index];
            final quantity = cartProvider.getQuantity(service.id);

            return GestureDetector(
              onTap: () => ServiceQuickAddSheet.show(context, service),
              child: ServiceCard(
                name: service.name,
                description: stripHtml(service.description),
                imageUrl: service.image,
                regularPrice: service.regularPrice,
                salePrice: service.salePrice ?? service.regularPrice,
                rating: service.rating,
                quantity: quantity,
                onAdd: () => cartProvider.addToCart(service),
                onRemove: () => cartProvider.removeFromCart(service.id),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}