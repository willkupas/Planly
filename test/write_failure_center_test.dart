import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/core/sync/write_failure_center.dart';

void main() {
  late ProviderContainer container;
  late WriteFailureCenter center;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    center = container.read(writeFailureCenterProvider.notifier);
  });

  List<WriteFailure> failures() => container.read(writeFailureCenterProvider);

  group('WriteFailureCenter', () {
    test('ack com sucesso não registra nada', () async {
      center.track(Future<void>.value(), kind: WriteKind.taskCreate, title: 'A');
      await Future<void>.delayed(Duration.zero);
      expect(failures(), isEmpty);
    });

    test('ack que só completa depois (offline) não registra nem trava; erro tardio é registrado', () async {
      final c = Completer<void>();
      center.track(c.future, kind: WriteKind.taskComplete, title: 'Lavar louça');
      await Future<void>.delayed(Duration.zero);
      expect(failures(), isEmpty);

      c.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await Future<void>.delayed(Duration.zero);
      expect(failures(), hasLength(1));
      expect(failures().single.kind, WriteKind.taskComplete);
      expect(failures().single.title, 'Lavar louça');
      expect(failures().single.error, isA<PermissionDeniedFailure>());
    });

    test('aceita AppFailure (tarefas) e exceções do SDK (listas) e nunca lança', () async {
      center.track(Future<void>.error(const PermissionDeniedFailure()), kind: WriteKind.taskCreate, title: 'X');
      center.track(
        Future<void>.error(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
        kind: WriteKind.itemAdd,
        title: 'Leite',
      );
      center.track(Future<void>.error(StateError('qualquer coisa')), kind: WriteKind.itemReorder);
      await Future<void>.delayed(Duration.zero);
      expect(failures().map((f) => f.error.runtimeType), [
        PermissionDeniedFailure,
        NetworkFailure,
        UnknownFailure,
      ]);
      expect(failures().last.title, isNull);
    });

    test('dismiss remove só a falha indicada; dismissAll limpa', () {
      center.report(WriteKind.listCreate, const PermissionDeniedFailure(), title: 'A');
      center.report(WriteKind.listDelete, const PermissionDeniedFailure(), title: 'B');
      final first = failures().first.id;
      expect(failures().map((f) => f.id).toSet(), hasLength(2));
      center.dismiss(first);
      expect(failures().single.title, 'B');
      center.dismissAll();
      expect(failures(), isEmpty);
    });

    test('report depois do dispose é ignorado (sem exceção)', () async {
      final c = Completer<void>();
      center.track(c.future, kind: WriteKind.taskCreate, title: 'A');
      container.dispose();
      c.completeError(const PermissionDeniedFailure());
      await Future<void>.delayed(Duration.zero); // sem erro não tratado
    });
  });

  group('indicador de sync', () {
    test('combineSyncMeta: null sem dados; pendência/cache em qualquer stream valem para todos', () {
      expect(combineSyncMeta([null, null]), isNull);
      expect(combineSyncMeta(const []), isNull);
      expect(
        combineSyncMeta(const [SyncMeta(), null, SyncMeta(hasPendingWrites: true)]),
        const SyncMeta(hasPendingWrites: true),
      );
      expect(
        combineSyncMeta(const [SyncMeta(isFromCache: true), SyncMeta()]),
        const SyncMeta(isFromCache: true),
      );
    });

    test('syncStatusFor: Salvo neste dispositivo -> Sincronizando -> Sincronizado', () {
      expect(
        syncStatusFor(const SyncMeta(hasPendingWrites: true, isFromCache: true), online: false),
        SyncStatus.savedLocally,
      );
      expect(syncStatusFor(const SyncMeta(hasPendingWrites: true), online: true), SyncStatus.syncing);
      expect(syncStatusFor(const SyncMeta(), online: true), SyncStatus.synced);
      expect(syncStatusFor(const SyncMeta(isFromCache: true), online: false), SyncStatus.offline);
      expect(syncStatusFor(const SyncMeta(isFromCache: true), online: true), SyncStatus.syncing);
    });
  });
}
