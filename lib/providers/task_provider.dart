import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../services/shared_preferences_service.dart';

import '../services/time_entry_service.dart';
import '../models/time_entry_model.dart' as model;
import '../services/sync_service.dart';
import '../models/task_state.dart';

class TaskNotifier extends StateNotifier<TaskState> {
  final _timeEntryService = TimeEntryService();
  final _syncService = SyncService();
  TaskNotifier() : super(TaskState.initial());

  // Charger les tâches (reset)
  Future<void> loadTasks() async {
    state = TaskState.initial();
  }

  // Initialiser les tâches pour une entreprise spécifique
  void initCompanyTasks(String company, List<Map<String, dynamic>> companyTasks) {
    final updatedCompanyTasks = Map<String, List<Map<String, dynamic>>>.from(state.companyTasks);
    updatedCompanyTasks[company] = List.from(companyTasks);
    final updatedTaskHours = Map<String, Map<String, String>>.from(state.taskHours);
    updatedTaskHours[company] = {};
    for (var task in companyTasks) {
      updatedTaskHours[company]![task['name']] = task['hours'];
    }
    state = state.copyWith(
      companyTasks: updatedCompanyTasks,
      taskHours: updatedTaskHours,
    );
  }
  
  // Obtenir les tâches pour une entreprise spécifique
  List<Map<String, dynamic>> getCompanyTasks(String company) {
    return state.companyTasks[company] ?? [];
  }
  
  // Basculer l'état d'une tâche pour une entreprise spécifique
  void toggleCompanyTask(String company, String taskName) {
    final updatedCompanyTasks = Map<String, List<Map<String, dynamic>>>.from(state.companyTasks);
    final updatedTaskHours = Map<String, Map<String, String>>.from(state.taskHours);
    if (!updatedCompanyTasks.containsKey(company)) return;
    for (var task in updatedCompanyTasks[company]!) {
      if (task['name'] == taskName) {
        final bool wasSelected = task['selected'] == true;
        task['selected'] = !wasSelected;
        if (!task['selected']) {
          task['hours'] = '';
          updatedTaskHours[company]![taskName] = '';
        } else {
          task['hours'] = task['hours'] ?? '';
          updatedTaskHours[company]![taskName] = task['hours'];
        }
        break;
      }
    }
    state = state.copyWith(
      companyTasks: updatedCompanyTasks,
      taskHours: updatedTaskHours,
    );
  }
  
  // Mettre à jour les heures d'une tâche pour une entreprise spécifique
  void updateCompanyTaskHours(String company, String taskName, String hours) {
    final updatedCompanyTasks = Map<String, List<Map<String, dynamic>>>.from(state.companyTasks);
    final updatedTaskHours = Map<String, Map<String, String>>.from(state.taskHours);
    if (!updatedCompanyTasks.containsKey(company)) return;
    updatedTaskHours[company]![taskName] = hours;
    for (var task in updatedCompanyTasks[company]!) {
      if (task['name'] == taskName) {
        task['hours'] = hours;
        if (hours.isNotEmpty) {
          task['selected'] = true;
        }
        break;
      }
    }
    state = state.copyWith(
      companyTasks: updatedCompanyTasks,
      taskHours: updatedTaskHours,
    );
  }
  
  // Sauvegarder les données pour une entreprise spécifique
  Future<String> saveData(String company, String firstName, String lastName, {required Map<String, String> taskHours, bool isEditing = false, double kilometers = 0.0, String reason = ''}) async {
    try {
      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final employeeId = '$firstName $lastName';
      
      debugPrint('===== DÉBUT DE LA SAUVEGARDE DES HEURES ====');
      debugPrint('Employé: $employeeId, Date: $formattedDate, Entreprise: $company');
      
      // IMPORTANT: Supprimer d'abord TOUTES les entrées existantes pour cet employé et cette date
      // Cela garantit qu'il n'y aura jamais de doublons, même lors d'un changement d'entreprise
      debugPrint('Suppression de toutes les entrées existantes pour $employeeId le $formattedDate');
      await _timeEntryService.deleteTimeEntriesByIdAndDate(employeeId, formattedDate);
      
      // Attendre un moment pour s'assurer que la suppression est traitée localement et sur le serveur
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Préparer les tâches sélectionnées
      final List<Map<String, dynamic>> selectedTasks = [];
      final Map<String, double> taskHoursMap = {};
      double totalHours = 0.0;
      
      debugPrint('Préparation des tâches sélectionnées:');
      for (var task in state.companyTasks[company]!) {
        // Check if task is selected AND has either day hours OR night hours
        final bool hasDayHours = task['hours'].toString().trim().isNotEmpty;
        final bool hasNightHours = task.containsKey('night_hours') && 
            task['night_hours'].toString().trim().isNotEmpty;
        
        if (task['selected'] == true && (hasDayHours || hasNightHours)) {
          final double dayHours = hasDayHours ? (double.tryParse(task['hours']) ?? 0.0) : 0.0;
          final double nightHours = hasNightHours ? (double.tryParse(task['night_hours']) ?? 0.0) : 0.0;
          final double totalTaskHours = dayHours + nightHours;
          totalHours += totalTaskHours;
          
          // Formatage pour le nouveau modèle (tasks)
          final Map<String, dynamic> taskData = {
            'name': task['name'],
            'hours': dayHours,
            'section': company,
            'company': company
          };
          
          // Add night_hours if present
          if (hasNightHours) {
            taskData['night_hours'] = nightHours;
          }
          
          selectedTasks.add(taskData);
          
          // Formatage pour l'ancien modèle (taskHours)
          final taskKey = "$company - ${task['name']}";
          taskHoursMap[taskKey] = totalTaskHours;
          
          // Log both day and night hours if applicable
          if (hasDayHours && hasNightHours) {
            debugPrint('  - ${task['name']}: $dayHours heures de jour, $nightHours heures de nuit');
          } else if (hasDayHours) {
            debugPrint('  - ${task['name']}: $dayHours heures de jour');
          } else {
            debugPrint('  - ${task['name']}: $nightHours heures de nuit');
          }
        }
      }
      
      if (selectedTasks.isEmpty) {
        throw Exception('Veuillez sélectionner au moins une tâche avec des heures');
      }
      
      // Créer la nouvelle entrée de temps
      final timeEntry = model.TimeEntryModel(
        kilometers: kilometers,
        reason: reason,
        employeeId: employeeId,
        firstName: firstName,
        lastName: lastName,
        date: formattedDate,
        hoursWorked: totalHours,
        tasks: selectedTasks,
        taskHours: taskHoursMap,
        isSynced: false,  // Marquer comme non synchronisé pour forcer la synchronisation
      );
      
      debugPrint('Création d\'une nouvelle entrée avec ${selectedTasks.length} tâches et $totalHours heures au total');
      
      // Un seul appel, qui gère tout (local + API)
      await _syncService.saveAndSync(
        timeEntry,
        isUpdating: isEditing, // true si on modifie, false si on crée
        forceDeleteExisting: false // ne pas supprimer systématiquement, laisser l'API faire l'upsert
      );
      
      // Mettre à jour la date de dernière entrée
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_entry_date', formattedDate);
      
      // Sauvegarder dans un fichier pour débogage
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/timesheet_${today.millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(timeEntry.toJson()));
      
      debugPrint('===== FIN DE LA SAUVEGARDE DES HEURES ====');
      return company;
    } catch (e) {
      debugPrint('ERREUR lors de la sauvegarde des données: $e');
      rethrow;
    }
  }
  
  // Mettre à jour les heures d'une tâche - pour rétrocompatibilité
  void updateTaskHours(String section, String taskName, String hours) {
    updateCompanyTaskHours(section, taskName, hours);
  }
  
  // Vérifier si une entrée existe pour aujourd'hui - utilise SharedPrefsService
  Future<bool> checkTodaysEntry(String employeeId) async {
    try {
      // Extraire prénom et nom de employeeId (si le format est "prénom nom")
      final parts = employeeId.split(' ');
      if (parts.length >= 2) {
        final firstName = parts[0];
        final lastName = parts.sublist(1).join(' '); // Pour gérer les noms composés
        
        // Utiliser la méthode centralisée
        return SharedPrefsService.hasUserEnteredHoursToday(firstName, lastName);
      }
      
      // Fallback: ancien système si format incorrect
      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final entry = await _timeEntryService.getTimeEntryByIdAndDate(employeeId, formattedDate);
      return entry != null;
    } catch (e) {
      debugPrint('Erreur lors de la vérification des entrées: $e');
      return false;
    }
  }
  
  // Charger les données de correction
  Future<void> loadCorrectionData(String employeeId, String formattedDate) async {
    try {
      final entry = await _timeEntryService.getTimeEntryByIdAndDate(employeeId, formattedDate);
      if (entry != null) {
        final updatedCompanyTasks = Map<String, List<Map<String, dynamic>>>.from(state.companyTasks);
        final updatedTaskHours = Map<String, Map<String, String>>.from(state.taskHours);
        
        debugPrint('Chargement des données de correction: ${entry.tasks.length} tâches trouvées');
        
        // Return the kilometers and reason info for the UI to use
        final Map<String, dynamic> kilometrageData = {
          'kilometers': entry.kilometers,
          'reason': entry.reason
        };
        
        // Log the kilometrage data
        debugPrint('Chargement des kilomètres: ${entry.kilometers} km, Motif: ${entry.reason}');
        
        // Process tasks
        for (var task in entry.tasks) {
          final company = task['section'] as String;
          if (updatedCompanyTasks.containsKey(company)) {
            final taskIndex = updatedCompanyTasks[company]!.indexWhere((t) => t['name'] == task['name']);
            if (taskIndex != -1) {
              // Mark task as selected
              updatedCompanyTasks[company]![taskIndex]['selected'] = true;
              
              // Handle day hours
              final dayHours = task['hours']?.toString() ?? '0';
              updatedCompanyTasks[company]![taskIndex]['hours'] = dayHours;
              updatedTaskHours[company]![task['name']] = dayHours;
              
              // Handle night hours if present in the task
              if (task.containsKey('night_hours') && updatedCompanyTasks[company]![taskIndex].containsKey('night_hours')) {
                final nightHours = task['night_hours']?.toString() ?? '0';
                updatedCompanyTasks[company]![taskIndex]['night_hours'] = nightHours;
                debugPrint('Chargé des heures de nuit pour ${task['name']}: $nightHours');
              }
            }
          }
        }
        state = state.copyWith(
          companyTasks: updatedCompanyTasks,
          taskHours: updatedTaskHours,
          kilometrageData: kilometrageData, // Add the kilometrage data to the state
        );
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données de correction: $e');
      rethrow;
    }
  }
  
  // Définir l'état de chargement
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }
  void setEmptyState(bool value) {
    state = state.copyWith(showEmptyState: value);
  }
}
final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) => TaskNotifier());