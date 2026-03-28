/// Service Category Model
class ServiceCategory {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final bool isFeatured;
  final int servicesCount;
  
  ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.isFeatured = false,
    this.servicesCount = 0,
  });
  
  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] ?? 0,
      name: json['category_name'] ?? json['name'] ?? '',
      description: json['description'],
      image: json['image'],
      isFeatured: json['is_featured'] == 1 || json['is_featured'] == true,
      servicesCount: json['services_count'] ?? 0,
    );
  }
}

/// Service Model
class Service {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final double regularPrice;
  final double? salePrice;
  final double rating;
  final int? categoryId;
  final String? categoryName;
  final bool isFeatured;
  
  Service({
    required this.id,
    required this.name,
    this.description,
    this.image,
    required this.regularPrice,
    this.salePrice,
    this.rating = 0,
    this.categoryId,
    this.categoryName,
    this.isFeatured = false,
  });
  
  factory Service.fromJson(Map<String, dynamic> json) {
    // Extract category info if present
    final category = json['category'] as Map<String, dynamic>?;
    
    return Service(
      id: json['id'] ?? 0,
      name: json['service_name'] ?? json['name'] ?? '',
      description: json['description'],
      image: json['image'],
      regularPrice: double.tryParse(json['regular_price']?.toString() ?? '0') ?? 0,
      salePrice: double.tryParse(json['sale_price']?.toString() ?? '0'),
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      categoryId: json['category_id'] ?? category?['id'],
      categoryName: category?['category_name'] ?? category?['name'],
      isFeatured: json['is_featured'] == 1 || json['is_featured'] == true,
    );
  }
  
  bool get hasDiscount => salePrice != null && regularPrice > salePrice!;
  double get discountPercent => hasDiscount ? ((regularPrice - salePrice!) / regularPrice * 100) : 0;
}
