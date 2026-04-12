import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/home_provider.dart';
import '../../models/service.dart';
import '../../models/feature_banner.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';           // ← CHANGED
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/no_internet_widget.dart';
import '../../widgets/shimmer_widget.dart';
import '../services/all_services_screen.dart';
import '../services/category_services_screen.dart';
import '../profile/profile_screen.dart';
import '../booking/my_bookings_screen.dart';

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

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ConnectivityService _connectivity = ConnectivityService();
  final PageController _bannerPageController = PageController();
  int _currentBannerIndex = 0;
  late Timer _autoScrollTimer;
  bool _locationChecked = false;                          // ← CHANGED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkLocationOnce();                               // ← CHANGED
    });
    _connectivity.addListener(_onConnectivityChanged);
    _startAutoScroll();
  }

  // ← CHANGED: show Lahore-only popup once per session
  Future<void> _checkLocationOnce() async {
    if (_locationChecked) return;
    _locationChecked = true;

    final isInLahore = await LocationService.isUserInLahore();

    // null means permission denied / unavailable — don't block the user
    if (!mounted || isInLahore == null || isInLahore == true) return;

    _showNotInLahoreDialog();
  }

  void _showNotInLahoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Service Unavailable\nin Your Area',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              const Text(
                'Gee HazirJnab is currently available only in Lahore, Pakistan. '
                    'We\'re working hard to expand to more cities soon!',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // City chip
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.location_on, color: AppTheme.secondary, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Lahore, Pakistan',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  // Browse anyway
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Browse',
                        style: TextStyle(color: AppTheme.primary, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // OK / understood
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(color: Colors.white, fontSize: 13),
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

  void _onConnectivityChanged() {
    if (_connectivity.isConnected) _loadData();
    setState(() {});
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<HomeProvider>().fetchCategories(),
      context.read<AuthProvider>().fetchProfile(),
    ]);

    if (mounted && context.read<HomeProvider>().hasBanners) {
      setState(() => _currentBannerIndex = 0);
      _bannerPageController.jumpToPage(0);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_bannerPageController.hasClients && mounted) {
        final homeProvider = context.read<HomeProvider>();
        if (homeProvider.hasBanners && homeProvider.banners.length > 1) {
          final nextPage =
              (_currentBannerIndex + 1) % homeProvider.banners.length;
          _bannerPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,               // ← CHANGED: smoother curve
          );
        }
      }
    });
  }

  Future<void> _onRefresh() async => _loadData();

  @override
  void dispose() {
    _autoScrollTimer.cancel();
    _bannerPageController.dispose();
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<AuthProvider>().customer;
    final homeProvider = context.watch<HomeProvider>();

    final displayAddress = customer?.defaultAddress ??
        (customer?.addresses.isNotEmpty == true
            ? customer!.addresses.first
            : null);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            if (!_connectivity.isConnected) const NoInternetBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.secondary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Header ───────────────────────────────────────
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
                            // Location row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on,
                                      color: AppTheme.secondary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayAddress?.addressType
                                            ?.toUpperCase() ??
                                            'Current Location',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      GestureDetector(
                                        onTap: () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                'Address selection coming soon!'),
                                            duration: Duration(seconds: 1),
                                          ));
                                        },
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _getShortAddress(
                                                    displayAddress?.address),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow:
                                                TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.white,
                                                size: 20),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content:
                                      Text('Notifications coming soon!'),
                                      duration: Duration(seconds: 1),
                                    ));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.notifications_none_rounded,
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Hello, ${customer?.name ?? 'User'}! 👋',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Find the best services for your home',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),

                            const SizedBox(height: 14),

                            // ─── Banner Carousel ───────────────────────── ← CHANGED
                            _buildBannerSection(homeProvider),

                            const SizedBox(height: 10),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Categories ───────────────────────────────────
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
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AllServicesScreen()),
                              ),
                              child: const Text(
                                'View All',
                                style: TextStyle(
                                    color: AppTheme.secondary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: homeProvider.isLoading
                            ? const CategoriesShimmer()     // ← CHANGED
                            : homeProvider.hasError
                            ? _buildCategoriesError(homeProvider)
                            : homeProvider.categories.isEmpty
                            ? _buildCategoriesEmpty()
                            : GridView.builder(
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
                          itemCount: homeProvider.categories
                              .length >
                              6
                              ? 6
                              : homeProvider.categories.length,
                          itemBuilder: (context, index) {
                            return _buildDynamicCategoryCard(
                                context,
                                homeProvider.categories[index]);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Company Info Card ─────────────────────────────
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
                                children: const [
                                  Text(
                                    'Gee HazirJnab',
                                    style: TextStyle(
                                        color: AppTheme.secondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '• Your Trusted Partner',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Professional handyman services for residential and commercial needs.',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    height: 1.3),
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

  // ─── CHANGED: Banner section with shimmer while loading ────────────────────
  Widget _buildBannerSection(HomeProvider homeProvider) {
    if (homeProvider.isLoading) {
      return const BannerShimmer();
    }

    if (!homeProvider.hasBanners || homeProvider.banners.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AllServicesScreen())),
        child: Container(
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
                      color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // ─── Carousel PageView ─────────────────────────────────── ← CHANGED
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _bannerPageController,
            onPageChanged: (index) =>
                setState(() => _currentBannerIndex = index),
            itemCount: homeProvider.banners.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _bannerPageController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_bannerPageController.position.haveDimensions) {
                    final page = _bannerPageController.page ?? index.toDouble();
                    scale = (1 - (page - index).abs() * 0.08).clamp(0.92, 1.0);
                  }
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: _buildBannerCard(homeProvider.banners[index], index),
              );
            },
          ),
        ),

        // ─── Dot indicators ───────────────────────────────────────
        if (homeProvider.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(homeProvider.banners.length, (index) {
                final isActive = _currentBannerIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: isActive ? 22.0 : 7.0,
                  height: 7.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isActive
                        ? AppTheme.secondary
                        : Colors.white.withOpacity(0.45),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ─── CHANGED: uses ShimmerNetworkImage ─────────────────────────────────────
  Widget _buildBannerCard(FeatureBanner banner, int index) {
    final colors = [
      [const Color(0xFFFFC107), const Color(0xFFFF9800)],
      [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
      [const Color(0xFF2196F3), const Color(0xFF1976D2)],
      [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
    ];
    final colorPair = colors[index % colors.length];

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AllServicesScreen())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: shimmer image or gradient fallback
              if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
                ShimmerNetworkImage(                      // ← CHANGED
                  imageUrl: banner.imageUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  errorWidget: Container(
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

              // Gradient overlay for text readability
              if (banner.title != null || banner.description != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),

              // Text
              if (banner.title != null || banner.description != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (banner.title != null && banner.title!.isNotEmpty)
                        Text(
                          banner.title!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (banner.description != null &&
                          banner.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            banner.description!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
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
      ),
    );
  }

  Widget _buildCategoriesError(HomeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
          const SizedBox(height: 12),
          Text(provider.error ?? 'Failed to load categories',
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => provider.fetchCategories(forceRefresh: true),
            style:
            ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.category_outlined,
              color: AppTheme.textSecondary, size: 40),
          SizedBox(height: 12),
          Text('No categories available',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDynamicCategoryCard(
      BuildContext context, ServiceCategory category) {
    return InkWell(
      onTap: () {
        context.read<CartProvider>().setCurrentCategory(category.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryServicesScreen(
                categoryId: category.id, categoryName: category.name),
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
                  borderRadius: BorderRadius.circular(14)),
              child: ShimmerNetworkImage(                 // ← CHANGED
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
                    color: AppTheme.primary),
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
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$text services - Coming soon!'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.primary,
      )),
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
            Text(text,
                style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.secondary, size: 10),
          ],
        ),
      ),
    );
  }

  String _getShortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) return 'Select Location';
    final parts = fullAddress.split(',');
    if (parts.length >= 3) {
      return '${parts[parts.length - 3].trim()}, ${parts[parts.length - 2].trim()}';
    } else if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    if (fullAddress.length <= 30) return fullAddress;
    return '${fullAddress.substring(0, 27)}...';
  }
}