
class Booking {
  final int id;
  final String bookingNumber;
  final String status;
  final String date;
  final String time;
  final double totalAmount;
  final String categoryName;
  final List<BookingItem> items;
  final Handyman? handyman;
  final BookingAddress? address;

  Booking({
    required this.id,
    required this.bookingNumber,
    required this.status,
    required this.date,
    required this.time,
    required this.totalAmount,
    required this.categoryName,
    required this.items,
    this.handyman,
    this.address,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    String fullDate = json['booking_date'] ?? '';
    String dateStr = '';
    String timeStr = '';
    
    if (fullDate.isNotEmpty) {
      try {
        final DateTime dt = DateTime.parse(fullDate);
        dateStr = "${dt.day} ${_getMonth(dt.month)} ${dt.year}";
        timeStr = "${dt.hour > 12 ? dt.hour - 12 : dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
      } catch (e) {
        dateStr = fullDate;
      }
    }

    return Booking(
      id: int.tryParse(json['id'].toString()) ?? 0,
      bookingNumber: json['booking_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      date: dateStr,
      time: timeStr,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      categoryName: json['category']?['category_name'] ?? 'General',
      items: (json['items'] as List? ?? [])
          .map((item) => BookingItem.fromJson(item))
          .toList(),
      handyman: json['handyman'] != null ? Handyman.fromJson(json['handyman']) : null,
      address: json['address'] != null ? BookingAddress.fromJson(json['address']) : null,
    );
  }

  /// Short display: "AC Repair + 1 more"
  String get servicesText {
    final activeItems = items.where((i) => i.status == 'active').toList();
    if (activeItems.isEmpty) return 'No active services';
    if (activeItems.length == 1) return activeItems.first.serviceName;
    return '${activeItems.first.serviceName} + ${activeItems.length - 1} more';
  }

  /// Number of active items
  int get activeItemCount => items.where((i) => i.status == 'active').length;

  static String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class BookingItem {
  final int id;
  final int serviceId;
  final String serviceName;
  final int quantity;
  final double price;
  final double totalPrice;
  final String status;

  BookingItem({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    required this.status,
  });

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      serviceId: int.tryParse(json['service_id'].toString()) ?? 0,
      serviceName: json['service']?['service_name'] ?? 'Unknown Service',
      quantity: int.tryParse(json['quantity'].toString()) ?? 1,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      totalPrice: double.tryParse(json['total_price'].toString()) ?? 0.0,
      status: json['status'] ?? 'active',
    );
  }
}

class Handyman {
  final int id;
  final String name;
  final String mobile;
  final String? profileImage;

  Handyman({
    required this.id,
    required this.name,
    required this.mobile,
    this.profileImage,
  });

  factory Handyman.fromJson(Map<String, dynamic> json) {
    return Handyman(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: "${json['first_name']} ${json['last_name']}",
      mobile: json['mobile'] ?? '',
      profileImage: json['profile_image'],
    );
  }
}

class BookingAddress {
  final int id;
  final String address;
  final double? latitude;
  final double? longitude;

  BookingAddress({
    required this.id,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory BookingAddress.fromJson(Map<String, dynamic> json) {
    return BookingAddress(
      id: int.tryParse(json['id'].toString()) ?? 0,
      address: json['address'] ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    );
  }
}
