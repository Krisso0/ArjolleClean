import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_preferences_service.dart';
import '../views/name_input_screen.dart';
import '../views/company_selection_screen.dart';
import '../views/success_screen.dart';

// Vérifie si l'utilisateur a déjà saisi ses heures aujourd'hui (utilise la méthode centralisée)
Future<bool> hasUserEnteredHoursToday(String firstName, String lastName, [String? company]) {
  // Utiliser la méthode centralisée pour une logique cohérente dans toute l'application
  return SharedPrefsService.hasUserEnteredHoursToday(firstName, lastName, company);
}

Future<Widget> getHomeScreen(UserSession session) async {
  debugPrint('startup_router - getHomeScreen - session: $session');
  
  // Si l'utilisateur n'est pas connecté, afficher l'écran de saisie du nom
  if (!session.isLoggedIn) return const NameInputScreen();

  // Vérifier si l'utilisateur a déjà saisi ses heures aujourd'hui
  // Utilise la méthode centralisée qui vérifie à la fois l'utilisateur et la date
  final bool hasEnteredToday = await hasUserEnteredHoursToday(session.firstName, session.lastName);
  
  if (hasEnteredToday) {
    // L'utilisateur a déjà saisi des heures aujourd'hui, rediriger vers l'écran de succès
    final prefs = await SharedPreferences.getInstance();
    final selectedCompany = prefs.getString('selectedCompany') ?? '';
    
    debugPrint('startup_router - Redirection vers Success Screen car l\'utilisateur a déjà saisi ses heures aujourd\'hui');
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
