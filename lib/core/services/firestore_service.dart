// FirestoreService is now a thin facade over CloudSyncService.
// All logic lives in cloud_sync_service.dart.
// This file is kept for backward compatibility.

export 'cloud_sync_service.dart' show CloudSyncService, SyncResult;
