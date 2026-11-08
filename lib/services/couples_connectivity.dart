import 'package:connectivity_plus/connectivity_plus.dart';

/// A network interface is only a hint; API requests can still fail or time out.
Stream<bool> couplesNetworkChanges() => Connectivity().onConnectivityChanged
    .map((values) => values.any((value) => value != ConnectivityResult.none))
    .distinct();
