import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/app.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/core/time/device_timezone.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/application/user_profile_providers.dart';
import 'package:planly/features/family/application/bootstrap_controller.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/core/share/share_service.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/invitation/application/invitation_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:planly/features/lists/application/list_providers.dart';
import 'package:planly/features/lists/data/firestore_list_repository.dart';
import 'package:planly/features/tasks/application/task_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_repository.dart';
import 'fake_backend.dart';
import 'fake_invitations.dart';
import 'fake_tasks.dart';

/// Tudo o que um teste de app precisa controlar.
class TestApp {
  TestApp._({
    required this.auth,
    required this.backend,
    required this.local,
    required this.prefs,
    required this.online,
  });

  final FakeAuthRepository auth;
  final FakeBackend backend;
  final FakeLocalData local;
  final SharedPreferences prefs;
  final StreamController<bool> online;
  final invitations = FakeInvitations();

  /// Tarefas em memória (repositório de tarefas fake).
  final tasks = FakeTasks();

  /// Firestore em memória por trás do `FirestoreListRepository` REAL (listas/itens/activity).
  final listsDb = FakeFirebaseFirestore();

  /// Textos enviados ao share sheet.
  final shared = <String>[];

  void setOnline(bool v) => online.add(v);

  static Future<TestApp> create({
    FakeAuthRepository? auth,
    FakeBackend? backend,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    return TestApp._(
      auth: auth ?? FakeAuthRepository(initialUser: testUser),
      backend: backend ?? FakeBackend(),
      local: FakeLocalData(),
      prefs: await SharedPreferences.getInstance(),
      online: StreamController<bool>.broadcast(),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    bool startOnline = true,
    DateTime? now,
    bool settle = true,
  }) async {
    addTearDown(online.close);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          familyRepositoryProvider.overrideWithValue(backend),
          householdRepositoryProvider.overrideWithValue(backend),
          invitationRepositoryProvider.overrideWithValue(invitations),
          taskRepositoryProvider.overrideWithValue(tasks),
          listRepositoryProvider.overrideWithValue(FirestoreListRepository(firestore: listsDb)),
          shareTextProvider.overrideWithValue((text, {subject}) async => shared.add(text)),
          userProfileRepositoryProvider.overrideWithValue(backend),
          localDataServiceProvider.overrideWithValue(local),
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWith((ref) async* {
            yield startOnline;
            yield* online.stream;
          }),
          deviceTimezoneProvider.overrideWithValue(() async => 'America/Sao_Paulo'),
          bootstrapRetryDelaysProvider.overrideWithValue(const []),
          if (now != null) clockProvider.overrideWithValue(() => now),
        ],
        child: const PlanlyApp(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}
