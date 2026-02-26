import 'package:flutter/foundation.dart';
import 'package:guarded_go_router/src/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class GoNotifier extends ChangeNotifier {
  final Ref _ref;
  final List<ProviderListenable<Object?>> dependencies;
  final LogCallback? logger;

  GoNotifier(
    this._ref, {
    this.dependencies = const [],
    this.logger,
  }) {
    for (final provider in dependencies) {
      _ref.listen<Object?>(
        provider,
        (Object? prev, Object? next) {
          logger?.call('⚪️ [$prev => $next] - ${provider.runtimeType}');
          notifyListeners();
        },
      );
    }
  }
}
