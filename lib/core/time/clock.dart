import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio injetável (testes fixam o "agora"). Retorna sempre o instante atual.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
