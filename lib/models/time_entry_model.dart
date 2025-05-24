class TimeEntryModel {
  final String employeeId;
  final String? firstName;
  final String? lastName;
  final String date;
  final double hoursWorked;
  final Map<String, double>? taskHours; // Map of task names to hours worked
  final List<Map<String, dynamic>> tasks; // List of tasks with details
  final bool isSynced;

  TimeEntryModel({
    required this.employeeId,
    this.firstName,
    this.lastName,
    required this.date,
    required this.hoursWorked,
    this.taskHours,
    List<Map<String, dynamic>>? tasks,
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
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  // Convert TimeEntryModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'employeeId': employeeId,
      'date': date,
      'hoursWorked': hoursWorked,
      'isSynced': isSynced,
      'tasks': tasks,
    };
    
    // Add optional fields if they exist
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (taskHours != null) data['taskHours'] = taskHours;
    
    return data;
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
      isSynced: isSynced ?? this.isSynced,
    );
  }
  
  // Calculate total hours from tasks
  double get totalTaskHours {
    if (tasks.isEmpty) return 0.0;
    return tasks.fold(0.0, (sum, task) {
      final hours = double.tryParse(task['hours']?.toString() ?? '0') ?? 0.0;
      return sum + hours;
    });
  }
}
