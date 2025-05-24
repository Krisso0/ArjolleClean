import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'views/name_input_screen.dart';
import 'views/company_selection_screen.dart';
import 'views/sas_task_screen.dart';
import 'views/scea_task_screen.dart';
import 'views/cuma_task_screen.dart';

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final String firstName;
  final String lastName;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<MyApp> createState() => _MyAppState();

}

class _MyAppState extends State<MyApp> {
  bool hasEnteredHoursToday = false;
  String selectedCompany = '';

  @override
  void initState() {
    super.initState();
    _checkIfHoursEnteredToday();
  }

  Future<void> _checkIfHoursEnteredToday() async {
    if (!widget.isLoggedIn) return;

    final prefs = await SharedPreferences.getInstance();
    final lastEntryDate = prefs.getString('lastEntryDate') ?? '';
    final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD format
    
    setState(() {
      // Vérification plus stricte: lastEntryDate doit être non vide ET égal à aujourd'hui
      hasEnteredHoursToday = lastEntryDate.isNotEmpty && lastEntryDate == today;
      selectedCompany = prefs.getString('selectedCompany') ?? '';
    });
    
    // Débogage
    debugPrint('_MyAppState - lastEntryDate: "$lastEntryDate", today: "$today", hasEnteredHoursToday: $hasEnteredHoursToday');
  }

  Widget _getHomeScreen() {
    if (!widget.isLoggedIn) {
      return const NameInputScreen();
    }

    if (hasEnteredHoursToday) {
      // Rediriger vers l'écran des heures déjà rentrées en fonction de la compagnie
      switch (selectedCompany) {
        case 'SAS':
          return SasTaskScreen(
            firstName: widget.firstName,
            lastName: widget.lastName,
            isCorrection: false,
          );
        case 'SCEA':
          return SceaTaskScreen(
            firstName: widget.firstName,
            lastName: widget.lastName,
            isCorrection: false,
          );
        case 'CUMA':
          return CumaTaskScreen(
            firstName: widget.firstName,
            lastName: widget.lastName,
            isCorrection: false,
          );
        default:
          // Si la compagnie n'est pas définie, rediriger vers l'écran de sélection
          return CompanySelectionScreen(
            firstName: widget.firstName,
            lastName: widget.lastName,
            isCorrection: false,
          );
      }
    } else {
      // Si l'utilisateur n'a pas encore saisi ses heures aujourd'hui
      return CompanySelectionScreen(
        firstName: widget.firstName,
        lastName: widget.lastName,
        isCorrection: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arjolle Présence',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.red,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: _getHomeScreen(),
    );
  }
}
