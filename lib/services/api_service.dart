import 'dart:convert';
import '../models/time_entry_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  /// Vérifie si une entrée existe déjà pour un employé à une date donnée
  Future<TimeEntryModel?> fetchTimeEntry(String employeeId, String date, {String? baseUrl}) async {
    final url = '${baseUrl ?? 'http://localhost:3000'}/api/timesheets/$employeeId/$date';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return TimeEntryModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'entrée: $e');
      return null;
    }
  }

  /// Met à jour une entrée existante (PUT)
  Future<bool> updateTimeEntry(TimeEntryModel entry, {String? baseUrl}) async {
    final url = '${baseUrl ?? 'http://localhost:3000'}/api/timesheets/${entry.employeeId}/${entry.date}';
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: entry.toJsonString(),
      );
      if (response.statusCode != 200) {
        debugPrint('Erreur API (update): Status ${response.statusCode}, Body: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour timesheet: $e');
      return false;
    }
  }
  // Exemple d'API pour ajouter ou mettre à jour une entrée
  /// Ajoute ou met à jour une entrée de timesheet via l'API
  Future<bool> upsertTimeEntry(TimeEntryModel entry, {String? baseUrl}) async {
    final url = '${baseUrl ?? 'http://localhost:3000'}/api/timesheets';
    try {
      final apiJson = entry.toApiJson();
      debugPrint('Body envoyé: $apiJson');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(apiJson),
      );
      if (!(response.statusCode == 200 || response.statusCode == 201)) {
        debugPrint('Erreur API (upsert): Status ${response.statusCode}, Body: ${response.body}');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erreur lors de l\'upsert timesheet: $e');
      return false;
    }
  }

  /// Teste la connexion au backend (retourne true si OK, false sinon)
  Future<bool> testConnection({String? baseUrl}) async {
    final url = '${baseUrl ?? 'http://localhost:3000'}/api/employees';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
