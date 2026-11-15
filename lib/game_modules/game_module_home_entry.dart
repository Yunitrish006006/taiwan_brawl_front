import 'package:flutter/material.dart';

class GameModuleHomeEntry {
  const GameModuleHomeEntry({
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.tag,
    required this.icon,
    required this.accentColor,
    required this.routeName,
    this.isPrimary = false,
    this.titleResolver,
    this.descriptionResolver,
  });

  final String moduleId;
  final String titleKey;
  final String descriptionKey;
  final String tag;
  final IconData icon;
  final Color accentColor;
  final String routeName;
  final bool isPrimary;
  final String Function(String locale)? titleResolver;
  final String Function(String locale)? descriptionResolver;
}

class GameModuleHomeCollectionEntry {
  const GameModuleHomeCollectionEntry({
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.routeName,
  });

  final String moduleId;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final String routeName;
}
