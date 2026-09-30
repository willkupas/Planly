import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Renderiza os estados obrigatórios de uma tela de dados (spec flutter-app §5.1):
/// Loading (skeleton), Empty, Success e Error. O estado Offline é tratado à parte pelo
/// `OfflineBanner`, que não bloqueia a tela.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;

  /// Se devolver true, mostra [empty].
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final v = value.requireValue;
      if (isEmpty != null && empty != null && isEmpty!(v)) return empty!;
      return data(context, v);
    }
    if (value.hasError) {
      return ErrorState(
        message: failureMessage(AppLocalizations.of(context), value.error!),
        onRetry: onRetry,
      );
    }
    return const LoadingSkeleton();
  }
}
