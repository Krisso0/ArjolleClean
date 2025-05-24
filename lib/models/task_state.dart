class TaskState {
  final Map<String, List<Map<String, dynamic>>> companyTasks;
  final Map<String, Map<String, String>> taskHours;
  final bool isLoading;
  final bool showEmptyState;

  const TaskState({
    required this.companyTasks,
    required this.taskHours,
    required this.isLoading,
    required this.showEmptyState,
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
    );
  }

  TaskState copyWith({
    Map<String, List<Map<String, dynamic>>>? companyTasks,
    Map<String, Map<String, String>>? taskHours,
    bool? isLoading,
    bool? showEmptyState,
  }) {
    return TaskState(
      companyTasks: companyTasks ?? this.companyTasks,
      taskHours: taskHours ?? this.taskHours,
      isLoading: isLoading ?? this.isLoading,
      showEmptyState: showEmptyState ?? this.showEmptyState,
    );
  }
}

