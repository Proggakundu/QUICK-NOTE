import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  String content;
  
  @HiveField(3)
  List<String> imagePaths;
  
  @HiveField(4)
  double? latitude;
  
  @HiveField(5)
  double? longitude;
  
  @HiveField(6)
  DateTime createdAt;
  
  @HiveField(7)
  bool synced;
  
  @HiveField(8)
  Map<String, String> imageData;

  Note({
    required this.id,
    required this.title,
    required this.content,
    List<String>? imagePaths,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.synced = false,
    Map<String, String>? imageData,
  }) : imagePaths = imagePaths ?? [],
       imageData = imageData ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'imagePaths': imagePaths,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'synced': synced,
      'imageData': imageData,
    };
  }
}
