/// Espaçamento entre `order`s ao anexar/renumerar. Duplos comportam ~50 divisões ao meio
/// antes de esgotar a precisão; aí renumeramos só o necessário.
const orderStep = 1024.0;

/// `order` de um item novo: depois de todos os existentes (concorrência pode empatar; o
/// desempate por id na ordenação mantém o resultado determinístico).
double nextOrder(Iterable<double> existing) {
  var max = 0.0;
  for (final o in existing) {
    if (o > max) max = o;
  }
  return max + orderStep;
}

/// Plano de reordenação de um item entre os pendentes.
///
/// [orders] = `order` dos itens pendentes na ordem atual; [newIndex] é a posição FINAL do
/// item (convenção do `onReorderItem` do `ReorderableListView`, já ajustada à remoção).
/// Devolve `índice-na-lista-atual -> novo order`. Normalmente 1 entrada (ponto médio entre
/// os vizinhos, sem reescrever a lista); se a precisão esgotar, renumera os pendentes
/// (`orderStep`) na nova ordem e devolve todas as mudanças. Vazio = nada a fazer.
Map<int, double> planReorder(List<double> orders, int oldIndex, int newIndex) {
  if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= orders.length) return const {};
  final rest = [...orders]..removeAt(oldIndex);
  newIndex = newIndex.clamp(0, rest.length);
  final prev = newIndex > 0 ? rest[newIndex - 1] : null;
  final next = newIndex < rest.length ? rest[newIndex] : null;

  double? value;
  if (prev == null && next == null) {
    value = orderStep;
  } else if (prev == null) {
    value = next! - orderStep;
  } else if (next == null) {
    value = prev + orderStep;
  } else {
    final mid = (prev + next) / 2;
    if (mid > prev && mid < next && (next - prev) > 1e-9) value = mid;
  }
  if (value != null) return {oldIndex: value};

  // Precisão esgotada: renumera os pendentes na ordem final.
  final indices = [for (var i = 0; i < orders.length; i++) i]
    ..removeAt(oldIndex)
    ..insert(newIndex, oldIndex);
  return {for (var pos = 0; pos < indices.length; pos++) indices[pos]: (pos + 1) * orderStep};
}
