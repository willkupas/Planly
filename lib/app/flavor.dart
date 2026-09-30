/// Ambiente em execução; cada flavor Android aponta para um projeto Firebase.
enum Flavor {
  dev(firebaseProjectId: 'planly-dev-d8533', useEmulators: true),
  staging(firebaseProjectId: 'planly-staging', useEmulators: false),
  prod(firebaseProjectId: 'planly-prod-be861', useEmulators: false);

  const Flavor({required this.firebaseProjectId, required this.useEmulators});

  final String firebaseProjectId;

  /// No dev o app aponta para o Emulator Suite (T-008) em vez da nuvem.
  final bool useEmulators;
}
