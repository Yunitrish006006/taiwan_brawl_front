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
    final t = context.read<LocaleProvider>().translation;
    try {
      await context.read<AuthService>().updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarSource: _avatarSource,
        customAvatarUrl: _customAvatarUrlController.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, t.text('Profile updated'));
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

  Widget _buildAvatarPreview(AppUser user, Map<String, String> t) {
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
          hasAvatar ? t.text('Avatar Preview') : t.text('No avatar available'),
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
      return Scaffold(body: Center(child: Text(t.text('Please log in first'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.text('Profile'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Email: ${user.email}'),
              const SizedBox(height: 8),
              Text('${t.text('Player ID')}: ${user.id}'),
              const SizedBox(height: 20),
              Center(child: _buildAvatarPreview(user, t)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/friends'),
                icon: const Icon(Icons.group_outlined),
                label: Text(t.text('Open Friends')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: t.text('Name')),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                t.text('Avatar Source'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'google',
                    icon: Icon(Icons.account_circle_outlined),
                    label: Text('Google'),
                  ),
                  ButtonSegment<String>(
                    value: 'custom',
                    icon: Icon(Icons.edit_outlined),
                    label: Text(t.text('Custom')),
                  ),
                ],
                selected: {_avatarSource},
                onSelectionChanged: (selection) {
                  final nextSource = selection.first;
                  if (nextSource == 'google' &&
                      (user.googleAvatarUrl == null ||
                          user.googleAvatarUrl!.isEmpty)) {
                    showAppSnackBar(
                      context,
                      t.text(
                        'This account does not have an available Google avatar.',
                      ),
                    );
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
                    ? t.text(
                        'Use your Google sign-in avatar. It will sync again the next time you sign in.',
                      )
                    : t.text(
                        'Use your custom image URL. Future Google sign-ins will not overwrite it.',
                      ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customAvatarUrlController,
                keyboardType: TextInputType.url,
                enabled: _avatarSource == 'custom',
                decoration: InputDecoration(
                  labelText: t.text('Custom Avatar URL'),
                  hintText: 'https://example.com/avatar.png',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 4,
                decoration: InputDecoration(labelText: t.text('Bio')),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: Text(t.text('Save'))),
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
