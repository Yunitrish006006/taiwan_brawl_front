import 'package:front/widgets/settings_panel.dart';

import '../../services/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _customAvatarUrlController = TextEditingController();
  String _avatarSource = 'google';
  int? _seededUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthService>().user;
    if (user != null && _seededUserId != user.id) {
      _seededUserId = user.id;
      _nameController.text = user.name;
      _bioController.text = user.bio ?? '';
      _customAvatarUrlController.text = user.customAvatarUrl ?? '';
      _avatarSource = user.avatarSource == 'custom' ? 'custom' : 'google';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _customAvatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await context.read<AuthService>().updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarSource: _avatarSource,
        customAvatarUrl: _customAvatarUrlController.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, '個人資料已更新');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    }
  }

  String _previewAvatarUrl(AppUser user) {
    final customAvatarUrl = _customAvatarUrlController.text.trim();
    if (_avatarSource == 'custom') {
      return customAvatarUrl;
    }
    return user.googleAvatarUrl ?? '';
  }

  Widget _buildAvatarPreview(AppUser user) {
    final avatarUrl = _previewAvatarUrl(user);
    final hasAvatar = avatarUrl.isNotEmpty;

    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.28),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: hasAvatar
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _AvatarFallback(
                        label: _nameController.text.trim(),
                      );
                    },
                  )
                : _AvatarFallback(label: _nameController.text.trim()),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hasAvatar ? '目前頭像預覽' : '目前沒有可用頭像',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final t = context.watch<LocaleProvider>().translation;
    if (user == null) {
      return Scaffold(body: Center(child: Text(t['請先登入'] ?? '請先登入')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t['個人資料'] ?? '個人資料')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Email: ${user.email}'),
              const SizedBox(height: 8),
              Text('玩家 ID: ${user.id}'),
              const SizedBox(height: 20),
              Center(child: _buildAvatarPreview(user)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/friends'),
                icon: const Icon(Icons.group_outlined),
                label: const Text('打開好友系統'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: t['名稱'] ?? '名稱'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text('頭像來源', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'google',
                    icon: Icon(Icons.account_circle_outlined),
                    label: Text('Google'),
                  ),
                  ButtonSegment<String>(
                    value: 'custom',
                    icon: Icon(Icons.edit_outlined),
                    label: Text('自訂'),
                  ),
                ],
                selected: {_avatarSource},
                onSelectionChanged: (selection) {
                  final nextSource = selection.first;
                  if (nextSource == 'google' &&
                      (user.googleAvatarUrl == null ||
                          user.googleAvatarUrl!.isEmpty)) {
                    showAppSnackBar(context, '這個帳號目前沒有可用的 Google 頭像');
                    return;
                  }
                  setState(() {
                    _avatarSource = nextSource;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _avatarSource == 'google'
                    ? '使用 Google 登入時的頭像，之後重新登入也會自動同步最新照片。'
                    : '使用你自訂的圖片網址，之後 Google 登入也不會覆蓋它。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customAvatarUrlController,
                keyboardType: TextInputType.url,
                enabled: _avatarSource == 'custom',
                decoration: const InputDecoration(
                  labelText: '自訂頭像網址',
                  hintText: 'https://example.com/avatar.png',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 4,
                decoration: InputDecoration(labelText: t['自我介紹'] ?? '自我介紹'),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: Text(t['儲存'] ?? '儲存')),
              const SizedBox(height: 24),
              // 顯示設定面板
              const SettingsPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    final glyph = text.isEmpty ? '?' : text.characters.first;
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        glyph,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
