import 'package:equatable/equatable.dart';

class Memory extends Equatable {
  final String id;
  final String imagePath;
  final DateTime dateTime;
  final String? location;
  final List<Person> people;
  final String? notes;

  const Memory({
    required this.id,
    required this.imagePath,
    required this.dateTime,
    this.location,
    required this.people,
    this.notes,
  });

  @override
  List<Object?> get props => [id, imagePath, dateTime, location, people, notes];

  Memory copyWith({
    String? id,
    String? imagePath,
    DateTime? dateTime,
    String? location,
    List<Person>? people,
    String? notes,
  }) {
    return Memory(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      people: people ?? this.people,
      notes: notes ?? this.notes,
    );
  }
}

class Person extends Equatable {
  final String id;
  final String name;
  final String? notes;
  final List<String> tags;
  final List<String> memoryIds;
  final DateTime firstMet;
  final DateTime lastSeen;
  final String? avatarPath;

  const Person({
    required this.id,
    required this.name,
    this.notes,
    required this.tags,
    required this.memoryIds,
    required this.firstMet,
    required this.lastSeen,
    this.avatarPath,
  });

  @override
  List<Object?> get props =>
      [id, name, notes, tags, memoryIds, firstMet, lastSeen, avatarPath];

  Person copyWith({
    String? id,
    String? name,
    String? notes,
    List<String>? tags,
    List<String>? memoryIds,
    DateTime? firstMet,
    DateTime? lastSeen,
    String? avatarPath,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      memoryIds: memoryIds ?? this.memoryIds,
      firstMet: firstMet ?? this.firstMet,
      lastSeen: lastSeen ?? this.lastSeen,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  int get meetingCount => memoryIds.length;

  String get relationshipStrength {
    final daysSinceMet = DateTime.now().difference(firstMet).inDays;
    if (daysSinceMet < 7) return 'New';
    if (daysSinceMet < 30) return 'Recent';
    if (daysSinceMet < 365) return 'Regular';
    return 'Close';
  }
}

class FaceData extends Equatable {
  final String personId;
  final double x;
  final double y;
  final double width;
  final double height;

  const FaceData({
    required this.personId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  List<Object?> get props => [personId, x, y, width, height];
}
