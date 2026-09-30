import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/invitation/application/invitation_providers.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Texto para falhas de "entrar com código": genérico (não distingue código inexistente de
/// usado/expirado) e o limite de pessoas é da família que convidou, não do plano do usuário.
String joinFailureMessage(AppLocalizations l10n, Object error) {
  if (error is BusinessFailure && error.reason == 'PLAN_LIMIT_MEMBERS') return l10n.errorJoinPlanLimit;
  return failureMessage(l10n, error);
}

/// Mantém só A-Z/0-9 em maiúsculas (aceita colar "abcde-fghjk" ou com espaços).
class _CodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = normalizeInviteCode(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Entrar com código (spec §1 #15). Só-online. O código vive apenas no campo de texto.
/// `?code=` (deep link futuro) só preenche o campo; nunca envia sozinho.
class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  late final TextEditingController _controller =
      TextEditingController(text: normalizeInviteCode(widget.initialCode ?? ''));
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => normalizeInviteCode(_controller.text).length == inviteCodeLength;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(invitationActionsProvider).accept(_controller.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e;
      });
      return;
    }
    if (!mounted) return;
    _controller.clear();
    setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.joinSuccess)));
    router.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.joinIntro),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('join-code'),
                  controller: _controller,
                  enabled: !_busy,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [_CodeInputFormatter(), LengthLimitingTextInputFormatter(inviteCodeLength)],
                  decoration: InputDecoration(labelText: l10n.joinCodeLabel, border: const OutlineInputBorder()),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      joinFailureMessage(l10n, _error!),
                      key: const Key('join-error'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('join-submit'),
                  onPressed: _valid && !_busy ? _submit : null,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.joinButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
