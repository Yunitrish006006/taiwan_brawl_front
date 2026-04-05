part of 'card_management_page.dart';

extension _CardManagementFormLayout on _CardManagementPageState {
  Widget _buildCardList(Map<String, String> t, {bool phoneLayout = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.text('Card List'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: phoneLayout
                      ? _openMobileEditorForNewCard
                      : _applyNewCardDefaults,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.text('New Card')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_cards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(t.text('No cards found'))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 720),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _cards.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    final selected =
                        !_isCreatingNew && _selectedCardId == card.id;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                      leading: _CardImageThumbnail(card: card),
                      title: Text(
                        card.localizedName(
                          context.read<LocaleProvider>().locale,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${card.id} · ${_typeLabel(t, card.type)} · ${_cardEnergyCostLabel(t, card)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => phoneLayout
                          ? _openMobileEditorForCard(card)
                          : _applyCard(card),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(
    Map<String, String> t,
    TextEditingController controller,
    String label, {
    String? hint,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: t.text(label),
        hintText: hint,
        helperText: helper == null ? null : t.text(helper),
      ),
    );
  }

  Widget _buildTextField(
    Map<String, String> t,
    TextEditingController controller,
    String label, {
    String? hint,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: t.text(label), hintText: hint),
    );
  }

  Widget _buildFieldBox(Widget child, {double width = 180}) {
    return SizedBox(width: width, child: child);
  }

  Widget _buildDropdownField({
    required Map<String, String> t,
    required String value,
    required String label,
    required String keyPrefix,
    required List<String> options,
    required String Function(String value) labelBuilder,
    required ValueChanged<String> onChanged,
    double width = 220,
  }) {
    return _buildFieldBox(
      DropdownButtonFormField<String>(
        key: ValueKey('$keyPrefix-$value-$_selectedCardId'),
        initialValue: value,
        decoration: InputDecoration(labelText: t.text(label)),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(labelBuilder(option)),
              ),
            )
            .toList(),
        onChanged: (nextValue) {
          if (nextValue == null) {
            return;
          }
          onChanged(nextValue);
        },
      ),
      width: width,
    );
  }

  Widget _buildFormHeader(Map<String, String> t, String formIntro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.text('Card Management'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          t.text(
            'Create or edit card stats and effects. Changes are saved to the live cards table immediately.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.text(
            'Cards are stored in the D1 cards table. Starter definitions live in src/royale_cards.js and seed the table when empty.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            t.text(
              'World unit scale: the battlefield uses 1000-based integer coordinates. Example: Attack Range 280 means 28% of the map height, and Body Radius 18 means the unit body takes 1.8% of the map height.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(formIntro),
        ),
      ],
    );
  }

  Widget _buildLocalizedNameFields(Map<String, String> t) {
    return Column(
      children: [
        _buildTextField(
          t,
          _idController,
          'Card ID',
          hint: 'swordsman',
          enabled: _isCreatingNew,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          t,
          _nameZhHantController,
          'Card Name (Traditional Chinese)',
        ),
        const SizedBox(height: 12),
        _buildTextField(t, _nameEnController, 'Card Name (English)'),
        const SizedBox(height: 12),
        _buildTextField(t, _nameJaController, 'Card Name (Japanese)'),
      ],
    );
  }

  Widget _buildSelectionFields(Map<String, String> t) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildFieldBox(
          _buildNumberField(t, _elixirCostController, 'Energy Cost'),
          width: 220,
        ),
        _buildDropdownField(
          t: t,
          value: _selectedEnergyCostType,
          label: 'Energy Type',
          keyPrefix: 'energy-type',
          options: _CardManagementPageState._energyCostTypeOptions,
          labelBuilder: (value) => _energyCostTypeLabel(t, value),
          onChanged: _setSelectedEnergyCostType,
        ),
        _buildDropdownField(
          t: t,
          value: _selectedType,
          label: 'Type',
          keyPrefix: 'type',
          options: _CardManagementPageState._typeOptions,
          labelBuilder: (value) => _typeLabel(t, value),
          onChanged: _setSelectedType,
        ),
        _buildDropdownField(
          t: t,
          value: _selectedTargetRule,
          label: 'Target Rule',
          keyPrefix: 'target',
          options: _CardManagementPageState._targetRuleOptions,
          labelBuilder: (value) => _targetRuleLabel(t, value),
          onChanged: _setSelectedTargetRule,
        ),
        _buildDropdownField(
          t: t,
          value: _selectedEffectKind,
          label: 'Effect Kind',
          keyPrefix: 'effect',
          options: _CardManagementPageState._effectKindOptions,
          labelBuilder: (value) => _effectKindLabel(t, value),
          onChanged: _setSelectedEffectKind,
        ),
      ],
    );
  }

  Widget _buildStatFields(Map<String, String> t) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildFieldBox(
          _buildNumberField(
            t,
            _hpController,
            'HP',
            helper: 'Hit points. Uses normal game damage values.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(
            t,
            _damageController,
            'Damage',
            helper: 'Damage dealt on each successful attack.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(
            t,
            _attackRangeController,
            'Attack Range',
            helper:
                'Weapon reach in world units. This does not include the unit body radius.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(
            t,
            _bodyRadiusController,
            'Body Radius',
            helper:
                'Unit body size in world units. Final reach uses body radius plus attack range.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(
            t,
            _moveSpeedController,
            'Move Speed',
            helper:
                'Movement speed in world units per second before global battle multipliers.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(
            t,
            _attackSpeedController,
            'Attack Speed',
            helper: 'Seconds between attacks. Smaller values attack faster.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(t, _spawnCountController, 'Spawn Count'),
        ),
        _buildFieldBox(
          _buildNumberField(
            t,
            _spellRadiusController,
            'Spell Radius',
            helper: 'Spell area radius in world units.',
          ),
        ),
        _buildFieldBox(
          _buildNumberField(t, _spellDamageController, 'Spell Damage'),
        ),
        _buildFieldBox(
          _buildNumberField(t, _effectValueController, 'Effect Value'),
        ),
      ],
    );
  }

  Widget _buildProgressActionIcon(bool busy, IconData icon) {
    if (busy) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(icon);
  }

  Widget _buildFormActionBar(Map<String, String> t) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveCard,
          icon: _buildProgressActionIcon(_isSaving, Icons.save_outlined),
          label: Text(t.text('Save Card')),
        ),
        OutlinedButton.icon(
          onPressed: _isDeleting || _isCreatingNew ? null : _deleteCard,
          icon: _buildProgressActionIcon(
            _isDeleting,
            Icons.delete_outline_rounded,
          ),
          label: Text(t.text('Delete Card')),
        ),
        TextButton.icon(
          onPressed: _applyNewCardDefaults,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: Text(t.text('Create a new card')),
        ),
      ],
    );
  }

  Widget _buildPageContent(Map<String, String> t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final phoneLayout = constraints.maxWidth < 700;
              final vertical = constraints.maxWidth < 1100;
              if (phoneLayout) {
                if (_showMobileEditor) {
                  return ListView(
                    children: [
                      _buildForm(t),
                    ],
                  );
                }
                return ListView(
                  children: [
                    _buildCardList(t, phoneLayout: true),
                  ],
                );
              }
              if (vertical) {
                return ListView(
                  children: [
                    _buildCardList(t),
                    const SizedBox(height: 16),
                    _buildForm(t),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: _buildCardList(t)),
                  const SizedBox(width: 16),
                  Expanded(child: SingleChildScrollView(child: _buildForm(t))),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Map<String, String> t) {
    final selectedCard = _selectedCard();
    final formIntro = _isCreatingNew
        ? t.text('Create a new card')
        : t.text(
            'Editing existing card IDs is disabled. Create a new card if you need a different ID.',
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormHeader(t, formIntro),
            const SizedBox(height: 16),
            _buildLocalizedNameFields(t),
            const SizedBox(height: 12),
            _CardImageEditor(
              card: selectedCard,
              pendingImageBytes: _pendingImageBytes,
              onPickImage: _pickImage,
              onUploadImage: _uploadImage,
              onRemoveImage: _removeImage,
              isCreatingNew: _isCreatingNew,
              isUploadingImage: _isUploadingImage,
              isRemovingImage: _isRemovingImage,
              hasPendingImage: _pendingImageBytes != null,
              translation: t,
            ),
            const SizedBox(height: 12),
            _buildSelectionFields(t),
            const SizedBox(height: 12),
            _buildStatFields(t),
            const SizedBox(height: 20),
            _buildFormActionBar(t),
          ],
        ),
      ),
    );
  }
}
