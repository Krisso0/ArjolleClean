import 'package:flutter/material.dart';

import 'package:timezone/timezone.dart' as tzlib;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/shared_preferences_service.dart';
import 'routes/startup_router.dart';

Future<void> main() async {
  // Assure que les bindings Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise les timezones
  tz.initializeTimeZones();
  tzlib.setLocalLocation(tzlib.getLocation('Europe/Paris'));
  
  // Initialise les formats de date
  await initializeDateFormatting('fr_FR', null);
  
  // Vérifie l'état de connexion et si des heures ont déjà été saisies aujourd'hui
  // Utilisation du service d'extraction des préférences
  UserSession session;
  try {
    session = await SharedPrefsService.loadUserSession();
    
    // DEBUG: Affichage des paramètres de session pour le débogage
    debugPrint('Session chargée : isLoggedIn=${session.isLoggedIn}, firstName=${session.firstName}, lastName=${session.lastName}, selectedCompany=${session.selectedCompany}, hasEnteredHoursToday=${session.hasEnteredHoursToday}');
    
    // DEBUG: Vérifier directement les valeurs dans SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final lastEntryDate = prefs.getString('lastEntryDate') ?? '';
      final company = prefs.getString('selectedCompany') ?? '';
      debugPrint('Vérification directe SharedPreferences - lastEntryDate: $lastEntryDate, selectedCompany: $company');
    });
    
    // IMPORTANT: Pour un nouvel utilisateur, s'assurer que selectedCompany est vide
    // Si le champ firstName est vide, c'est un nouvel utilisateur
    if (session.isLoggedIn && session.firstName.isNotEmpty && session.selectedCompany.isEmpty) {
      debugPrint('Nouvel utilisateur connecté sans entreprise sélectionnée - Réinitialisation de selectedCompany');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedCompany', '');
      
      // Recharger la session après modification
      session = await SharedPrefsService.loadUserSession();
    }
    
  } catch (e) {
    debugPrint('Erreur lors de la récupération des préférences: $e');
    session = UserSession(
      isLoggedIn: false,
      firstName: '',
      lastName: '',
      selectedCompany: '',
      hasEnteredHoursToday: false,
    );
  }
  
  // getHomeScreen est maintenant asynchrone, nous devons donc l'attendre
  final Widget homeScreen = await getHomeScreen(session);
  debugPrint('Écran d\'accueil sélectionné: ${homeScreen.runtimeType}');
  
  // Lance l'application
  runApp(ProviderScope(
    child: MaterialApp(
      title: 'Arjolle Présence',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: homeScreen,
    ),
  ));
}
