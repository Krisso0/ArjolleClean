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
  Future<String> saveData(String company, String firstName, String lastName, {required Map<String, String> taskHours, bool isEditing = false}) async {
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
        if (task['selected'] == true && task['hours'].isNotEmpty) {
          final double hours = double.tryParse(task['hours']) ?? 0.0;
          totalHours += hours;
          
          // Formatage pour le nouveau modèle (tasks)
          selectedTasks.add({
            'name': task['name'],
            'hours': hours,
            'section': company,
            'company': company
          });
          
          // Formatage pour l'ancien modèle (taskHours)
          final taskKey = "$company - ${task['name']}";
          taskHoursMap[taskKey] = hours;
          
          debugPrint('  - ${task['name']}: $hours heures');
        }
      }
      
      if (selectedTasks.isEmpty) {
        throw Exception('Veuillez sélectionner au moins une tâche avec des heures');
      }
      
      // Créer la nouvelle entrée de temps
      final timeEntry = model.TimeEntryModel(
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
      
      // D'abord, sauvegarder localement
      await _timeEntryService.saveTimeEntry(timeEntry);
      
      // Ensuite, synchroniser avec le serveur (toujours comme une nouvelle entrée)
      // Correction :
      // Si on est en mode correction (modification d'heures déjà saisies), il faut mettre à jour l'entrée existante
      // Sinon, on crée une nouvelle entrée (qui remplacera automatiquement l'ancienne côté API si elle existe pour la même date)
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
      if (entry?.tasks != null) {
        final updatedCompanyTasks = Map<String, List<Map<String, dynamic>>>.from(state.companyTasks);
        final updatedTaskHours = Map<String, Map<String, String>>.from(state.taskHours);
        for (var task in entry!.tasks) {
          final company = task['section'] as String;
          if (updatedCompanyTasks.containsKey(company)) {
            final taskIndex = updatedCompanyTasks[company]!.indexWhere((t) => t['name'] == task['name']);
            if (taskIndex != -1) {
              updatedCompanyTasks[company]![taskIndex]['selected'] = true;
              updatedCompanyTasks[company]![taskIndex]['hours'] = task['hours']?.toString() ?? '0';
              updatedTaskHours[company]![task['name']] = task['hours']?.toString() ?? '0';
            }
          }
        }
        state = state.copyWith(
          companyTasks: updatedCompanyTasks,
          taskHours: updatedTaskHours,
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