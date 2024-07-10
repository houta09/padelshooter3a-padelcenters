import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../utils/training_settings.dart';

class FileManager {
  static Future<void> exportSettings(TrainingSettings settings) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final file = File('$path/training_settings.json');
      print('*AVH-Export: Writing to file: ${file.path}');
      await file.writeAsString(json.encode(settings.toJson()));
      print('*AVH-Export: File written successfully');
    } catch (e) {
      print('*AVH-Export: Error writing to file: $e');
    }
  }

  static Future<TrainingSettings?> importSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final file = File('$path/training_settings.json');
      if (await file.exists()) {
        String content = await file.readAsString();
        Map<String, dynamic> jsonContent = json.decode(content);
        return TrainingSettings.fromJson(jsonContent);
      } else {
        print('*AVH-Import: File not found');
        return null;
      }
    } catch (e) {
      print('*AVH-Import: Error reading from file: $e');
      return null;
    }
  }
}
