// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Examples of Dart pattern matching for JSON handling:
/// - Polymorphic JSON deserialization (discriminated unions)
/// - Nested JSON validation with optional and omitted keys
library;

/// Represents an API response in a sealed hierarchy.
sealed class ApiResponse {}

/// Successful API response carrying data.
class SuccessResponse implements ApiResponse {
  final Map<String, dynamic> data;
  SuccessResponse(this.data);
}

/// Error API response carrying an error message and code.
class ErrorResponse implements ApiResponse {
  final String message;
  final int code;
  ErrorResponse(this.message, this.code);
}

/// Parses a raw JSON map into an [ApiResponse] subtype.
ApiResponse parseApiResponse(Map<String, dynamic> json) => switch (json) {
  {'status': 'ok', 'data': Map<String, dynamic> data} => SuccessResponse(data),
  {'status': 'error', 'message': String msg, 'code': int code} => ErrorResponse(
    msg,
    code,
  ),
  _ => throw FormatException('Invalid or unrecognized API response: $json'),
};

/// Validates a nested user payload with both required schema and optional keys.
void processUserPayload(Map<String, dynamic> json) {
  if (json case {
    'id': String id,
    'profile':
        {'name': String name, 'email': String email} &&
        final Map<String, dynamic> profile,
    'tags': [
      String primaryTag,
      ...,
    ], // Matches at least 1 element, ignores rest
  }) {
    // Read optional/omitted fields directly from the validated submap.
    // Map patterns check for key existence (containsKey), so an omitted key
    // fails matching even if typed as String?.
    final avatarUrl = profile['avatarUrl'] as String?;
    print(
      'User $name ($id, $email, avatar: $avatarUrl) - Primary tag: $primaryTag',
    );
  } else {
    throw FormatException('Malformed user payload structure: $json');
  }
}

void main() {
  // Test polymorphic deserialization
  final success = parseApiResponse({
    'status': 'ok',
    'data': {'userId': '123'},
  });
  print('Parsed success: $success');

  final error = parseApiResponse({
    'status': 'error',
    'message': 'Not found',
    'code': 404,
  });
  print('Parsed error: $error');

  // Test nested validation
  processUserPayload({
    'id': 'u100',
    'profile': {
      'name': 'Alice',
      'email': 'alice@example.com',
      'avatarUrl': 'https://example.com/avatar.png',
    },
    'tags': ['admin', 'staff'],
  });
}
