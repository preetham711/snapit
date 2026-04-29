import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/memory_model.dart';
import 'storage_service.dart';

/// CloudSyncService — offline-first Firebase backup layer.
///
/// Principles:
///   1. App NEVER waits on this service. All calls are fire-and-forget.
///   2. Local Hive is always written first. Firebase is secondary.
///   3. Failed uploads are queued in Hive and retried when online.
///   4. No Firebase call ever throws to the UI.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final FirebaseFirestore _db      = FirebaseFirestore.instance;
  final FirebaseStorage   _storage = FirebaseStorage.instance;

  // Pending-sync queue stored in Hive under key 'pending_sync'
  // Format: List of memoryIds that haven't been uploaded yet.
  static const String _pendingBox = 'pending_sync';

  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Call once from main() after Firebase.initializeApp().
  /// Starts listening for connectivity changes and retries pending uploads.
  Future<void> init() async {
    // Listen for connectivity — retry queue whenever we come online
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        debugPrint('[CloudSync] Online — processing pending queue');
        await _processPendingQueue();
      }
    });

    // Also try immediately on startup
    final results = await Connectivity().checkConnectivity();
    final online  = results.any((r) => r != ConnectivityResult.none);
    if (online) {
      await _processPendingQueue();
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Upload a local image file to Firebase Storage.
  /// Returns the download URL, or null on failure.
  ///
  /// Path in Storage: images/{memoryId}/{filename}
  Future<String?> uploadImageToFirebase({
    required String localPath,
    required String memoryId,
  }) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        debugPrint('[CloudSync] uploadImage: file not found — $localPath');
        return null;
      }

      final filename = localPath.split('/').last;
      final ref = _storage.ref('images/$memoryId/$filename');

      final task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Report progress to debug log
      task.snapshotEvents.listen((snap) {
        final pct = (snap.bytesTransferred / snap.totalBytes * 100).round();
        debugPrint('[CloudSync] Upload $memoryId: $pct%');
      });

      final snap = await task;
      final url  = await snap.ref.getDownloadURL();
      debugPrint('[CloudSync] Upload complete: $url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint('[CloudSync] uploadImage FirebaseException: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[CloudSync] uploadImage error: $e');
      return null;
    }
  }

  /// Save a Memory document to Firestore.
  /// Optionally pass [imageUrl] to store the cloud image URL.
  Future<void> saveMemoryToFirestore(
    Memory memory, {
    String? imageUrl,
  }) async {
    try {
      final data = _memoryToMap(memory, imageUrl: imageUrl);
      await _db.collection('memories').doc(memory.id).set(data);
      debugPrint('[CloudSync] saveMemory OK: ${memory.id}');
    } on FirebaseException catch (e) {
      debugPrint('[CloudSync] saveMemory FirebaseException: ${e.code}');
      rethrow;
    }
  }

  /// Save a Person document to Firestore.
  Future<void> savePersonToFirestore(Person person) async {
    try {
      await _db.collection('people').doc(person.id).set(_personToMap(person));
      debugPrint('[CloudSync] savePerson OK: ${person.id}');
    } on FirebaseException catch (e) {
      debugPrint('[CloudSync] savePerson FirebaseException: ${e.code}');
      rethrow;
    }
  }

  /// Full sync: upload image → save person → save memory.
  /// Queues the memoryId for retry if offline or on failure.
  ///
  /// This is fire-and-forget — call without await from the UI.
  Future<void> syncMemoryToCloud(Memory memory) async {
    final online = await _isOnline();
    if (!online) {
      debugPrint('[CloudSync] Offline — queuing ${memory.id}');
      await _enqueue(memory.id);
      return;
    }

    await _uploadMemory(memory);
  }

  /// Push ALL local Hive data to Firebase (manual backup from Settings).
  Future<SyncResult> syncLocalDataToCloud() async {
    final online = await _isOnline();
    if (!online) {
      return SyncResult(
        success: false,
        message: 'No internet connection. Data will sync when online.',
        uploaded: 0,
        failed: 0,
      );
    }

    final memories = await StorageService.getAllMemories();
    final people   = await StorageService.getAllPeople();

    int uploaded = 0;
    int failed   = 0;

    // Upload people first (memories reference them)
    for (final p in people) {
      try {
        await savePersonToFirestore(p);
      } catch (_) {
        failed++;
      }
    }

    // Upload memories + images
    for (final m in memories) {
      try {
        await _uploadMemory(m);
        uploaded++;
      } catch (_) {
        failed++;
        await _enqueue(m.id);
      }
    }

    return SyncResult(
      success: failed == 0,
      message: failed == 0
          ? 'All $uploaded memories backed up successfully.'
          : '$uploaded uploaded, $failed failed (will retry when online).',
      uploaded: uploaded,
      failed: failed,
    );
  }

  /// Pull all data from Firestore into local Hive (restore from cloud).
  Future<SyncResult> restoreFromCloud() async {
    final online = await _isOnline();
    if (!online) {
      return SyncResult(
        success: false,
        message: 'No internet connection.',
        uploaded: 0,
        failed: 0,
      );
    }

    try {
      final memoriesSnap = await _db
          .collection('memories')
          .orderBy('dateTime', descending: true)
          .get();

      final peopleSnap = await _db.collection('people').get();

      final memories = memoriesSnap.docs
          .map((d) => _memoryFromMap(d.id, d.data()))
          .toList();
      final people = peopleSnap.docs
          .map((d) => _personFromMap(d.id, d.data()))
          .toList();

      // Overwrite local cache
      await StorageService.restoreFromCloud(memories, people);

      return SyncResult(
        success: true,
        message:
            'Restored ${memories.length} memories and ${people.length} people.',
        uploaded: memories.length,
        failed: 0,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Restore failed: $e',
        uploaded: 0,
        failed: 0,
      );
    }
  }

  /// Real-time stream of memories from Firestore.
  /// Falls back to an empty stream on error — UI uses local data instead.
  Stream<List<Memory>> memoriesStream() {
    return _db
        .collection('memories')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _memoryFromMap(d.id, d.data())).toList())
        .handleError((e) {
      debugPrint('[CloudSync] memoriesStream error: $e');
      return <Memory>[];
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _uploadMemory(Memory memory) async {
    // 1. Upload image if it's a local file
    String? imageUrl;
    if (!memory.imagePath.startsWith('http')) {
      imageUrl = await uploadImageToFirebase(
        localPath: memory.imagePath,
        memoryId: memory.id,
      );
    } else {
      imageUrl = memory.imagePath; // already a URL
    }

    // 2. Save person docs
    for (final p in memory.people) {
      await savePersonToFirestore(p);
    }

    // 3. Save memory doc (with cloud image URL if upload succeeded)
    await saveMemoryToFirestore(memory, imageUrl: imageUrl);

    // 4. Remove from pending queue on success
    await _dequeue(memory.id);
  }

  Future<void> _processPendingQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = await _getPendingIds();
      if (pending.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[CloudSync] Processing ${pending.length} pending items');

      for (final memoryId in List<String>.from(pending)) {
        final memory = await StorageService.getMemory(memoryId);
        if (memory == null) {
          await _dequeue(memoryId); // stale entry
          continue;
        }
        try {
          await _uploadMemory(memory);
          debugPrint('[CloudSync] Retry success: $memoryId');
        } catch (e) {
          debugPrint('[CloudSync] Retry failed: $memoryId — $e');
          // Leave in queue for next attempt
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ── Pending queue (stored in Hive settings box) ───────────────────────────

  Future<List<String>> _getPendingIds() async {
    final raw = await StorageService.getSetting(_pendingBox, defaultValue: <dynamic>[]);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  Future<void> _enqueue(String memoryId) async {
    final ids = await _getPendingIds();
    if (!ids.contains(memoryId)) {
      ids.add(memoryId);
      await StorageService.saveSetting(_pendingBox, ids);
    }
  }

  Future<void> _dequeue(String memoryId) async {
    final ids = await _getPendingIds();
    ids.remove(memoryId);
    await StorageService.saveSetting(_pendingBox, ids);
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> _memoryToMap(Memory m, {String? imageUrl}) => {
        'id':          m.id,
        'imagePath':   m.imagePath,   // local path (for reference)
        'imageUrl':    imageUrl,       // cloud URL (null until uploaded)
        'dateTime':    m.dateTime.toIso8601String(),
        'location':    m.location,
        'notes':       m.notes,
        'peopleIds':   m.people.map((p) => p.id).toList(),
        'peopleNames': m.people.map((p) => p.name).toList(),
        'updatedAt':   FieldValue.serverTimestamp(),
      };

  Memory _memoryFromMap(String id, Map<String, dynamic> data) {
    final names = List<String>.from(data['peopleNames'] ?? []);
    final ids   = List<String>.from(data['peopleIds']   ?? []);

    final people = List.generate(
      names.length,
      (i) => Person(
        id:        i < ids.length ? ids[i] : 'unknown_$i',
        name:      names[i],
        tags:      const [],
        memoryIds: [id],
        firstMet:  DateTime.tryParse(data['dateTime'] ?? '') ?? DateTime.now(),
        lastSeen:  DateTime.tryParse(data['dateTime'] ?? '') ?? DateTime.now(),
      ),
    );

    // Prefer cloud URL; fall back to local path
    final imagePath = (data['imageUrl'] as String?)?.isNotEmpty == true
        ? data['imageUrl'] as String
        : (data['imagePath'] as String? ?? '');

    return Memory(
      id:        data['id'] ?? id,
      imagePath: imagePath,
      dateTime:  DateTime.tryParse(data['dateTime'] ?? '') ?? DateTime.now(),
      location:  data['location'],
      notes:     data['notes'],
      people:    people,
    );
  }

  Map<String, dynamic> _personToMap(Person p) => {
        'id':        p.id,
        'name':      p.name,
        'notes':     p.notes,
        'tags':      p.tags,
        'memoryIds': p.memoryIds,
        'firstMet':  p.firstMet.toIso8601String(),
        'lastSeen':  p.lastSeen.toIso8601String(),
        'avatarPath': p.avatarPath,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Person _personFromMap(String id, Map<String, dynamic> data) => Person(
        id:        data['id'] ?? id,
        name:      data['name'] ?? '',
        notes:     data['notes'],
        tags:      List<String>.from(data['tags']      ?? []),
        memoryIds: List<String>.from(data['memoryIds'] ?? []),
        firstMet:  DateTime.tryParse(data['firstMet'] ?? '') ?? DateTime.now(),
        lastSeen:  DateTime.tryParse(data['lastSeen'] ?? '') ?? DateTime.now(),
        avatarPath: data['avatarPath'],
      );
}

// ── Result model ──────────────────────────────────────────────────────────────

class SyncResult {
  final bool   success;
  final String message;
  final int    uploaded;
  final int    failed;

  const SyncResult({
    required this.success,
    required this.message,
    required this.uploaded,
    required this.failed,
  });
}
