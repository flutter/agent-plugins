import 'package:path/path.dart' as p;

void main() {
  const user = 'Test';

  // Interpolation (clean Dart idiom)
  const message = 'Hello $user';

  // Cross platform path
  final String path = p.join('my', 'path', 'data.txt');

  if (message.isEmpty || path.isEmpty) {
    throw Exception('Validation failed');
  }
}
