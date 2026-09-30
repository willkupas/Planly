/// Metadados de sincronização de um snapshot (spec flutter-app §5.2).
class SyncMeta {
  const SyncMeta({this.hasPendingWrites = false, this.isFromCache = false});

  final bool hasPendingWrites;
  final bool isFromCache;

  @override
  bool operator ==(Object other) =>
      other is SyncMeta &&
      other.hasPendingWrites == hasPendingWrites &&
      other.isFromCache == isFromCache;

  @override
  int get hashCode => Object.hash(hasPendingWrites, isFromCache);
}

enum SyncStatus {
  /// Escrita só neste dispositivo (offline ou ainda vindo do cache).
  savedLocally,
  syncing,
  synced,

  /// Sem pendências, mostrando dados do cache e sem rede.
  offline,
}

/// Regra pura do indicador de sync.
SyncStatus syncStatusFor(SyncMeta meta, {required bool online}) {
  if (meta.hasPendingWrites) {
    return (!online || meta.isFromCache) ? SyncStatus.savedLocally : SyncStatus.syncing;
  }
  if (!meta.isFromCache) return SyncStatus.synced;
  return online ? SyncStatus.syncing : SyncStatus.offline;
}

/// Junta o `SyncMeta` de vários streams que alimentam a mesma tela: pendência em qualquer um
/// vale para a tela toda; "do cache" idem. `null` quando nenhum stream tem dado ainda (o
/// indicador some em vez de mentir "Sincronizado").
SyncMeta? combineSyncMeta(Iterable<SyncMeta?> metas) {
  final present = metas.whereType<SyncMeta>().toList();
  if (present.isEmpty) return null;
  return SyncMeta(
    hasPendingWrites: present.any((m) => m.hasPendingWrites),
    isFromCache: present.any((m) => m.isFromCache),
  );
}
