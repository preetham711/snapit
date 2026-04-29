import 'meeting_model.dart';

class PersonModel {
  final String id;
  final String name;
  final String timeLabel;
  final int meetingCount;
  final String indicatorColor;
  final String? imagePath;       // local file path (from camera)
  final String? avatarUrl;       // profile avatar URL
  final List<String> recentImageUrls; // multiple recent memory photos

  // Detail screen fields
  final String tag;
  final String strength;
  final String lastLocation;
  final List<MeetingModel> meetings;

  const PersonModel({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.meetingCount,
    required this.indicatorColor,
    this.imagePath,
    this.avatarUrl,
    this.recentImageUrls = const [],
    this.tag = 'Friend',
    this.strength = 'Strong',
    this.lastLocation = 'San Francisco, CA',
    this.meetings = const [],
  });
}
