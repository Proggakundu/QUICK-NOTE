import 'package:hive/hive.dart';
import '../models/note.dart';
import 'auth_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _authService = AuthService();

  /// Get the user-specific box name for notes
  String get notesBoxName {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return 'notes_guest'; // Fallback for non-authenticated users
    }
    return 'notes_$userId';
  }

  /// Get the notes box for the current user
  Future<Box<Note>> getNotesBox() async {
    final boxName = notesBoxName;
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<Note>(boxName);
    }
    return Hive.box<Note>(boxName);
  }

  /// Close the current user's box (call on logout if needed)
  Future<void> closeNotesBox() async {
    final boxName = notesBoxName;
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<Note>(boxName).close();
    }
  }
}

final storageService = StorageService();