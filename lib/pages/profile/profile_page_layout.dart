part of 'profile_page.dart';

extension _ProfilePageLayout on _ProfilePageState {
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

  Widget _buildAvatarSourceSection(AppUser user, Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.text('Avatar Source'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            const ButtonSegment<String>(
              value: 'google',
              icon: Icon(Icons.account_circle_outlined),
              label: Text('Google'),
            ),
            ButtonSegment<String>(
              value: 'custom',
              icon: const Icon(Icons.edit_outlined),
              label: Text(t.text('Custom')),
            ),
            ButtonSegment<String>(
              value: 'upload',
              icon: const Icon(Icons.photo_library_outlined),
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
          onChanged: (_) => _refreshProfileDraftPreview(),
        ),
      ],
    );
  }

  Widget _buildUploadedAvatarCard(AppUser user, Map<String, String> t) {
    return Card(
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
                  onPressed: _isUploadingAvatar || _pendingAvatarBytes == null
                      ? null
                      : () => _uploadAvatarImage(),
                  icon: _buildLoadingActionIcon(
                    _isUploadingAvatar,
                    Icons.cloud_upload_outlined,
                  ),
                  label: Text(t.text('Upload Selected Image')),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isRemovingAvatar ||
                          (!_hasUploadedAvatar(user) &&
                              _pendingAvatarBytes == null)
                      ? null
                      : _removeAvatarImage,
                  icon: _buildLoadingActionIcon(
                    _isRemovingAvatar,
                    Icons.delete_outline,
                  ),
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
    );
  }

  Widget _buildProfileBody(AppUser user, Map<String, String> t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Email: ${user.email}'),
            const SizedBox(height: 20),
            Center(child: _buildAvatarPreview(user, t)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.text('Name')),
              onChanged: (_) => _refreshProfileDraftPreview(),
            ),
            const SizedBox(height: 12),
            _buildAvatarSourceSection(user, t),
            const SizedBox(height: 12),
            _buildUploadedAvatarCard(user, t),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(labelText: t.text('Bio')),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(t.text('Save'))),
            const SizedBox(height: 24),
            const SettingsPanel(),
          ],
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
