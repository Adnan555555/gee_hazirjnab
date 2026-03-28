import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../models/service.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/service_quick_add_sheet.dart';
import 'category_services_screen.dart';

/// All Services Screen - Featured services carousel + all categories grid
class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});
  
  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final _searchController = TextEditingController();
  final ApiService _api = ApiService();
  
  List<ServiceCategory> _categories = [];
  List<Service> _featuredServices = [];
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final response = await _api.get(AppConfig.publicCategories);
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        // Parse all categories
        final categoriesJson = data['categories'] as List? ?? [];
        _categories = categoriesJson
            .map((json) => ServiceCategory.fromJson(json))
            .toList();
        
        // Parse featured services
        final servicesJson = data['featured_services'] as List? ?? [];
        _featuredServices = servicesJson
            .map((json) => Service.fromJson(json))
            .toList();
        
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load data';
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
      debugPrint('Error loading categories: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CustomAppBar(title: 'Home Services'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
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
                                hintText: 'Search services...',
                                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                        ),
                        
                        // Featured Services Section
                        if (_featuredServices.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Featured Services',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Featured Carousel
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _featuredServices.length,
                              itemBuilder: (context, index) {
                                return _buildFeaturedCard(_featuredServices[index]);
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 28),
                        ],
                        
                        // All Categories Section
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'All Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Categories Grid
                        _categories.isEmpty
                            ? _buildEmptyCategories()
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.9,
                                  ),
                                  itemCount: _categories.length,
                                  itemBuilder: (context, index) {
                                    return _buildCategoryCard(_categories[index]);
                                  },
                                ),
                              ),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
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
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyCategories() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.category_outlined, color: AppTheme.textSecondary, size: 50),
            SizedBox(height: 16),
            Text(
              'No categories available',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeaturedCard(Service service) {
    return GestureDetector(
      onTap: () {
        // Show quick add popup
        ServiceQuickAddSheet.show(context, service);
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 100,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
              child: service.image != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: Image.network(
                        service.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.build,
                          color: AppTheme.secondary,
                          size: 40,
                        ),
                      ),
                    )
                  : const Icon(Icons.build, color: AppTheme.secondary, size: 40),
            ),
            
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (service.salePrice != null && service.salePrice! < service.regularPrice) ...[
                          Text(
                            'Rs.${service.regularPrice.toInt()}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'Rs.${(service.salePrice ?? service.regularPrice).toInt()}',
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryCard(ServiceCategory category) {
    return InkWell(
      onTap: () {
        context.read<CartProvider>().setCurrentCategory(category.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryServicesScreen(
              categoryId: category.id,
              categoryName: category.name,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: category.image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        category.image!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.category,
                          color: AppTheme.secondary,
                          size: 40,
                        ),
                      ),
                    )
                  : const Icon(Icons.category, color: AppTheme.secondary, size: 40),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
