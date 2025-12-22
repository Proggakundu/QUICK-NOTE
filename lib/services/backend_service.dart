import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class BackendService {
  final _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  Future<bool> syncNote(Note note) async {
    try {
      final userId = _authService.currentUserId ?? 'anonymous';
      
      // Save directly to Firestore (no Cloud Function needed!)
      await _firestore
          .collection('notes')
          .doc(note.id)
          .set({
            'id': note.id,
            'title': note.title,
            'content': note.content,
            'imagePaths': note.imagePaths,
            'latitude': note.latitude,
            'longitude': note.longitude,
            'createdAt': note.createdAt.toIso8601String(),
            'userId': userId,
            'syncedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      return true;
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
      await _firestore.collection('test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}

final backendService = BackendService();
