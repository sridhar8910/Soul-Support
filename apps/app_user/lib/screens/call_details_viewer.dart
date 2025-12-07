import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:common/api/api_client.dart';

class CallDetailsViewer extends StatefulWidget {
  final int callId;
  final String counsellorName;
  final Map<String, dynamic>? callData;

  const CallDetailsViewer({
    super.key,
    required this.callId,
    required this.counsellorName,
    this.callData,
  });

  @override
  State<CallDetailsViewer> createState() => _CallDetailsViewerState();
}

class _CallDetailsViewerState extends State<CallDetailsViewer> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _callData;

  @override
  void initState() {
    super.initState();
    if (widget.callData != null) {
      _callData = widget.callData;
      _loading = false;
    } else {
      _loadCallDetails();
    }
  }

  Future<void> _loadCallDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try to get call from history first
      final historyResponse = await _api.getCallHistory();
      final allCalls = [
        ...(historyResponse['active_calls'] as List<dynamic>? ?? []),
        ...(historyResponse['history'] as List<dynamic>? ?? []),
      ];
      
      final call = allCalls.firstWhere(
        (c) => (c as Map<String, dynamic>)['id'] == widget.callId,
        orElse: () => <String, dynamic>{},
      );
      
      if (!mounted) return;
      
      if (call.isEmpty) {
        setState(() {
          _error = 'Call not found';
          _loading = false;
        });
        return;
      }
      
      setState(() {
        _callData = call as Map<String, dynamic>;
        _loading = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load call details. Please try again.';
        _loading = false;
      });
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return 'N/A';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ended':
        return Colors.green;
      case 'active':
        return const Color(0xFF8B5FBF);
      case 'missed':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      case 'ringing':
        return Colors.blue;
      case 'scheduled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'ended':
        return 'Completed';
      case 'active':
        return 'Active';
      case 'missed':
        return 'Missed';
      case 'cancelled':
        return 'Cancelled';
      case 'ringing':
        return 'Ringing';
      case 'scheduled':
        return 'Scheduled';
      default:
        return status ?? 'Unknown';
    }
  }

  IconData _getCallTypeIcon(String? callType) {
    return callType == 'video' ? Icons.videocam : Icons.phone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.counsellorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_callData != null)
              Text(
                _getStatusText(_callData!['status'] as String?),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: _getStatusColor(_callData!['status'] as String?),
                ),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8B5FBF),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCallDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _callData == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Call details not available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Call Type and Status Card
                          Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: _getStatusColor(_callData!['status'] as String?)
                                        .withOpacity(0.1),
                                    child: Icon(
                                      _getCallTypeIcon(_callData!['call_type'] as String?),
                                      color: _getStatusColor(_callData!['status'] as String?),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _callData!['call_type'] == 'video'
                                              ? 'Video Call'
                                              : 'Voice Call',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1B41),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                                    _callData!['status'] as String?)
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getStatusText(_callData!['status'] as String?),
                                            style: TextStyle(
                                              color: _getStatusColor(
                                                  _callData!['status'] as String?),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Duration Card
                          if (_callData!['duration_seconds'] != null &&
                              (_callData!['duration_seconds'] as int) > 0)
                            Card(
                              color: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.timer,
                                      color: Color(0xFF8B5FBF),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Duration',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDuration(
                                              _callData!['duration_seconds'] as int?),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1B41),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_callData!['duration_seconds'] != null &&
                              (_callData!['duration_seconds'] as int) > 0)
                            const SizedBox(height: 16),
                          
                          // Timestamps
                          Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Timestamps',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1B41),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(
                                    'Created',
                                    _formatDateTime(_callData!['created_at'] as String?),
                                    Icons.add_circle_outline,
                                  ),
                                  if (_callData!['started_at'] != null) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      'Started',
                                      _formatDateTime(_callData!['started_at'] as String?),
                                      Icons.play_circle_outline,
                                    ),
                                  ],
                                  if (_callData!['ended_at'] != null) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      'Ended',
                                      _formatDateTime(_callData!['ended_at'] as String?),
                                      Icons.stop_circle,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          
                          // Notes
                          if (_callData!['notes'] != null &&
                              (_callData!['notes'] as String).isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Card(
                              color: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.note,
                                          color: Color(0xFF8B5FBF),
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Notes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1B41),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _callData!['notes'] as String,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B6B8E),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1B41),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

