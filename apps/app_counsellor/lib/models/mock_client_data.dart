import '../models/client_intake.dart';

// Sample mock data demonstrating all 13 client requirements
ClientIntake getMockClientIntake() {
  return ClientIntake(
    // 1. User ID
    userId: 'CL-2024-00145',

    // 2. Display Name
    displayName: 'Sarah Johnson',

    // 3. Age
    age: 28,

    // 4. Issue/Reason for Counseling
    issue: 'Anxiety and Stress Management',
    detailedReason:
        'Experiencing high levels of work-related stress and anxiety. Having difficulty '
        'sleeping and managing daily responsibilities. Looking for coping strategies and support.',
    goals: [
      'Learn stress management techniques',
      'Improve sleep quality',
      'Develop better work-life balance',
      'Build confidence in handling challenging situations',
    ],

    // 5. Chat History
    totalChatSessions: 8,
    lastChatDate: DateTime.now().subtract(const Duration(days: 2)),
    previousChats: [
      ChatMessage(
        messageId: 'msg_001',
        content: 'I\'ve been feeling really overwhelmed at work lately.',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
        isFromClient: true,
      ),
      ChatMessage(
        messageId: 'msg_002',
        content:
            'I understand. Can you tell me more about what specifically is causing stress?',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
        isFromClient: false,
      ),
      ChatMessage(
        messageId: 'msg_003',
        content:
            'The breathing exercises you suggested last time really helped!',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isFromClient: true,
      ),
    ],

    // 6. Call History
    totalCallSessions: 5,
    lastCallDate: DateTime.now().subtract(const Duration(days: 7)),
    previousCalls: [
      CallRecord(
        callId: 'call_001',
        callDate: DateTime.now().subtract(const Duration(days: 7)),
        durationMinutes: 45,
        notes: 'Discussed coping mechanisms for workplace anxiety',
      ),
      CallRecord(
        callId: 'call_002',
        callDate: DateTime.now().subtract(const Duration(days: 14)),
        durationMinutes: 38,
        notes: 'Client reported improvement in sleep patterns',
      ),
      CallRecord(
        callId: 'call_003',
        callDate: DateTime.now().subtract(const Duration(days: 21)),
        durationMinutes: 42,
        notes: 'Initial assessment and goal setting',
      ),
    ],

    // 7. Profession
    profession: 'Software Engineer',
    employmentStatus: 'Full-time employed',

    // 8. Feedback History (directed to admin)
    feedbackHistory: [
      SessionFeedback(
        sessionId: 'sess_101',
        sessionDate: DateTime.now().subtract(const Duration(days: 7)),
        rating: 5,
        comment:
            'Very helpful session. The counselor was understanding and provided practical advice.',
        sessionType: 'call',
        status: 'submitted_to_admin',
      ),
      SessionFeedback(
        sessionId: 'sess_102',
        sessionDate: DateTime.now().subtract(const Duration(days: 14)),
        rating: 5,
        comment: 'Great techniques for managing stress.',
        sessionType: 'chat',
        status: 'reviewed',
      ),
      SessionFeedback(
        sessionId: 'sess_103',
        sessionDate: DateTime.now().subtract(const Duration(days: 21)),
        rating: 4,
        comment: 'Good first session, looking forward to continuing.',
        sessionType: 'call',
        status: 'reviewed',
      ),
    ],
    averageRating: 4.7,
    hasPendingFeedback: false,

    // 9. Risk Flag (green, yellow, red)
    flag: RiskFlag.yellow,
    flagReason:
        'Moderate anxiety levels - monitoring sleep patterns and stress response',

    // 10. Session Details with Minutes
    totalMinutes: 486,
    sessionCount: 13,
    lastSessionDate: DateTime.now().subtract(const Duration(days: 2)),
    lastSessionType: 'chat',

    // 11. Insights and Reports (Returning Client)
    clientInsights: ClientInsights(
      moodTrend: 'improving',
      commonThemes: ['work stress', 'sleep issues', 'anxiety management'],
      engagementScore: 92,
      progressSummary:
          'Client shows consistent improvement in managing anxiety. Reports better sleep '
          'quality and increased confidence in using coping strategies. Regular engagement '
          'with sessions indicates strong commitment to progress.',
      recommendations: [
        'Continue practicing mindfulness techniques',
        'Consider introducing progressive muscle relaxation',
        'Maintain regular session schedule',
      ],
      metrics: {
        'anxiety_level': 'moderate',
        'sleep_quality': 'improving',
        'session_attendance': '100%',
      },
    ),
    progressReports: [
      ProgressReport(
        reportId: 'RPT_001',
        reportDate: DateTime.now().subtract(const Duration(days: 30)),
        summary:
            'First month progress report: Client has made significant strides in recognizing '
            'anxiety triggers and implementing coping strategies. Recommending continued support.',
        metrics: {
          'sessions_completed': 8,
          'goals_achieved': 2,
          'satisfaction_score': 4.5,
        },
      ),
    ],
    isReturningClient: true,

    // 12. Emergency Contact & Support Resources
    emergencyContact: EmergencyContact(
      name: 'Michael Johnson',
      relationship: 'Spouse',
      phone: '+1 (555) 123-4567',
      email: 'michael.j@email.com',
      canBeContacted: true,
    ),
    supportResources: [
      'National Crisis Hotline: 988',
      'Local Mental Health Center: (555) 999-8888',
      'Employee Assistance Program (EAP) available through employer',
    ],
    hasActiveCrisis: false,

    // 13. Language Preference
    languagePreference: 'English',
    additionalLanguages: ['Spanish'],

    // Additional Info
    profilePhoto: null,
    email: 'sarah.johnson@email.com',
    phone: '+1 (555) 234-5678',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

// Example of a high-risk client
ClientIntake getMockHighRiskClient() {
  return ClientIntake(
    userId: 'CL-2024-00156',
    displayName: 'John Smith',
    age: 35,
    issue: 'Severe Depression and Suicidal Ideation',
    detailedReason:
        'Client is experiencing severe depressive symptoms with recent suicidal thoughts. '
        'Requires immediate intervention and close monitoring.',
    goals: [
      'Establish safety plan',
      'Regular check-ins with counselor',
      'Connect with psychiatric services',
    ],
    totalChatSessions: 3,
    lastChatDate: DateTime.now().subtract(const Duration(hours: 2)),
    previousChats: [
      ChatMessage(
        messageId: 'msg_004',
        content: 'I need to talk to someone right now.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isFromClient: true,
      ),
    ],
    totalCallSessions: 2,
    lastCallDate: DateTime.now().subtract(const Duration(hours: 12)),
    previousCalls: [
      CallRecord(
        callId: 'call_004',
        callDate: DateTime.now().subtract(const Duration(hours: 12)),
        durationMinutes: 60,
        notes:
            'URGENT: Crisis intervention. Safety plan established. Follow-up scheduled.',
      ),
    ],
    profession: 'Accountant',
    employmentStatus: 'On medical leave',
    feedbackHistory: [],
    averageRating: null,
    hasPendingFeedback: true,
    flag: RiskFlag.red,
    flagReason:
        'HIGH RISK: Suicidal ideation reported. Requires immediate attention and daily check-ins.',
    totalMinutes: 172,
    sessionCount: 5,
    lastSessionDate: DateTime.now().subtract(const Duration(hours: 2)),
    lastSessionType: 'chat',
    clientInsights: null,
    progressReports: [],
    isReturningClient: false,
    emergencyContact: EmergencyContact(
      name: 'Lisa Smith',
      relationship: 'Sister',
      phone: '+1 (555) 987-6543',
      email: 'lisa.smith@email.com',
      canBeContacted: true,
    ),
    supportResources: [
      'National Suicide Prevention Lifeline: 988',
      'Crisis Text Line: Text HOME to 741741',
      'Local Emergency Services: 911',
      'Psychiatric Emergency Team: (555) 111-2222',
    ],
    hasActiveCrisis: true,
    languagePreference: 'English',
    additionalLanguages: null,
    profilePhoto: null,
    email: 'john.smith@email.com',
    phone: '+1 (555) 876-5432',
    createdAt: DateTime.now().subtract(const Duration(days: 14)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
  );
}

// Example of a low-risk/stable client
ClientIntake getMockStableClient() {
  return ClientIntake(
    userId: 'CL-2024-00089',
    displayName: 'Maria Garcia',
    age: 42,
    issue: 'Life Transitions and Personal Growth',
    detailedReason:
        'Seeking support during career change and personal development. No acute concerns, '
        'focused on building resilience and achieving personal goals.',
    goals: [
      'Develop career transition plan',
      'Enhance communication skills',
      'Build self-confidence',
    ],
    totalChatSessions: 15,
    lastChatDate: DateTime.now().subtract(const Duration(days: 5)),
    previousChats: [
      ChatMessage(
        messageId: 'msg_005',
        content: 'I got the job interview! Thank you for helping me prepare.',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        isFromClient: true,
      ),
    ],
    totalCallSessions: 10,
    lastCallDate: DateTime.now().subtract(const Duration(days: 14)),
    previousCalls: [
      CallRecord(
        callId: 'call_005',
        callDate: DateTime.now().subtract(const Duration(days: 14)),
        durationMinutes: 30,
        notes: 'Career coaching session - resume and interview preparation',
      ),
    ],
    profession: 'Marketing Manager',
    employmentStatus: 'Transitioning careers',
    feedbackHistory: [
      SessionFeedback(
        sessionId: 'sess_201',
        sessionDate: DateTime.now().subtract(const Duration(days: 30)),
        rating: 5,
        comment: 'Excellent support during my career transition.',
        sessionType: 'call',
        status: 'reviewed',
      ),
    ],
    averageRating: 5.0,
    hasPendingFeedback: false,
    flag: RiskFlag.green,
    flagReason: null,
    totalMinutes: 675,
    sessionCount: 25,
    lastSessionDate: DateTime.now().subtract(const Duration(days: 5)),
    lastSessionType: 'chat',
    clientInsights: ClientInsights(
      moodTrend: 'stable',
      commonThemes: [
        'career development',
        'personal growth',
        'confidence building',
      ],
      engagementScore: 98,
      progressSummary:
          'Client demonstrates excellent progress in career transition goals. High engagement '
          'and proactive in implementing strategies. Approaching completion of primary goals.',
      recommendations: [
        'Consider focusing on leadership development',
        'Prepare for potential graduation from regular counseling',
      ],
      metrics: {
        'confidence_level': 'high',
        'goal_progress': '85%',
        'session_attendance': '100%',
      },
    ),
    progressReports: [
      ProgressReport(
        reportId: 'RPT_002',
        reportDate: DateTime.now().subtract(const Duration(days: 60)),
        summary:
            'Two-month review: Exceptional progress. Client has achieved 75% of stated goals '
            'and shows strong resilience and self-awareness.',
        metrics: {
          'sessions_completed': 15,
          'goals_achieved': 3,
          'satisfaction_score': 5.0,
        },
      ),
    ],
    isReturningClient: true,
    emergencyContact: EmergencyContact(
      name: 'Carlos Garcia',
      relationship: 'Husband',
      phone: '+1 (555) 456-7890',
      email: 'carlos.g@email.com',
      canBeContacted: true,
    ),
    supportResources: ['Career Services Hotline: (555) 888-9999'],
    hasActiveCrisis: false,
    languagePreference: 'Spanish',
    additionalLanguages: ['English'],
    profilePhoto: null,
    email: 'maria.garcia@email.com',
    phone: '+1 (555) 345-6789',
    createdAt: DateTime.now().subtract(const Duration(days: 180)),
    updatedAt: DateTime.now().subtract(const Duration(days: 5)),
  );
}
