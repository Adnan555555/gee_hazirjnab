import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/home_provider.dart';
import '../../models/service.dart';
import '../../models/feature_banner.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/no_internet_widget.dart';
import '../services/all_services_screen.dart';
import '../services/category_services_screen.dart';
import '../profile/profile_screen.dart';
import '../booking/my_bookings_screen.dart';

/// Home Screen - Main app screen with bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeContent(),
    const MyBookingsScreen(),
    const ProfileScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

/// Home Content - The home tab content
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ConnectivityService _connectivity = ConnectivityService();
  
  @override
  void initState() {
    super.initState();
    // Fetch categories on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    // Listen for connectivity changes
    _connectivity.addListener(_onConnectivityChanged);
  }
  
  void _onConnectivityChanged() {
    if (_connectivity.isConnected) {
      // Reload data when connection is restored
      _loadData();
    }
    setState(() {});
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      context.read<HomeProvider>().fetchCategories(),
      context.read<AuthProvider>().fetchProfile(),
    ]);
  }
  
  Future<void> _onRefresh() async {
    await _loadData();
  }
  
  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<AuthProvider>().customer;
    final homeProvider = context.watch<HomeProvider>();
    
    // Fallback if defaultAddress is null (e.g. backend issue)
    final displayAddress = customer?.defaultAddress ?? 
        (customer?.addresses.isNotEmpty == true ? customer!.addresses.first : null);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // No internet banner
            if (!_connectivity.isConnected)
              const NoInternetBanner(),
            
            // Main content with pull to refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.secondary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Image Carousel
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(20),
                          ),
                        ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppTheme.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                displayAddress?.addressType?.toUpperCase() ?? 'Current Location',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _getShortAddress(displayAddress?.address),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Notification
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Welcome
                    Text(
                      'Hello, ${customer?.name ?? 'User'}! 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Find the best services for your home',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Feature Banner Carousel - Dynamic from API
                    if (homeProvider.hasBanners)
                      SizedBox(
                        height: 140,
                        child: PageView.builder(
                          controller: PageController(viewportFraction: 1.0),
                          itemCount: homeProvider.banners.length,
                          itemBuilder: (context, index) {
                            final banner = homeProvider.banners[index];
                            return _buildBannerCard(banner, index);
                          },
                        ),
                      )
                    else if (!homeProvider.isLoading)
                      // Fallback placeholder banner
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppTheme.secondary.withOpacity(0.1),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_offer, color: AppTheme.secondary, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Browse Our Services',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Categories Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllServicesScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Categories Grid - Dynamic from API
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: homeProvider.isLoading
                    ? _buildCategoriesLoading()
                    : homeProvider.hasError
                        ? _buildCategoriesError(homeProvider)
                        : homeProvider.categories.isEmpty
                            ? _buildCategoriesEmpty()
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.9,
                                ),
                                itemCount: homeProvider.categories.length > 6 
                                    ? 6 
                                    : homeProvider.categories.length,
                                itemBuilder: (context, index) {
                                  final category = homeProvider.categories[index];
                                  return _buildDynamicCategoryCard(context, category);
                                },
                              ),
              ),
              
              const SizedBox(height: 20),
              
              // Company Info Card - Compact
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Gee HazirJnab',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '• Your Trusted Partner',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Professional handyman services for residential and commercial needs.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildServiceTypeButton('Residential'),
                          const SizedBox(width: 6),
                          _buildServiceTypeButton('Commercial'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build banner card from API data
  Widget _buildBannerCard(FeatureBanner banner, int index) {
    final colors = [
      [const Color(0xFFFFC107), const Color(0xFFFF9800)],
      [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
      [const Color(0xFF2196F3), const Color(0xFF1976D2)],
      [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
    ];
    final colorPair = colors[index % colors.length];
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner.imageUrl != null)
              Image.network(
                banner.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colorPair,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colorPair,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            if (banner.title != null || banner.description != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            if (banner.title != null || banner.description != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (banner.title != null)
                      Text(
                        banner.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (banner.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          banner.description!,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Loading shimmer for categories
  Widget _buildCategoriesLoading() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Error state with retry
  Widget _buildCategoriesError(HomeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
          const SizedBox(height: 12),
          Text(
            provider.error ?? 'Failed to load categories',
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => provider.fetchCategories(forceRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  // Empty state
  Widget _buildCategoriesEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.category_outlined, color: AppTheme.textSecondary, size: 40),
          SizedBox(height: 12),
          Text(
            'No categories available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
  
  // Dynamic category card from API data
  Widget _buildDynamicCategoryCard(BuildContext context, ServiceCategory category) {
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                  : const Icon(
                      Icons.category,
                      color: AppTheme.secondary,
                      size: 40,
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
  
  Widget _buildServiceTypeButton(String text) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to service type screen in next update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$text services - Coming soon!'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.primary,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: AppTheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.secondary, size: 10),
          ],
        ),
      ),
    );
  }
  
  /// Extract short address for display in header
  String _getShortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) {
      return 'Select Location';
    }
    
    // Try to extract area/locality from address
    // Usually format: "Street, Area, City, Province"
    final parts = fullAddress.split(',');
    if (parts.length >= 3) {
      // Return area and city
      return '${parts[parts.length - 3].trim()}, ${parts[parts.length - 2].trim()}';
    } else if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    
    // If address is short, return as is
    if (fullAddress.length <= 30) {
      return fullAddress;
    }
    
    // Truncate long addresses
    return '${fullAddress.substring(0, 27)}...';
  }
}
