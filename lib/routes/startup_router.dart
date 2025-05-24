import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_preferences_service.dart';
import '../views/name_input_screen.dart';
import '../views/company_selection_screen.dart';
import '../views/success_screen.dart';

// Vérifie si l'utilisateur actuel correspond à celui qui a déjà saisi des heures
Future<bool> userMatchesLastEntryUser(String firstName, String lastName) async {
  final prefs = await SharedPreferences.getInstance();
  final lastEntryFirstName = prefs.getString('lastEntryFirstName') ?? '';
  final lastEntryLastName = prefs.getString('lastEntryLastName') ?? '';
  
  final bool matches = firstName.isNotEmpty && 
                      lastName.isNotEmpty && 
                      firstName == lastEntryFirstName && 
                      lastName == lastEntryLastName;
  
  debugPrint('startup_router - Vérification utilisateur: $firstName $lastName vs dernier utilisateur: $lastEntryFirstName $lastEntryLastName - Match: $matches');
  
  return matches;
}

Future<Widget> getHomeScreen(UserSession session) async {
  debugPrint('startup_router - getHomeScreen - session: $session');
  
  // Si l'utilisateur n'est pas connecté, afficher l'écran de saisie du nom
  if (!session.isLoggedIn) return const NameInputScreen();

  // Vérifier si l'utilisateur actuel correspond à celui qui a saisi des heures
  final bool userMatches = await userMatchesLastEntryUser(session.firstName, session.lastName);
  
  if (userMatches) {
    // L'utilisateur actuel est le même que celui qui a saisi des heures, rediriger vers l'écran de succès
    final prefs = await SharedPreferences.getInstance();
    final selectedCompany = prefs.getString('selectedCompany') ?? '';
    
    debugPrint('startup_router - Redirection vers Success Screen car même utilisateur');
    return SuccessScreen(
      firstName: session.firstName,
      lastName: session.lastName,
      taskHours: {},
      filePath: '',
      companyName: selectedCompany,
    );
  }

  // Si c'est un nouvel utilisateur, le rediriger vers l'écran de sélection d'entreprise
  debugPrint('startup_router - Redirection vers Company Selection Screen pour nouvel utilisateur');
  return CompanySelectionScreen(
    firstName: session.firstName,
    lastName: session.lastName,
    isCorrection: false,
    showSuccessIfHoursEntered: false,
  );
}
