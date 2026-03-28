import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';
import '../auth/map_address_screen.dart';
import '../../models/cart_item.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Lahore');
  
  String _addressType = 'Home';
  bool _isDefault = false;
  bool _isLoading = false;
  LatLng? _selectedLocation;
  
  final List<String> _types = ['Home', 'Work', 'Other'];

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapAddressScreen(isSelecting: true)),
    );
    
    if (result != null && result is LatLng) {
      setState(() {
        _selectedLocation = result;
        _isLoading = true;
      });
      
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          result.latitude,
          result.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Construct address
          String address = '';
          if (place.name != null && place.name != place.street) address += '${place.name}, ';
          if (place.street != null) address += '${place.street}, ';
          if (place.subLocality != null) address += '${place.subLocality}, ';
          if (place.locality != null) address += place.locality!;
          
          setState(() {
             _addressController.text = address;
             if (place.locality != null) _cityController.text = place.locality!;
          });
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not fetch address details, please enter manually')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Create CustomerAddress object
      final newAddress = CustomerAddress( // Import if needed, but it should be available or I'll add import
        address: _addressController.text,
        city: _cityController.text,
        addressType: _addressType,
        isDefault: _isDefault,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );

      final result = await context.read<AuthProvider>().addAddress(newAddress);
      
      if (result['success'] == true) {
        if (mounted) {
           Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to save address')),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const CustomAppBar(title: 'Add New Address'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address Type
              const Text(
                'Address Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: _types.map((type) {
                  final isSelected = _addressType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => setState(() => _addressType = type),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Address Field Header with Map Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full Address/Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Pick on Map'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
                TextFormField(
                controller: _addressController,
                readOnly: true, // Force map selection
                onTap: _pickLocation, // Open map on tap
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tap to select location on map...',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Icon(Icons.map, color: AppTheme.primary),
                ),
                validator: (v) {
                  if (v?.isEmpty == true) return 'Address is required';
                  if (_selectedLocation == null) return 'Please pick a location on map';
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // City
              const Text(
                'City',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  hintText: 'City Name',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v?.isEmpty == true ? 'City is required' : null,
              ),
              
              const SizedBox(height: 20),
              
              // Set Default
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as Default Address'),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 40),
              
              PrimaryButton(
                text: 'Save Address',
                onPressed: _saveAddress,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}
