import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/note.dart';
import 'note_detail_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../services/feature_flag_service.dart';
import '../services/storage_service.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isOnline = true;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _startConnectivityCheck();
  }

  void _startConnectivityCheck() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    // Check if offline mode is enabled in settings
    final offlineModeEnabled = await featureFlagService.isEnabled('offline-mode');
    
    setState(() {
      _isOnline = !offlineModeEnabled;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  List<Note> _filterNotes(List<Note> notes) {
    if (_searchQuery.isEmpty) {
      return notes;
    }

    return notes.where((note) {
      final titleMatch = note.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final contentMatch = note.content.toLowerCase().contains(_searchQuery.toLowerCase());
      return titleMatch || contentMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Row(
                children: [
                  const Text('Quick Notes'),
                  const SizedBox(width: 8),
                  if (!_isOnline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close Search' : 'Search Notes',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Box<Note>>(
        future: storageService.getNotesBox(),
        builder: (context, boxSnapshot) {
          if (boxSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!boxSnapshot.hasData) {
            return const Center(
              child: Text('Error loading notes'),
            );
          }

          return Column(
            children: [
              // Offline Mode Banner
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Working Offline',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'All notes are saved locally on this device',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Notes list
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: boxSnapshot.data!.listenable(),
                  builder: (context, Box<Note> box, _) {
                    if (box.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 100,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes yet',
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to create your first note',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final allNotes = box.values.toList().reversed.toList();
                    final filteredNotes = _filterNotes(allNotes);

                    if (filteredNotes.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 100,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Search results count
                        if (_searchQuery.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.blue.withOpacity(0.1),
                            child: Text(
                              'Found ${filteredNotes.length} ${filteredNotes.length == 1 ? 'note' : 'notes'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        
                        // Notes list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = filteredNotes[index];
                              final hasImages = note.imagePaths.isNotEmpty;
                              final imageCount = note.imagePaths.length;
                              final hasLocation = note.latitude != null && note.longitude != null;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: hasImages
                                      ? Stack(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: Colors.grey[200],
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  color: Colors.grey,
                                                  size: 30,
                                                ),
                                              ),
                                            ),
                                            if (imageCount > 1)
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).primaryColor,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '+${imageCount - 1}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.note,
                                            color: Theme.of(context).primaryColor,
                                            size: 30,
                                          ),
                                        ),
                                  title: _buildHighlightedText(
                                    note.title,
                                    _searchQuery,
                                    const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (note.content.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildHighlightedText(
                                          note.content,
                                          _searchQuery,
                                          TextStyle(color: Colors.grey[600]),
                                          maxLines: 2,
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (hasLocation)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 12,
                                                    color: Colors.blue,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Location',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (hasLocation && hasImages) const SizedBox(width: 8),
                                          if (hasImages)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.image,
                                                    size: 12,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$imageCount',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const Spacer(),
                                          Text(
                                            _formatDate(note.createdAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteNote(context, note),
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NoteDetailScreen(note: note),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NoteDetailScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style, {int? maxLines}) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines ?? 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        text,
        style: style,
        maxLines: maxLines ?? 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: maxLines ?? 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: style.copyWith(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await note.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}