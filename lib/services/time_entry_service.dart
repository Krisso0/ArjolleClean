import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/time_entry_model.dart';
import 'api_service.dart';

class TimeEntryService {
  static const String _storageKey = 'time_entries';

  // Sauvegarder une nouvelle entrée de temps (ou remplacer une existante pour le même jour)
  Future<void> saveTimeEntry(TimeEntryModel entry, {String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_storageKey) ?? [];
    final entries = entriesJson
        .map((json) => TimeEntryModel.fromJson(jsonDecode(json)))
        .toList();

    // Un seul appel API, le backend gère l'upsert
    final api = ApiService();
    final apiSuccess = await api.upsertTimeEntry(entry, baseUrl: baseUrl);

    // Mise à jour du stockage local seulement si succès API
    if (apiSuccess) {
      final existingIndex = entries.indexWhere((e) =>
          e.employeeId == entry.employeeId &&
          e.date == entry.date);
      if (existingIndex != -1) {
        entries[existingIndex] = entry;
      } else {
        entries.add(entry);
      }
      final updatedEntriesJson = entries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_storageKey, updatedEntriesJson);
    } else {
      debugPrint('Échec de la sauvegarde côté API, stockage local non mis à jour.');
    }
  }

  // Supprimer toutes les entrées d'un employé pour une date donnée
  Future<bool> deleteTimeEntriesByIdAndDate(String employeeId, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_storageKey) ?? [];
    
    // Lire les entrées existantes
    final entries = entriesJson
        .map((json) => TimeEntryModel.fromJson(jsonDecode(json)))
        .toList();
    
    // Filtrer pour ne garder que les entrées qui ne correspondent pas aux critères
    final initialCount = entries.length;
    entries.removeWhere((e) => e.employeeId == employeeId && e.date == date);
    
    // Si des entrées ont été supprimées
    if (entries.length < initialCount) {
      debugPrint('${initialCount - entries.length} entrée(s) supprimée(s) pour $employeeId le $date');
      
      // Mettre à jour le stockage local
      final updatedEntriesJson = entries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_storageKey, updatedEntriesJson);
      return true;
    }
    
    debugPrint('Aucune entrée trouvée à supprimer pour $employeeId le $date');
    return false;
  }
  
  // Récupérer toutes les entrées de temps
  Future<List<TimeEntryModel>> getAllTimeEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_storageKey) ?? [];
    
    return entriesJson
        .map((json) => TimeEntryModel.fromJson(jsonDecode(json)))
        .toList();
  }

  // Récupérer les entrées non synchronisées
  Future<List<TimeEntryModel>> getUnsyncedEntries() async {
    final entries = await getAllTimeEntries();
    return entries.where((entry) => !entry.isSynced).toList();
  }

  // Marquer une entrée comme synchronisée
  Future<void> markAsSynced(TimeEntryModel entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_storageKey) ?? [];
    
    final entries = entriesJson
        .map((json) => TimeEntryModel.fromJson(jsonDecode(json)))
        .toList();
    
    // Trouver l'index de l'entrée correspondante
    final index = entries.indexWhere((e) => 
        e.employeeId == entry.employeeId && 
        e.date == entry.date);
    
    if (index != -1) {
      // Mettre à jour l'entrée
      entries[index] = TimeEntryModel(
        employeeId: entry.employeeId,
        firstName: entry.firstName,
        lastName: entry.lastName,
        date: entry.date,
        hoursWorked: entry.hoursWorked,
        taskHours: entry.taskHours,
        isSynced: true,
      );
      
      // Mettre à jour le stockage
      final updatedEntriesJson = entries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_storageKey, updatedEntriesJson);
    }
  }

  // Récupérer une entrée par ID d'employé et date
  Future<TimeEntryModel?> getTimeEntryByIdAndDate(String employeeId, String date) async {
    final entries = await getAllTimeEntries();
    try {
      return entries.firstWhere(
        (entry) => entry.employeeId == employeeId && entry.date == date,
      );
    } catch (e) {
      return null;
    }
  }

  // Supprimer une entrée de temps
  Future<void> deleteTimeEntry(TimeEntryModel entry) async {
    // Ancienne méthode conservée pour compatibilité
  }

  // Supprimer une entrée locale par employeeId et date
  Future<void> deleteTimeEntryByIdAndDate(String employeeId, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_storageKey) ?? [];
    final entries = entriesJson
        .map((json) => TimeEntryModel.fromJson(jsonDecode(json)))
        .toList();
    entries.removeWhere((e) => e.employeeId == employeeId && e.date == date);
    final updatedEntriesJson = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, updatedEntriesJson);
  }
}

