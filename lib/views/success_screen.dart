import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'name_input_screen.dart';
import 'company_selection_screen.dart';
import 'debug_screen.dart';

class SuccessScreen extends StatelessWidget {
  // Compteur pour la fonction de débogage
  static int _debugTapCount = 0;
  final String firstName;
  final String lastName;
  final Map<String, Map<String, String>> taskHours;
  final String filePath;
  final String companyName; // Ajout du paramètre pour l'entreprise

  const SuccessScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.taskHours,
    required this.filePath,
    this.companyName = '', // Valeur par défaut
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Succès'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          // No leading/back button, only logout in actions
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const NameInputScreen()),
                );
              },
              tooltip: 'Déconnexion',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône avec geste caché pour accéder à l'écran de débogage
                  GestureDetector(
                    onTap: () {
                      // Utiliser une variable statique en dehors de la méthode
                      _debugTapCount++;
                      
                      // Si l'utilisateur appuie 5 fois sur l'icône, accéder à l'écran de débogage
                      if (_debugTapCount >= 5) {
                        _debugTapCount = 0;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const DebugScreen()),
                        );
                      }
                    },
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Enregistrement réussi !',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: const Text(
                      'Vos heures ont bien été enregistrées.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Passer en mode correction
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => CompanySelectionScreen(
                            firstName: firstName,
                            lastName: lastName,
                            isCorrection: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier mes heures'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
