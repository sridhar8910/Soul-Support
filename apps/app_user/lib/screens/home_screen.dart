import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Removed flutter_native_timezone plugin - using built-in Dart timezone support instead

import 'package:common/api/api_client.dart';
import 'advanced_care_support_page.dart';
import 'affirmations_page.dart';
import 'assessment_page.dart';
import 'breathing_page.dart';
import 'expert_connect_page.dart';
import 'guidelines_page.dart';
import 'insights_reports_page.dart';
import 'journal_page.dart';
import 'login_screen.dart';
import 'meditation_page.dart';
import 'mindcare_booster_page.dart';
import 'music_page.dart';
import 'history_center_page.dart';
import 'support_groups_page.dart';
import 'upcoming_sessions_page.dart';
import 'wallet_page.dart';
import 'wellness_journal_page.dart';
import 'wellness_plan_page.dart';
import 'professional_guidance_page.dart';
import 'reports_analytics_page.dart';
import 'schedule_session_page.dart';
import 'settings_page.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();
  late Map<String, dynamic> _profile;

  @override
  void initState() {
    super.initState();
    final data = widget.profile ?? {};
    _profile = {
      'username': data['username'] ?? '',
      'email': data['email'] ?? '',
      'full_name': data['full_name'] ?? '',
      'nickname': data['nickname'] ?? '',
      'phone': data['phone'] ?? '',
      'age': data['age'],
      'gender': data['gender'] ?? '',
      'preferences': data['preferences'] ?? '',
      'last_mood': data['last_mood'] ?? 3,
      'mood_updates_count': data['mood_updates_count'] ?? 0,
      'mood_updates_date': data['mood_updates_date'],
    };
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _updateProfile(Map<String, dynamic> updated) {
    setState(() {
      _profile = {
        ..._profile,
        ...updated,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      profile: _profile,
      onProfileUpdated: _updateProfile,
      onLogout: _logout,
    );
  }
}

/* ---------- Palette ---------- */
class _Palette {
  static const primary = Color(0xFF8B5FBF);
  static const accent = Color(0xFF4AC6B7);
  static const bg = Color(0xFFFDFBFF);
  static const cardBg = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1B41);
  static const subtext = Color(0xFF6B6B8E);
  static const soft = Color(0xFFF0EBFF);
  static const border = Color(0xFFF5F3FF);
}

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> profile;
  final ValueChanged<Map<String, dynamic>> onProfileUpdated;
  final Future<void> Function() onLogout;

  const DashboardPage({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    required this.onLogout,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiClient _api = ApiClient();
  static const _maxMoodUpdatesPerDay = 3;

  double _currentMoodValue = 3;
  double _lastCommittedMood = 3;
  int _moodUpdatesToday = 0;
  bool _moodUpdating = false;
  String? _timeZoneName;

  int _walletAmount = 0;
  bool _walletLoading = false;
  Map<String, int> _walletMinimums = const {"call": 100, "chat": 50};

  late Map<String, dynamic> profile;

  String _formatNameForDisplay(String name) {
    if (name.trim().isEmpty) return 'Soul Support User';
    return name
        .split(RegExp(r'\s+'))
        .map((part) => part.isEmpty
            ? ''
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    profile = Map<String, dynamic>.from(widget.profile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWalletBalance();
    });
    _initMoodState();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.profile, widget.profile)) {
      setState(() {
        profile = Map<String, dynamic>.from(widget.profile);
      });
    }
  }

  Future<void> _loadWalletBalance() async {
    if (_walletLoading) return;
    setState(() {
      _walletLoading = true;
    });
    try {
      final wallet = await _api.getWallet();
      if (!mounted) return;
      setState(() {
        _walletAmount = wallet.amount;
        _walletMinimums = wallet.minimumBalance;
      });
    } on ApiClientException catch (error) {
      if (kDebugMode) {
        debugPrint('Wallet load failed: ${error.message}');
      }
      if (mounted) {
        setState(() {
          _walletAmount = 0;
        });
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to load wallet: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _walletLoading = false;
        });
      }
    }
  }

  Future<void> _initMoodState() async {
    // Use built-in Dart timezone support instead of plugin
    String? detectedTz;
    try {
      // Get timezone offset and convert to IANA-like format
      // Format: UTC+5:30 or UTC-8:00
      final now = DateTime.now();
      final local = now.toLocal();
      final utc = now.toUtc();
      final offset = local.difference(utc);
      final totalMinutes = offset.inMinutes;
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes.abs() % 60;
      final sign = totalMinutes >= 0 ? '+' : '-';
      detectedTz = 'UTC$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to read device timezone: $error');
      }
      // Fallback to UTC if detection fails
      detectedTz = 'UTC+00:00';
    }

    final lastMood = profile['last_mood'];
    final updatesUsed = profile['mood_updates_count'];

    if (!mounted) return;
    setState(() {
      _timeZoneName = detectedTz;
      if (lastMood is num) {
        _currentMoodValue = lastMood.toDouble().clamp(1, 5);
        _lastCommittedMood = _currentMoodValue;
      }
      if (updatesUsed is int) {
        _moodUpdatesToday = updatesUsed;
      }
    });
  }

  Future<void> _attemptMoodChange(double newValue, {String? feedbackEmoji}) async {
    final normalized = newValue.clamp(1, 5).toDouble();
    if (_moodUpdating || _lastCommittedMood.round() == normalized.round()) {
      if (mounted) {
        setState(() => _currentMoodValue = _lastCommittedMood);
      }
      return;
    }

    setState(() {
      _currentMoodValue = normalized;
      _moodUpdating = true;
    });

    try {
      final result = await _api.updateMood(
        value: normalized.round(),
        timezone: _timeZoneName,
      );
      if (!mounted) return;

      if (result.status == MoodUpdateStatus.limitReached) {
        setState(() {
          _currentMoodValue = _lastCommittedMood;
          if (result.timezone != null && result.timezone!.trim().isNotEmpty) {
            profile['timezone'] = result.timezone!.trim();
          }
        });
        await _showMoodLimitDialog();
        return;
      }

      setState(() {
        _lastCommittedMood = normalized;
        _currentMoodValue = normalized;
        if (result.updatesUsed != null) {
          _moodUpdatesToday = result.updatesUsed!.clamp(0, _maxMoodUpdatesPerDay);
        }
        profile['last_mood'] = normalized.round();
        profile['mood_updates_count'] = _moodUpdatesToday;
        profile['mood_updates_date'] = DateTime.now().toIso8601String();
      });

      if (feedbackEmoji != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mood updated: $feedbackEmoji')),
        );
      }
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() => _currentMoodValue = _lastCommittedMood);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _currentMoodValue = _lastCommittedMood);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update mood. Please try again later.')),
      );
      if (kDebugMode) {
        debugPrint('Mood update failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _moodUpdating = false);
      }
    }
  }

  Future<void> _showMoodLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily limit reached'),
        content: const Text(
          'You can update your mood only 3 times per day. '
          'Your limit is complete for today. Please try again after 12:00 AM.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMoodTap(double value, String emoji) {
    _attemptMoodChange(value, feedbackEmoji: emoji);
  }

  int get _remainingMoodUpdates =>
      (_maxMoodUpdatesPerDay - _moodUpdatesToday).clamp(0, _maxMoodUpdatesPerDay);

  int calculateProfileCompletion() {
    final preferredName = (profile['nickname'] as String?)?.trim().isNotEmpty == true
        ? profile['nickname']
        : profile['full_name'];
    final fields = [
      preferredName,
      profile['email'],
      profile['phone'],
      profile['age'],
      profile['gender'],
    ];
    final filled = fields.where((value) {
      if (value == null) return false;
      if (value is String && value.trim().isEmpty) return false;
      return true;
    }).length;
    return ((filled / fields.length) * 100).round();
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          initialProfile: profile,
        ),
      ),
    );
    if (updated != null) {
      try {
        final result = await _api.updateUserSettings(
          fullName: updated['full_name'] as String?,
          nickname: updated['nickname'] as String?,
          phone: updated['phone'] as String?,
          age: updated['age'] as int?,
          gender: updated['gender'] as String?,
        );
        widget.onProfileUpdated({
          'full_name': result.fullName ?? updated['full_name'],
          'nickname': result.nickname ?? updated['nickname'],
          'phone': result.phone ?? updated['phone'],
          'age': result.age ?? updated['age'],
          'gender': result.gender ?? updated['gender'],
          'email': updated['email'],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $error')),
        );
      }
    } else {
      setState(() {}); // trigger UI refresh to reflect any controller edits
    }
  }

  void _openFeature(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('wellness plan') || normalized.contains('view plan')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyWellnessPlanPage()),
      );
      return;
    }
    if (normalized.contains('wellness journal')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WellnessJournalPage()),
      );
      return;
    }
    if (normalized.contains('journal')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyJournalPage()),
      );
      return;
    }
    if (normalized.contains('guideline')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GuidelinesPage()),
      );
      return;
    }
    if (normalized.contains('mental health') || normalized.contains('assessment')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AIAssessmentPage()),
      );
      return;
    }
    if (normalized.contains('expert connect')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExpertConnectPage()),
      );
      return;
    }
    if (normalized.contains('mindcare') || normalized.contains('booster')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MindCareBoosterPage()),
      );
      return;
    }
    if (normalized.contains('meditation')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MeditationPage()),
      );
      return;
    }
    if (normalized.contains('music')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MusicPage()),
      );
      return;
    }
    if (normalized.contains('breathing')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BreathingPage()),
      );
      return;
    }
    if (normalized.contains('affirmation')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AffirmationsPage()),
      );
      return;
    }
    if (normalized.contains('support group')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SupportGroupsPage()),
      );
      return;
    }
    if (normalized.contains('schedule session')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScheduleSessionPage()),
      );
      return;
    }
    if (normalized == 'schedule') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpcomingSessionsPage()),
      );
      return;
    }
    if (normalized.contains('insights') && normalized.contains('reports')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InsightsReportsPage()),
      );
      return;
    }
    if (normalized.contains('reports') && normalized.contains('analytics')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportsAnalyticsPage()),
      );
      return;
    }
    if (normalized.contains('professional guidance')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfessionalGuidancePage()),
      );
      return;
    }
    if (normalized.contains('settings')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      return;
    }
    if (normalized.contains('wallet')) {
      _openWallet();
      return;
    }
    if (normalized.contains('advanced care')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdvancedCareSupportPage()),
      );
      return;
    }
    if (normalized.contains('recharge room')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MindCareBoosterPage()),
      );
      return;
    }
    _showFeatureDetails(name);
  }

  void _showFeatureDetails(String name) {
    final Map<String, String> featureContents = {
      'My Wellness Plan': 'Personalized daily mental-wellness roadmap.\n\n'
          'Section 1: "Daily Tasks"\n'
          '• Meditation (10 min)\n'
          '• Drink 2 L Water\n'
          '• Gratitude Note\n\n'
          'Section 2: "Weekly Goals"\n'
          '• No social media after 10 PM\n'
          '• 3 Workout Days\n\n'
          'Progress bar shows completion percentage. "Add Custom Task" button available.',
      'Reports & Analytics': 'Visual insights about your progress.\n\n'
          '• Graph: Mood Trends (7-day / 30-day)\n'
          '• Chart: Most completed wellness tasks\n'
          '• Counter: Total sessions attended\n'
          '• Insight card: "You felt better 4 times this week — great job!"\n\n'
          'See your journey through data, visualized simply.',
      'My Journal': 'Safe personal space for emotional reflection.\n\n'
          '• Add new entry (title, text, tags)\n'
          '• List of past entries with dates\n'
          '• Search or filter by tags\n\n'
          'Your private space to record thoughts and feelings.',
      'Schedule':
          'Manage upcoming counselling sessions or self-care reminders.\n\n'
              '• Calendar view\n'
              '• List of upcoming appointments + reminders\n'
              '• "Add New Event" button\n'
              '• Option: "Notify me 30 mins before session"\n\n'
              'Never miss an important wellness moment.',
      'Professional Guidance':
          'Resource hub for expert mental-health content.\n\n'
              'Explore:\n'
              '• Articles\n'
              '• Podcasts\n'
              '• Videos\n\n'
              'Each with title, short description, and read/listen/watch button.',
      'Schedule session': 'Book a counselling session for your convenient time.\n\n'
          'Select:\n'
          '• Date\n'
          '• Time slot\n'
          '• Session duration (30 / 45 / 60 mins)\n'
          '• Optional: choose counsellor or "auto assign"\n\n'
          'Confirms booking via email/notification. Syncs with counsellor\'s calendar.',
      'Mental Health':
          'AI-Based Assessment to help self-evaluate mental well-being.\n\n'
              'Answer 10–15 emotional health questions like:\n'
              '• "I\'ve been feeling anxious or restless lately."\n'
              '• "I have trouble concentrating."\n\n'
              'AI calculates score → categorizes results (Normal / Mild / Moderate / Severe).\n'
              'Generates recommendation or next step.',
      'Expert Connect':
          'Find and connect with counsellors based on your preferences.\n\n'
              'Filter by:\n'
              '• Male / Female counsellor\n'
              '• Expertise (Stress, Relationship, Career, Depression, etc.)\n'
              '• Rating or Language preference\n\n'
              'View counsellor profile & schedule session. AI suggests best counsellor match using your assessment.',
      'Meditation':
          'Guided relaxation using AI-generated meditation and ambient music.\n\n'
              'Categories:\n'
              '• Relaxation\n'
              '• Sleep\n'
              '• Focus\n'
              '• Gratitude\n'
              '• Breathing\n\n'
              'AI-generated voice and Mubert music provide guided experience.',
      'Journal': 'Space for logging emotions and experiences.\n\n'
          '• Add entry → Title, Note, Mood emoji\n'
          '• View past entries\n'
          '• Option to mark as 3-day journal or weekly summary\n\n'
          'AI suggests writing prompts and provides tone feedback.',
      'Support Groups': 'Engage with a safe and anonymous community.\n\n'
          'Choose groups:\n'
          '• Anxiety\n'
          '• Career Stress\n'
          '• Relationships\n'
          '• General Wellness\n\n'
          'Post thoughts anonymously. Comment and support other members.',
      'View Plan': 'Quick view of your wellness journey.\n\n'
          '• Today\'s tasks and goals\n'
          '• Progress indicators\n'
          '• Next scheduled activities\n'
          '• Quick actions to start/complete tasks',
      'Insights & Reports': 'Weekly mood trend snapshot + activity summary.\n\n'
          '• Your overall wellness looks balanced this week\n'
          '• Activity completion stats\n'
          '• Mood trend line\n'
          '• Recommended next steps based on your data',
      'MindCare Booster': 'Quick 1–2 minute instant wellness activities.\n\n'
          'Choose from:\n'
          '• Deep breathing cue (animation + audio)\n'
          '• Short music burst (AI-generated calm sound)\n'
          '• Positive affirmation (text/voice)\n\n'
          '"Breathe in peace... exhale stress... you\'re doing great."',
      'Advanced Care Support':
          'Counsellor-guided pathway to specialized care.\n\n'
              'Appears when counsellor recommends doctor consultation:\n'
              '• View recommended specialist\n'
              '• See available appointment slots\n'
              '• Book consultation directly\n\n'
              'Private, professional, and supportive transition to deeper care.',
      'Recharge Room': 'Your personal self-care space for relaxation.\n\n'
          'Choose your recharge mode:\n'
          '• Breathing: AI-guided deep breathing with animation\n'
          '• Music: Calming ambient or instrumental tracks\n'
          '• Affirmations: Spoken or written positive messages\n\n'
          'AI suggests duration based on your mood data.',
      'Guidelines': 'Community and usage guidelines will appear here.',
    };

    final content = featureContents[name] ??
        'This is a placeholder for "$name". Integrate the actual feature here.';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, controller) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openWallet() async {
    final updatedAmount = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const WalletPage()),
    );
    if (!mounted) return;
    if (updatedAmount != null) {
      setState(() => _walletAmount = updatedAmount);
    } else {
      await _loadWalletBalance();
    }
  }

  void _openChatbot() {
    final minChatBalance = _walletMinimums['chat'] ?? 0;
    if (_walletAmount < minChatBalance) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Low Balance'),
          content: Text(
              "You need at least ₹$minChatBalance to start a chat. Please recharge to continue."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openWallet();
              },
              child: const Text('Recharge'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatWithCounsellorPage()),
    );
  }

  void _navigateToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(profile: profile),
      ),
      (route) => false,
    );
  }

  String get _displayName {
    final nickname = profile['nickname'] as String? ?? '';
    if (nickname.trim().isNotEmpty) return nickname.trim();
    final fullName = profile['full_name'] as String? ?? '';
    if (fullName.isNotEmpty) return fullName;
    final username = profile['username'] as String? ?? '';
    return username.isNotEmpty ? username : 'Soul Support User';
  }

  @override
  Widget build(BuildContext context) {
    final profileCompletion = calculateProfileCompletion();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: const Text(
          'Soul Support',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _Palette.primary,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
                if (_walletAmount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 7,
                      backgroundColor: Colors.orange,
                      child: Text(
                        _walletAmount >= 1000 ? '₹1k' : '₹$_walletAmount',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openWallet,
          ),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: _Palette.accent,
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            onPressed: _openProfile,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(profileCompletion),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 600 ? screenWidth * 0.1 : 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(profileCompletion),
                      const SizedBox(height: 20),
                      _buildMoodCard(),
                      const SizedBox(height: 14),
                      _buildUpcomingCard(),
                      const SizedBox(height: 16),
                      const Text(
                        'QUICK ACCESS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _Palette.text,
                        ),
                      ),
                      const Text(
                        'Essential Wellness Services',
                        style: TextStyle(fontSize: 16, color: _Palette.subtext),
                      ),
                      const SizedBox(height: 20),
                      _buildQuickAccessGrid(screenWidth),
                      const SizedBox(height: 8),
                      WellnessExtras(onOpenFeature: _openFeature),
                      const SizedBox(height: 12),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 18,
            child: FloatingChatWidget(onTap: _openChatbot),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int completion) {
    final greeting = _displayName.split(' ').first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5FBF),
            Color(0xFF4AC6B7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5FBF).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $greeting',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Let’s keep your wellness momentum strong today.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMoodCard() {
    const gradients = [
      [Color(0xFFFEE3E2), Color(0xFFFFB7B6)],
      [Color(0xFFE8EAF2), Color(0xFFCED3E5)],
      [Color(0xFFF5F3FF), Color(0xFFE9E5FF)],
      [Color(0xFFE2F5EA), Color(0xFFBFE5CE)],
      [Color(0xFFFFECB8), Color(0xFFFFE08C)],
    ];
    const emojis = ['😢', '😞', '😐', '🙂', '😄'];

    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Mood Check-in',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _Palette.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap how you feel today and slide to fine tune.',
              style: TextStyle(color: _Palette.subtext, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(emojis.length, (index) {
                final idx = index + 1;
                final isSelected = _currentMoodValue.round() == idx;
                final colors = gradients[index];
                return GestureDetector(
                  onTap: _moodUpdating ? null : () => _handleMoodTap(idx.toDouble(), emojis[index]),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: isSelected ? _Palette.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          emojis[index],
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        opacity: isSelected ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _Palette.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _Palette.primary,
                inactiveTrackColor: _Palette.soft,
                trackHeight: 6,
                thumbColor: _Palette.primary,
                overlayColor: _Palette.primary.withOpacity(0.2),
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                activeTickMarkColor: Colors.white,
                inactiveTickMarkColor: Colors.white54,
              ),
              child: Slider(
                value: _currentMoodValue,
                min: 1,
                max: 5,
                divisions: 8,
                label: _currentMoodValue.toStringAsFixed(1),
                onChanged: _moodUpdating
                    ? null
                    : (value) => setState(() => _currentMoodValue = value),
                onChangeEnd: _moodUpdating ? null : (value) => _attemptMoodChange(value),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mood score: ${_currentMoodValue.toStringAsFixed(1)} / 5',
              style: const TextStyle(fontSize: 12, color: _Palette.subtext),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mood: ${_moodEmoji(_currentMoodValue)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _Palette.soft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Updates left: $_remainingMoodUpdates / $_maxMoodUpdatesPerDay',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _Palette.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Today's note: ${_currentMoodValue.round() >= 4 ? 'Feeling okay' : 'Need support'}",
              style: const TextStyle(color: _Palette.subtext, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 16, color: _Palette.subtext),
                Text(
                  'Resets at 12:00 AM (${_moodResetTimezoneLabel})',
                  style: const TextStyle(fontSize: 12, color: _Palette.subtext),
                  softWrap: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _moodEmoji(double value) {
    switch (value.round()) {
      case 1:
        return '😢';
      case 2:
        return '😞';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '🙂';
    }
  }

  String get _moodResetTimezoneLabel {
    final stored = profile['timezone'];
    String? tz;
    if (stored is String && stored.trim().isNotEmpty) {
      tz = stored.trim();
    } else if (_timeZoneName != null && _timeZoneName!.trim().isNotEmpty) {
      tz = _timeZoneName!.trim();
    }
    if (tz == null || tz.isEmpty) return 'local time';
    return tz.replaceAll('_', ' ');
  }

  Widget _buildUpcomingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCD6FF), Color(0xFFB8C5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDCD6FF).withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_today, color: _Palette.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Upcoming this week',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _Palette.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check your planned sessions and daily self-care reminders.',
                  style: TextStyle(color: _Palette.subtext, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpcomingSessionsPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _Palette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(double screenWidth) {
    return GridView.count(
      crossAxisCount: screenWidth > 600 ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: screenWidth > 600 ? 1.15 : 0.95,
      children: [
        _QuickCard(
          icon: Icons.calendar_today,
          title: 'Schedule Session',
          subtitle: 'Book Appointment',
          iconColor: Colors.blue,
          onTap: () => _openFeature('Schedule session'),
        ),
        _QuickCard(
          icon: Icons.psychology,
          title: 'Mental Health',
          subtitle: 'Take Assessment',
          iconColor: _Palette.primary,
          onTap: () => _openFeature('Mental Health'),
        ),
        _QuickCard(
          icon: Icons.person_outline,
          title: 'Expert Connect',
          subtitle: 'Find Counsellor',
          iconColor: Colors.purple,
          onTap: () => _openFeature('Expert Connect'),
        ),
        _QuickCard(
          icon: Icons.self_improvement,
          title: 'Meditation',
          subtitle: 'Start Session',
          iconColor: Colors.teal,
          onTap: () => _openFeature('Meditation'),
        ),
        _QuickCard(
          icon: Icons.note_alt_outlined,
          title: 'Wellness Journal',
          subtitle: 'Track Progress',
          iconColor: Colors.indigo,
          onTap: () => _openFeature('Wellness Journal'),
        ),
        _QuickCard(
          icon: Icons.groups_outlined,
          title: 'Support Groups',
          subtitle: 'Join Community',
          iconColor: Colors.blueGrey,
          onTap: () => _openFeature('Support Groups'),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: _Palette.cardBg,
        border: Border(top: BorderSide(color: _Palette.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FooterItem(
            icon: Icons.description,
            label: 'T&C',
            onTap: () => _openSimplePage(const TermsPage()),
          ),
          _FooterItem(
            icon: Icons.lock,
            label: 'Privacy',
            onTap: () => _openSimplePage(const PrivacyPage()),
          ),
          _FooterItem(
            icon: Icons.rule,
            label: 'Guidelines',
            onTap: () => _openFeature('Guidelines'),
          ),
          _FooterItem(
            icon: Icons.info_outline,
            label: 'About',
            onTap: () => _openSimplePage(const AboutPage()),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(int profileCompletion) {
    final username = _displayName;
    return Drawer(
      child: Container(
        color: const Color(0xFFFFFAFD),
        width: MediaQuery.of(context).size.width *
            (MediaQuery.of(context).size.width > 600 ? 0.3 : 0.85),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: _Palette.primary),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _Palette.accent,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _openProfile();
                          },
                          child: Text(
                            _formatNameForDisplay(username),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Profile Completion: $profileCompletion%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (profileCompletion.clamp(0, 100)) / 100,
                            backgroundColor: Colors.white24,
                            color: _Palette.accent,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _drawerTile('Dashboard', Icons.home, _navigateToDashboard),
            _drawerTile('Connect with Counsellor', Icons.chat, _openChatbot),
            _drawerTile(
              'History Center',
              Icons.history,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryCenterPage())),
            ),
            _drawerTile('My Wellness Plan', Icons.insights,
                () => _openFeature('My Wellness Plan')),
            _drawerTile('Reports & Analytics', Icons.bar_chart,
                () => _openFeature('Reports & Analytics')),
            _drawerTile(
                'My Journal', Icons.book, () => _openFeature('My Journal')),
            _drawerTile('Schedule', Icons.calendar_today,
                () => _openFeature('Schedule')),
            _drawerTile('Professional Guidance', Icons.medical_services,
                () => _openFeature('Professional Guidance')),
            _drawerTile(
              'Settings',
              Icons.settings,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
            const Divider(),
            _drawerTile('About Us', Icons.info,
                () => _openSimplePage(const AboutPage())),
            _drawerTile('Terms & Conditions', Icons.article,
                () => _openSimplePage(const TermsPage())),
            _drawerTile('Privacy Policy', Icons.lock,
                () => _openSimplePage(const PrivacyPage())),
            _drawerTile('Contact & Feedback', Icons.contact_support,
                () => _openSimplePage(ContactPage())),
            _drawerTile(
                'Logout', Icons.exit_to_app, () async => widget.onLogout()),
          ],
        ),
      ),
    );
  }

  void _openSimplePage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  ListTile _drawerTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _Palette.primary),
      title: Text(title, style: const TextStyle(color: Colors.black)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _Palette.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _Palette.border, width: 1),
      ),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _Palette.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor ?? _Palette.accent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _Palette.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: _Palette.subtext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FooterItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _Palette.primary, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class WellnessExtras extends StatelessWidget {
  final ValueChanged<String> onOpenFeature;

  const WellnessExtras({super.key, required this.onOpenFeature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: _Palette.cardBg,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpenFeature('Advanced Care Support'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _Palette.soft,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _Palette.soft.withOpacity(0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: _Palette.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Advanced Care Support',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _Palette.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Professional guidance when you need it',
                            style: TextStyle(
                              fontSize: 13,
                              color: _Palette.subtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _Palette.subtext),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final left = _buildInsightCard(
                  onTap: () => onOpenFeature('Insights & Reports'));
              final right = _buildBoosterCard(
                  onTap: () => onOpenFeature('MindCare Booster'));
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 12),
                    Expanded(child: right),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 12),
                  Expanded(child: right),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            color: _Palette.cardBg,
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recharge Room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _Palette.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RechargePill(
                        icon: Icons.self_improvement,
                        label: 'Breathing',
                        onTap: () => onOpenFeature('Breathing'),
                      ),
                      _RechargePill(
                        icon: Icons.music_note,
                        label: 'Music',
                        onTap: () => onOpenFeature('Music'),
                      ),
                      _RechargePill(
                        icon: Icons.record_voice_over,
                        label: 'Affirmations',
                        onTap: () => onOpenFeature('Affirmations'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => onOpenFeature('Recharge Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Start Session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInsightCard({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _Palette.border),
        ),
        elevation: 3,
        color: const Color(0xFFEBF2E7),
        child: SizedBox(
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.insights, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Insights & Reports',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoosterCard({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _Palette.border),
        ),
        elevation: 3,
        color: const Color(0xFFEBF2E7),
        child: SizedBox(
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Icon(Icons.bolt, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'MindCare Booster',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RechargePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _RechargePill({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _Palette.soft,
            child: Icon(icon, color: _Palette.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: _Palette.subtext)),
        ],
      ),
    );
  }
}

class FloatingChatWidget extends StatelessWidget {
  final VoidCallback onTap;

  const FloatingChatWidget({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF25D366),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.headset_mic, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}

class ChatWithCounsellorPage extends StatefulWidget {
  const ChatWithCounsellorPage({super.key});

  @override
  State<ChatWithCounsellorPage> createState() => _ChatWithCounsellorPageState();
}

class _ChatWithCounsellorPageState extends State<ChatWithCounsellorPage>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  String _currentFlow = 'questionnaire';
  int _currentQuestionIndex = 0;
  bool _checkingExistingChat = true;
  Map<String, dynamic>? _activeChat;
  final List<Question> _questions = [
    Question(
      text: 'What type of concern are you experiencing?',
      options: [
        'Work stress',
        'Relationship issues',
        'Anxiety',
        'Family problems',
        'Others',
      ],
    ),
    Question(
      text: 'How long have you been feeling this way?',
      options: [
        'Less than a week',
        '1-2 weeks',
        '2-4 weeks',
        'More than a month',
        'Others',
      ],
    ),
    Question(
      text: 'What would help you most right now?',
      options: [
        'Someone to talk to',
        'Coping strategies',
        'Understanding my feelings',
        'Immediate support',
        'Others',
      ],
    ),
  ];

  final List<String?> _answers = [null, null, null];
  final TextEditingController _othersController = TextEditingController();
  bool _showOthersInput = false;

  bool _showGreeting = true;

  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _checkForExistingChat();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _showGreeting) {
        setState(() => _showGreeting = false);
      }
    });
  }

  Future<void> _checkForExistingChat() async {
    try {
      final chatList = await _api.getChatList();
      
      // Find active or queued chat (not completed or cancelled)
      final activeChat = chatList.firstWhere(
        (chat) => chat['status'] == 'active' || chat['status'] == 'queued',
        orElse: () => <String, dynamic>{},
      );

      if (mounted && activeChat.isNotEmpty) {
        setState(() {
          _activeChat = activeChat;
          _checkingExistingChat = false;
          // Skip questionnaire and go directly to chat
          _currentFlow = 'chat';
          _showGreeting = false;
          
          // Add initial message if exists
          if (activeChat['initial_message'] != null && 
              activeChat['initial_message'].toString().isNotEmpty) {
            _chatMessages.add(
              ChatMessage(
                text: activeChat['initial_message'].toString(),
                isUser: true,
              ),
            );
          }
          
          // Add welcome message from counselor if chat is active
          if (activeChat['status'] == 'active') {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _addCounsellorMessage(
                  "Hello! I'm here to support you. How can I help you today?",
                );
              }
            });
          } else {
            // Chat is queued, show waiting message
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _addCounsellorMessage(
                  "Your chat request has been received. A counselor will connect with you shortly. Thank you for your patience.",
                );
              }
            });
          }
        });
      } else if (mounted) {
        setState(() {
          _checkingExistingChat = false;
        });
      }
    } catch (e) {
      // If error, just proceed with normal flow
      if (mounted) {
        setState(() {
          _checkingExistingChat = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _othersController.dispose();
    _chatInputController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _selectOption(int questionIndex, String option) {
    setState(() {
      _answers[questionIndex] = option;
      _showOthersInput = option == 'Others';
      if (option != 'Others') _othersController.clear();
    });
    if (option != 'Others') {
      Future.delayed(const Duration(milliseconds: 400), _moveToNextQuestion);
    }
  }

  void _moveToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _showOthersInput = false;
      });
    } else {
      setState(() => _currentFlow = 'actions');
    }
  }

  void _continueFromOthers() {
    if (_othersController.text.trim().isNotEmpty) {
      _answers[_currentQuestionIndex] = _othersController.text.trim();
      _moveToNextQuestion();
    }
  }

  Future<void> _startChat() async {
    // Check if there's already an active chat
    if (_activeChat != null && 
        (_activeChat!['status'] == 'active' || _activeChat!['status'] == 'queued')) {
      // Go directly to chat if already exists
      setState(() => _currentFlow = 'chat');
      return;
    }

    // Create new chat request
    try {
      final initialMessage = _answers.join(', ').trim();
      final chatData = await _api.createChat(
        initialMessage: initialMessage.isNotEmpty ? initialMessage : null,
      );
      
      if (mounted) {
        setState(() {
          _activeChat = chatData;
          _currentFlow = 'chat';
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _addCounsellorMessage(
              "Hello! I'm here to support you. Thank you for sharing your concerns. A counselor will connect with you shortly.",
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCall() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.phone, color: _Palette.primary),
            SizedBox(width: 8),
            Text('Call Counsellor'),
          ],
        ),
        content: const Text(
          'A counsellor will call you shortly. Please make sure you\'re in a comfortable and private space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call initiated (demo mode)'),
                  backgroundColor: _Palette.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Palette.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Call'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _chatMessages.add(ChatMessage(text: text, isUser: true)));
    _chatInputController.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 800), () {
      _addCounsellorMessage(_generateCounsellorResponse(text));
    });
  }

  void _addCounsellorMessage(String text) {
    setState(() => _chatMessages.add(ChatMessage(text: text, isUser: false)));
    _scrollToBottom();
  }

  String _generateCounsellorResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    final responses = [
      "I understand. It takes courage to share what you're going through. Can you tell me more about how this is affecting your daily life?",
      "Thank you for opening up. Your feelings are valid, and it's okay to feel this way. What would you like to focus on today?",
      "I hear you. Let's work through this together. Is there a specific moment or situation that triggers these feelings?",
      "You're not alone in this. Many people experience similar challenges. What coping strategies have you tried so far?",
      "I appreciate you sharing that with me. How do you feel when you think about seeking support?",
    ];

    if (lowerMessage.contains('stress') ||
        lowerMessage.contains('overwhelmed')) {
      return "Stress can be really challenging. Let's explore some relaxation techniques. Have you tried deep breathing or mindfulness exercises?";
    } else if (lowerMessage.contains('sad') ||
        lowerMessage.contains('depressed')) {
      return "I'm sorry you're feeling this way. Remember that your feelings matter. How long have you been feeling like this?";
    } else if (lowerMessage.contains('anxiety') ||
        lowerMessage.contains('worried')) {
      return "Anxiety can feel overwhelming, but there are ways to manage it. Can you identify what triggers your anxiety?";
    } else if (lowerMessage.contains('thank')) {
      return "You're very welcome. I'm here whenever you need support. Is there anything else you'd like to discuss?";
    }
    return responses[DateTime.now().millisecond % responses.length];
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildGreeting() {
    if (_showGreeting) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.sentiment_satisfied_alt,
                    size: 40, color: _Palette.primary),
              ),
              SizedBox(height: 24),
              Text(
                'Hello! 👋',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _Palette.text,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "I'm here to help you today",
                style: TextStyle(fontSize: 18, color: _Palette.subtext),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuestionnaire() {
    if (_currentFlow != 'questionnaire') return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: _Palette.primary,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _questions[_currentQuestionIndex].text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _Palette.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._questions[_currentQuestionIndex].options.map((option) {
                    final isSelected =
                        _answers[_currentQuestionIndex] == option;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () =>
                            _selectOption(_currentQuestionIndex, option),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? _Palette.primary : _Palette.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? _Palette.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? _Palette.primary
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  color: isSelected
                                      ? _Palette.primary
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_showOthersInput) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _othersController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Please describe your concern...',
                        filled: true,
                        fillColor: _Palette.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: _Palette.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _continueFromOthers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _Palette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _questions.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentQuestionIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentQuestionIndex >= index
                        ? _Palette.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_currentFlow != 'actions') return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.sentiment_satisfied_alt,
                    size: 40, color: _Palette.primary),
              ),
              const SizedBox(height: 32),
              const Text(
                'Thank you for sharing!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _Palette.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How would you like to connect?',
                style: TextStyle(fontSize: 16, color: _Palette.subtext),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: _startChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Palette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.chat_bubble_outline, size: 28),
                      SizedBox(width: 12),
                      Text(
                        '🗨️ Chat with Us',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: _startCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _Palette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: _Palette.primary, width: 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.phone_outlined, size: 28),
                      SizedBox(width: 12),
                      Text(
                        '📞 Call with Us',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    if (_currentFlow != 'chat') return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) =>
                _buildChatBubble(_chatMessages[index]),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: _Palette.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _Palette.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              backgroundColor: _Palette.primary,
              child: Icon(Icons.sentiment_satisfied_alt, color: Colors.white),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? _Palette.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.white : Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            const CircleAvatar(
              backgroundColor: _Palette.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat with Counsellor',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        backgroundColor: _Palette.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: _currentFlow == 'chat'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentFlow = 'actions';
                    _chatMessages.clear();
                  });
                },
              )
            : null,
      ),
      body: _checkingExistingChat
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showGreeting
                  ? _buildGreeting()
                  : _currentFlow == 'questionnaire'
                      ? _buildQuestionnaire()
                      : _currentFlow == 'actions'
                          ? _buildActionButtons()
                          : _buildChatInterface(),
            ),
    );
  }
}

class Question {
  final String text;
  final List<String> options;

  Question({required this.text, required this.options});
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;

  const ProfilePage({super.key, required this.initialProfile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _ageCtrl;
  String _gender = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initialProfile['full_name'] ?? '');
    _nicknameCtrl =
        TextEditingController(text: widget.initialProfile['nickname'] ?? '');
    _emailCtrl =
        TextEditingController(text: widget.initialProfile['email'] ?? '');
    _phoneCtrl =
        TextEditingController(text: widget.initialProfile['phone'] ?? '');
    _ageCtrl = TextEditingController(
      text: widget.initialProfile['age'] != null
          ? '${widget.initialProfile['age']}'
          : '',
    );
    _gender = widget.initialProfile['gender'] ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _Palette.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _Palette.primary),
      ),
      filled: true,
      fillColor: _Palette.cardBg,
    );
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final updated = {
        'full_name': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _gender,
      };
      Navigator.pop(context, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completionFields = <String>[
      _nicknameCtrl.text,
      _nameCtrl.text,
      _emailCtrl.text,
      _phoneCtrl.text,
      _ageCtrl.text,
      _gender,
    ];
    final completion =
        completionFields.where((value) => value.trim().isNotEmpty).length;
    final completionPercent =
        ((completion / completionFields.length) * 100).round();

    final displayName = _nicknameCtrl.text.isNotEmpty
        ? _nicknameCtrl.text
        : (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Your Name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: _Palette.soft,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: _Palette.primary,
              child: Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Profile Completion: $completionPercent%',
                    style: const TextStyle(color: Colors.black)),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: completionPercent / 100,
                    color: _Palette.primary,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'Personal Information',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black),
                      ),
                    ),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration('Full Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter name'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nicknameCtrl,
                      decoration: _inputDecoration(
                          'Nickname (shown to counsellors & doctors)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _ageCtrl,
                      decoration: _inputDecoration('Age'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _gender.isNotEmpty ? _gender : null,
                      decoration: _inputDecoration('Gender'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                        DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say')),
                      ],
                      onChanged: (value) =>
                          setState(() => _gender = value ?? ''),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 18, bottom: 4),
                      child: Text(
                        'Contact Details',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black),
                      ),
                    ),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _inputDecoration('Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter email'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: _inputDecoration('Phone Number'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Palette.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFF6DC9F3),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text('Our Vision', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
                'To bring mental peace and support through technology and empathy.'),
            SizedBox(height: 12),
            Text('Our Approach', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
                'AI + professional counselling synergy for continuous wellbeing.'),
            SizedBox(height: 12),
            Text('Our Team', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
                'Certified psychologists, clinical advisors, and wellness coaches.'),
            SizedBox(height: 12),
            Text('Ethics', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Confidentiality, safety, and no forced disclosure.'),
            SizedBox(height: 12),
            Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('support@example.com'),
            SizedBox(height: 20),
            Text('Location: Hyderabad, India'),
          ],
        ),
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  final String demoText =
      'Terms & Conditions content placeholder. Use the actual legal content you prepared here (T&C, crisis protocol, privacy exceptions, limitations of liability).';

  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions',
            style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFF2CCDBD),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: Text(demoText)),
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  final String demoText =
      'Privacy Policy placeholder. Explain how data is stored, shared, and emergency disclosure flow.';

  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Privacy Policy', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFF4BD6EB),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: Text(demoText)),
      ),
    );
  }
}

class ContactPage extends StatelessWidget {
  ContactPage({super.key});

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact & Feedback',
            style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFF65D9EB),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send us a message or request help.'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Write your message...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message sent (demo)')),
                );
                _controller.clear();
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
