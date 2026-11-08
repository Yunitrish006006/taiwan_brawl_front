import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

final Set<String> _heldSlots = {};

Future<StreetScrapWriterLease?> acquireStreetScrapWriterLease(
  String slotKey,
) async {
  if (!_heldSlots.add(slotKey)) return null;
  return _LocalLease(slotKey);
}

class _LocalLease implements StreetScrapWriterLease {
  _LocalLease(this.slotKey);

  final String slotKey;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _heldSlots.remove(slotKey);
  }
}
