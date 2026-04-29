import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/memory_model.dart';
import 'cloud_sync_service.dart';

/// StorageService — single entry-point for all data persistence.
///
/// Architecture:
///   LOCAL  (Hive)  — always written first, always read from.
///   CLOUD  (Firebase) — written in background via CloudSyncService.
///
/// The app is 100% functional with no internet. Firebase is purely additive.
class StorageService {
  static const String _memoriesBox = 'memories';
  static const String _peopleBox   = 'people';
  static const String _settingsBox = 'settings';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_memoriesBox);
    await Hive.openBox<String>(_peopleBox);
    await Hive.openBox<String>(_settingsBox);
  }

  // ── Memory — local CRUD ───────────────────────────────────────────────────

  static Future<void> saveMemory(Memory memory) async {
    // Step 1: Write to Hive immediately (synchronous from user's perspective)
    final box = Hive.box<String>(_memoriesBox);
    await box.put(memory.id, jsonEncode(_memoryToJson(memory)));

    // Step 2: Fire-and-forget cloud sync (never blocks the UI)
    CloudSyncService.instance.syncMemoryToCloud(memory).catchError((e) {
      debugPrint('[StorageService] background sync error: $e');
    });
  }

  static Future<Memory?> getMemory(String id) async {
    final data = Hive.box<String>(_memoriesBox).get(id);
    if (data == null) return null;
    return _memoryFromJson(jsonDecode(data));
  }

  /// Returns a Memory with its peopleIds populated (for gallery linking).
  static Future<MemoryWithPeopleIds?> getMemoryWithPeopleIds(String id) async {
    final data = Hive.box<String>(_memoriesBox).get(id);
    if (data == null) return null;
    final j = jsonDecode(data) as Map<String, dynamic>;
    return MemoryWithPeopleIds(
      memory:    _memoryFromJson(j),
      peopleIds: List<String>.from(j['peopleIds'] ?? []),
    );
  }

  /// Returns all memories, each with their peopleIds populated.
  static Future<List<MemoryWithPeopleIds>> getAllMemoriesWithPeopleIds() async {
    return Hive.box<String>(_memoriesBox)
        .values
        .map((d) {
          final j = jsonDecode(d) as Map<String, dynamic>;
          return MemoryWithPeopleIds(
            memory:    _memoryFromJson(j),
            peopleIds: List<String>.from(j['peopleIds'] ?? []),
          );
        })
        .toList()
      ..sort((a, b) => b.memory.dateTime.compareTo(a.memory.dateTime));
  }

  static Future<List<Memory>> getAllMemories() async {
    return Hive.box<String>(_memoriesBox)
        .values
        .map((d) => _memoryFromJson(jsonDecode(d)))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  static Future<void> deleteMemory(String id) async {
    await Hive.box<String>(_memoriesBox).delete(id);
    // Best-effort cloud delete
    CloudSyncService.instance
        .saveMemoryToFirestore(
          Memory(
            id: id,
            imagePath: '',
            dateTime: DateTime.now(),
            people: const [],
          ),
        )
        .catchError((_) {});
  }

  // ── Person — local CRUD ───────────────────────────────────────────────────

  static Future<void> savePerson(Person person) async {
    final box = Hive.box<String>(_peopleBox);
    await box.put(person.id, jsonEncode(_personToJson(person)));

    // Background cloud sync
    CloudSyncService.instance.savePersonToFirestore(person).catchError((e) {
      debugPrint('[StorageService] savePerson cloud error: $e');
    });
  }

  static Future<Person?> getPerson(String id) async {
    final data = Hive.box<String>(_peopleBox).get(id);
    if (data == null) return null;
    return _personFromJson(jsonDecode(data));
  }

  static Future<List<Person>> getAllPeople() async {
    return Hive.box<String>(_peopleBox)
        .values
        .map((d) => _personFromJson(jsonDecode(d)))
        .toList();
  }

  static Future<void> deletePerson(String id) async {
    await Hive.box<String>(_peopleBox).delete(id);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  static Future<void> saveSetting(String key, dynamic value) async {
    await Hive.box<String>(_settingsBox).put(key, jsonEncode(value));
  }

  static Future<dynamic> getSetting(String key, {dynamic defaultValue}) async {
    final data = Hive.box<String>(_settingsBox).get(key);
    if (data == null) return defaultValue;
    return jsonDecode(data);
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await Hive.box<String>(_memoriesBox).clear();
    await Hive.box<String>(_peopleBox).clear();
    // Keep settings — only clear data boxes
  }

  // ── Cloud sync helpers (called by CloudSyncService) ───────────────────────

  /// Overwrite local Hive with data pulled from Firestore.
  static Future<void> restoreFromCloud(
    List<Memory> memories,
    List<Person> people,
  ) async {
    final mBox = Hive.box<String>(_memoriesBox);
    final pBox = Hive.box<String>(_peopleBox);

    await mBox.clear();
    await pBox.clear();

    for (final m in memories) {
      await mBox.put(m.id, jsonEncode(_memoryToJson(m)));
    }
    for (final p in people) {
      await pBox.put(p.id, jsonEncode(_personToJson(p)));
    }
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _memoryToJson(Memory m) => {
        'id':        m.id,
        'imagePath': m.imagePath,
        'dateTime':  m.dateTime.toIso8601String(),
        'location':  m.location,
        'notes':     m.notes,
        'peopleIds': m.people.map((p) => p.id).toList(),
      };

  static Memory _memoryFromJson(Map<String, dynamic> j) => Memory(
        id:        j['id'],
        imagePath: j['imagePath'],
        dateTime:  DateTime.parse(j['dateTime']),
        location:  j['location'],
        notes:     j['notes'],
        people:    const [], // loaded separately when needed
      );

  static Map<String, dynamic> _personToJson(Person p) => {
        'id':        p.id,
        'name':      p.name,
        'notes':     p.notes,
        'tags':      p.tags,
        'memoryIds': p.memoryIds,
        'firstMet':  p.firstMet.toIso8601String(),
        'lastSeen':  p.lastSeen.toIso8601String(),
        'avatarPath': p.avatarPath,
      };

  static Person _personFromJson(Map<String, dynamic> j) => Person(
        id:        j['id'],
        name:      j['name'],
        notes:     j['notes'],
        tags:      List<String>.from(j['tags']      ?? []),
        memoryIds: List<String>.from(j['memoryIds'] ?? []),
        firstMet:  DateTime.parse(j['firstMet']),
        lastSeen:  DateTime.parse(j['lastSeen']),
        avatarPath: j['avatarPath'],
      );
}

/// Lightweight wrapper returned by getMemoryWithPeopleIds.
class MemoryWithPeopleIds {
  final Memory memory;
  final List<String> peopleIds;
  const MemoryWithPeopleIds({required this.memory, required this.peopleIds});
}
