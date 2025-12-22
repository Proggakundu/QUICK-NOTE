import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Guest mode tracking
  bool _isGuest = false;
  String? _guestId;

  // Getters
  User? get currentUser => _auth.currentUser;
  String? get currentUserId {
    if (_isGuest) return _guestId;
    return _auth.currentUser?.uid;
  }
  String? get currentUserEmail => _auth.currentUser?.email;
  bool get isAuthenticated => _auth.currentUser != null || _isGuest;
  bool get isGuest => _isGuest;
  
  // Get auth token for API calls
  Future<String?> get authToken async {
    if (_isGuest) return null;
    return await _auth.currentUser?.getIdToken();
  }

  /// Initialize and check if user is already logged in
  Future<bool> initialize() async {
    // Check if Firebase user exists
    if (_auth.currentUser != null) {
      _isGuest = false;
      return true;
    }
    
    // Check if guest session exists
    final prefs = await SharedPreferences.getInstance();
    final savedGuestId = prefs.getString('guest_id');
    
    if (savedGuestId != null) {
      _isGuest = true;
      _guestId = savedGuestId;
      return true;
    }
    
    return false;
  }

  /// Continue as guest
  Future<AuthResult> continueAsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if guest ID already exists
      String? guestId = prefs.getString('guest_id');
      
      if (guestId == null) {
        // Create new guest ID
        guestId = 'guest_${const Uuid().v4()}';
        await prefs.setString('guest_id', guestId);
      }
      
      _isGuest = true;
      _guestId = guestId;
      
      return AuthResult.success(
        message: 'Welcome! Using guest mode',
      );
    } catch (e) {
      return AuthResult.failure(
        message: 'Error setting up guest mode: $e',
      );
    }
  }

  /// Convert guest to registered user
  Future<AuthResult> convertGuestToUser(String email, String password, String name) async {
    if (!_isGuest) {
      return AuthResult.failure(
        message: 'Not in guest mode',
      );
    }
    
    try {
      // Create Firebase account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      // Clear guest mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('guest_id');
      
      _isGuest = false;
      _guestId = null;
      
      return AuthResult.success(
        message: 'Account created! Your notes have been saved.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Login with email and password
  Future<AuthResult> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _isGuest = false;
      _guestId = null;
      
      return AuthResult.success(message: 'Login successful');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Sign up new user
  Future<AuthResult> signup(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      _isGuest = false;
      _guestId = null;
      
      return AuthResult.success(message: 'Account created successfully');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Logout user or exit guest mode
  Future<void> logout() async {
    if (_isGuest) {
      // For guest mode, ask if they want to keep data
      _isGuest = false;
      _guestId = null;
      
      // Optionally clear guest data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('guest_id');
    } else {
      await _auth.signOut();
    }
  }

  /// Send password reset email
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(
        message: 'Password reset email sent. Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Get user-friendly error messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

class AuthResult {
  final bool success;
  final String message;

  AuthResult.success({required this.message}) : success = true;
  AuthResult.failure({required this.message}) : success = false;
}