import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Abre o share sheet do sistema com um texto. Injetável para testar sem plataforma.
typedef ShareText = Future<void> Function(String text, {String? subject});

final shareTextProvider = Provider<ShareText>((ref) {
  return (text, {subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  };
});
