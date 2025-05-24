import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/time_entry_model.dart';
import 'time_entry_service.dart';

class ApiService {
  // Upsert (update or insert) a time entry in the DB
  Future<void> upsertTimeEntry(TimeEntryModel entry) async {
    try {
      debugPrint('Tentative d\'upsert d\'une entrée de temps');
      final isConnected = await testConnection();
      if (!isConnected) {
        debugPrint('Pas de connexion Internet disponible');
        return;
      }
      debugPrint('Connexion Internet disponible, préparation des données...');
      final entryJson = entry.toJson();
      entryJson.remove('isSynced');
      
      // Traiter les nouvelles tâches spécifiques aux entreprises
      if (entryJson.containsKey('tasks')) {
        final tasks = entryJson['tasks'] as List;
        // Ajouter l'information sur l'entreprise à chaque tâche si elle n'existe pas déjà
        for (var i = 0; i < tasks.length; i++) {
          // Conserver la compatibilité avec l'ancien format
          if (!tasks[i].containsKey('company') && tasks[i].containsKey('section')) {
            tasks[i]['company'] = tasks[i]['section'];
          }
          // S'assurer que toutes les tâches ont une section pour l'admin panel
          if (!tasks[i].containsKey('section')) {
            tasks[i]['section'] = 'Tâches';
          }
        }
      }
      
      if (entryJson.containsKey('taskHours')) {
        final taskHours = entryJson['taskHours'];
        if (taskHours is Map) {
          entryJson['taskHours'] = taskHours.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      }

      final employeeId = entryJson['employeeId'];
      final date = entryJson['date'];

      // Vérifier si une entrée existe déjà pour cet employé et cette date
      final checkResponse = await http.get(
        Uri.parse('$baseUrl/timeentries/employee/$employeeId/date/$date'),
      );

      String? existingEntryId;
      if (checkResponse.statusCode == 200) {
        debugPrint('[API] checkResponse.statusCode: ${checkResponse.statusCode}');
        debugPrint('[API] checkResponse.body: ${checkResponse.body}');
        try {
          final data = jsonDecode(checkResponse.body);
          if (data != null && data is Map && data.containsKey('_id')) {
            existingEntryId = data['_id'];
          }
        } catch (e) {
          debugPrint('[API] Erreur de décodage JSON (checkResponse): $e');
        }
      }

      if (existingEntryId != null) {
        // Remplace l'entrée existante (PUT)
        final updateUrl = '$baseUrl/timeentries/$existingEntryId';
        await http.put(
          Uri.parse(updateUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(entryJson),
        );
        debugPrint("[API] Mise à jour de l'entrée existante (PUT)");
      } else {
        // Crée une nouvelle entrée (POST)
        await http.post(
          Uri.parse('$baseUrl/timeentries'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(entryJson),
        );
        debugPrint("[API] Création d'une nouvelle entrée (POST)");
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'upsert de l\'entrée de temps: $e');
    }
  }

  // Supprimer une entrée de temps de la DB
  Future<bool> deleteTimeEntry(String employeeId, String date) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/timeentries?employeeId=$employeeId&date=$date'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur lors de la suppression de l\'entrée de temps: $e');
      return false;
    }
  }

  // URL de base de l'API - point d'accès à l'API déployée sur Heroku
  static const String baseUrl = 'http://localhost:3000/api';

  // Tester la connexion à Internet
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      debugPrint('Exception: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  // Envoyer une entrée de temps à l'API
  Future<Map<String, dynamic>?> sendTimeEntry(TimeEntryModel entry) async {
    try {
      // Vérifier la connexion d'abord
      final isConnected = await testConnection();
      if (!isConnected) {
        return null;
      }

      
      // Préparer les données avec firstName et lastName
      final entryJson = entry.toJson();
      // Enlever isSynced car l'API n'en a pas besoin
      entryJson.remove('isSynced');
      
      // Make sure taskHours is properly formatted for MongoDB
      if (entryJson.containsKey('taskHours')) {
        // Ensure taskHours is properly formatted as a Map<String, dynamic>
        // This is important for MongoDB to store it correctly
        final Map<String, dynamic> taskHoursMap = {};
        (entryJson['taskHours'] as Map<String, dynamic>).forEach((key, value) {
          taskHoursMap[key] = value;
        });
        entryJson['taskHours'] = taskHoursMap;
      }
      
      // Vérifier et traiter les tâches pour l'admin panel
      if (entryJson.containsKey('tasks')) {
        final tasks = entryJson['tasks'] as List;
        // Formater les tâches pour assurer la compatibilité avec l'admin panel
        for (var i = 0; i < tasks.length; i++) {
          var task = tasks[i] as Map<String, dynamic>;
          
          // S'assurer que le champ 'hours' est un nombre (et non une chaîne)
          if (task.containsKey('hours') && task['hours'] is String) {
            task['hours'] = double.tryParse(task['hours']) ?? 0.0;
          }
          
          // Ajouter des informations d'entreprise si elles n'existent pas
          if (!task.containsKey('company')) {
            // Déduire l'entreprise à partir du nom de la tâche si possible
            if (task['name'].toString().contains('SAS')) {
              task['company'] = 'SAS';
            } else if (task['name'].toString().contains('SCEA')) {
              task['company'] = 'SCEA';
            } else if (task['name'].toString().contains('CUMA')) {
              task['company'] = 'CUMA';
            } else {
              // Valeur par défaut
              task['company'] = 'SAS';
            }
          }
        }
      }
      
      // Extraire firstName et lastName de employeeId si nécessaire
      if (entryJson['employeeId'] != null && entryJson['employeeId'].contains(' ')) {
        final nameParts = entryJson['employeeId'].split(' ');
        if (!entryJson.containsKey('firstName')) {
          entryJson['firstName'] = nameParts[0];
        }
        if (!entryJson.containsKey('lastName')) {
          entryJson['lastName'] = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        }
      }
      
      // Envoi des données à l'API
      
      final response = await http.post(
        Uri.parse('$baseUrl/timeentries'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(entryJson),
      );
      
      // Vérification de la réponse API
      debugPrint('[API] response.statusCode: ${response.statusCode}');
      debugPrint('[API] response.body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          debugPrint('[API] Erreur de décodage JSON (response): $e');
          return null;
        }
      } else {
        debugPrint('[API] Erreur, statusCode: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Exception: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    }
  }
  
  // Obtenir le total mensuel des heures d'un employé
  Future<double?> getMonthlyTotal(String employeeId, int year, int month) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timeentries/monthly/$employeeId/$year/$month'),
      );
      debugPrint('[API] response.statusCode: ${response.statusCode}');
      debugPrint('[API] response.body: ${response.body}');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return data['totalHours'];
        } catch (e) {
          debugPrint('[API] Erreur de décodage JSON (getMonthlyTotal): $e');
          return null;
        }
      } else {
        debugPrint('[API] Erreur, statusCode: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e) {
      // debugPrint removed for production
//'Erreur lors de la récupération des totaux mensuels: $e');
      return null;
    }
  }
  
  // Récupérer toutes les entrées non synchronisées depuis l'API
  Future<List<TimeEntryModel>> getUnsyncedEntries() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timeentries/unsynced'),
      );
      debugPrint('[API] response.statusCode: ${response.statusCode}');
      debugPrint('[API] response.body: ${response.body}');
      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => TimeEntryModel.fromJson(json)).toList();
        } catch (e) {
          debugPrint('[API] Erreur de décodage JSON (getUnsyncedEntries): $e');
          return [];
        }
      } else {
        debugPrint('[API] Erreur, statusCode: ${response.statusCode}, body: ${response.body}');
        return [];
      }
    } catch (e) {
      // debugPrint removed for production
//'Erreur lors de la récupération des entrées non synchronisées: $e');
      return [];
    }
  }
  
  // Marquer une entrée comme synchronisée sur l'API
  Future<bool> markAsSynced(String entryId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/timeentries/$entryId/sync'),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      // debugPrint removed for production
//'Erreur lors du marquage de l\'entrée comme synchronisée: $e');
      return false;
    }
  }
  
  // Synchroniser toutes les entrées non synchronisées
  Future<int> syncUnsyncedEntries() async {
    // Importer le service de gestion des entrées de temps
    final timeEntryService = TimeEntryService();
    
    // Récupérer toutes les entrées non synchronisées
    final unsyncedEntries = await timeEntryService.getUnsyncedEntries();
    
    // Synchroniser chaque entrée
    for (final entry in unsyncedEntries) {
      await upsertTimeEntry(entry);
    }
    
    return 0;
  }
}
