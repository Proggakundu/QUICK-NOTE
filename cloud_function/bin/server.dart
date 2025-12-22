import 'dart:convert';
import 'dart:io';
import 'package:functions_framework/functions_framework.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

@CloudFunction()
Future<Response> syncNotes(Request request) async {
  // Handle CORS preflight
  if (request.method == 'OPTIONS') {
    return Response.ok('', headers: _corsHeaders);
  }

  // Only accept POST requests
  if (request.method != 'POST') {
    return Response(
      405,
      body: jsonEncode({'error': 'Method not allowed'}),
      headers: _corsHeaders,
    );
  }

  try {
    // Read request body
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Simple auth check
    final userId = request.headers['x-user-id'];
    if (userId == null || userId.isEmpty) {
      return Response(
        401,
        body: jsonEncode({'error': 'Unauthorized - missing x-user-id'}),
        headers: _corsHeaders,
      );
    }

    // Validate required fields
    if (!data.containsKey('id') || 
        !data.containsKey('title') || 
        !data.containsKey('content')) {
      return Response(
        400,
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: _corsHeaders,
      );
    }

    // Connect to Postgres
    final connection = await _getConnection();

    try {
      // Insert or update note
      await connection.execute(
        Sql.named('''
          INSERT INTO notes (id, user_id, title, content, image_path, latitude, longitude, created_at, synced)
          VALUES (@id, @userId, @title, @content, @imagePath, @lat, @lng, @createdAt, true)
          ON CONFLICT (id) DO UPDATE SET
            title = EXCLUDED.title,
            content = EXCLUDED.content,
            image_path = EXCLUDED.image_path,
            latitude = EXCLUDED.latitude,
            longitude = EXCLUDED.longitude,
            synced = true
        '''),
        parameters: {
          'id': data['id'],
          'userId': userId,
          'title': data['title'],
          'content': data['content'],
          'imagePath': data['imagePath'],
          'lat': data['latitude'],
          'lng': data['longitude'],
          'createdAt': data['createdAt'],
        },
      );

      // FIX: Use Response with json.encode instead of Response.json
      return Response.ok(
        jsonEncode({'success': true, 'message': 'Note synced successfully'}),
        headers: {..._corsHeaders, 'Content-Type': 'application/json'},
      );
    } finally {
      await connection.close();
    }
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
    return Response(
      500,
      body: jsonEncode({'error': 'Internal server error', 'details': e.toString()}),
      headers: _corsHeaders,
    );
  }
}

Future<Connection> _getConnection() async {
  final endpoint = Endpoint(
    host: Platform.environment['DB_HOST'] ?? 'localhost',
    database: Platform.environment['DB_NAME'] ?? 'notes_db',
    // FIX: username and password are named parameters in ConnectionSettings
  );

  return await Connection.open(
    endpoint,
    settings: ConnectionSettings(
      sslMode: SslMode.disable, // Use SslMode.require in production
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password: Platform.environment['DB_PASS'] ?? 'password',
    ),
  );
}

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-user-id',
};