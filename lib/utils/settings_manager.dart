import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_settings.dart';

class SettingsManager {
  static Future<void> saveTrainingSettings(String trainingId, TrainingSettings settings) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(trainingId, jsonEncode(settings.toJson()));
  }

  static Future<TrainingSettings?> loadTrainingSettings(String trainingId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(trainingId);
    if (jsonString != null) {
      return TrainingSettings.fromJson(jsonDecode(jsonString));
    }
    return null;
  }
}
