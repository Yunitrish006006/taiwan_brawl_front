import 'dart:js_interop';

import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

@JS('window.taiwanBrawlStreetScrapLock.acquire')
external JSPromise<JSBoolean> _acquireLock(JSString name, JSString owner);

@JS('window.taiwanBrawlStreetScrapLock.release')
external void _releaseLock(JSString owner);

Future<StreetScrapWriterLease?> acquireStreetScrapWriterLease(
  String slotKey,
) async {
  final owner = '$slotKey:${DateTime.now().microsecondsSinceEpoch}';
  try {
    final acquired = await _acquireLock(
      'taiwan-brawl:street-scrap:$slotKey'.toJS,
      owner.toJS,
    ).toDart;
    if (!acquired.toDart) return null;
    return _WebLease(owner);
  } on Object {
    // Fail closed: if Web Locks is unavailable or the bootstrap is absent,
    // this tab remains read-only rather than risking a lost update.
    return null;
  }
}

class _WebLease implements StreetScrapWriterLease {
  _WebLease(this.owner);

  final String owner;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _releaseLock(owner.toJS);
  }
}
