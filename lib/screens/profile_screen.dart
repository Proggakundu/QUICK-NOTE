import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/feature_flag_service.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _authService = AuthService();
  Uint8List? _profileImageBytes;
  bool _isDarkMode = false;
  bool _locationEnabled = true;
  bool _autoSave = true;
  bool _notifications = false;
  bool _offlineMode = false;
  bool _isEditingName = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _isDarkMode = await featureFlagService.isEnabled('dark-mode');
    _locationEnabled = await featureFlagService.isEnabled('location-tagging');
    _autoSave = await featureFlagService.isEnabled('auto-save');
    _notifications = await featureFlagService.isEnabled('notifications');
    _offlineMode = await featureFlagService.isEnabled('offline-mode');
    
    // Get user-specific keys
    final userId = _authService.currentUserId ?? 'guest';
    final savedName = prefs.getString('profile_name_$userId');
    final savedImageBase64 = prefs.getString('profile_image_$userId');
    
    if (savedName != null) {
      _nameController.text = savedName;
    } else {
      if (_authService.isGuest) {
        _nameController.text = 'Guest User';
      } else {
        final user = _authService.currentUser;
        _nameController.text = user?.email?.split('@')[0] ?? 'User';
      }
    }
    
    if (savedImageBase64 != null) {
      _profileImageBytes = base64Decode(savedImageBase64);
    }
    
    setState(() {});
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _authService.currentUserId ?? 'guest';
    
    await prefs.setString('profile_name_$userId', _nameController.text);
    
    if (_profileImageBytes != null) {
      final base64Image = base64Encode(_profileImageBytes!);
      await prefs.setString('profile_image_$userId', base64Image);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
        });
        
        await _saveProfileData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _convertToRegisteredUser() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController(text: _nameController.text);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create an account to sync your notes across devices!',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final result = await _authService.convertGuestToUser(
                emailController.text.trim(),
                passwordController.text,
                nameController.text.trim(),
              );

              if (mounted) {
                Navigator.pop(context, result.success);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              }
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _loadSettings();
      });
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    await featureFlagService.setFlag('dark-mode', value);
    setState(() {
      _isDarkMode = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Dark mode enabled - restart app to apply' : 'Light mode enabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleLocation(bool value) async {
    await featureFlagService.setFlag('location-tagging', value);
    setState(() {
      _locationEnabled = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Location tagging enabled' : 'Location tagging disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleAutoSave(bool value) async {
    await featureFlagService.setFlag('auto-save', value);
    setState(() {
      _autoSave = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Auto-save enabled' : 'Auto-save disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final granted = await NotificationService.initialize();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied. Please enable in browser settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      await NotificationService.showNotification(
        '🔔 Notifications Enabled',
        'You will now receive notifications for auto-save and location updates',
      );
    }
    
    await featureFlagService.setFlag('notifications', value);
    setState(() {
      _notifications = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Notifications enabled' : 'Notifications disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleOfflineMode(bool value) async {
    await featureFlagService.setFlag('offline-mode', value);
    setState(() {
      _offlineMode = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.cloud_off : Icons.cloud,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value 
                    ? 'Offline Mode: Notes saved locally only' 
                    : 'Online Mode: Notes sync to cloud',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: value ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_authService.isGuest ? 'Exit Guest Mode?' : 'Sign Out'),
        content: Text(
          _authService.isGuest
              ? 'Your notes will remain on this device. You can continue using them next time.'
              : 'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _authService.isGuest ? 'Exit' : 'Sign Out',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isGuest = _authService.isGuest;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: _profileImageBytes != null
                            ? MemoryImage(_profileImageBytes!)
                            : null,
                        child: _profileImageBytes == null
                            ? Icon(
                                isGuest ? Icons.person_outline : Icons.person,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (!_isEditingName)
                    GestureDetector(
                      onTap: () => setState(() => _isEditingName = true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _nameController.text,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, size: 18, color: Colors.white70),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.white),
                          onPressed: () async {
                            setState(() => _isEditingName = false);
                            await _saveProfileData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Name updated!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Guest badge or email
                  if (isGuest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Guest Mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guest upgrade option
                  if (isGuest) ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.upgrade, color: Colors.blue),
                        title: const Text('Create Account'),
                        subtitle: const Text('Sync your notes across devices'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _convertToRegisteredUser,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  
                  Card(
                    child: SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Switch between light and dark theme'),
                      secondary: Icon(
                        _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).primaryColor,
                      ),
                      value: _isDarkMode,
                      onChanged: _toggleDarkMode,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Sync & Storage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  
                  Card(
                    child: SwitchListTile(
                      title: const Text('Offline Mode'),
                      subtitle: Text(
                        _offlineMode 
                          ? 'Notes saved locally only (no cloud sync)'
                          : 'Notes sync to cloud automatically',
                      ),
                      secondary: Icon(
                        _offlineMode ? Icons.cloud_off : Icons.cloud,
                        color: _offlineMode ? Colors.orange : Colors.green,
                      ),
                      value: _offlineMode,
                      onChanged: _toggleOfflineMode,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  
                  Card(
                    child: SwitchListTile(
                      title: const Text('Location Tagging'),
                      subtitle: const Text('Automatically tag notes with location'),
                      secondary: Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                      value: _locationEnabled,
                      onChanged: _toggleLocation,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Card(
                    child: SwitchListTile(
                      title: const Text('Auto Save'),
                      subtitle: const Text('Automatically save notes as you type'),
                      secondary: Icon(Icons.save, color: Theme.of(context).primaryColor),
                      value: _autoSave,
                      onChanged: _toggleAutoSave,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Card(
                    child: SwitchListTile(
                      title: const Text('Notifications'),
                      subtitle: const Text('Get browser notifications'),
                      secondary: Icon(Icons.notifications, color: Theme.of(context).primaryColor),
                      value: _notifications,
                      onChanged: _toggleNotifications,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        isGuest ? 'Exit Guest Mode' : 'Sign Out',
                        style: const TextStyle(color: Colors.red),
                      ),
                      subtitle: Text(
                        isGuest 
                          ? 'Your notes will remain on this device'
                          : 'Log out of your account',
                      ),
                      onTap: _signOut,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Quick Notes App',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}