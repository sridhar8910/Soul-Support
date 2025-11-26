import 'api_client.dart';

class ApiEndpoints {
  static String get base => ApiClient.base;

  // Authentication
  static String get sendOtp => '$base/auth/send-otp/';
  static String get verifyOtp => '$base/auth/verify-otp/';
  static String get register => '$base/auth/register/';
  static String get login => '$base/auth/token/';
  static String get refreshToken => '$base/auth/token/refresh/';

  // Profile
  static String get profile => '$base/profile/';
  static String get settings => '$base/settings/';

  // Wellness
  static String get mood => '$base/mood/';
  static String get wellnessTasks => '$base/wellness/tasks/';
  static String wellnessTask(int id) => '$base/wellness/tasks/$id/';
  static String get wellnessJournals => '$base/wellness/journals/';
  static String wellnessJournal(int id) => '$base/wellness/journals/$id/';

  // Wallet
  static String get wallet => '$base/wallet/';
  static String get walletRecharge => '$base/wallet/recharge/';

  // Support Groups
  static String get supportGroups => '$base/support-groups/';

  // Sessions
  static String get sessions => '$base/sessions/';
  static String session(int id) => '$base/sessions/$id/';
  static String get quickSession => '$base/sessions/quick/';

  // Analytics
  static String get analytics => '$base/reports/analytics/';

  // Content
  static String get guidanceResources => '$base/guidance/resources/';
  static String get musicTracks => '$base/content/music/';
  static String get mindCareBoosters => '$base/content/boosters/';
  static String get meditationSessions => '$base/content/meditations/';

  // Counselor/Doctor specific
  static String get counselorAppointments => '$base/counselor/appointments/';
  static String get counselorStats => '$base/counselor/stats/';
  static String counselorAvailability(int id) => '$base/providers/$id/availability';
  static String sessionStart(int id) => '$base/sessions/$id/start';
  static String sessionEnd(int id) => '$base/sessions/$id/end';
  static String sessionNotes(int id) => '$base/sessions/$id/notes';
  static String sessionRisk(int id) => '$base/sessions/$id/risk';
  static String sessionEscalate(int id) => '$base/sessions/$id/escalate';
}

