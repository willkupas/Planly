import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/data/firestore_task_repository.dart';
import 'package:planly/features/tasks/domain/task_models.dart';

/// Conflito last-write-wins (T-021, docs/testing/offline-dois-clientes.md).
///
/// O Firestore resolve conflitos POR CAMPO: cada escrita do app é um `update` com só os campos
/// que o usuário mudou, então escritas em campos diferentes se somam e, no MESMO campo, vence
/// a que o servidor aplicar por último. Aqui dois "clientes" aplicam, na ordem em que o
/// servidor as recebe, os patches REAIS gerados pelo `FirestoreTaskRepository`.
const _scope = TaskScope('f1', 'h1');
const _a = TaskActor(uid: 'ana', name: 'Ana');
const _b = TaskActor(uid: 'beto', name: 'Beto');

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTaskRepository repo;
  late Task base;

  Future<Map<String, dynamic>> read() async =>
      (await db.collection('families/f1/households/h1/tasks').doc(base.id).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreTaskRepository(firestore: db);
    final w = repo.create(_scope, const TaskDraft(title: 'Original'), _a);
    await w.ack;
    // Estado que os DOIS clientes enxergavam antes de divergirem.
    base = Task(id: w.id, title: 'Original', createdBy: 'ana', status: TaskStatus.pending);
  });

  test('concluir (A) x editar título (B): campos disjuntos, as duas mudanças sobrevivem', () async {
    await repo.complete(_scope, base, _a).ack;
    await repo.update(_scope, base, const TaskDraft(title: 'Novo título'), _b)!.ack;

    final d = await read();
    expect(d['status'], 'done');
    expect(d['completedBy'], 'ana');
    expect(d['title'], 'Novo título');
  });

  test('a ordem inversa chega ao mesmo resultado (campos disjuntos não dependem da ordem)', () async {
    await repo.update(_scope, base, const TaskDraft(title: 'Novo título'), _b)!.ack;
    await repo.complete(_scope, base, _a).ack;

    final d = await read();
    expect(d['status'], 'done');
    expect(d['title'], 'Novo título');
  });

  test('mesmo campo: quem chega por último ao servidor vence (título)', () async {
    await repo.update(_scope, base, const TaskDraft(title: 'Versão da Ana'), _a)!.ack;
    await repo.update(_scope, base, const TaskDraft(title: 'Versão do Beto'), _b)!.ack;
    expect((await read())['title'], 'Versão do Beto');
  });

  test('concluir (A) x reabrir (B) sobre o mesmo estado: o último aplicado vence', () async {
    final done = Task(id: base.id, title: 'Original', createdBy: 'ana', status: TaskStatus.done);
    await repo.complete(_scope, base, _a).ack;
    await repo.reopen(_scope, done, _b).ack;
    final d = await read();
    expect(d['status'], 'pending');
    expect(d['completedBy'], isNull);
  });

  test('concluir não sobrescreve o título que outro cliente mudou no meio (patch mínimo)', () async {
    await db
        .doc('families/f1/households/h1/tasks/${base.id}')
        .update({'title': 'Mexido por B'});
    await repo.complete(_scope, base, _a).ack; // A ainda achava que o título era "Original"
    final d = await read();
    expect(d['title'], 'Mexido por B');
    expect(d['status'], 'done');
    expect(d['updatedAt'], isA<Timestamp>());
  });
}
