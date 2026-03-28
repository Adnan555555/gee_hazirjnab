import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';
import '../../models/cart_item.dart';

class MapAddressScreen extends StatefulWidget {
  final bool isSelecting; // If true, return result. If false, save & go home.
  final bool isSavingResult; // If true, save & return result.

  const MapAddressScreen({
    super.key, 
    this.isSelecting = false,
    this.isSavingResult = false,
  });

  @override
  State<MapAddressScreen> createState() => _MapAddressScreenState();
}

class _MapAddressScreenState extends State<MapAddressScreen> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(31.5204, 74.3587); // Default: Lahore
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _center = LatLng(position.latitude, position.longitude);
    });
    
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _center, zoom: 15.0),
      ),
    );
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final latLng = LatLng(loc.latitude, loc.longitude);
        setState(() => _center = latLng);
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 15.0),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLocation() async {
    if (widget.isSelecting) {
      Navigator.pop(context, _center);
    } else {
      // Auth Flow: Save Address & Go Home
      await _saveAddressAndNavigate();
    }
  }

  Future<void> _saveAddressAndNavigate() async {
    setState(() => _isLoading = true);
    try {
      // ... existing Geocoding logic ...
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _center.latitude, 
        _center.longitude
      );
      
      String addressText = 'Unknown Location';
      String city = 'Lahore';
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        addressText = '${place.name}, ${place.street}, ${place.subLocality}, ${place.locality}';
        if (place.locality != null) city = place.locality!;
      }

      // 2. Call AuthProvider to add address
      final newAddress = CustomerAddress( // Import required
        address: addressText,
        city: city,
        latitude: _center.latitude,
        longitude: _center.longitude,
        addressType: 'Home',
        isDefault: true,
      );

      // Check mounted before context usage
      if (!mounted) return;
      
      final result = await context.read<AuthProvider>().addAddress(newAddress);

      if (result['success'] == true) {
        if (mounted) {
          // REFRESH PROFILE BEFORE NAVIGATING (already done in addAddress, but safe to keep if simple)
          // await context.read<AuthProvider>().fetchProfile(); // already in addAddress
          
          if (widget.isSavingResult) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to save address');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // Autocomplete Logic
  List<dynamic> _predictions = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _getPlacePredictions(query);
      } else {
        setState(() => _predictions = []);
      }
    });
  }

  Future<void> _getPlacePredictions(String query) async {
    // Requires Google Places API Key (Same as Map Key)
    // using dio to call https://maps.googleapis.com/maps/api/place/autocomplete/json
    // But we need the KEY. It's in AndroidManifest, but not easily accessible here without hardcoding or using a package.
    // However, since we used `geocoding` package before, we can stick to `locationFromAddress` which is free and simple, 
    // OR we can try to use a Places API if the user insists on "Autocomplete".
    // The user said "show map to select address with serchbar with auto complete address".
    
    // For now, I'll stick to `locationFromAddress` logic in the text field submission 
    // BUT simulate autocomplete if possible? No, `geocoding` doesn't do autocomplete.
    
    // I will use `dio` to call Google Places Autocomplete API.
    // I need the API Key. I'll use the one from AndroidManifest: AIzaSyBYJbjMnqYFSQ1lssqHH4A52HWD1H13FtI
    
    final apiKey = 'AIzaSyBYJbjMnqYFSQ1lssqHH4A52HWD1H13FtI'; 
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:pk';
    
    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200) {
        if (response.data['status'] == 'OK' || response.data['status'] == 'ZERO_RESULTS') {
          setState(() {
            _predictions = response.data['predictions'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Autocomplete Network Error: $e');
    }
  }
  
  Future<void> _selectPrediction(String placeId, String description) async {
    setState(() {
      _searchController.text = description;
      _predictions = [];
    });
    
    final apiKey = 'AIzaSyBYJbjMnqYFSQ1lssqHH4A52HWD1H13FtI';
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey';
    
    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200) {
        final result = response.data['result'];
        final location = result['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        
        final latLng = LatLng(lat, lng);
        setState(() => _center = latLng);
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 15.0),
          ),
        );
      }
    } catch (e) {
      print('Place Details error: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent map from resizing when keyboard opens
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15.0,
            ),
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We'll use custom button if needed
            zoomControlsEnabled: false,
          ),
          
          // Search Bar
          // Search Bar & Autocomplete
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.isSelecting) ...[
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged, // Hook up autocomplete
                          onSubmitted: (_) => _searchLocation(), // Keep manual search too
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _predictions = []);
                                    },
                                  )
                                : const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Autocomplete Suggestions Overlay
                if (_predictions.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8, left: widget.isSelecting ? 50 : 0), // Offset if back button exists
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return ListTile(
                          title: Text(
                            prediction['description'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          leading: const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          dense: true,
                          onTap: () => _selectPrediction(
                            prediction['place_id'],
                            prediction['description'],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Center Marker (Fixed)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Icon(
                Icons.location_on,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
          ),
          
          // Current Location Button
          Positioned(
            right: 16,
            bottom: 200,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),
          
          // Bottom Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Text(
                    widget.isSelecting ? 'Select Location' : 'Set Home Location',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Move the map to point to the location',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: widget.isSelecting ? 'Confirm Location' : 'Save & Continue',
                    onPressed: _confirmLocation,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
