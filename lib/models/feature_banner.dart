/// Feature Banner Model - For home screen carousel
class FeatureBanner {
  final int id;
  final String? name;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? linkUrl;
  final int sortOrder;

  FeatureBanner({
    required this.id,
    this.name,
    this.title,
    this.description,
    this.imageUrl,
    this.linkUrl,
    this.sortOrder = 0,
  });

  factory FeatureBanner.fromJson(Map<String, dynamic> json) {
    return FeatureBanner(
      id: json['id'] ?? 0,
      name: json['name'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      linkUrl: json['link_url'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
