import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/time_entry_model.dart' as model;
import '../services/time_entry_service.dart';

class TaskController extends ChangeNotifier {
  final String firstName;
  final String lastName;
  final bool isCorrection;
  
  List<Map<String, dynamic>> tasks = [];
  Map<String, Map<String, String>> taskHours = {};
  
  // Service de gestion des entrées de temps
  final TimeEntryService _timeEntryService = TimeEntryService();
  
  TaskController({
    required this.firstName,
    required this.lastName,
    required this.isCorrection,
  });

  Future<void> initialize() async {
    await _loadTasks();
    if (isCorrection) {
      await _loadCorrectionData();
    }
  }

  Future<void> _loadTasks() async {
    // Charger les tâches depuis une source de données
    // Ici, nous utilisons une liste codée en dur pour l'exemple
    tasks = [
      {
        'section': 'Projets',
        'tasks': [
          {'name': 'Développement', 'selected': false, 'hours': '0'},
          {'name': 'Réunions', 'selected': false, 'hours': '0'},
          {'name': 'Documentation', 'selected': false, 'hours': '0'},
        ],
      },
      {
        'section': 'Formation',
        'tasks': [
          {'name': 'Formation en ligne', 'selected': false, 'hours': '0'},
          {'name': 'Ateliers', 'selected': false, 'hours': '0'},
        ],
      },
      {
        'section': 'Autres',
        'tasks': [
          {'name': 'Pause déjeuner', 'selected': false, 'hours': '0'},
          {'name': 'Autre', 'selected': false, 'hours': '0'},
        ],
      },
    ];
    
    // Initialiser taskHours
    for (var section in tasks) {
      taskHours[section['section']] = {};
      for (var task in section['tasks']) {
        taskHours[section['section']]![task['name']] = task['hours'];
      }
    }
    
    notifyListeners();
  }

  Future<void> _loadCorrectionData() async {
    try {
      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final employeeId = '$firstName $lastName';
      
      final entry = await _timeEntryService.getTimeEntryByIdAndDate(employeeId, formattedDate);
      
      if (entry != null) {
        // Mettre à jour les tâches avec les données existantes
        for (var task in entry.tasks) {
          for (var section in tasks) {
            final taskIndex = section['tasks'].indexWhere((t) => t['name'] == task['name']);
            if (taskIndex != -1) {
              section['tasks'][taskIndex]['selected'] = true;
              section['tasks'][taskIndex]['hours'] = task['hours'].toString();
              taskHours[section['section']]![task['name']] = task['hours'].toString();
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données de correction: $e');
      rethrow;
    }
  }

  void toggleTask(String section, String taskName) {
    for (var sectionData in tasks) {
      if (sectionData['section'] == section) {
        for (var task in sectionData['tasks']) {
          if (task['name'] == taskName) {
            task['selected'] = !(task['selected'] ?? false);
            if (!task['selected']) {
              task['hours'] = '0';
              taskHours[section]![taskName] = '0';
            } else {
              task['hours'] = task['hours'] ?? '0';
              taskHours[section]![taskName] = task['hours'];
            }
            break;
          }
        }
        break;
      }
    }
    notifyListeners();
  }

  void updateTaskHours(String section, String taskName, String hours) {
    taskHours[section]![taskName] = hours;
    
    // Mettre à jour également la liste des tâches
    for (var sectionData in tasks) {
      if (sectionData['section'] == section) {
        for (var task in sectionData['tasks']) {
          if (task['name'] == taskName) {
            task['hours'] = hours;
            task['selected'] = hours != '0' && hours.isNotEmpty;
            break;
          }
        }
        break;
      }
    }
    notifyListeners();
  }

  Future<String> saveData() async {
    try {
      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final employeeId = '$firstName $lastName';
      
      // Préparer les tâches sélectionnées
      final List<Map<String, dynamic>> selectedTasks = [];
      
      for (var section in tasks) {
        for (var task in section['tasks']) {
          if (task['selected'] == true && task['hours'] != '0' && task['hours'].isNotEmpty) {
            selectedTasks.add({
              'name': task['name'],
              'hours': task['hours'],
              'section': section['section'],
            });
          }
        }
      }
      
      if (selectedTasks.isEmpty) {
        throw Exception('Veuillez sélectionner au moins une tâche avec des heures');
      }
      
      // Créer l'entrée de temps
      final timeEntry = model.TimeEntryModel(
        employeeId: employeeId,
        date: formattedDate,
        hoursWorked: selectedTasks.fold(0.0, (sum, task) {
          final hours = double.tryParse(task['hours']?.toString() ?? '0') ?? 0.0;
          return sum + hours;
        }),
        tasks: selectedTasks,
        isSynced: false,
      );
      
      // Sauvegarder localement
      await _timeEntryService.saveTimeEntry(timeEntry);
      
      // Tenter une synchronisation (méthode à implémenter dans SyncService si nécessaire)
      // await _syncService.syncPendingEntries();
      
      // Sauvegarder dans un fichier (pour le débogage)
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/timesheet_${today.millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(timeEntry.toJson()));
      
      // Mettre à jour la date de dernière entrée
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_entry_date', formattedDate);
      
      return file.path;
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde: $e');
      rethrow;
    }
  }

  Future<bool> checkTodaysEntry() async {
    try {
      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final employeeId = '$firstName $lastName';
      
      final entry = await _timeEntryService.getTimeEntryByIdAndDate(employeeId, formattedDate);
      return entry != null;
    } catch (e) {
      debugPrint('Erreur lors de la vérification des entrées: $e');
      return false;
    }
  }
}
