import 'dart:async';

import 'package:flutter/foundation.dart';

/// Faz o GoRouter "reavaliar redirect" toda vez que um Stream emite evento.
/// Padrão bem comum para auth com Firebase + go_router.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
