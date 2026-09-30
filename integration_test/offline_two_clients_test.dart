// T-021: cenário crítico de sincronização com DOIS clientes contra o Emulator Suite (Rules
// reais). Não usa a UI: exercita os repositórios reais (`FirestoreTaskRepository`) com dois
// `FirebaseApp` independentes (cada um com Auth, cache e fila de escritas próprios), que é o
// que um segundo aparelho seria. Roteiro manual equivalente: docs/testing/offline-dois-clientes.md
//
// Como rodar (emuladores de pé + emulador Android ligado; ver docs/testing/integracao-emulador.md):
//   .\integration_test\run_emulator_tests.ps1 -Test integration_test/offline_two_clients_test.dart
//
// Contas do seed: A = dono (owner da Família Dono, vê a casa Principal), B = ana (membro com acesso
// à casa Principal). Cada teste usa títulos únicos: não depende de um Firestore vazio.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/write_failure_center.dart';
import 'package:planly/features/tasks/data/firestore_task_repository.dart';
import 'package:planly/features/tasks/domain/task_models.dart';

import 'support/env.dart';

// Mesmo host/porta de `lib/core/firebase/emulators.dart` (portas de firebase.json).
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const _seedFrozen = String.fromEnvironment('SEED_FROZEN');

/// Um "aparelho": Auth + Firestore + repositório de tarefas próprios.
class Client {
  Client(this.name, this.auth, this.db) : repo = FirestoreTaskRepository(firestore: db);

  final String name;
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final FirestoreTaskRepository repo;

  String get uid => auth.currentUser!.uid;
  TaskActor get actor => TaskActor(uid: uid, name: name);

  Future<void> signIn(FakeAccount acc) async {
    await auth.signOut();
    await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: acc.idToken));
  }
}

Client? _clientB;

/// Cliente B: segundo `FirebaseApp` (criado uma vez por processo), apontado para o emulador.
Future<Client> _secondClient() async {
  final existing = _clientB;
  if (existing != null) return existing;
  final app = await Firebase.initializeApp(name: 'clientB', options: Firebase.app().options);
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(_emulatorHost, 9099);
  final db = FirebaseFirestore.instanceFor(app: app)..useFirestoreEmulator(_emulatorHost, 8080);
  return _clientB = Client('B', auth, db);
}

/// Observa um stream guardando o último valor (para esperar por condições com tempo real).
class Watch<T> {
  Watch(Stream<T> stream) {
    _sub = stream.listen((v) => latest = v, onError: (Object e) => error = e);
  }

  late final StreamSubscription<T> _sub;
  T? latest;
  Object? error;

  Future<void> until(bool Function(T) ok, String why, {Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (error != null) throw TestFailure('erro no stream ao esperar "$why": $error');
      final v = latest;
      if (v != null && ok(v)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TestFailure('timeout esperando: $why');
  }

  Future<void> cancel() => _sub.cancel();
}

Task? _find(TasksSnapshot s, String id) {
  for (final t in s.items) {
    if (t.id == id) return t;
  }
  return null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initEmulatorFirebase);

  late Client a;
  late Client b;
  late TaskScope scope;

  /// Abre as duas sessões e deixa as duas redes ligadas.
  Future<void> openClients() async {
    await resetClientState();
    a = Client('A', FirebaseAuth.instance, FirebaseFirestore.instance);
    b = await _secondClient();
    await b.db.enableNetwork();
    await a.signIn(accDono);
    await b.signIn(accAna);
    scope = const TaskScope(seedFamilyId, seedH1);
  }

  Future<void> closeClients() async {
    await b.db.enableNetwork(); // nunca deixar B offline para o próximo teste
    await b.auth.signOut();
  }

  testWidgets('CRITICO: A online / B offline cria tarefa -> B volta online -> A recebe', (tester) async {
    await tester.runAsync(() async {
      await openClients();
      final title = 'Criada offline por B ${DateTime.now().millisecondsSinceEpoch}';
      final aView = Watch(a.repo.watchUnscheduled(scope));
      final bView = Watch(b.repo.watchUnscheduled(scope));
      try {
        await aView.until((s) => !s.meta.isFromCache, 'A com a lista vinda do servidor');
        await bView.until((s) => !s.meta.isFromCache, 'B com a lista vinda do servidor');

        // B perde a rede e cria a tarefa: efeito local imediato, marcada como pendente.
        await b.db.disableNetwork();
        final w = b.repo.create(scope, TaskDraft(title: title, assignedTo: b.uid), b.actor);
        await bView.until(
          (s) => _find(s, w.id)?.hasPendingWrites == true,
          'B vê a própria tarefa como pendente (salvo neste dispositivo)',
        );

        // Enquanto B está offline, A NÃO recebe nada.
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(_find(aView.latest!, w.id), isNull, reason: 'A não pode ver a tarefa antes de B sincronizar');

        // B volta: o servidor aceita o batch (Rules reais) e confirma.
        await b.db.enableNetwork();
        await w.ack.timeout(const Duration(seconds: 30));
        await bView.until(
          (s) => _find(s, w.id) != null && !_find(s, w.id)!.hasPendingWrites,
          'B vê a tarefa confirmada (sem pendência)',
        );

        // A recebe a tarefa de B, já confirmada pelo servidor.
        await aView.until((s) => _find(s, w.id) != null, 'A recebe a tarefa criada por B');
        final got = _find(aView.latest!, w.id)!;
        expect(got.title, title);
        expect(got.createdBy, b.uid);
        expect(got.status, TaskStatus.pending);

        // A activity gravada no MESMO batch chegou junto.
        final acts = await a.db
            .collection('families/$seedFamilyId/households/$seedH1/activity')
            .where('targetId', isEqualTo: w.id)
            .limit(10)
            .get(const GetOptions(source: Source.server));
        expect(acts.docs.map((d) => d.data()['type']), contains('task_created'));
      } finally {
        await aView.cancel();
        await bView.cancel();
        await closeClients();
      }
    });
  });

  testWidgets('LWW campos diferentes: A conclui (online) x B edita o título (offline) -> as duas mudanças ficam',
      (tester) async {
    await tester.runAsync(() async {
      await openClients();
      final original = 'LWW campos ${DateTime.now().millisecondsSinceEpoch}';
      final bView = Watch(b.repo.watchUnscheduled(scope));
      try {
        // B (autor) cria online; A (owner) enxerga.
        final created = b.repo.create(scope, TaskDraft(title: original, assignedTo: b.uid), b.actor);
        await created.ack.timeout(const Duration(seconds: 30));
        await bView.until((s) => _find(s, created.id) != null, 'B vê a própria tarefa');
        final base = _find(bView.latest!, created.id)!;

        // B fica offline e edita o título (pendente).
        await b.db.disableNetwork();
        final edit = b.repo.update(scope, base, TaskDraft(title: '$original (editado por B)', assignedTo: b.uid), b.actor)!;
        await bView.until((s) => _find(s, created.id)?.title.endsWith('(editado por B)') == true, 'B vê o título novo local');

        // A conclui a mesma tarefa online.
        final aBase = Task(id: created.id, title: original, createdBy: b.uid, status: TaskStatus.pending);
        await a.repo.complete(scope, aBase, a.actor).ack.timeout(const Duration(seconds: 30));

        // B reconecta: o patch de B só tem `title` (+updatedAt), então não desfaz a conclusão de A.
        await b.db.enableNetwork();
        await edit.ack.timeout(const Duration(seconds: 30));

        final doc = await a.db
            .doc('families/$seedFamilyId/households/$seedH1/tasks/${created.id}')
            .get(const GetOptions(source: Source.server));
        expect(doc.data()!['status'], 'done');
        expect(doc.data()!['completedBy'], a.uid);
        expect(doc.data()!['title'], '$original (editado por B)');
      } finally {
        await bView.cancel();
        await closeClients();
      }
    });
  });

  testWidgets('LWW mesmo campo: A edita o título online, B edita offline e reconecta depois -> vence B',
      (tester) async {
    await tester.runAsync(() async {
      await openClients();
      final original = 'LWW titulo ${DateTime.now().millisecondsSinceEpoch}';
      final bView = Watch(b.repo.watchUnscheduled(scope));
      try {
        final created = b.repo.create(scope, TaskDraft(title: original, assignedTo: b.uid), b.actor);
        await created.ack.timeout(const Duration(seconds: 30));
        await bView.until((s) => _find(s, created.id) != null, 'B vê a própria tarefa');
        final base = _find(bView.latest!, created.id)!;

        await b.db.disableNetwork();
        final bEdit = b.repo.update(scope, base, TaskDraft(title: 'Versao de B', assignedTo: b.uid), b.actor)!;

        // A (owner = admin) edita o mesmo campo, online, ANTES de B reconectar.
        final aBase = Task(id: created.id, title: original, createdBy: b.uid, status: TaskStatus.pending);
        await a.repo
            .update(scope, aBase, TaskDraft(title: 'Versao de A', assignedTo: b.uid), a.actor)!
            .ack
            .timeout(const Duration(seconds: 30));

        await b.db.enableNetwork();
        await bEdit.ack.timeout(const Duration(seconds: 30));

        final doc = await a.db
            .doc('families/$seedFamilyId/households/$seedH1/tasks/${created.id}')
            .get(const GetOptions(source: Source.server));
        expect(doc.data()!['title'], 'Versao de B', reason: 'a escrita que chega por último ao servidor vence');
      } finally {
        await bView.cancel();
        await closeClients();
      }
    });
  });

  testWidgets('escrita offline recusada ao sincronizar (família congelada): ack falha e o canal registra',
      (tester) async {
    await tester.runAsync(() async {
      await openClients();
      // B (Ana) é membro da "Família Congelada" (somente leitura pelas Rules).
      final houses = await b.db
          .collection('families/$_seedFrozen/households')
          .where('accessUids', arrayContains: b.uid)
          .limit(5)
          .get(const GetOptions(source: Source.server));
      final frozenScope = TaskScope(_seedFrozen, houses.docs.single.id);
      final container = ProviderContainer();
      final view = Watch(b.repo.watchUnscheduled(frozenScope));
      try {
        await view.until((s) => !s.meta.isFromCache, 'B com a lista da casa congelada');

        await b.db.disableNetwork();
        final title = 'Vai ser recusada ${DateTime.now().millisecondsSinceEpoch}';
        final w = b.repo.create(frozenScope, TaskDraft(title: title, assignedTo: b.uid), b.actor);
        container.read(writeFailureCenterProvider.notifier).track(w.ack, kind: WriteKind.taskCreate, title: title);
        // Offline as Rules não rodam: o efeito local aparece como pendente.
        await view.until((s) => _find(s, w.id)?.hasPendingWrites == true, 'efeito local pendente');

        // Reconecta: o servidor recusa e o SDK desfaz o efeito local.
        await b.db.enableNetwork();
        await expectLater(w.ack.timeout(const Duration(seconds: 30)), throwsA(isA<PermissionDeniedFailure>()));
        await view.until((s) => _find(s, w.id) == null, 'tarefa recusada some da lista local');

        final failures = container.read(writeFailureCenterProvider);
        expect(failures, hasLength(1));
        expect(failures.single.kind, WriteKind.taskCreate);
        expect(failures.single.title, title);
        expect(failures.single.error, isA<PermissionDeniedFailure>());
      } finally {
        await view.cancel();
        container.dispose();
        await closeClients();
      }
    });
  });
}
