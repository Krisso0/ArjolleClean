import 'dart:convert';

class TimeEntryModel {
  final String employeeId;
  final String? firstName;
  final String? lastName;
  final String date;
  final double hoursWorked;
  final Map<String, double>? taskHours; // Map of task names to hours worked
  final List<Map<String, dynamic>> tasks; // List of tasks with details
  final double kilometers;
  final String reason;
  final bool isSynced;

  TimeEntryModel({
    required this.employeeId,
    this.firstName,
    this.lastName,
    required this.date,
    required this.hoursWorked,
    this.taskHours,
    List<Map<String, dynamic>>? tasks,
    this.kilometers = 0.0,
    this.reason = '',
    this.isSynced = false,
  }) : tasks = tasks ?? [];

  // Create a TimeEntryModel from a JSON map
  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    // Handle taskHours which might be a Map in the JSON
    Map<String, double>? taskHoursMap;
    if (json['taskHours'] != null) {
      taskHoursMap = Map<String, double>.from(
        (json['taskHours'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      );
    }
    
    // Handle tasks list
    List<Map<String, dynamic>> tasks = [];
    if (json['tasks'] != null && json['tasks'] is List) {
      tasks = List<Map<String, dynamic>>.from(
        (json['tasks'] as List).map((task) => Map<String, dynamic>.from(task as Map)),
      );
    }
    
    return TimeEntryModel(
      employeeId: json['employeeId'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      date: json['date'] as String,
      hoursWorked: (json['hoursWorked'] as num).toDouble(),
      taskHours: taskHoursMap,
      tasks: tasks,
      kilometers: (json['kilometers'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  // Convert TimeEntryModel to un JSON map pour le stockage local
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'employeeId': employeeId,
      'date': date,
      'hoursWorked': hoursWorked,
      'isSynced': isSynced,
      'tasks': tasks,
      'kilometers': kilometers,
      'reason': reason,
    };
    
    // Add optional fields if they exist
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (taskHours != null) data['taskHours'] = taskHours;
    
    return data;
  }

  // Convert TimeEntryModel to a JSON map pour l'API backend
  Map<String, dynamic> toApiJson() {
    // Calcul du total des heures (jour + nuit)
    double totalHours = tasks.isNotEmpty
        ? tasks.fold(0.0, (sum, t) {
            double dayHours = t['hours'] is num ? t['hours'] : double.tryParse(t['hours'].toString()) ?? 0.0;
            double nightHours = t.containsKey('night_hours') ? 
                (t['night_hours'] is num ? t['night_hours'] : double.tryParse(t['night_hours'].toString()) ?? 0.0) : 0.0;
            return sum + dayHours + nightHours;
          })
        : hoursWorked;
    
    // Préparation de la liste des tâches
    List<Map<String, dynamic>> tasksForApi = tasks.map((t) {
      // Check if we have either day or night hours
      final double dayHours = t['hours'] is num ? t['hours'] : double.tryParse(t['hours'].toString()) ?? 0.0;
      final double nightHours = t.containsKey('night_hours') ? 
          (t['night_hours'] is num ? t['night_hours'] : double.tryParse(t['night_hours'].toString()) ?? 0.0) : 0.0;
      
      final taskMap = {
        'name': t['name'] ?? '',
        'hours': dayHours
      };
      
      // Add night hours if present
      if (nightHours > 0) {
        taskMap['night_hours'] = nightHours;
      }
      
      // Ajouter les kilomètres et raisons spécifiques à la tâche si présents
      if (t.containsKey('kilometers') && t['kilometers'] != null && t['kilometers'] > 0) {
        taskMap['kilometers'] = t['kilometers'] is num ? t['kilometers'] : double.tryParse(t['kilometers'].toString()) ?? 0.0;
        if (t.containsKey('reason') && t['reason'] != null && t['reason'].toString().trim().isNotEmpty) {
          taskMap['reason'] = t['reason'].toString().trim();
        }
      }
      
      return taskMap;
    }).where((t) => t['name'] != '' && (t['hours'] > 0 || (t.containsKey('night_hours') && t['night_hours'] > 0))).toList();
    // Raison seulement si kilomètres > 0
    String reasonForApi = '';
    if ((this as dynamic).kilometers != null && (this as dynamic).kilometers > 0 && (this as dynamic).reason != null && (this as dynamic).reason.toString().trim().isNotEmpty) {
      reasonForApi = (this as dynamic).reason.toString().trim();
    }
    return {
      'employeeId': employeeId,
      'employeeName': (firstName != null && lastName != null) ? '$firstName $lastName' : employeeId,
      'company': tasks.isNotEmpty && tasks[0]['company'] != null ? tasks[0]['company'] : null,
      'date': date,
      'hours': totalHours,
      'kilometers': (this as dynamic).kilometers ?? 0,
      'reason': reasonForApi,
      'tasks': tasksForApi,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // Create a copy of the TimeEntryModel with updated fields
  TimeEntryModel copyWith({
    String? employeeId,
    String? firstName,
    String? lastName,
    String? date,
    double? hoursWorked,
    Map<String, double>? taskHours,
    List<Map<String, dynamic>>? tasks,
    bool? isSynced,
  }) {
    return TimeEntryModel(
      employeeId: employeeId ?? this.employeeId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      date: date ?? this.date,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      taskHours: taskHours ?? this.taskHours,
      tasks: tasks ?? List<Map<String, dynamic>>.from(this.tasks),
      kilometers: kilometers,
      reason: reason,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Sérialise le modèle en JSON string pour les requêtes API
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Calculate total hours from tasks (day + night)
  double get totalTaskHours {
    if (tasks.isEmpty) return 0.0;
    return tasks.fold(0.0, (sum, task) {
      final dayHours = double.tryParse(task['hours']?.toString() ?? '0') ?? 0.0;
      final nightHours = task.containsKey('night_hours') ?
          (double.tryParse(task['night_hours']?.toString() ?? '0') ?? 0.0) : 0.0;
      return sum + dayHours + nightHours;
    });
  }
}
