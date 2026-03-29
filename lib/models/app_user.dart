class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.bio,
    this.avatarUrl,
    this.lastActiveAt,
    required this.themeMode,
    required this.fontSizeScale,
    required this.locale,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? bio;
  final String? avatarUrl;
  final String? lastActiveAt;
  final String themeMode;
  final double fontSizeScale;
  final String locale;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastActiveAt: json['last_active_at'] as String?,
      themeMode: (json['theme_mode'] as String?) ?? 'system',
      fontSizeScale: (json['font_size_scale'] as num?)?.toDouble() ?? 1.0,
      locale: (json['locale'] as String?) ?? 'zh-Hant',
    );
  }
}
