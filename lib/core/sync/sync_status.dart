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
