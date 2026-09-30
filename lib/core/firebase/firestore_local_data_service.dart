import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/sync/local_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingClearKey = 'firestore.pendingClear';

class FirestoreLocalDataService implements LocalDataService {
  FirestoreLocalDataService({
    required this.firestore,
    required this.prefs,
    this.pendingWritesProbe = const Duration(seconds: 2),
  });

  final FirebaseFirestore firestore;
  final SharedPreferences prefs;

  /// `waitForPendingWrites` só resolve quando o servidor confirma; se não resolver neste
  /// intervalo (offline/lento) consideramos que há escritas pendentes.
  final Duration pendingWritesProbe;

  @override
  Future<bool> hasPendingWrites() async {
    try {
      await firestore.waitForPendingWrites().timeout(pendingWritesProbe);
      return false;
    } on TimeoutException {
      return true;
    } catch (_) {
      // Sem como saber: assume que pode haver pendências (o usuário decide).
      return true;
    }
  }

  @override
  Future<void> clearLocalData() async {
    try {
      // terminate cancela listeners; o próximo uso recria a instância nativa com as mesmas
      // settings (persistência/emulador), pois o Dart reenvia as settings a cada chamada.
      await firestore.terminate();
      await firestore.clearPersistence();
      await prefs.remove(_pendingClearKey);
    } catch (_) {
      await prefs.setBool(_pendingClearKey, true);
    }
  }
}

/// Executa a limpeza agendada de uma sessão anterior. Chamar no `bootstrap()`, depois de
/// configurar emuladores e antes de qualquer outro uso do Firestore.
Future<void> runPendingFirestoreClear(SharedPreferences prefs) async {
  if (prefs.getBool(_pendingClearKey) != true) return;
  try {
    await FirebaseFirestore.instance.clearPersistence();
    await prefs.remove(_pendingClearKey);
  } catch (_) {
    // Mantém o flag: tenta de novo na próxima inicialização.
  }
}
