import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:common/api/api_client.dart';

class AppPalette {
  static const primary = Color(0xFF8B5FBF);
  static const accent = Color(0xFF4AC6B7);
  static const bg = Color(0xFFFDFBFF);
  static const cardBg = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1B41);
  static const subtext = Color(0xFF6B6B8E);
  static const soft = Color(0xFFF0EBFF);
  static const border = Color(0xFFF5F3FF);
}

class HistoryCenterPage extends StatefulWidget {
  const HistoryCenterPage({super.key});

  @override
  State<HistoryCenterPage> createState() => _HistoryCenterPageState();
}

class _HistoryCenterPageState extends State<HistoryCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final ApiClient _api = ApiClient();
  bool _loadingSessions = true;
  String? _sessionsError;
  List<UpcomingSessionItem> _sessions = const <UpcomingSessionItem>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  Future<void> _loadSessions({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loadingSessions = true;
        _sessionsError = null;
      });
    } else {
      setState(() {
        _sessionsError = null;
      });
    }

    try {
      final sessions = await _api.fetchUpcomingSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _sessionsError = error.message;
        _loadingSessions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessionsError = 'Unable to load session history. Please try again.';
        _loadingSessions = false;
      });
    }
  }

  Future<void> _refreshSessions() => _loadSessions(showLoader: false);

  List<UpcomingSessionItem> get _sortedSessions {
    final list = [..._sessions];
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History Center',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        foregroundColor: AppPalette.primary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppPalette.primary,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            Tab(icon: Icon(Icons.call_outlined), text: 'Calls'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatHistory(), _buildCallHistory(), _buildPayments()],
      ),
    );
  }

  Widget _buildChatHistory() {
    if (_loadingSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessionsError != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.history, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          Text(
            _sessionsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppPalette.text),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadSessions,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final orderedSessions = _sortedSessions;
    if (orderedSessions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          const Icon(Icons.chat_bubble_outline,
              size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          const Text(
            'Session chat history will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'After each counselling session, a summary of the conversation will be listed below. '
            'Here is a sample entry to show how it will look:',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.subtext),
          ),
          const SizedBox(height: 24),
          Card(
            color: AppPalette.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: const ListTile(
              leading: CircleAvatar(
                backgroundColor: AppPalette.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                'Therapist Sample',
                style: TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Session summary available.\n3:30 PM',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '14/11/2025',
                style: TextStyle(
                  color: AppPalette.subtext,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSessions,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: orderedSessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final session = orderedSessions[index];
          final now = DateTime.now();
          final isPast = session.startTime.isBefore(now);
          final counsellor = session.counsellorName.isNotEmpty
              ? session.counsellorName
              : session.title.isNotEmpty
                  ? session.title
                  : 'Counsellor';
          final summary = session.notes.isNotEmpty
              ? session.notes
              : isPast
                  ? 'Session summary available.'
                  : 'Scheduled ${DateFormat('EEE, MMM d').format(session.startTime)}';
          final dateText = DateFormat('dd/MM/yyyy').format(session.startTime);
          final timeText = DateFormat('h:mm a').format(session.startTime);

          return Card(
            color: AppPalette.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppPalette.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                counsellor,
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '$summary\n$timeText',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                dateText,
                style: const TextStyle(
                  color: AppPalette.subtext,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallHistory() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        const Icon(Icons.call, size: 48, color: AppPalette.subtext),
        const SizedBox(height: 12),
        const Text(
          'Your call history will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppPalette.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Once you speak with a counsellor, details such as duration and date will be listed below. '
          'Here is a sample entry for reference:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.subtext),
        ),
        const SizedBox(height: 24),
        Card(
          color: AppPalette.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppPalette.border),
          ),
          child: const ListTile(
            leading: CircleAvatar(
              backgroundColor: AppPalette.primary,
              child: Icon(Icons.call, color: Colors.white),
            ),
            title: Text(
              'Therapist Sample',
              style: TextStyle(color: AppPalette.text),
            ),
            subtitle: Text('Duration: 20 mins'),
            trailing: Text(
              '14/11/2025',
              style: TextStyle(color: AppPalette.subtext, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayments() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        const Icon(Icons.payments, size: 48, color: AppPalette.subtext),
        const SizedBox(height: 12),
        const Text(
          'Payment records will show here',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppPalette.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'When you purchase sessions or recharge your wallet, a receipt entry will be listed below. '
          'Here is an illustrative example:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.subtext),
        ),
        const SizedBox(height: 24),
        Card(
          color: AppPalette.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppPalette.border),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppPalette.soft,
              child: Icon(Icons.receipt_long, color: AppPalette.primary),
            ),
            title: const Text(
              '#TXN1204',
              style: TextStyle(color: AppPalette.text),
            ),
            subtitle: const Text('UPI • 499 INR'),
            trailing: SizedBox(
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '05/11/2025',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

