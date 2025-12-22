import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/notes_list_screen.dart';
import 'models/note.dart';
import 'services/auth_service.dart';
import 'services/feature_flag_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Timer? _themeCheckTimer;

  @override
  void initState() {
    super.initState();
    _startThemeCheck();
  }

  void _startThemeCheck() {
    _themeCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final isDarkMode = await featureFlagService.isEnabled('dark-mode');
      final newThemeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      
      if (_themeMode != newThemeMode) {
        setState(() {
          _themeMode = newThemeMode;
        });
      }
    });
  }

  @override
  void dispose() {
    _themeCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Notes',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/notes': (context) => const NotesListScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check if user is already logged in
    final isLoggedIn = await _authService.initialize();
    
    if (isLoggedIn) {
      // Open user-specific Hive box
      await _openUserBox();
    }
    
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _openUserBox() async {
    final userId = _authService.currentUserId;
    if (userId != null) {
      // Open notes box with user ID prefix to keep data separate per user
      final boxName = 'notes_$userId';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<Note>(boxName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Check auth state periodically
    return FutureBuilder<bool>(
      future: _authService.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isAuthenticated = _authService.isAuthenticated;

        if (isAuthenticated) {
          _openUserBox();
          return const NotesListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}