import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/app.dart';

void main() {
  testWidgets('abre o dashboard em pt-BR', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlanlyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
