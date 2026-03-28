import 'cart_item.dart';

/// Customer Model
class Customer {
  final int id;
  final String mobile;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? gender;
  final String? profileImage;
  final bool isActive;
  final String? token;
  final List<CustomerAddress> addresses;
  final CustomerAddress? defaultAddress;
  
  Customer({
    required this.id,
    required this.mobile,
    this.firstName,
    this.lastName,
    this.email,
    this.gender,
    this.profileImage,
    this.isActive = true,
    this.token,
    this.addresses = const [],
    this.defaultAddress,
  });
  
  /// Full name from first + last
  String? get name {
    if (firstName == null && lastName == null) return null;
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }
  
  factory Customer.fromJson(Map<String, dynamic> json) {
    // Parse addresses if available
    List<CustomerAddress> addresses = [];
    if (json['addresses'] != null) {
      addresses = (json['addresses'] as List)
          .map((a) => CustomerAddress.fromJson(a))
          .toList();
    }
    
    // Parse default address
    CustomerAddress? defaultAddr;
    if (json['default_address'] != null) {
      defaultAddr = CustomerAddress.fromJson(json['default_address']);
    }
    
    return Customer(
      id: json['id'] ?? 0,
      mobile: json['mobile'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      gender: json['gender'],
      profileImage: json['profile_image'],
      isActive: json['status'] == 'active',
      token: json['token'],
      addresses: addresses,
      defaultAddress: defaultAddr,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile': mobile,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'gender': gender,
      'profile_image': profileImage,
      'status': isActive ? 'active' : 'inactive',
      'addresses': addresses.map((a) => a.toJson()).toList(),
      'default_address': defaultAddress?.toJson(),
    };
  }
  
  Customer copyWith({
    int? id,
    String? mobile,
    String? firstName,
    String? lastName,
    String? email,
    String? gender,
    String? profileImage,
    bool? isActive,
    String? token,
    List<CustomerAddress>? addresses,
    CustomerAddress? defaultAddress,
  }) {
    return Customer(
      id: id ?? this.id,
      mobile: mobile ?? this.mobile,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      isActive: isActive ?? this.isActive,
      token: token ?? this.token,
      addresses: addresses ?? this.addresses,
      defaultAddress: defaultAddress ?? this.defaultAddress,
    );
  }
}
