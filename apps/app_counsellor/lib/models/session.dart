enum SessionStatus { scheduled, inProgress, completed, cancelled, noShow }

enum SessionType { voice, chat }

enum RiskLevel { none, low, medium, high, critical }

class Session {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientPhoto;
  final String counselorId;
  final DateTime scheduledTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final SessionType type;
  final SessionStatus status;
  final String? notes;
  final RiskLevel riskLevel;
  final bool isEscalated;
  final int durationMinutes;

  Session({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientPhoto,
    required this.counselorId,
    required this.scheduledTime,
    this.startTime,
    this.endTime,
    required this.type,
    required this.status,
    this.notes,
    this.riskLevel = RiskLevel.none,
    this.isEscalated = false,
    this.durationMinutes = 60,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      clientPhoto: json['clientPhoto'],
      counselorId: json['counselorId'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      type: SessionType.values.firstWhere((e) => e.name == json['type']),
      status: SessionStatus.values.firstWhere((e) => e.name == json['status']),
      notes: json['notes'],
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == (json['riskLevel'] ?? 'none'),
      ),
      isEscalated: json['isEscalated'] ?? false,
      durationMinutes: json['durationMinutes'] ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhoto': clientPhoto,
      'counselorId': counselorId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'type': type.name,
      'status': status.name,
      'notes': notes,
      'riskLevel': riskLevel.name,
      'isEscalated': isEscalated,
      'durationMinutes': durationMinutes,
    };
  }
}
