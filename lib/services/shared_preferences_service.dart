import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SharedPrefsService {
  // Méthode pour réinitialiser la date de dernière saisie (pour débogage)
  static Future<void> resetLastEntryDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastEntryDate');
    debugPrint('SharedPrefsService - lastEntryDate réinitialisé');
  }
  
  // Méthode centralisée pour vérifier si un utilisateur a déjà saisi ses heures aujourd'hui
  static Future<bool> hasUserEnteredHoursToday(String firstName, String lastName, [String? company]) async {
    // Vérifier que l'utilisateur est valide
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      debugPrint('SharedPrefsService.hasUserEnteredHoursToday - ATTENTION: utilisateur invalide (nom ou prénom vide)');
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    // Obtenir la date d'aujourd'hui au format YYYY-MM-DD
    final today = DateTime.now().toString().split(' ')[0];
    
    // Récupérer la dernière date d'entrée
    final lastEntryDate = prefs.getString('lastEntryDate') ?? '';
    
    // Récupérer les informations sur le dernier utilisateur qui a saisi des heures
    final lastEntryFirstName = prefs.getString('lastEntryFirstName') ?? '';
    final lastEntryLastName = prefs.getString('lastEntryLastName') ?? '';
    
    // Récupérer l'entreprise concernée (si spécifiée)
    final lastCompany = prefs.getString('selectedCompany') ?? '';
    
    // Vérification de la date (doit être aujourd'hui)
    final bool dateIsToday = lastEntryDate.isNotEmpty && lastEntryDate == today;
    
    // Vérification de l'utilisateur (doit être le même)
    final bool userMatches = lastEntryFirstName.isNotEmpty && 
                             lastEntryLastName.isNotEmpty && 
                             lastEntryFirstName == firstName && 
                             lastEntryLastName == lastName;
    
    // Vérification de l'entreprise (si spécifiée)
    bool companyMatches = true;
    if (company != null && company.isNotEmpty) {
      companyMatches = lastCompany == company;
    }
    
    // Résultat final: toutes les conditions doivent être vraies
    bool hasEnteredHours = dateIsToday && userMatches && companyMatches;
    
    // Logs détaillés pour débogage
    debugPrint('SharedPrefsService.hasUserEnteredHoursToday - Détails:');
    debugPrint('  - Date vérifiée: $lastEntryDate (aujourd’hui: $today) => match date: $dateIsToday');
    debugPrint('  - Utilisateur vérifié: $lastEntryFirstName $lastEntryLastName (demandé: $firstName $lastName) => match utilisateur: $userMatches');
    if (company != null) {
      debugPrint('  - Entreprise vérifiée: $lastCompany (demandée: $company) => match entreprise: $companyMatches');
    }
    
    // Débogage
    debugPrint('SharedPrefsService.hasUserEnteredHoursToday - User: $firstName $lastName, Company: ${company ?? "any"}, Result: $hasEnteredHours');
    
    return hasEnteredHours;
  }
  
  static Future<UserSession> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Initialisation des valeurs
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final firstName = prefs.getString('firstName') ?? '';
    final lastName = prefs.getString('lastName') ?? '';
    final selectedCompany = prefs.getString('selectedCompany') ?? '';
    
    // Utiliser la méthode centralisée pour vérifier les entrées
    final hasEnteredHours = await hasUserEnteredHoursToday(firstName, lastName);
    
    // Débogage
    debugPrint('SharedPrefsService - isLoggedIn: $isLoggedIn, firstName: $firstName, lastName: $lastName, selectedCompany: $selectedCompany');
    
    return UserSession(
      isLoggedIn: isLoggedIn,
      firstName: firstName,
      lastName: lastName,
      selectedCompany: selectedCompany,
      hasEnteredHoursToday: hasEnteredHours,
    );
  }
}

class UserSession {
  final bool isLoggedIn;
  final String firstName;
  final String lastName;
  final String selectedCompany;
  final bool hasEnteredHoursToday;

  UserSession({
    required this.isLoggedIn,
    required this.firstName,
    required this.lastName,
    required this.selectedCompany,
    required this.hasEnteredHoursToday,
  });
}
