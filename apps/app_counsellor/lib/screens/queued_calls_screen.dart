import 'package:flutter/material.dart';
import 'package:common/api/api_client.dart';
import 'package:common/widgets/widgets.dart';
import 'video_call_screen.dart';
import 'dart:async';

class QueuedCallsScreen extends StatefulWidget {
  const QueuedCallsScreen({super.key});

  @override
  State<QueuedCallsScreen> createState() => _QueuedCallsScreenState();
}

class _QueuedCallsScreenState extends State<QueuedCallsScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _queuedCalls = [];
  List<Map<String, dynamic>> _activeCalls = [];
  List<Map<String, dynamic>> _previousCalls = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadQueuedCalls();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadQueuedCalls();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQueuedCalls() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('[QueuedCallsScreen] Fetching queued calls from API...');
      final queuedCallsData = await _api.getQueuedCalls();
      print('[QueuedCallsScreen] API returned ${queuedCallsData.length} queued calls');
      
      // Also fetch all calls to get active/previous calls
      print('[QueuedCallsScreen] Fetching all calls to get active/previous calls...');
      final allCallsData = await _api.getCalls();
      print('[QueuedCallsScreen] API returned ${allCallsData.length} total calls');
      
      // Separate into active and previous calls
      final activeCallsData = allCallsData.where((call) {
        final status = call['status']?.toString().toLowerCase();
        return status == 'active' || status == 'ringing';
      }).toList();
      
      final previousCallsData = allCallsData.where((call) {
        final status = call['status']?.toString().toLowerCase();
        return status == 'ended' || status == 'completed' || status == 'missed' || status == 'cancelled';
      }).toList();
      
      // Sort active calls by most recent first
      activeCallsData.sort((a, b) {
        final aTime = a['updated_at'] ?? a['created_at'];
        final bTime = b['updated_at'] ?? b['created_at'];
        return _compareDates(bTime, aTime);
      });
      
      // Sort previous calls by most recent first
      previousCallsData.sort((a, b) {
        final aTime = a['ended_at'] ?? a['updated_at'] ?? a['created_at'];
        final bTime = b['ended_at'] ?? b['updated_at'] ?? b['created_at'];
        return _compareDates(bTime, aTime);
      });
      
      print('[QueuedCallsScreen] Found ${activeCallsData.length} active calls and ${previousCallsData.length} previous calls');
      
      if (mounted) {
        setState(() {
          _queuedCalls = queuedCallsData;
          _activeCalls = activeCallsData;
          _previousCalls = previousCallsData;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      print('[QueuedCallsScreen] Error loading calls: $e');
      print('[QueuedCallsScreen] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  int _compareDates(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    
    try {
      final aDate = DateTime.parse(a.toString());
      final bDate = DateTime.parse(b.toString());
      return aDate.compareTo(bDate);
    } catch (e) {
      return 0;
    }
  }

  Future<void> _acceptCall(Map<String, dynamic> call) async {
    try {
      setState(() {
        _loading = true;
      });

      print('[QueuedCallsScreen] Accepting call ${call['id']}');
      final callData = await _api.acceptCall(call['id'] as int);
      
      if (mounted) {
        setState(() {
          _loading = false;
        });
        
        // Navigate to call screen
        final callId = callData['id'] as int;
        final callType = callData['call_type'] as String? ?? 'video';
        final userName = call['user_username'] as String? ?? 'User';
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              callId: callId,
              counsellorName: null,
              isVideoCall: callType == 'video',
            ),
          ),
        );
        
        // Refresh after returning from call
        _loadQueuedCalls();
      }
    } catch (e) {
      print('[QueuedCallsScreen] Error accepting call: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        showErrorSnackBar(context, 'Failed to accept call: ${e.toString()}');
      }
    }
  }

  String _formatCallType(String? callType) {
    switch (callType?.toLowerCase()) {
      case 'video':
        return 'Video Call';
      case 'voice':
        return 'Voice Call';
      default:
        return 'Call';
    }
  }

  IconData _getCallTypeIcon(String? callType) {
    switch (callType?.toLowerCase()) {
      case 'video':
        return Icons.videocam;
      case 'voice':
        return Icons.phone;
      default:
        return Icons.call;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'ringing':
      case 'scheduled':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'ended':
      case 'completed':
        return Colors.grey;
      case 'missed':
        return Colors.red;
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return timestamp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queued Calls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQueuedCalls,
          ),
        ],
      ),
      body: _loading && _queuedCalls.isEmpty && _activeCalls.isEmpty && _previousCalls.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _queuedCalls.isEmpty && _activeCalls.isEmpty && _previousCalls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadQueuedCalls,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.queue),
                                SizedBox(width: 8),
                                Text('Queued'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_in_talk),
                                SizedBox(width: 8),
                                Text('Active'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history),
                                SizedBox(width: 8),
                                Text('History'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildQueuedCallsTab(),
                            _buildActiveCallsTab(),
                            _buildPreviousCallsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildQueuedCallsTab() {
    if (_loading && _queuedCalls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_queuedCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_disabled, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No queued calls',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for incoming calls...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueuedCalls,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _queuedCalls.length,
        itemBuilder: (context, index) {
          final call = _queuedCalls[index];
          final callId = call['id'];
          final userName = call['user_username'] ?? 'Unknown User';
          final callType = call['call_type'] ?? 'video';
          final status = call['status'] ?? 'ringing';
          final createdAt = call['created_at'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(status).withOpacity(0.2),
                child: Icon(
                  _getCallTypeIcon(callType),
                  color: _getStatusColor(status),
                ),
              ),
              title: Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getCallTypeIcon(callType),
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCallType(callType),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton.icon(
                onPressed: () => _acceptCall(call),
                icon: const Icon(Icons.phone, size: 20),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveCallsTab() {
    if (_loading && _activeCalls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_in_talk_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No active calls',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueuedCalls,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeCalls.length,
        itemBuilder: (context, index) {
          final call = _activeCalls[index];
          final userName = call['user_username'] ?? 'Unknown User';
          final callType = call['call_type'] ?? 'video';
          final status = call['status'] ?? 'active';
          final startedAt = call['started_at'];
          final durationSeconds = call['duration_seconds'] as int? ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(status).withOpacity(0.2),
                child: Icon(
                  _getCallTypeIcon(callType),
                  color: _getStatusColor(status),
                ),
              ),
              title: Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getCallTypeIcon(callType),
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCallType(callType),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Started: ${_formatTimestamp(startedAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  if (durationSeconds > 0)
                    Text(
                      'Duration: ${_formatDuration(durationSeconds)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: _getStatusColor(status),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviousCallsTab() {
    if (_loading && _previousCalls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_previousCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No call history',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueuedCalls,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _previousCalls.length,
        itemBuilder: (context, index) {
          final call = _previousCalls[index];
          final userName = call['user_username'] ?? 'Unknown User';
          final callType = call['call_type'] ?? 'video';
          final status = call['status'] ?? 'ended';
          final endedAt = call['ended_at'] ?? call['updated_at'];
          final durationSeconds = call['duration_seconds'] as int? ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            color: Colors.grey.shade50,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(status).withOpacity(0.2),
                child: Icon(
                  _getCallTypeIcon(callType),
                  color: _getStatusColor(status),
                ),
              ),
              title: Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getCallTypeIcon(callType),
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCallType(callType),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ended: ${_formatTimestamp(endedAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  if (durationSeconds > 0)
                    Text(
                      'Duration: ${_formatDuration(durationSeconds)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: _getStatusColor(status),
              ),
            ),
          );
        },
      ),
    );
  }
}

