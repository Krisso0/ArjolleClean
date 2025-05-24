import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sas_task_screen.dart';
import 'scea_task_screen.dart';
import 'cuma_task_screen.dart';
import 'name_input_screen.dart';

class CompanySelectionScreen extends StatelessWidget {
  final String firstName;
  final String lastName;
  final bool isCorrection;
  final bool showSuccessIfHoursEntered;

  const CompanySelectionScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.isCorrection,
    this.showSuccessIfHoursEntered = false,
  });

  @override
  Widget build(BuildContext context) {
    // Si l'utilisateur a déjà saisi des heures aujourd'hui et que showSuccessIfHoursEntered est true,
    // on le redirige directement vers l'écran de tâches de l'entreprise correspondante
    // qui vérifiera à son tour s'il faut rediriger vers l'écran de succès
    if (showSuccessIfHoursEntered) {
      // Utilisez Future.microtask pour éviter de modifier l'arbre de widgets pendant le build
      Future.microtask(() async {
        final prefs = await SharedPreferences.getInstance();
        final selectedCompany = prefs.getString('selectedCompany') ?? '';
        
        // DEBUG: Afficher la compagnie récupérée des préférences
        debugPrint('CompanySelectionScreen - Compagnie sélectionnée: $selectedCompany');
        
        if (!context.mounted) return;
        
        Widget screen;
        switch (selectedCompany) {
          case 'SAS':
            debugPrint('Redirection vers SasTaskScreen');
            screen = SasTaskScreen(
              firstName: firstName,
              lastName: lastName,
              isCorrection: false,
            );
            break;
          case 'SCEA':
            debugPrint('Redirection vers SceaTaskScreen');
            screen = SceaTaskScreen(
              firstName: firstName,
              lastName: lastName,
              isCorrection: false,
            );
            break;
          case 'CUMA':
            debugPrint('Redirection vers CumaTaskScreen');
            screen = CumaTaskScreen(
              firstName: firstName,
              lastName: lastName,
              isCorrection: false,
            );
            break;
          default:
            // Si aucune entreprise n'est sélectionnée, ne rien faire
            debugPrint('Aucune redirection - Compagnie non reconnue: $selectedCompany');
            return;
        }
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => screen),
        );
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélection de l\'entreprise'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bonjour, $firstName $lastName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Veuillez sélectionner l\'entreprise pour laquelle vous souhaitez saisir vos heures :',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildCompanyButton(
                context,
                'SAS',
                Theme.of(context).colorScheme.primary,
                () => _navigateToTaskScreen(context, 'SAS'),
              ),
              const SizedBox(height: 20),
              _buildCompanyButton(
                context,
                'SCEA',
                Theme.of(context).colorScheme.primary,
                () => _navigateToTaskScreen(context, 'SCEA'),
              ),
              const SizedBox(height: 20),
              _buildCompanyButton(
                context,
                'CUMA',
                Theme.of(context).colorScheme.primary,
                () => _navigateToTaskScreen(context, 'CUMA'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyButton(
      BuildContext context, String companyName, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        companyName,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void _navigateToTaskScreen(BuildContext context, String company) async {
    // Sauvegarder la compagnie sélectionnée dans SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCompany', company);
    
    if (!context.mounted) return;
    
    Widget screen;
    
    switch (company) {
      case 'SAS':
        screen = SasTaskScreen(
          firstName: firstName,
          lastName: lastName,
          isCorrection: isCorrection,
        );
        break;
      case 'SCEA':
        screen = SceaTaskScreen(
          firstName: firstName,
          lastName: lastName,
          isCorrection: isCorrection,
        );
        break;
      case 'CUMA':
        screen = CumaTaskScreen(
          firstName: firstName,
          lastName: lastName,
          isCorrection: isCorrection,
        );
        break;
      default:
        throw Exception('Entreprise non reconnue');
    }

    // Utiliser push pour permettre le retour arrière standard
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
