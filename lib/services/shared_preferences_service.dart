import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SharedPrefsService {
  // Méthode pour réinitialiser la date de dernière saisie (pour débogage)
  static Future<void> resetLastEntryDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastEntryDate');
    debugPrint('SharedPrefsService - lastEntryDate réinitialisé');
  }
  
  static Future<UserSession> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Récupération de lastEntryDate et de la date du jour
    final lastEntryDate = prefs.getString('lastEntryDate') ?? '';
    final today = DateTime.now().toString().split(' ')[0];
    
    // Vérification plus stricte pour déterminer si des heures ont été saisies aujourd'hui
    final bool hasEnteredHours = lastEntryDate.isNotEmpty && lastEntryDate == today;
    
    // Débogage
    debugPrint('SharedPrefsService - lastEntryDate: "$lastEntryDate", today: "$today", hasEnteredHours: $hasEnteredHours');
    
    // Initialisation des autres valeurs
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final firstName = prefs.getString('firstName') ?? '';
    final lastName = prefs.getString('lastName') ?? '';
    final selectedCompany = prefs.getString('selectedCompany') ?? '';
    
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
