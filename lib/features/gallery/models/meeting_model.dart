class MeetingModel {
  final String id;
  final String title;
  final String date;
  final String notes;
  final String? imagePath;   // local file
  final String? imageUrl;    // demo network image

  const MeetingModel({
    required this.id,
    required this.title,
    required this.date,
    required this.notes,
    this.imagePath,
    this.imageUrl,
  });
}
