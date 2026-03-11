class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.bio,
    required this.themeMode,
    required this.fontSizeScale,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? bio;
  final String themeMode;
  final double fontSizeScale;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      bio: json['bio'] as String?,
      themeMode: (json['theme_mode'] as String?) ?? 'system',
      fontSizeScale: (json['font_size_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
