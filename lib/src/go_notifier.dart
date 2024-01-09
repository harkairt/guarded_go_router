import 'package:flutter/foundation.dart';
import 'package:guarded_go_router/src/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class GoNotifier extends ChangeNotifier {
  final Ref _ref;
  final List<AlwaysAliveProviderListenable<Object>> dependencies;
  final bool debugLog;

  GoNotifier(
    this._ref, {
    this.dependencies = const [],
    this.debugLog = false,
  }) {
    for (final provider in dependencies) {
      _ref.listen<dynamic>(
        provider,
        (dynamic prev, dynamic next) {
          if (debugLog) {
            timedDebugPrint('⚪️ [$prev => $next] - ${provider.runtimeType}');
          }
          notifyListeners();
        },
      );
    }
  }
}
