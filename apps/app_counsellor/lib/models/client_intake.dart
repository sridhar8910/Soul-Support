class ClientIntake {
  // 1. User ID
  final String userId;

  // 2. Display Name
  final String displayName;

  // 3. Age
  final int age;

  // 4. Issue/Reason
  final String issue;
  final String detailedReason;
  final List<String> goals;

  // 5. Chat History
  final int totalChatSessions;
  final DateTime? lastChatDate;
  final List<ChatMessage> previousChats;

  // 6. Call History
  final int totalCallSessions;
  final DateTime? lastCallDate;
  final List<CallRecord> previousCalls;

  // 7. Profession
  final String profession;
  final String? employmentStatus;

  // 8. Feedback (directed to admin)
  final List<SessionFeedback>? feedbackHistory;
  final double? averageRating;
  final bool hasPendingFeedback;

  // 9. Flag (green, yellow, red)
  final RiskFlag flag;
  final String? flagReason;

  // 10. Session Details
  final int totalMinutes;
  final int sessionCount;
  final DateTime? lastSessionDate;
  final String? lastSessionType;

  // 11. Insights and Reports (for returning clients)
  final ClientInsights? clientInsights;
  final List<ProgressReport> progressReports;
  final bool isReturningClient;

  // 12. Emergency/Support Info
  final EmergencyContact emergencyContact;
  final List<String> supportResources;
  final bool hasActiveCrisis;

  // 13. Language Preference
  final String languagePreference;
  final List<String>? additionalLanguages;

  // Additional fields
  final String? profilePhoto;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientIntake({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.issue,
    required this.detailedReason,
    required this.goals,
    required this.totalChatSessions,
    this.lastChatDate,
    required this.previousChats,
    required this.totalCallSessions,
    this.lastCallDate,
    required this.previousCalls,
    required this.profession,
    this.employmentStatus,
    this.feedbackHistory,
    this.averageRating,
    required this.hasPendingFeedback,
    required this.flag,
    this.flagReason,
    required this.totalMinutes,
    required this.sessionCount,
    this.lastSessionDate,
    this.lastSessionType,
    this.clientInsights,
    required this.progressReports,
    required this.isReturningClient,
    required this.emergencyContact,
    required this.supportResources,
    required this.hasActiveCrisis,
    required this.languagePreference,
    this.additionalLanguages,
    this.profilePhoto,
    this.email,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  factory ClientIntake.fromJson(Map<String, dynamic> json) {
    return ClientIntake(
      userId: json['userId'],
      displayName: json['displayName'],
      age: json['age'],
      issue: json['issue'],
      detailedReason: json['detailedReason'],
      goals: List<String>.from(json['goals'] ?? []),
      totalChatSessions: json['totalChatSessions'] ?? 0,
      lastChatDate: json['lastChatDate'] != null
          ? DateTime.parse(json['lastChatDate'])
          : null,
      previousChats: json['previousChats'] != null
          ? (json['previousChats'] as List)
                .map((e) => ChatMessage.fromJson(e))
                .toList()
          : [],
      totalCallSessions: json['totalCallSessions'] ?? 0,
      lastCallDate: json['lastCallDate'] != null
          ? DateTime.parse(json['lastCallDate'])
          : null,
      previousCalls: json['previousCalls'] != null
          ? (json['previousCalls'] as List)
                .map((e) => CallRecord.fromJson(e))
                .toList()
          : [],
      profession: json['profession'],
      employmentStatus: json['employmentStatus'],
      feedbackHistory: json['feedbackHistory'] != null
          ? (json['feedbackHistory'] as List)
                .map((e) => SessionFeedback.fromJson(e))
                .toList()
          : null,
      averageRating: _parseDouble(json['averageRating']),
      hasPendingFeedback: json['hasPendingFeedback'] ?? false,
      flag: RiskFlag.values.firstWhere(
        (e) => e.name == json['flag'],
        orElse: () => RiskFlag.green,
      ),
      flagReason: json['flagReason'],
      totalMinutes: json['totalMinutes'] ?? 0,
      sessionCount: json['sessionCount'] ?? 0,
      lastSessionDate: json['lastSessionDate'] != null
          ? DateTime.parse(json['lastSessionDate'])
          : null,
      lastSessionType: json['lastSessionType'],
      clientInsights: json['clientInsights'] != null
          ? ClientInsights.fromJson(json['clientInsights'])
          : null,
      progressReports: json['progressReports'] != null
          ? (json['progressReports'] as List)
                .map((e) => ProgressReport.fromJson(e))
                .toList()
          : [],
      isReturningClient: json['isReturningClient'] ?? false,
      emergencyContact: EmergencyContact.fromJson(json['emergencyContact']),
      supportResources: List<String>.from(json['supportResources'] ?? []),
      hasActiveCrisis: json['hasActiveCrisis'] ?? false,
      languagePreference: json['languagePreference'] ?? 'English',
      additionalLanguages: json['additionalLanguages'] != null
          ? List<String>.from(json['additionalLanguages'])
          : null,
      profilePhoto: json['profilePhoto'],
      email: json['email'],
      phone: json['phone'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

// Risk Flag Enum (9)
enum RiskFlag {
  green, // No risk / Low concern
  yellow, // Moderate concern / Monitoring needed
  red, // High risk / Immediate attention
}

// Session Feedback Model (8)
class SessionFeedback {
  final String sessionId;
  final DateTime sessionDate;
  final int rating; // 1-5 stars
  final String? comment;
  final String sessionType; // 'chat' or 'call'
  final String status; // 'pending', 'submitted_to_admin', 'reviewed'

  SessionFeedback({
    required this.sessionId,
    required this.sessionDate,
    required this.rating,
    this.comment,
    required this.sessionType,
    required this.status,
  });

  factory SessionFeedback.fromJson(Map<String, dynamic> json) {
    return SessionFeedback(
      sessionId: json['sessionId'],
      sessionDate: DateTime.parse(json['sessionDate']),
      rating: json['rating'],
      comment: json['comment'],
      sessionType: json['sessionType'],
      status: json['status'] ?? 'pending',
    );
  }
}

// Client Insights Model (11)
class ClientInsights {
  final String moodTrend; // 'improving', 'stable', 'declining'
  final List<String> commonThemes;
  final int engagementScore; // 0-100
  final String? progressSummary;
  final List<String> recommendations;
  final Map<String, dynamic> metrics;

  ClientInsights({
    required this.moodTrend,
    required this.commonThemes,
    required this.engagementScore,
    this.progressSummary,
    required this.recommendations,
    required this.metrics,
  });

  factory ClientInsights.fromJson(Map<String, dynamic> json) {
    return ClientInsights(
      moodTrend: json['moodTrend'],
      commonThemes: List<String>.from(json['commonThemes'] ?? []),
      engagementScore: json['engagementScore'] ?? 0,
      progressSummary: json['progressSummary'],
      recommendations: List<String>.from(json['recommendations'] ?? []),
      metrics: json['metrics'] ?? {},
    );
  }
}

// Emergency Contact Model (12)
class EmergencyContact {
  final String name;
  final String relationship;
  final String phone;
  final String? email;
  final bool canBeContacted;

  EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
    required this.canBeContacted,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'],
      relationship: json['relationship'],
      phone: json['phone'],
      email: json['email'],
      canBeContacted: json['canBeContacted'] ?? true,
    );
  }
}

// Chat Message Model (5)
class ChatMessage {
  final String messageId;
  final String content;
  final DateTime timestamp;
  final bool isFromClient;

  ChatMessage({
    required this.messageId,
    required this.content,
    required this.timestamp,
    required this.isFromClient,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromClient: json['isFromClient'] ?? true,
    );
  }
}

// Call Record Model (6)
class CallRecord {
  final String callId;
  final DateTime callDate;
  final int durationMinutes;
  final String? notes;

  CallRecord({
    required this.callId,
    required this.callDate,
    required this.durationMinutes,
    this.notes,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      callId: json['callId'],
      callDate: DateTime.parse(json['callDate']),
      durationMinutes: json['durationMinutes'] ?? 0,
      notes: json['notes'],
    );
  }
}

// Progress Report Model (11)
class ProgressReport {
  final String reportId;
  final DateTime reportDate;
  final String summary;
  final Map<String, dynamic> metrics;

  ProgressReport({
    required this.reportId,
    required this.reportDate,
    required this.summary,
    required this.metrics,
  });

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    return ProgressReport(
      reportId: json['reportId'],
      reportDate: DateTime.parse(json['reportDate']),
      summary: json['summary'],
      metrics: json['metrics'] ?? {},
    );
  }
}
