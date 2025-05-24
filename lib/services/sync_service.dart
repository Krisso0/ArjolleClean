import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/time_entry_model.dart';
import 'time_entry_service.dart';
import 'api_service.dart';

class SyncService {
  final TimeEntryService _repository = TimeEntryService();
  final ApiService _apiService = ApiService();
  
  // Synchroniser toutes les entrées non synchronisées
  Future<int> syncUnsyncedEntries() async {
    final unsyncedEntries = await _repository.getUnsyncedEntries();
    for (final entry in unsyncedEntries) {
      await _apiService.upsertTimeEntry(entry);
    }
    return 0;
  }
  
  // Enregistrer une nouvelle entrée ou mettre à jour une entrée existante et tenter de la synchroniser immédiatement
  Future<void> saveAndSync(TimeEntryModel entry, {bool isUpdating = false, bool forceDeleteExisting = false}) async {
    // Sauvegarder localement d'abord
    await _repository.saveTimeEntry(entry);
    
    // Si c'est une mise à jour ou s'il y a un changement d'entreprise, supprimer l'ancienne entrée d'abord
    if (isUpdating || forceDeleteExisting) {
      // Suppression via API désactivée (plus de deleteTimeEntry côté client)
    }
    await _apiService.upsertTimeEntry(entry);
  }
  
  // Vérifier si l'appareil est connecté à Internet
  Future<bool> isConnected() async {
    try {
      // Vérifier la connectivité avec connectivity_plus
      final connectivityResult = await Connectivity().checkConnectivity();
      
      // Si nous avons une connexion, vérifier si nous pouvons réellement atteindre le serveur
      if (connectivityResult != ConnectivityResult.none) {
        // Tester la connexion au serveur
        final response = await _apiService.testConnection();
        return response;
      }
      
      return false;
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la connexion: $e');
      return false;
    }
  }
  
  // Synchroniser et retourner le statut de synchronisation
  Future<Map<String, dynamic>> syncStatus() async {
    final isOnline = await isConnected();
    final unsyncedCount = (await _repository.getUnsyncedEntries()).length;
    
    int syncedCount = 0;
    if (isOnline && unsyncedCount > 0) {
      syncedCount = await syncUnsyncedEntries();
    }
    
    return {
      'isOnline': isOnline,
      'unsyncedCount': unsyncedCount - syncedCount,
      'syncedCount': syncedCount,
      'lastSyncAttempt': DateTime.now().toIso8601String(),
    };
  }
}
