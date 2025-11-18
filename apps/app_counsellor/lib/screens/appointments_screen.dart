import 'package:flutter/material.dart';
import '../models/session.dart';
import '../utils/responsive.dart';
import 'chat_session_screen.dart';
import 'audio_call_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String _selectedFilter = 'all';

  final List<Session> sessions = [
    Session(
      id: 'session_1',
      clientId: 'client_1',
      clientName: 'John Doe',
      counselorId: 'counselor_1',
      scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      type: SessionType.voice,
      status: SessionStatus.scheduled,
      durationMinutes: 60,
    ),
    Session(
      id: 'session_2',
      clientId: 'client_2',
      clientName: 'Jane Smith',
      counselorId: 'counselor_1',
      scheduledTime: DateTime.now().add(const Duration(hours: 3)),
      type: SessionType.chat,
      status: SessionStatus.scheduled,
      durationMinutes: 45,
    ),
    Session(
      id: 'session_3',
      clientId: 'client_3',
      clientName: 'Mike Wilson',
      counselorId: 'counselor_1',
      scheduledTime: DateTime.now().subtract(const Duration(days: 1)),
      type: SessionType.voice,
      status: SessionStatus.completed,
      durationMinutes: 60,
    ),
    Session(
      id: 'session_4',
      clientId: 'client_4',
      clientName: 'Sarah Brown',
      counselorId: 'counselor_1',
      scheduledTime: DateTime.now().subtract(const Duration(hours: 5)),
      type: SessionType.chat,
      status: SessionStatus.noShow,
      durationMinutes: 60,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _filterSessions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // Show calendar view
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
                vertical: 12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Upcoming', 'upcoming'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', 'completed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'cancelled'),
                  ],
                ),
              ),
            ),

            // Sessions List
            Expanded(
              child: filteredSessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: Responsive.isMobile(context) ? 56 : 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No appointments found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: Responsive.body(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.horizontalPadding(context),
                      ),
                      itemCount: filteredSessions.length,
                      itemBuilder: (context, index) {
                        final session = filteredSessions[index];
                        return _buildSessionCard(session);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildSessionCard(Session session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: InkWell(
        onTap: () {
          // Navigate to appropriate session screen based on type
          if (session.type == SessionType.chat) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatSessionScreen(session: session),
              ),
            );
          } else if (session.type == SessionType.voice) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AudioCallScreen(session: session),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(Responsive.isMobile(context) ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: Responsive.isMobile(context) ? 22 : 24,
                    backgroundColor: _getSessionTypeColor(
                      session.type,
                    ).withOpacity(0.2),
                    child: Icon(
                      _getSessionTypeIcon(session.type),
                      color: _getSessionTypeColor(session.type),
                      size: Responsive.isMobile(context) ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.clientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(session.scheduledTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(session.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    session.type.name.toUpperCase(),
                    _getSessionTypeColor(session.type),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip('${session.durationMinutes} min', Colors.grey),
                  if (session.isEscalated) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip('ESCALATED', Colors.red),
                  ],
                  if (session.riskLevel != RiskLevel.none) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      session.riskLevel.name.toUpperCase(),
                      _getRiskLevelColor(session.riskLevel),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SessionStatus status) {
    Color color;
    String text;

    switch (status) {
      case SessionStatus.scheduled:
        color = Colors.blue;
        text = 'Scheduled';
        break;
      case SessionStatus.inProgress:
        color = Colors.green;
        text = 'In Progress';
        break;
      case SessionStatus.completed:
        color = Colors.grey;
        text = 'Completed';
        break;
      case SessionStatus.cancelled:
        color = Colors.red;
        text = 'Cancelled';
        break;
      case SessionStatus.noShow:
        color = Colors.orange;
        text = 'No Show';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  List<Session> _filterSessions() {
    switch (_selectedFilter) {
      case 'upcoming':
        return sessions
            .where((s) => s.status == SessionStatus.scheduled)
            .toList();
      case 'completed':
        return sessions
            .where((s) => s.status == SessionStatus.completed)
            .toList();
      case 'cancelled':
        return sessions
            .where(
              (s) =>
                  s.status == SessionStatus.cancelled ||
                  s.status == SessionStatus.noShow,
            )
            .toList();
      default:
        return sessions;
    }
  }

  IconData _getSessionTypeIcon(SessionType type) {
    switch (type) {
      case SessionType.voice:
        return Icons.phone;
      case SessionType.chat:
        return Icons.chat;
    }
  }

  Color _getSessionTypeColor(SessionType type) {
    switch (type) {
      case SessionType.voice:
        return Colors.green;
      case SessionType.chat:
        return Colors.purple;
    }
  }

  Color _getRiskLevelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.none:
        return Colors.green;
      case RiskLevel.low:
        return Colors.yellow;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.deepOrange;
      case RiskLevel.critical:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (sessionDate == today) {
      dateStr = 'Today';
    } else if (sessionDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }
}
