import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/task_provider.dart';
import 'success_screen.dart';
import 'name_input_screen.dart';
import 'company_selection_screen.dart';

class SasTaskScreen extends ConsumerStatefulWidget {
  final String firstName;
  final String lastName;
  final bool isCorrection;
  // Paramètre supprimé: showAlreadyEnteredMessage

  const SasTaskScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.isCorrection,
    // Parameter showAlreadyEnteredMessage removed
  });

  @override
  ConsumerState<SasTaskScreen> createState() => _SasTaskScreenState();
}

// --- Helper pour la gestion du retour ---
class BackButtonHandler {
  static void handleBackPress(BuildContext context, {
    required bool hasChanges,
    required VoidCallback onSave,
    required VoidCallback onReset,
  }) async {
    if (!hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarder les modifications ?'),
        content: const Text('Voulez-vous conserver les données saisies ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      onSave();
    } else if (shouldSave == false) {
      onReset();
    }
    Navigator.of(context).pop();
  }
}

class _SasTaskScreenState extends ConsumerState<SasTaskScreen> with TickerProviderStateMixin {
  // --- Tracking des changements ---
  bool _hasChanges = false;

  // --- Ajout des valeurs initiales pour comparaison ---
  late List<Map<String, dynamic>> _initialTasks;
  late List<Map<String, String>> _initialKilometrageEntries;

  // --- Ajout des listeners pour détection automatique ---
  void _setupChangeTracking() {
    // Prendre un snapshot initial des tâches et kilométrage
    final taskNotifier = ref.read(taskProvider.notifier);
    _initialTasks = List<Map<String, dynamic>>.from(
      taskNotifier.getCompanyTasks('SAS').map((t) => Map<String, dynamic>.from(t)),
    );
    _initialKilometrageEntries = List<Map<String, String>>.from(
      _kilometrageEntries.map((e) => Map<String, String>.from(e)),
    );
  }

  void _detectChanges() {
    final taskNotifier = ref.read(taskProvider.notifier);
    final currentTasks = taskNotifier.getCompanyTasks('SAS');
    bool changed = false;
    for (int i = 0; i < currentTasks.length; i++) {
      final t = currentTasks[i];
      final tInit = i < _initialTasks.length ? _initialTasks[i] : null;
      if (tInit == null ||
          t['selected'] != tInit['selected'] ||
          t['hours'] != tInit['hours'] ||
          (t.containsKey('night_hours') && t['night_hours'] != tInit['night_hours'])) {
        changed = true;
        break;
      }
    }
    for (int i = 0; i < _kilometrageEntries.length; i++) {
      final e = _kilometrageEntries[i];
      final eInit = i < _initialKilometrageEntries.length ? _initialKilometrageEntries[i] : null;
      if (eInit == null || e['kilometres'] != eInit['kilometres'] || e['motif'] != eInit['motif']) {
        changed = true;
        break;
      }
    }
    if (_hasChanges != changed) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  // --- À appeler après chaque modification d'un champ ---
  void _onAnyFieldChanged() {
    _detectChanges();
  }

  // --- Sauvegarde toutes les données sans navigation ---
  void _saveAllData() async {
    final taskNotifier = ref.read(taskProvider.notifier);
    
    // Vérifier si au moins une tâche est sélectionnée
    bool hasSelectedTask = false;
    for (var task in taskNotifier.getCompanyTasks('SAS')) {
      if (task['selected'] == true) {
        hasSelectedTask = true;
        break;
      }
    }
    
    if (!hasSelectedTask) {
      // Ne pas afficher d'erreur ici, simplement revenir
      return;
    }
    
    try {
      // Sauvegarde directe sans demander confirmation
      taskNotifier.setLoading(true);
      await taskNotifier.saveData(
        'SAS',
        widget.firstName,
        widget.lastName,
        taskHours: ref.watch(taskProvider).taskHours['SAS'] ?? {},
      );
      
      // Enregistrer dans les préférences
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];
      await prefs.setString('selectedCompany', 'SAS');
      await prefs.setString('lastEntryDate', today);
      await prefs.setString('lastEntryFirstName', widget.firstName);
      await prefs.setString('lastEntryLastName', widget.lastName);
      
      // Important: ne pas rediriger vers l'écran de succès
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Erreur lors de l\'enregistrement: $e');
      }
    } finally {
      if (mounted) {
        taskNotifier.setLoading(false);
        // Uniquement appeler cette méthode si le widget est toujours monté
        _setupChangeTracking(); // reset snapshot après save
      }
    }
  }

  // --- Réinitialise tous les champs (checkboxes, textfields, kilométrage) ---
  void _resetAllFields() {
    final taskNotifier = ref.read(taskProvider.notifier);
    for (var task in taskNotifier.getCompanyTasks('SAS')) {
      task['selected'] = false;
      task['hours'] = '';
      if (task.containsKey('night_hours')) {
        task['night_hours'] = '';
      }
    }
    for (var entry in _kilometrageEntries) {
      entry['kilometres'] = '';
      entry['motif'] = '';
    }
    setState(() {});
    _setupChangeTracking();
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? _inactiveTimer;
  DateTime? _lastInteractionTime;
  static const _inactiveDuration = Duration(minutes: 15);
  // Variable supprimée: _forceShowAlreadyEnteredMessage

  // Groupement des tâches par catégorie pour une meilleure organisation
  final Map<String, List<Map<String, dynamic>>> _sasTaskCategories = {
    'Kilométrage': [
      // Dynamic entries will be managed in state, initialized empty
    ],
    'Cave': [
      {'name': 'Mise en bouteille', 'selected': false, 'hours': ''},
      {'name': 'Expédition', 'selected': false, 'hours': ''},
      {'name': 'Récéption', 'selected': false, 'hours': ''},
    ],
    'Commerce': [
      {'name': 'Vente caveau', 'selected': false, 'hours': ''},
      {'name': 'Déplacement dégustation', 'selected': false, 'hours': ''},
      {'name': 'Communication', 'selected': false, 'hours': ''},
      {'name': 'Administration ventes', 'selected': false, 'hours': ''},
    ],
    'Administratif & Divers': [
      {'name': 'Formation', 'selected': false, 'hours': ''},
      {'name': 'Congés payés', 'selected': false, 'hours': ''},
      {'name': 'Arrêt maladie', 'selected': false, 'hours': ''},
      {'name': 'RTT', 'selected': false, 'hours': ''},
      {'name': 'Congés Ev familiaux', 'selected': false, 'hours': ''},
    ],
  };

  // Pour l'interface avec tabs
  int _selectedCategoryIndex = 0;
  late List<String> _categoryNames;
  late List<List<Map<String, dynamic>>> _categoryTasks;

  // For dynamic kilométrage entries
  final List<Map<String, String>> _kilometrageEntries = [
    {'kilometres': '', 'motif': ''},
  ];
  late TabController _tabController;

  @override
  void initState() {
    // If "Kilométrage" category exists, initialize with one entry
    if (_sasTaskCategories.containsKey('Kilométrage')) {
      _sasTaskCategories['Kilométrage'] = [];
    }

    super.initState();
    
    // Préparer les données pour l'interface
    _categoryNames = _sasTaskCategories.keys.toList();
    // Déplace 'Kilométrage' à la fin si présent
    if (_categoryNames.contains('Kilométrage')) {
      _categoryNames.remove('Kilométrage');
      _categoryNames.add('Kilométrage');
    }
    _categoryTasks = _categoryNames.map((k) => _sasTaskCategories[k] ?? []).toList();
    
    // Initialiser le TabController
    _tabController = TabController(
      length: _categoryNames.length,
      vsync: this,
      initialIndex: _selectedCategoryIndex,
    );
    
    _initNotifications();
    _startInactivityTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
      _setupChangeTracking();
    });
  }

  Future<void> _initData() async {
    final taskNotifier = ref.read(taskProvider.notifier);
    taskNotifier.setLoading(true);
    try {
      // Aplatir les tâches pour l'initialisation
      final flatTasks = <Map<String, dynamic>>[];
      for (var categoryTasks in _categoryTasks) {
        flatTasks.addAll(categoryTasks);
      }
      
      taskNotifier.initCompanyTasks('SAS', flatTasks);

      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final employeeId = '${widget.firstName} ${widget.lastName}';

      if (widget.isCorrection) {
        // En mode correction, on charge simplement les données existantes
        await taskNotifier.loadCorrectionData(employeeId, formattedDate);
      } else {
        // Vérifier si l'utilisateur a déjà saisi ses heures aujourd'hui
        final hasEntry = await taskNotifier.checkTodaysEntry(employeeId);
        
        if (hasEntry) {
          // Charger les données déjà saisies
          await taskNotifier.loadCorrectionData(employeeId, formattedDate);
          
          // Rediriger vers l'écran de succès
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/timesheet_${today.millisecondsSinceEpoch}.json';
          
          if (!mounted) return;
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuccessScreen(
                firstName: widget.firstName,
                lastName: widget.lastName,
                taskHours: ref.read(taskProvider).taskHours,
                filePath: filePath,
                companyName: 'SAS',
              ),
            ),
          );
          return;
        }
      }
      
      if (!mounted) return;
      taskNotifier.setEmptyState(false);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Erreur lors de l\'initialisation: $e');
      }
    } finally {
      if (mounted) {
        taskNotifier.setLoading(false);
      }
    }
  }

  @override
  void dispose() {
    _inactiveTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startInactivityTimer() {
    _lastInteractionTime = DateTime.now();
    _inactiveTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_lastInteractionTime != null &&
          DateTime.now().difference(_lastInteractionTime!) > _inactiveDuration) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        // Réinitialiser l'état de l'application
        final taskNotifier = ref.read(taskProvider.notifier);
        taskNotifier.setLoading(false);
        taskNotifier.setEmptyState(false);
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        if (isLoggedIn) {
          final firstName = prefs.getString('firstName') ?? '';
          final lastName = prefs.getString('lastName') ?? '';
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CompanySelectionScreen(
                firstName: firstName,
                lastName: lastName,
                isCorrection: false,
              ),
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const NameInputScreen(),
            ),
          );
        }
        timer.cancel();
      }
    });
  }

  void _resetInactivityTimer() {
    _lastInteractionTime = DateTime.now();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
  }

  Future<void> _saveData() async {
    final taskNotifier = ref.read(taskProvider.notifier);
    
    // Vérifier si au moins une tâche est sélectionnée
    bool hasSelectedTask = false;
    for (var task in taskNotifier.getCompanyTasks('SAS')) {
      if (task['selected'] == true) {
        hasSelectedTask = true;
        break;
      }
    }
    
    if (!hasSelectedTask) {
      _showErrorDialog('Veuillez sélectionner au moins une tâche');
      return;
    }
    
    // Construire le récapitulatif par catégorie
    final List<Widget> summaryItems = [];
    double totalDayHours = 0.0;
    double totalNightHours = 0.0;
    
    summaryItems.add(
      const Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: Text(
          'SAS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
    // Ajout spécial pour Kilométrage
    final kilometrages = _kilometrageEntries.where((e) => e['kilometres'] != null && e['kilometres']!.trim().isNotEmpty).toList();
    if (kilometrages.isNotEmpty) {
      summaryItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Kilométrage',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.blue),
          ),
        ),
      );
      for (var entry in kilometrages) {
        summaryItems.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Déplacement'),
                Text('${entry['kilometres']} km', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      }
      summaryItems.add(const SizedBox(height: 8));
    }
    for (int i = 0; i < _categoryNames.length; i++) {
      final categoryName = _categoryNames[i];
      if (categoryName == 'Kilométrage') continue;
      final categoryTasks = _categoryTasks[i];
      
      bool hasCategoryTasks = false;
      final categoryItems = <Widget>[];
      
      for (var task in categoryTasks) {
        final savedTask = taskNotifier.getCompanyTasks('SAS')
            .firstWhere((t) => t['name'] == task['name'], orElse: () => {});
        
        if (savedTask['selected'] == true) {
          hasCategoryTasks = true;
          // Vérifier si les champs sont remplis ou non
          final String dayHours = savedTask['hours'] ?? '';
          final bool hasDayHours = dayHours.trim().isNotEmpty && dayHours != '0' && dayHours != '0.0';
          
          // Additionner au total si des heures de jour sont renseignées
          if (hasDayHours) {
            try {
              totalDayHours += double.parse(dayHours.replaceAll(',', '.'));
            } catch (e) {
              // Ignorer si la conversion échoue
            }
          }
          
          final bool hasNightHoursField = savedTask.containsKey('night_hours') && 
              (savedTask['name'] == 'Vendanges' || savedTask['name'] == 'Traitement Bertoni' || savedTask['name'] == 'Traitement pulvé desherbage');
          
          final String nightHours = hasNightHoursField ? (savedTask['night_hours'] ?? '') : '';
          final bool hasNightHours = nightHours.trim().isNotEmpty && nightHours != '0' && nightHours != '0.0';
          
          // Additionner au total si des heures de nuit sont renseignées
          if (hasNightHours) {
            try {
              totalNightHours += double.parse(nightHours.replaceAll(',', '.'));
            } catch (e) {
              // Ignorer si la conversion échoue
            }
          }

          if (hasNightHoursField && (hasDayHours || hasNightHours)) {
            categoryItems.add(
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(savedTask['name'])),
                      ],
                    ),
                    if (hasDayHours)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text('de jour: $dayHours h', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          ),
                        ],
                      ),
                    if (hasNightHours)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text('de nuit: $nightHours h', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          } else if (hasDayHours) {
            // Affichage standard pour les tâches sans heures de nuit ou si les heures de nuit ne sont pas remplies
            categoryItems.add(
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(savedTask['name'])),
                    Text('$dayHours h', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }
          // Si aucune heure n'est renseignée, on n'ajoute rien au récapitulatif
        }
      }
      
      if (hasCategoryTasks) {
        summaryItems.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              categoryName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.blue),
            ),
          ),
        );
        summaryItems.addAll(categoryItems);
        summaryItems.add(const SizedBox(height: 8));
      }
    }
    
    // Ajouter le total des heures à la fin du récapitulatif
    summaryItems.add(const Divider(thickness: 1.0));
    
    if (totalDayHours > 0) {
      summaryItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total heures de jour:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${totalDayHours.toStringAsFixed(1)} h', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    
    if (totalNightHours > 0) {
      summaryItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total heures de nuit:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${totalNightHours.toStringAsFixed(1)} h', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    
    if (totalDayHours > 0 && totalNightHours > 0) {
      summaryItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total général:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${(totalDayHours + totalNightHours).toStringAsFixed(1)} h', 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      );
    }
    
    // Afficher la boîte de dialogue de confirmation
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'enregistrement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: summaryItems,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        taskNotifier.setLoading(true);
        final filePath = await taskNotifier.saveData(
          'SAS',
          widget.firstName,
          widget.lastName,
          taskHours: ref.watch(taskProvider).taskHours['SAS'] ?? {},
        );
        
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toString().split(' ')[0];
        await prefs.setString('selectedCompany', 'SAS');
        await prefs.setString('lastEntryDate', today);
        
        // Enregistrement du nom et prénom de l'utilisateur qui a saisi les heures
        await prefs.setString('lastEntryFirstName', widget.firstName);
        await prefs.setString('lastEntryLastName', widget.lastName);
        debugPrint('SAS - Sauvegarde utilisateur: ${widget.firstName} ${widget.lastName}');
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuccessScreen(
                firstName: widget.firstName,
                lastName: widget.lastName,
                taskHours: ref.watch(taskProvider).taskHours,
                filePath: filePath,
                companyName: 'SAS',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Erreur lors de l\'enregistrement: $e');
        }
      } finally {
        if (mounted) {
          taskNotifier.setLoading(false);
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, String categoryName) {
    final taskNotifier = ref.read(taskProvider.notifier);
    final isSelected = task['selected'] == true;
    final bool hasNightHours = task.containsKey('night_hours') && 
        (task['name'] == 'Vendanges' || task['name'] == 'Traitement Bertoni' || task['name'] == 'Traitement pulvé desherbage');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? Theme.of(context).colorScheme.primary.withAlpha((255 * 0.05).round()) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Checkbox personnalisé
                GestureDetector(
                  onTap: () {
                    taskNotifier.toggleCompanyTask('SAS', task['name']);
                    _onAnyFieldChanged();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                        width: 2,
                      ),
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Nom de la tâche
                Expanded(
                  child: Text(
                    task['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (isSelected) ...[  
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Heures de jour:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      color: Colors.white,
                    ),
                    child: TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        hintText: '0h',
                        hintStyle: TextStyle(fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      enabled: true,
                      initialValue: task['hours'],
                      onChanged: (value) {
                        taskNotifier.updateCompanyTaskHours('SAS', task['name'], value);
                        _onAnyFieldChanged();
                      },
                    ),
                  ),
                ],
              ),
              if (hasNightHours) ...[  
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Heures de nuit:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        color: Colors.white,
                      ),
                      child: TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          hintText: '0h',
                          hintStyle: TextStyle(fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        enabled: true,
                        initialValue: task['night_hours'] ?? '',
                        onChanged: (value) {
                          task['night_hours'] = value;
                          // La mise à jour doit être gérée spécifiquement
                          final tasks = taskNotifier.getCompanyTasks('SAS');
                          for (var t in tasks) {
                            if (t['name'] == task['name']) {
                              t['night_hours'] = value;
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent(int categoryIndex) {
    final categoryName = _categoryNames[categoryIndex];
    if (categoryName == 'Kilométrage') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildKilometrageCard(),
      );
    }
    final categoryTasks = _categoryTasks[categoryIndex];
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: categoryTasks.length,
      itemBuilder: (context, index) {
        final task = categoryTasks[index];
        // Synchroniser avec les données du provider
        final savedTask = ref.read(taskProvider.notifier).getCompanyTasks('SAS')
            .firstWhere((t) => t['name'] == task['name'], orElse: () => task);
        return _buildTaskCard(savedTask, categoryName);
      },
    );
  }

  Widget _buildKilometrageCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_kilometrageEntries.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Kilomètres',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _kilometrageEntries[index]['kilometres'] = value;
                      });
                      _onAnyFieldChanged();
                    },
                    initialValue: _kilometrageEntries[index]['kilometres'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Motif du déplacement',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _kilometrageEntries[index]['motif'] = value;
                      });
                      _onAnyFieldChanged();
                    },
                    initialValue: _kilometrageEntries[index]['motif'],
                  ),
                ),
                const SizedBox(width: 8),
                // Remove button (not for first entry)
                if (_kilometrageEntries.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _kilometrageEntries.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un déplacement'),
            onPressed: () {
              setState(() {
                _kilometrageEntries.add({'kilometres': '', 'motif': ''});
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _resetInactivityTimer();
    final taskState = ref.watch(taskProvider);
    
    // --- Ajout du bouton retour personnalisé avec confirmation ---
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => BackButtonHandler.handleBackPress(
            context,
            hasChanges: _hasChanges,
            onSave: _saveAllData,
            onReset: _resetAllFields,
          ),
        ),
        automaticallyImplyLeading: false,
        title: const Text('Saisie des heures - SAS'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
      body: taskState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
                  children: [
                    // Header avec instructions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.05).round()),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Sélectionnez les tâches et saisissez les heures',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Tabs des catégories
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        tabs: _categoryNames.map((name) => Tab(text: name)).toList(),
                        onTap: (index) {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                      ),
                    ),
                    
                    // Contenu de la catégorie sélectionnée
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: List.generate(
                          _categoryNames.length,
                          (index) => _buildCategoryContent(index),
                        ),
                      ),
                    ),
                    
                    // Bouton d'enregistrement
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.1).round()),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                                              child: ElevatedButton(
                        onPressed: _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Enregistrer',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}