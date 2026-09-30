import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/lists/domain/item_order.dart';

void main() {
  group('nextOrder', () {
    test('lista vazia começa em 1024', () => expect(nextOrder(const []), 1024));
    test('vai depois do maior', () => expect(nextOrder([1024, 5000.5, 2048]), 6024.5));
  });

  group('planReorder', () {
    final orders = [1024.0, 2048.0, 3072.0, 4096.0];

    test('sem mudança devolve vazio', () {
      expect(planReorder(orders, 1, 1), isEmpty);
      
    });

    test('meio: ponto médio entre vizinhos, só 1 escrita', () {
      // move o índice 0 para entre 2048 e 3072 (newIndex 2 => vira posição 1 após remover)
      final plan = planReorder(orders, 0, 2);
      expect(plan, {0: (3072 + 4096) / 2});
    });

    test('topo: primeiro order menos o passo', () {
      expect(planReorder(orders, 2, 0), {2: 1024 - orderStep});
    });

    test('fim: último order mais o passo', () {
      expect(planReorder(orders, 0, 3), {0: 4096 + orderStep});
    });

    test('precisão esgotada renumera só os pendentes na nova ordem', () {
      const a = 1.0;
      final b = a + 1e-12; // vizinhos colados
      final plan = planReorder([a, b, 5.0], 2, 1);
      expect(plan.length, 3);
      // novo arranjo: índice0, índice2, índice1
      expect(plan[0], orderStep);
      expect(plan[2], 2 * orderStep);
      expect(plan[1], 3 * orderStep);
    });

    test('aplicar vários movimentos mantém a ordem relativa correta', () {
      var list = [for (var i = 0; i < 6; i++) MapEntry('i$i', (i + 1) * orderStep)];
      void move(int from, int to) {
        final plan = planReorder(list.map((e) => e.value).toList(), from, to);
        final next = [...list];
        plan.forEach((idx, v) => next[idx] = MapEntry(next[idx].key, v));
        final moved = next[from];
        final target = to;
        next.removeAt(from);
        next.insert(target, moved);
        // a lista resultante, ordenada por order, deve coincidir com a posição esperada
        final sorted = [...next]..sort((a, b) => a.value.compareTo(b.value));
        expect(sorted.map((e) => e.key), next.map((e) => e.key));
        list = sorted;
      }

      for (var n = 0; n < 40; n++) {
        move(5, 1); // arrasta repetidamente o último para perto do topo (estreita intervalo)
        move(3, 0);
        move(0, 5);
      }
    });
  });
}
