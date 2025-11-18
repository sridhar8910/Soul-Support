class Counselor {
  final String id;
  final String name;
  final String email;
  final String specialization;
  final String? bio;
  final String? photoUrl;
  final List<String> certifications;
  final bool isVerified;
  final double rating;
  final int totalSessions;

  Counselor({
    required this.id,
    required this.name,
    required this.email,
    required this.specialization,
    this.bio,
    this.photoUrl,
    this.certifications = const [],
    this.isVerified = false,
    this.rating = 0.0,
    this.totalSessions = 0,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }

  factory Counselor.fromJson(Map<String, dynamic> json) {
    return Counselor(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      specialization: json['specialization'],
      bio: json['bio'],
      photoUrl: json['photoUrl'],
      certifications: List<String>.from(json['certifications'] ?? []),
      isVerified: json['isVerified'] ?? false,
      rating: _parseDouble(json['rating']),
      totalSessions: json['totalSessions'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'specialization': specialization,
      'bio': bio,
      'photoUrl': photoUrl,
      'certifications': certifications,
      'isVerified': isVerified,
      'rating': rating,
      'totalSessions': totalSessions,
    };
  }
}
