class TaskState {
  final Map<String, List<Map<String, dynamic>>> companyTasks;
  final Map<String, Map<String, String>> taskHours;
  final bool isLoading;
  final bool showEmptyState;
  final Map<String, dynamic>? kilometrageData; // Add kilometrageData to store kilometers and reason

  const TaskState({
    required this.companyTasks,
    required this.taskHours,
    required this.isLoading,
    required this.showEmptyState,
    this.kilometrageData,
  });

  factory TaskState.initial() {
    return TaskState(
      companyTasks: {
        'SAS': [],
        'SCEA': [],
        'CUMA': [],
      },
      taskHours: {
        'SAS': {},
        'SCEA': {},
        'CUMA': {},
      },
      isLoading: false,
      showEmptyState: false,
      kilometrageData: {'kilometers': 0.0, 'reason': ''},
    );
  }

  TaskState copyWith({
    Map<String, List<Map<String, dynamic>>>? companyTasks,
    Map<String, Map<String, String>>? taskHours,
    bool? isLoading,
    bool? showEmptyState,
    Map<String, dynamic>? kilometrageData,
  }) {
    return TaskState(
      companyTasks: companyTasks ?? this.companyTasks,
      taskHours: taskHours ?? this.taskHours,
      isLoading: isLoading ?? this.isLoading,
      showEmptyState: showEmptyState ?? this.showEmptyState,
      kilometrageData: kilometrageData ?? this.kilometrageData,
    );
  }
}

