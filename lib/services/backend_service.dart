import 'package:dio/dio.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class BackendService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  
  // Replace with your actual Cloud Function URL
  static const String cloudFunctionUrl = 
      'https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/syncNotes';
  
  Future<bool> syncNote(Note note) async {
    try {
      final userId = _authService.currentUserId ?? 'anonymous';
      final token = await _authService.authToken;
      
      final response = await _dio.post(
        cloudFunctionUrl,
        data: note.toJson(),
        options: Options(
          headers: {
            'x-user-id': userId,
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Sync failed for note ${note.id}: $e');
      return false;
    }
  }
  
  Future<int> syncAllNotes() async {
    if (!_authService.isAuthenticated) {
      print('User not authenticated, skipping sync');
      return 0;
    }
    
    try {
      // Use storage service to get user-specific box
      final box = await storageService.getNotesBox();
      final unsyncedNotes = box.values.where((n) => !n.synced).toList();
      
      int syncedCount = 0;
      
      for (final note in unsyncedNotes) {
        final success = await syncNote(note);
        if (success) {
          note.synced = true;
          await note.save();
          syncedCount++;
        }
      }
      
      return syncedCount;
    } catch (e) {
      print('Error syncing notes: $e');
      return 0;
    }
  }
  
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get(
        cloudFunctionUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200 || response.statusCode == 405;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}

final backendService = BackendService();