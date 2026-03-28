/// Cart Item Model
class CartItem {
  final int serviceId;
  final String serviceName;
  final String? serviceImage;
  final String? description;
  final double regularPrice;
  final double salePrice;
  final double rating;
  int quantity;
  
  CartItem({
    required this.serviceId,
    required this.serviceName,
    this.serviceImage,
    this.description,
    required this.regularPrice,
    required this.salePrice,
    this.rating = 0,
    this.quantity = 1,
  });
  
  double get totalPrice => salePrice * quantity;
  
  CartItem copyWith({int? quantity}) {
    return CartItem(
      serviceId: serviceId,
      serviceName: serviceName,
      serviceImage: serviceImage,
      description: description,
      regularPrice: regularPrice,
      salePrice: salePrice,
      rating: rating,
      quantity: quantity ?? this.quantity,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      'service_name': serviceName,
      'service_image': serviceImage,
      'description': description,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'rating': rating,
      'quantity': quantity,
    };
  }
  
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      serviceId: json['service_id'],
      serviceName: json['service_name'],
      serviceImage: json['service_image'],
      description: json['description'],
      regularPrice: json['regular_price']?.toDouble() ?? 0,
      salePrice: json['sale_price']?.toDouble() ?? 0,
      rating: json['rating']?.toDouble() ?? 0,
      quantity: json['quantity'] ?? 1,
    );
  }
}

/// Customer Address Model
class CustomerAddress {
  final int? id;
  final String address;
  final String? addressType;  // home, work, other
  final String? city;
  final String? area;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  
  CustomerAddress({
    this.id,
    required this.address,
    this.addressType,
    this.city,
    this.area,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });
  
  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id'],
      address: json['address'] ?? '',
      addressType: json['address_type'],
      city: json['city'],
      area: json['area'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'address_type': addressType,
      'city': city,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault ? 1 : 0,
    };
  }
}
