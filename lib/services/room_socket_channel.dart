import 'package:web_socket_channel/web_socket_channel.dart';

import 'room_socket_channel_stub.dart'
    if (dart.library.io) 'room_socket_channel_io.dart'
    as impl;

WebSocketChannel connectRoomSocket(Uri uri, {Map<String, dynamic>? headers}) {
  return impl.connectRoomSocket(uri, headers: headers);
}
