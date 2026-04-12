import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../models/service.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/service_quick_add_sheet.dart';
import '../../widgets/shimmer_widget.dart';
import '../../utils/html_helper.dart';
import 'category_services_screen.dart';

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final _searchController = TextEditingController();
  final _featuredPageController = PageController(viewportFraction: 0.88);
  final ApiService _api = ApiService();

  List<ServiceCategory> _categories = [];
  List<Service> _featuredServices = [];
  List<Service> _filteredCategories = []; // for search
  bool _isLoading = true;
  String? _error;

  int _currentFeaturedIndex = 0;
  Timer? _featuredAutoScroll;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      // filter categories by name if search active
    });
  }

  void _startFeaturedAutoScroll() {
    _featuredAutoScroll?.cancel();
    if (_featuredServices.length <= 1) return;

    _featuredAutoScroll =
        Timer.periodic(const Duration(seconds: 4), (timer) {
          if (!mounted || !_featuredPageController.hasClients) return;
          final next =
              (_currentFeaturedIndex + 1) % _featuredServices.length;
          _featuredPageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        });
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

        final categoriesJson = data['categories'] as List? ?? [];
        _categories = categoriesJson
            .map((json) => ServiceCategory.fromJson(json))
            .toList();

        final servicesJson = data['featured_services'] as List? ?? [];
        _featuredServices = servicesJson
            .map((json) => Service.fromJson(json))
            .toList();

        setState(() => _isLoading = false);

        // Start auto-scroll after data loads
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _startFeaturedAutoScroll());
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      String errorMsg = 'Something went wrong. Please try again.';
      if (e is NoInternetException ||
          (e is DioException && e.error is NoInternetException)) {
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
  void dispose() {
    _featuredAutoScroll?.cancel();
    _featuredPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Search-filtered categories ───────────────────────────────────────────
  List<ServiceCategory> get _displayedCategories {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return _categories;
    return _categories
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CustomAppBar(title: 'Home Services'),
      body: _isLoading
          ? _buildShimmer()
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
              // ── Search Bar ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(
                        AppTheme.radiusLarge),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search services...',
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),

              // ── Featured Carousel ──────────────────────────
              if (_featuredServices.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    'Featured Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildFeaturedCarousel(),
                const SizedBox(height: 28),
              ],

              // ── All Categories ─────────────────────────────
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

              _displayedCategories.isEmpty
                  ? _buildEmptyCategories()
                  : Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _displayedCategories.length,
                  itemBuilder: (context, index) =>
                      _buildCategoryCard(
                          _displayedCategories[index]),
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

  // ── Featured carousel with scale effect + dot indicators ────────────────
  Widget _buildFeaturedCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _featuredPageController,
            itemCount: _featuredServices.length,
            onPageChanged: (i) =>
                setState(() => _currentFeaturedIndex = i),
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _featuredPageController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_featuredPageController.position.haveDimensions) {
                    final page = _featuredPageController.page ??
                        index.toDouble();
                    scale =
                        (1 - (page - index).abs() * 0.07).clamp(0.93, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: _buildFeaturedCard(_featuredServices[index]),
              );
            },
          ),
        ),

        // Dot indicators
        if (_featuredServices.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_featuredServices.length, (i) {
                final active = _currentFeaturedIndex == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: active ? 22.0 : 7.0,
                  height: 7.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active
                        ? AppTheme.primary
                        : AppTheme.primary.withOpacity(0.25),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedCard(Service service) {
    return GestureDetector(
      onTap: () => ServiceQuickAddSheet.show(context, service),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image with shimmer placeholder
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: ShimmerNetworkImage(
                imageUrl: service.image,
                width: 110,
                height: double.infinity,
                fit: BoxFit.cover,
                errorWidget: Container(
                  width: 110,
                  color: Colors.white.withOpacity(0.15),
                  child: const Icon(Icons.build,
                      color: AppTheme.secondary, size: 36),
                ),
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stripHtml(service.description),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (service.salePrice != null &&
                            service.salePrice! < service.regularPrice) ...[
                          Text(
                            'Rs.${service.regularPrice.toInt()}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
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
              child: ShimmerNetworkImage(
                imageUrl: category.image,
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(10),
                errorWidget: const Icon(Icons.category,
                    color: AppTheme.secondary, size: 40),
              ),
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

  // ── Full-screen shimmer while loading ────────────────────────────────────
  Widget _buildShimmer() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar shimmer
            _shimmerBox(double.infinity, 52, radius: 14),
            const SizedBox(height: 24),

            // "Featured Services" label
            _shimmerBox(160, 20, radius: 6),
            const SizedBox(height: 14),

            // Featured card shimmer
            _shimmerBox(double.infinity, 130, radius: 16),
            const SizedBox(height: 28),

            // "All Categories" label
            _shimmerBox(130, 20, radius: 6),
            const SizedBox(height: 16),

            // Category grid shimmer
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double width, double height, {double radius = 8}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
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
            Text(_error ?? 'Something went wrong',
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary),
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
            Icon(Icons.category_outlined,
                color: AppTheme.textSecondary, size: 50),
            SizedBox(height: 16),
            Text('No categories available',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}