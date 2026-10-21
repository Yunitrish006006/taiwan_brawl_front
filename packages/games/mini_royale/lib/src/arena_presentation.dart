import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

const miniRoyaleArenaPresentationResourceId =
    'game.mini-royale.arena-presentation';
const miniRoyaleArenaPresentationSchemaVersion = 1;

/// Versioned, non-gameplay presentation data for the Mini Royale arena.
class MiniRoyaleArenaPresentation {
  const MiniRoyaleArenaPresentation({required this.fieldColors});

  static const fallback = MiniRoyaleArenaPresentation(
    fieldColors: [
      Color(0xFFDEF4FF),
      Color(0xFF9DD6FF),
      Color(0xFF7EC97D),
      Color(0xFF5DAA4D),
    ],
  );

  final List<Color> fieldColors;

  factory MiniRoyaleArenaPresentation.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != miniRoyaleArenaPresentationSchemaVersion) {
      throw const FormatException(
        'Unsupported Mini Royale presentation schema.',
      );
    }
    final rawColors = json['fieldColors'];
    if (rawColors is! List || rawColors.length != 4) {
      throw const FormatException(
        'Arena presentation requires four field colors.',
      );
    }
    final colors = rawColors
        .map((value) {
          if (value is! String ||
              !RegExp(r'^#[0-9a-fA-F]{8}$').hasMatch(value)) {
            throw const FormatException('Invalid arena presentation color.');
          }
          return Color(int.parse(value.substring(1), radix: 16));
        })
        .toList(growable: false);
    return MiniRoyaleArenaPresentation(fieldColors: List.unmodifiable(colors));
  }

  Map<String, Object> toJson() => {
    'schemaVersion': miniRoyaleArenaPresentationSchemaVersion,
    'fieldColors': fieldColors
        .map(
          (color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        )
        .toList(growable: false),
  };
}

/// Validates presentation payload bytes before the host activates this pack.
Future<void> validateMiniRoyaleArenaPresentationPayload(
  Uint8List payload,
) async {
  final decoded = jsonDecode(utf8.decode(payload, allowMalformed: false));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Arena presentation root must be an object.');
  }
  MiniRoyaleArenaPresentation.fromJson(decoded);
}

abstract interface class MiniRoyaleArenaPresentationSource {
  Future<String?> readActivePresentationJson();
}

Future<MiniRoyaleArenaPresentation> loadMiniRoyaleArenaPresentation(
  MiniRoyaleArenaPresentationSource source,
) async {
  try {
    final json = await source.readActivePresentationJson();
    if (json == null) return MiniRoyaleArenaPresentation.fallback;
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Arena presentation root must be an object.');
    }
    return MiniRoyaleArenaPresentation.fromJson(decoded);
  } on FormatException {
    return MiniRoyaleArenaPresentation.fallback;
  }
}
