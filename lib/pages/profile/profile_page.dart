import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarMimeType;
  String? _pendingAvatarFileName;
  bool _isUploadingAvatar = false;
  bool _isRemovingAvatar = false;

  AuthService get _auth => context.read<AuthService>();
  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  void _clearPendingAvatarSelection() {
    _pendingAvatarBytes = null;
    _pendingAvatarMimeType = null;
    _pendingAvatarFileName = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = _auth.user;
    if (user != null && _seededUserId != user.id) {
      _seededUserId = user.id;
      _nameController.text = user.name;
      _bioController.text = user.bio ?? '';
      _customAvatarUrlController.text = user.customAvatarUrl ?? '';
      _avatarSource = ['google', 'custom', 'upload'].contains(user.avatarSource)
          ? user.avatarSource!
          : 'google';
      _clearPendingAvatarSelection();
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
      if (_avatarSource == 'upload' && _pendingAvatarBytes != null) {
        await _uploadAvatarImage(showSuccessMessage: false);
      }
      if (!mounted) return;
      final latestUser = _auth.user;
      if (_avatarSource == 'upload' &&
          (latestUser?.uploadedAvatarUrl == null ||
              latestUser!.uploadedAvatarUrl!.isEmpty)) {
        showAppSnackBar(
          context,
          _t.text('Please upload an avatar image first'),
        );
        return;
      }
      await _auth.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarSource: _avatarSource,
        customAvatarUrl: _customAvatarUrlController.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, _t.text('Profile updated'));
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
    if (_avatarSource == 'upload') {
      return user.uploadedAvatarUrl ?? '';
    }
    return user.googleAvatarUrl ?? '';
  }

  bool _hasUploadedAvatar(AppUser user) {
    return (user.uploadedAvatarUrl ?? '').isNotEmpty;
  }

  bool _canUseGoogleAvatar(AppUser user) {
    return (user.googleAvatarUrl ?? '').isNotEmpty;
  }

  String _avatarSourceDescription(Map<String, String> t) {
    switch (_avatarSource) {
      case 'custom':
        return t.text(
          'Use your custom image URL. Future Google sign-ins will not overwrite it.',
        );
      case 'upload':
        return t.text(
          'Use an uploaded image stored in Taiwan Brawl. You can pick a file from your device and future Google sign-ins will not overwrite it.',
        );
      case 'google':
      default:
        return t.text(
          'Use your Google sign-in avatar. It will sync again the next time you sign in.',
        );
    }
  }

  void _selectAvatarSource(String nextSource, AppUser user) {
    if (nextSource == 'google' && !_canUseGoogleAvatar(user)) {
      showAppSnackBar(
        context,
        _t.text('This account does not have an available Google avatar.'),
      );
      return;
    }
    if (nextSource == 'upload' &&
        _pendingAvatarBytes == null &&
        !_hasUploadedAvatar(user)) {
      showAppSnackBar(context, _t.text('Please upload an avatar image first'));
      return;
    }
    setState(() {
      _avatarSource = nextSource;
    });
  }

  String? _detectImageMimeType(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  Future<void> _pickAvatarImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showAppSnackBar(context, _t.text('Selected file has no readable bytes'));
      return;
    }

    final mimeType = _detectImageMimeType(file);
    if (mimeType == null) {
      showAppSnackBar(context, _t.text('Selected image is unsupported'));
      return;
    }

    if (bytes.length > 1024 * 1024) {
      showAppSnackBar(context, _t.text('Image must be 1 MB or smaller'));
      return;
    }

    setState(() {
      _pendingAvatarBytes = bytes;
      _pendingAvatarMimeType = mimeType;
      _pendingAvatarFileName = file.name;
      _avatarSource = 'upload';
    });
  }

  Future<void> _uploadAvatarImage({bool showSuccessMessage = true}) async {
    final bytes = _pendingAvatarBytes;
    final mimeType = _pendingAvatarMimeType;
    if (bytes == null || mimeType == null) {
      if (showSuccessMessage && mounted) {
        showAppSnackBar(
          context,
          _t.text('Please upload an avatar image first'),
        );
      }
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      await _auth.uploadAvatarImage(
        bytesBase64: base64Encode(bytes),
        contentType: mimeType,
        fileName: _pendingAvatarFileName,
      );
      if (!mounted) return;
      setState(() {
        _clearPendingAvatarSelection();
        _avatarSource = 'upload';
      });
      if (showSuccessMessage) {
        showAppSnackBar(context, _t.text('Avatar image uploaded successfully'));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _removeAvatarImage() async {
    setState(() {
      _isRemovingAvatar = true;
    });
    try {
      await _auth.deleteAvatarImage();
      if (!mounted) return;
      final latestUser = _auth.user;
      if (!mounted) return;
      setState(() {
        _clearPendingAvatarSelection();
        _avatarSource =
            ['google', 'custom', 'upload'].contains(latestUser?.avatarSource)
            ? latestUser!.avatarSource!
            : 'google';
      });
      showAppSnackBar(context, _t.text('Avatar image removed successfully'));
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingAvatar = false;
        });
      }
    }
  }

  Widget _buildAvatarPreview(AppUser user, Map<String, String> t) {
    final avatarUrl = _previewAvatarUrl(user);
    final hasPendingAvatar =
        _pendingAvatarBytes != null && _avatarSource == 'upload';
    final hasAvatar = hasPendingAvatar || avatarUrl.isNotEmpty;

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
            child: hasPendingAvatar
                ? Image.memory(_pendingAvatarBytes!, fit: BoxFit.cover)
                : hasAvatar
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
          hasPendingAvatar
              ? t.text('Avatar Preview (Pending Upload)')
              : hasAvatar
              ? t.text('Avatar Preview')
              : t.text('No avatar available'),
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
                  ButtonSegment<String>(
                    value: 'upload',
                    icon: Icon(Icons.photo_library_outlined),
                    label: Text(t.text('Upload')),
                  ),
                ],
                selected: {_avatarSource},
                onSelectionChanged: (selection) {
                  _selectAvatarSource(selection.first, user);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _avatarSourceDescription(t),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.text('Uploaded Avatar Image'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.text('PNG, JPG, WEBP, or GIF up to 1 MB'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickAvatarImage,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(t.text('Choose Avatar Image')),
                          ),
                          FilledButton.icon(
                            onPressed:
                                _isUploadingAvatar ||
                                    _pendingAvatarBytes == null
                                ? null
                                : () => _uploadAvatarImage(),
                            icon: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(t.text('Upload Selected Image')),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _isRemovingAvatar ||
                                    (!_hasUploadedAvatar(user) &&
                                        _pendingAvatarBytes == null)
                                ? null
                                : _removeAvatarImage,
                            icon: _isRemovingAvatar
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                            label: Text(t.text('Remove Uploaded Image')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pendingAvatarFileName != null
                            ? '${t.text('Selected file')}: $_pendingAvatarFileName'
                            : _hasUploadedAvatar(user)
                            ? t.text('An uploaded avatar image is ready to use')
                            : t.text('No uploaded avatar image yet'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
