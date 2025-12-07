import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:common/api/api_client.dart';
import 'chat_history_viewer.dart';
import 'call_details_viewer.dart';

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
  
  // Chat history state
  bool _loadingChats = true;
  String? _chatsError;
  List<Map<String, dynamic>> _chats = [];
  
  // Call history state
  bool _loadingCalls = false;
  String? _callsError;
  List<Map<String, dynamic>> _activeCalls = [];
  List<Map<String, dynamic>> _callHistory = [];

  // Payment history state
  bool _loadingPayments = false;
  String? _paymentsError;
  WalletInfo? _walletData;

  // Mood history state
  bool _loadingMoodHistory = false;
  String? _moodHistoryError;
  Map<String, dynamic>? _moodHistoryData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadChats();
    _loadCalls();
    _loadPayments();
    _loadMoodHistory();
    
    // Listen to tab changes to load data when switching tabs
    _tabController.addListener(() {
      if (_tabController.index == 0 && _chats.isEmpty && !_loadingChats) {
        _loadChats();
      } else if (_tabController.index == 1 && _callHistory.isEmpty && _activeCalls.isEmpty && !_loadingCalls) {
        _loadCalls();
      } else if (_tabController.index == 2 && _walletData == null && !_loadingPayments) {
        _loadPayments();
      } else if (_tabController.index == 3 && _moodHistoryData == null && !_loadingMoodHistory) {
        _loadMoodHistory();
      }
    });
  }

  Future<void> _loadChats({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loadingChats = true;
        _chatsError = null;
      });
    } else {
      setState(() {
        _chatsError = null;
      });
    }

    try {
      final chats = await _api.getChatList();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loadingChats = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _chatsError = error.message;
        _loadingChats = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chatsError = 'Unable to load chat history. Please try again.';
        _loadingChats = false;
      });
    }
  }

  Future<void> _refreshChats() => _loadChats(showLoader: false);

  Future<void> _loadPayments() async {
    setState(() {
      _loadingPayments = true;
      _paymentsError = null;
    });

    try {
      final walletData = await _api.getWallet();
      if (!mounted) return;
      setState(() {
        _walletData = walletData;
        _loadingPayments = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _paymentsError = error.message;
        _loadingPayments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _paymentsError = 'Unable to load wallet information. Please try again.';
        _loadingPayments = false;
      });
    }
  }

  Future<void> _refreshPayments() => _loadPayments();

  Future<void> _loadMoodHistory() async {
    setState(() {
      _loadingMoodHistory = true;
      _moodHistoryError = null;
    });

    try {
      final data = await _api.getMoodHistory(days: 30);
      if (!mounted) return;
      setState(() {
        _moodHistoryData = data;
        _loadingMoodHistory = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _moodHistoryError = error.message;
        _loadingMoodHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _moodHistoryError = 'Unable to load mood history. Please try again.';
        _loadingMoodHistory = false;
      });
    }
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
            Tab(icon: Icon(Icons.mood), text: 'Mood'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatHistory(), _buildCallHistory(), _buildPayments(), _buildMoodHistory()],
      ),
    );
  }

  Widget _buildChatHistory() {
    if (_loadingChats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatsError != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          Text(
            _chatsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppPalette.text),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadChats,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_chats.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          const Text(
            'No chat history yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your chat conversations with counsellors will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.subtext),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshChats,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final counsellorName = chat['counsellor_username'] as String? ?? 
                                chat['counsellor'] as String? ?? 
                                'Counsellor';
          final status = chat['status'] as String? ?? 'unknown';
          final createdAt = chat['created_at'] as String?;
          final updatedAt = chat['updated_at'] as String?;
          
          DateTime? date;
          String dateText = '';
          String timeText = '';
          
          try {
            if (updatedAt != null && updatedAt.isNotEmpty) {
              date = DateTime.parse(updatedAt);
            } else if (createdAt != null && createdAt.isNotEmpty) {
              date = DateTime.parse(createdAt);
            }
            if (date != null) {
              dateText = DateFormat('dd/MM/yyyy').format(date);
              timeText = DateFormat('h:mm a').format(date);
            }
          } catch (e) {
            dateText = 'Date unavailable';
          }

          // Status display
          String statusText = status;
          Color statusColor = AppPalette.subtext;
          if (status == 'active') {
            statusText = 'Active';
            statusColor = Colors.green;
          } else if (status == 'completed') {
            statusText = 'Completed';
            statusColor = Colors.blue;
          } else if (status == 'queued') {
            statusText = 'Waiting';
            statusColor = Colors.orange;
          }

          final chatId = chat['id'] as int?;
          
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
                counsellorName,
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: AppPalette.subtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Text(
                dateText,
                style: const TextStyle(
                  color: AppPalette.subtext,
                  fontSize: 12,
                ),
              ),
              onTap: chatId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatHistoryViewer(
                            chatId: chatId,
                            counsellorName: counsellorName,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadCalls({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loadingCalls = true;
        _callsError = null;
      });
    } else {
      setState(() {
        _callsError = null;
      });
    }

    try {
      final response = await _api.getCallHistory();
      if (!mounted) return;
      
      final activeCalls = (response['active_calls'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];
      final history = (response['history'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];
      
      setState(() {
        _activeCalls = activeCalls;
        _callHistory = history;
        _loadingCalls = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _callsError = error.message;
        _loadingCalls = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _callsError = 'Unable to load call history. Please try again.';
        _loadingCalls = false;
      });
    }
  }

  Future<void> _refreshCalls() => _loadCalls(showLoader: false);

  Widget _buildCallHistory() {
    if (_loadingCalls) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_callsError != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.call, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          Text(
            _callsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppPalette.text),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadCalls,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final allCalls = [..._activeCalls, ..._callHistory];
    
    if (allCalls.isEmpty) {
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
            'Once you speak with a counsellor, details such as duration and date will be listed below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.subtext),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCalls,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: allCalls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final call = allCalls[index];
          final callType = call['call_type'] as String? ?? 'video';
          final status = call['status'] as String? ?? '';
          final counsellorName = call['counsellor_username'] as String? ?? 'Counsellor';
          final durationFormatted = call['duration_formatted'] as String? ?? 
              (call['duration_seconds'] != null 
                  ? '${(call['duration_seconds'] as int) ~/ 60} mins'
                  : 'N/A');
          
          // Parse created_at or ended_at for date display
          String? dateStr;
          try {
            final dateTimeStr = call['ended_at'] as String? ?? call['created_at'] as String?;
            if (dateTimeStr != null) {
              final dateTime = DateTime.parse(dateTimeStr);
              dateStr = DateFormat('dd/MM/yyyy').format(dateTime);
            }
          } catch (e) {
            dateStr = null;
          }
          
          // Determine status color and text
          Color statusColor = AppPalette.subtext;
          String statusText = status;
          if (status == 'ended') {
            statusText = 'Completed';
            statusColor = Colors.green;
          } else if (status == 'active') {
            statusText = 'Active';
            statusColor = AppPalette.primary;
          } else if (status == 'missed') {
            statusText = 'Missed';
            statusColor = Colors.orange;
          } else if (status == 'cancelled') {
            statusText = 'Cancelled';
            statusColor = Colors.red;
          }

          final callId = call['id'] as int?;
          
          return Card(
            color: AppPalette.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppPalette.primary,
                child: Icon(
                  callType == 'video' ? Icons.videocam : Icons.call,
                  color: Colors.white,
                ),
              ),
              title: Text(
                counsellorName,
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duration: $durationFormatted',
                    style: const TextStyle(color: AppPalette.subtext),
                  ),
                  if (statusText.isNotEmpty)
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                ],
              ),
              trailing: dateStr != null
                  ? Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppPalette.subtext,
                        fontSize: 12,
                      ),
                    )
                  : null,
              onTap: callId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallDetailsViewer(
                            callId: callId,
                            counsellorName: counsellorName,
                            callData: call,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPayments() {
    if (_loadingPayments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentsError != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.payments, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          Text(
            _paymentsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppPalette.text),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadPayments,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final walletMinutes = _walletData?.balance ?? 0;
    final rates = _walletData?.rates ?? {};

    return RefreshIndicator(
      onRefresh: _refreshPayments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallet Balance Card
          Card(
            color: AppPalette.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: AppPalette.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹$walletMinutes',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Service Rates
          if (rates.isNotEmpty) ...[
            const Text(
              'Service Rates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppPalette.text,
              ),
            ),
            const SizedBox(height: 8),
            ...rates.entries.map((entry) {
              final service = entry.key;
              final rate = entry.value;
              return Card(
                color: AppPalette.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppPalette.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppPalette.soft,
                    child: Icon(
                      service == 'call' ? Icons.phone : Icons.chat,
                      color: AppPalette.primary,
                    ),
                  ),
                  title: Text(
                    service.toUpperCase(),
                    style: const TextStyle(
                      color: AppPalette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '₹$rate per minute',
                    style: const TextStyle(color: AppPalette.subtext),
                  ),
                ),
              );
            }),
          ],
          
          const SizedBox(height: 24),
          const Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            color: AppPalette.cardBg,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Transaction history will be available soon. '
                'You can recharge your wallet from the wallet section.',
                style: TextStyle(color: AppPalette.subtext),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodHistory() {
    if (_loadingMoodHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_moodHistoryError != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const Icon(Icons.mood, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          Text(
            _moodHistoryError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppPalette.text),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadMoodHistory,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    // Check if data exists and has entries (API returns 'recent_logs', not 'entries')
    final recentLogs = _moodHistoryData?['recent_logs'];
    if (_moodHistoryData == null || recentLogs == null || (recentLogs as List).isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          const Icon(Icons.mood, size: 48, color: AppPalette.subtext),
          const SizedBox(height: 12),
          const Text(
            'Your mood history will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start tracking your mood to see your history and trends.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.subtext),
          ),
        ],
      );
    }

    final entries = (recentLogs as List).cast<Map<String, dynamic>>();
    
    return RefreshIndicator(
      onRefresh: _loadMoodHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final value = entry['value'] as num? ?? 0;
          final dateStr = entry['recorded_at'] as String? ?? '';
          
          DateTime? date;
          String formattedDate = '';
          try {
            if (dateStr.isNotEmpty) {
              date = DateTime.parse(dateStr);
              formattedDate = DateFormat('dd/MM/yyyy').format(date);
            }
          } catch (e) {
            formattedDate = dateStr;
          }

          // Determine mood emoji and color based on value
          String moodEmoji = '😐';
          Color moodColor = AppPalette.subtext;
          if (value >= 4.5) {
            moodEmoji = '😊';
            moodColor = Colors.green;
          } else if (value >= 3.5) {
            moodEmoji = '🙂';
            moodColor = Colors.lightGreen;
          } else if (value >= 2.5) {
            moodEmoji = '😐';
            moodColor = Colors.orange;
          } else if (value >= 1.5) {
            moodEmoji = '😔';
            moodColor = Colors.deepOrange;
          } else {
            moodEmoji = '😢';
            moodColor = Colors.red;
          }

          return Card(
            color: AppPalette.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: moodColor.withOpacity(0.1),
                child: Text(
                  moodEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                'Mood: ${value.toStringAsFixed(1)}/5.0',
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                formattedDate.isNotEmpty ? formattedDate : 'Date not available',
                style: const TextStyle(color: AppPalette.subtext),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: moodColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: moodColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

