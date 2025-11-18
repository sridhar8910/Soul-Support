class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isAvailable': isAvailable,
    };
  }
}

class Availability {
  final String counselorId;
  final Map<String, List<TimeSlot>> weeklySchedule;
  final List<DateTime> blockedDates;

  Availability({
    required this.counselorId,
    required this.weeklySchedule,
    this.blockedDates = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'counselorId': counselorId,
      'weeklySchedule': weeklySchedule.map(
        (key, value) =>
            MapEntry(key, value.map((slot) => slot.toJson()).toList()),
      ),
      'blockedDates': blockedDates.map((d) => d.toIso8601String()).toList(),
    };
  }
}
