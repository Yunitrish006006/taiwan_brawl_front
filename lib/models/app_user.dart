import '../utils/remote_image_url.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.bio,
    this.avatarUrl,
    this.googleAvatarUrl,
    this.customAvatarUrl,
    this.uploadedAvatarUrl,
    this.uploadedAvatarVersion,
    this.avatarSource,
    this.lastActiveAt,
    required this.themeMode,
    required this.fontSizeScale,
    required this.locale,
    required this.llmBaseUrl,
    required this.llmModel,
    required this.hasLlmApiKey,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? bio;
  final String? avatarUrl;
  final String? googleAvatarUrl;
  final String? customAvatarUrl;
  final String? uploadedAvatarUrl;
  final int? uploadedAvatarVersion;
  final String? avatarSource;
  final String? lastActiveAt;
  final String themeMode;
  final double fontSizeScale;
  final String locale;
  final String llmBaseUrl;
  final String llmModel;
  final bool hasLlmApiKey;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'player',
      bio: json['bio'] as String?,
      avatarUrl: resolveRemoteImageUrl(json['avatar_url'] as String?),
      googleAvatarUrl: resolveRemoteImageUrl(
        json['google_avatar_url'] as String?,
      ),
      customAvatarUrl: resolveRemoteImageUrl(
        json['custom_avatar_url'] as String?,
      ),
      uploadedAvatarUrl: resolveRemoteImageUrl(
        json['uploaded_avatar_url'] as String?,
      ),
      uploadedAvatarVersion: (json['uploaded_avatar_version'] as num?)?.toInt(),
      avatarSource: json['avatar_source'] as String?,
      lastActiveAt: json['last_active_at'] as String?,
      themeMode: (json['theme_mode'] as String?) ?? 'system',
      fontSizeScale: (json['font_size_scale'] as num?)?.toDouble() ?? 1.0,
      locale: (json['locale'] as String?) ?? 'zh-Hant',
      llmBaseUrl:
          (json['llm_base_url'] as String?) ?? 'https://api.openai.com/v1',
      llmModel: (json['llm_model'] as String?) ?? 'gpt-4o-mini',
      hasLlmApiKey: json['llm_has_api_key'] as bool? ?? false,
    );
  }
}
