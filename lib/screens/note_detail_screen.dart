import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../services/feature_flag_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'package:hive/hive.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note;

  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _imagePaths = [];
  Map<String, String> _tempImageData = {};
  
  final _cameraService = CameraService();
  
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  
  double? _latitude;
  double? _longitude;
  
  Note? _savedNote;
  bool _isNewNote = true;
  
  // Offline mode
  bool _isOnline = true;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    
    if (widget.note != null) {
      _imagePaths = List<String>.from(widget.note!.imagePaths);
      _latitude = widget.note!.latitude;
      _longitude = widget.note!.longitude;
      _savedNote = widget.note;
      _isNewNote = false;
    }
    
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    
    _loadLocation();
    _startConnectivityCheck();
  }

  void _startConnectivityCheck() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final offlineModeEnabled = await featureFlagService.isEnabled('offline-mode');
    
    setState(() {
      _isOnline = !offlineModeEnabled;
    });
  }

  Future<void> _loadLocation() async {
    final locationEnabled = await featureFlagService.isEnabled('location-tagging');
    if (locationEnabled && _latitude == null) {
      try {
        final position = await LocationService.getCurrentLocation();
        if (position != null && mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
          });
        }
      } catch (e) {
        print('Error getting location: $e');
      }
    }
  }

  void _onTextChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });

    _autoSaveTimer?.cancel();
    
    _autoSaveTimer = Timer(const Duration(seconds: 5), () async {
      if (_hasUnsavedChanges) {
        final autoSaveEnabled = await featureFlagService.isEnabled('auto-save');
        if (autoSaveEnabled) {
          await _autoSave();
        }
      }
    });
  }

  Future<void> _autoSave() async {
    if (_titleController.text.isEmpty) return;

    if (_savedNote == null || 
        _savedNote!.title != _titleController.text ||
        _savedNote!.content != _contentController.text) {
      
      await _saveNote(showMessage: false);
      
      setState(() {
        _hasUnsavedChanges = false;
      });

      final notificationsEnabled = await featureFlagService.isEnabled('notifications');
      if (notificationsEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline ? '✓ Auto-saved' : '✓ Auto-saved (offline)'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _addImage() async {
    final result = await _cameraService.takePicture();
    if (result != null) {
      setState(() {
        if (kIsWeb && result.bytes != null) {
          final imagePath = 'web_image_${DateTime.now().millisecondsSinceEpoch}';
          _imagePaths.add(imagePath);
          
          final base64Data = base64Encode(result.bytes!);
          
          if (_savedNote != null) {
            _savedNote!.imageData[imagePath] = base64Data;
          } else {
            _tempImageData[imagePath] = base64Data;
          }
        } else if (result.path != null) {
          _imagePaths.add(result.path!);
        }
        _hasUnsavedChanges = true;
      });
    }
  }

  void _deleteImage(int index) {
    setState(() {
      final imagePath = _imagePaths[index];
      if (kIsWeb) {
        if (_savedNote != null) {
          _savedNote!.imageData.remove(imagePath);
        } else {
          _tempImageData.remove(imagePath);
        }
      }
      _imagePaths.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _insertBulletList() async {
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    if (selection.start >= 0) {
      final newText = text.substring(0, selection.start) + 
                     '• ' + 
                     text.substring(selection.start);
      _contentController.text = newText;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: selection.start + 2),
      );
    }
  }

  Future<void> _insertNumberedList() async {
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    if (selection.start >= 0) {
      final newText = text.substring(0, selection.start) + 
                     '1. ' + 
                     text.substring(selection.start);
      _contentController.text = newText;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: selection.start + 3),
      );
    }
  }

  Future<void> _insertTable() async {
    final table = '''
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Data 1   | Data 2   | Data 3   |
| Data 4   | Data 5   | Data 6   |
''';
    
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    if (selection.start >= 0) {
      final newText = text.substring(0, selection.start) + 
                     table + 
                     text.substring(selection.start);
      _contentController.text = newText;
    }
  }

  Future<void> _saveNote({bool showMessage = true}) async {
    if (_titleController.text.isEmpty) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a title'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final box = await storageService.getNotesBox();
      
      if (_savedNote == null) {
        final newNote = Note(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imagePaths: _imagePaths,
          latitude: _latitude,
          longitude: _longitude,
          createdAt: DateTime.now(),
          imageData: _tempImageData,
        );
        
        await box.put(newNote.id, newNote);
        
        setState(() {
          _savedNote = newNote;
          _isNewNote = false;
          _hasUnsavedChanges = false;
        });
      } else {
        _savedNote!.title = _titleController.text.trim();
        _savedNote!.content = _contentController.text.trim();
        _savedNote!.imagePaths = _imagePaths;
        _savedNote!.latitude = _latitude;
        _savedNote!.longitude = _longitude;
        
        await _savedNote!.save();
        
        setState(() {
          _hasUnsavedChanges = false;
        });
      }

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline ? 'Note saved' : 'Note saved (offline)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving note: $e');
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote() async {
    if (_savedNote == null) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _savedNote!.delete();
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting note: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildImageWidget(String imagePath) {
    if (kIsWeb) {
      String? base64Data;
      if (_savedNote != null) {
        base64Data = _savedNote!.imageData[imagePath];
      } else {
        base64Data = _tempImageData[imagePath];
      }
      
      if (base64Data != null) {
        try {
          final bytes = base64Decode(base64Data);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        } catch (e) {
          return const Center(child: Icon(Icons.error));
        }
      }
      return const Center(child: Icon(Icons.image));
    } else {
      // For mobile platforms, use file path
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.error));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewNote ? 'New Note' : 'Edit Note'),
        actions: [
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Center(
                child: Chip(
                  label: Text('Offline', style: TextStyle(fontSize: 12)),
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveNote(),
            tooltip: 'Save Note',
          ),
          if (!_isNewNote)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteNote,
              tooltip: 'Delete Note',
            ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[850]
                  : Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[700]!
                      : Colors.grey[300]!
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: () async {
                    final RenderBox button = context.findRenderObject() as RenderBox;
                    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                    final RelativeRect position = RelativeRect.fromRect(
                      Rect.fromPoints(
                        button.localToGlobal(Offset.zero, ancestor: overlay),
                        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                      ),
                      Offset.zero & overlay.size,
                    );

                    await showMenu(
                      context: context,
                      position: position,
                      items: [
                        PopupMenuItem(
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _insertBulletList(),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle, size: 8),
                              SizedBox(width: 12),
                              Text('Bullet List'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _insertNumberedList(),
                          ),
                          child: const Row(
                            children: [
                              Text('1.', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(width: 12),
                              Text('Numbered List'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  tooltip: 'Lists',
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart),
                  onPressed: _insertTable,
                  tooltip: 'Insert Table',
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _addImage,
                  tooltip: 'Add Image',
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Note Title',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Content
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'Start typing...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 10,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Images
                  if (_imagePaths.isNotEmpty) ...[
                    const Text(
                      'Images:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _imagePaths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImageWidget(_imagePaths[index]),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deleteImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  
                  // Location info
                  if (_latitude != null && _longitude != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _autoSaveTimer?.cancel();
    _connectivityTimer?.cancel();
    super.dispose();
  }
}