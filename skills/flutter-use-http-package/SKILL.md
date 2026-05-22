---
name: flutter-use-http-package
description: Use the `http` package to execute GET, POST, PUT, or DELETE requests. Use when you need to fetch from or send data to a REST API.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:36:42 GMT
---
# Implementing Flutter Networking

## Contents
- [Configuration & Permissions](#configuration--permissions)
- [Request Execution & Response Handling](#request-execution--response-handling)
- [Background Parsing](#background-parsing)
- [Workflow: Executing Network Operations](#workflow-executing-network-operations)
- [Examples](#examples)

## Configuration & Permissions

Configure the environment and platform-specific permissions required for network access.

1. Add the `http` package dependency via the terminal:
   ```bash
   flutter pub add http
   ```
2. Import the package in your Dart files:
   ```dart
   import 'package:http/http.dart' as http;
   ```
3. Configure Android permissions by adding the Internet permission to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```
4. Configure macOS entitlements by adding the network client key to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:
   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   ```

## Request Execution & Response Handling

Execute HTTP operations and map responses to strongly typed Dart objects.

*   **URIs:** Always parse URL strings using `Uri.parse('your_url')`.
*   **Headers:** Inject authorization and content-type headers via the `headers` parameter map. Use `HttpHeaders.authorizationHeader` for auth tokens.
*   **Payloads:** For POST and PUT requests, encode the body using `jsonEncode()` from `dart:convert`.
*   **Status Validation:** Evaluate `response.statusCode`. Treat `200 OK` (GET/PUT/DELETE) and `201 CREATED` (POST) as success. 
*   **Error Handling:** Throw explicit exceptions for non-success status codes. Never return `null` on failure, as this prevents `FutureBuilder` from triggering its error state and causes infinite loading indicators.
*   **Deserialization:** Parse the raw string using `jsonDecode(response.body)` and map it to a custom Dart object using a factory constructor (e.g., `fromJson`).

## Background Parsing

Offload expensive JSON parsing to a separate Isolate to prevent UI jank (frame drops).

*   Import `package:flutter/foundation.dart`.
*   Use the `compute()` function to run the parsing logic in a background isolate.
*   Ensure the parsing function passed to `compute()` is a top-level function or a static method, as closures or instance methods cannot be passed across isolates.

## Workflow: Executing Network Operations

Use the following checklist to implement and validate network operations.

**Task Progress:**
- [ ] 1. Define the strongly typed Dart model with a `fromJson` factory constructor.
- [ ] 2. Implement the network request method returning a `Future<Model>`.
- [ ] 3. Apply conditional logic based on the operation type:
  - **If fetching data (GET):** Append query parameters to the URI.
  - **If mutating data (POST/PUT):** Set `'Content-Type': 'application/json; charset=UTF-8'` and attach the `jsonEncode` body.
  - **If deleting data (DELETE):** Return an empty model instance on success (`200 OK`).
- [ ] 4. Validate the `statusCode` and throw an `Exception` on failure.
- [ ] 5. Integrate the `Future` into the UI using `FutureBuilder`.
- [ ] 6. Handle `snapshot.hasData`, `snapshot.hasError`, and default to a `CircularProgressIndicator`.
- [ ] 7. **Feedback Loop:** Run the app -> trigger the network request -> review console for unhandled exceptions -> fix parsing or permission errors.

## Examples

### High-Fidelity Implementation: Fetching and Parsing in the Background

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 1. Top-level parsing function for Isolate
List<Photo> parsePhotos(String responseBody) {
  final parsed = (jsonDecode(responseBody) as List<Object?>)
      .cast<Map<String, Object?>>();
  return parsed.map<Photo>(Photo.fromJson).toList();
}

// 2. Network execution with background parsing
Future<List<Photo>> fetchPhotos() async {
  final response = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/photos'),
    headers: {
      HttpHeaders.authorizationHeader: 'Bearer your_token_here',
      HttpHeaders.acceptHeader: 'application/json',
    },
  );

  if (response.statusCode == 200) {
    // Offload heavy parsing to a background isolate
    return compute(parsePhotos, response.body);
  } else {
    throw Exception('Failed to load photos. Status: ${response.statusCode}');
  }
}

// 3. Strongly typed model
class Photo {
  final int id;
  final String title;
  final String thumbnailUrl;

  const Photo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
    );
  }
}

// 4. UI Integration
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key});

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  late Future<List<Photo>> _futurePhotos;

  @override
  void initState() {
    super.initState();
    // Initialize Future once to prevent re-fetching on rebuilds
    _futurePhotos = fetchPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Photo>>(
      future: _futurePhotos,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final photos = snapshot.data!;
          return ListView.builder(
            itemCount: photos.length,
            itemBuilder: (context, index) => ListTile(
              leading: Image.network(photos[index].thumbnailUrl),
              title: Text(photos[index].title),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        // Default loading state
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
```
