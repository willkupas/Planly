import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';

/// Tipo de escrita client-direct (tarefas, listas e itens) que pode ser recusada ao sincronizar.
enum WriteKind {
  taskCreate,
  taskUpdate,
  taskComplete,
  taskReopen,
  taskDelete,
  listCreate,
  listRename,
  listDelete,
  itemAdd,
  itemComplete,
  itemRename,
  itemReorder,
  itemDelete,
}

/// Uma escrita que o servidor recusou DEPOIS de já ter sido aplicada localmente (ex.: família
/// congelada enquanto o aparelho estava offline). O SDK do Firestore já desfez o efeito local:
/// não existe "item fantasma" para manter na lista, então a falha vira um aviso dispensável.
class WriteFailure {
  const WriteFailure({required this.id, required this.kind, required this.error, this.title});

  final int id;
  final WriteKind kind;

  /// Nome do alvo (título da tarefa/lista/item) para a descrição amigável; pode ser nulo.
  final String? title;
  final AppFailure error;
}

/// Canal central de "escritas rejeitadas" (T-021). Quem faz escrita otimista entrega aqui o
/// `ack` (ou o erro tardio) e segue a vida: a UI nunca espera pelo servidor.
///
/// Limite do SDK: a rejeição é tratada pelo Firestore como remoção da mutação pendente, então
/// "Descartar" só dispensa o aviso (o dado local já voltou ao estado do servidor).
class WriteFailureCenter extends Notifier<List<WriteFailure>> {
  var _seq = 0;

  @override
  List<WriteFailure> build() => const [];

  /// Acompanha [ack] em segundo plano. Nunca lança e não segura o chamador (offline o ack só
  /// completa ao reconectar).
  void track(Future<void> ack, {required WriteKind kind, String? title}) {
    ack.then<void>((_) {}, onError: (Object e, StackTrace _) => report(kind, e, title: title));
  }

  void report(WriteKind kind, Object error, {String? title}) {
    if (!ref.mounted) return;
    state = [
      ...state,
      WriteFailure(id: ++_seq, kind: kind, error: mapFirebaseError(error), title: title),
    ];
  }

  void dismiss(int id) => state = [
        for (final f in state)
          if (f.id != id) f,
      ];

  void dismissAll() => state = const [];
}

final writeFailureCenterProvider =
    NotifierProvider<WriteFailureCenter, List<WriteFailure>>(WriteFailureCenter.new);
