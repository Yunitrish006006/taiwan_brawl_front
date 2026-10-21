import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../config/app_configuration.dart';
import 'api_client.dart';
import 'royale_remote_source.dart';

export 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    show MiniRoyaleService;
export 'royale_remote_source.dart'
    show RoyaleRemoteSource, RoyaleRoomChannel, RoyaleRoomChannelFactory;

/// Host composition adapter. The game-owned application service lives in the
/// Mini Royale package; this wrapper only supplies host HTTP and configuration.
class RoyaleService extends MiniRoyaleService {
  RoyaleService(
    ApiClient apiClient, {
    RoyaleRoomChannelFactory? channelFactory,
    RoyaleRemoteSource? remoteSource,
    AppConfiguration? configuration,
    super.gameContractProvider,
  }) : super(
         remotePort:
             remoteSource ??
             ServerRoyaleRemoteSource(
               apiClient,
               channelFactory: channelFactory,
             ),
         apiBaseUrl: (configuration ?? AppConfiguration.environment).apiBaseUrl,
       );

  @override
  Future<RoyaleRoomChannel> connectToRoom(String roomCode) async =>
      await remotePort.connectToRoom(roomCode, gameContract) as RoyaleRoomChannel;
}
