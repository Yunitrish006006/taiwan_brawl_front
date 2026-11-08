import 'direct_message_service.dart';
import 'direct_message_sync_service.dart';
import 'manual_p2p_dm_service.dart';
import 'relay_fallback_dm_service.dart';
import 'retryable_dm_service.dart';

/// A conversation-scoped DM service with an explicit lifecycle.
/// Retry and manual P2P are optional capabilities, discovered independently.
abstract interface class DirectMessageSession implements DirectMessageService {
  void dispose();
}

extension DirectMessageSessionCapabilities on DirectMessageSession {
  RetryableDmService? get retryCapability {
    final session = this;
    return session is RetryableDmService ? session as RetryableDmService : null;
  }

  ManualP2pDmService? get manualP2pCapability {
    final session = this;
    return session is ManualP2pDmService ? session as ManualP2pDmService : null;
  }

  RelayFallbackDmService? get relayFallbackCapability {
    final session = this;
    return session is RelayFallbackDmService
        ? session as RelayFallbackDmService
        : null;
  }

  DirectMessageSyncService? get syncCapability {
    final session = this;
    return session is DirectMessageSyncService
        ? session as DirectMessageSyncService
        : null;
  }
}

/// Composition-root port for opening a conversation-scoped DM session.
abstract interface class DirectMessageSessionFactory {
  DirectMessageSession create();
}
