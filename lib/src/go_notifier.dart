import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guarded_go_router/src/utils.dart';

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
        (dynamic _, dynamic __) {
          if (debugLog) {
            timedDebugPrint('⚪️ [$_ => $__] - ${provider.runtimeType}');
          }
          notifyListeners();
        },
      );
    }
  }
}
