import 'dart:convert';
import 'dart:io';

Future<Map<String, Map<String, String>>> loadTaskHoursFromFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    // Expecting JSON, fallback to empty map if not parsable
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((section, tasks) => MapEntry(
        section,
        Map<String, String>.from(tasks as Map)
      ));
    }
    return {};
  } catch (_) {
    return {};
  }
}
