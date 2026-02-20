/// A single promoted ad from GET /api/v1/ads/active.
class PromotedAdModel {
  final String id;
  final String imageUrl;
  final String link;
  final String? title;
  final bool isActive;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PromotedAdModel({
    required this.id,
    required this.imageUrl,
    required this.link,
    this.title,
    this.isActive = true,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PromotedAdModel.fromJson(Map<String, dynamic> json) {
    return PromotedAdModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      title: json['title']?.toString(),
      isActive: json['isActive'] == true,
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }
}
