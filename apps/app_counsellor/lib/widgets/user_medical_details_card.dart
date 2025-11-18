import 'package:flutter/material.dart';

class UserMedicalDetailsCard extends StatelessWidget {
  // 1. User ID
  final String userId;

  // 2. Display Name
  final String displayName;

  // 3. Age
  final int age;

  // 4. Issue / Reason
  final String issueReason;
  final String? detailedReason;

  // 7. Profession
  final String profession;

  // 9. Flag status (Green / Yellow / Red)
  final String flagStatus; // 'green', 'yellow', or 'red'
  final String? flagReason;

  // 10. Session details with total minutes
  final int totalSessions;
  final int totalMinutes;
  final String? lastSessionDate;

  // 11. Insights and reports (only show if this is second or more session)
  final bool isReturningClient;
  final String? insights;
  final List<String>? progressNotes;

  // 12. Emergency / Support Info
  final String? emergencyContact;
  final String? emergencyPhone;
  final List<String>? supportResources;

  // 13. Language Preference
  final String languagePreference;
  final List<String>? additionalLanguages;

  // Callbacks for buttons
  final VoidCallback? onChatPressed;
  final VoidCallback? onCallPressed;
  final VoidCallback? onFeedbackPressed;

  const UserMedicalDetailsCard({
    super.key,
    required this.userId,
    required this.displayName,
    required this.age,
    required this.issueReason,
    this.detailedReason,
    required this.profession,
    required this.flagStatus,
    this.flagReason,
    required this.totalSessions,
    required this.totalMinutes,
    this.lastSessionDate,
    required this.isReturningClient,
    this.insights,
    this.progressNotes,
    this.emergencyContact,
    this.emergencyPhone,
    this.supportResources,
    required this.languagePreference,
    this.additionalLanguages,
    this.onChatPressed,
    this.onCallPressed,
    this.onFeedbackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getFlagColor(), width: 2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with User Info
              _buildHeader(context),
              const Divider(height: 32),

              // Issue/Reason Section
              _buildIssueSection(context),
              const SizedBox(height: 20),

              // Action Buttons (Chat, Call, Feedback)
              _buildActionButtons(context),
              const SizedBox(height: 20),

              // Additional Info Grid
              _buildInfoGrid(context),
              const SizedBox(height: 20),

              // Flag Status
              _buildFlagStatus(context),
              const SizedBox(height: 20),

              // Session Details
              _buildSessionDetails(context),

              // Insights (only for returning clients)
              if (isReturningClient) ...[
                const SizedBox(height: 20),
                _buildInsightsSection(context),
              ],

              // Emergency Contact
              if (emergencyContact != null) ...[
                const SizedBox(height: 20),
                _buildEmergencySection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: _getFlagColor().withOpacity(0.2),
          child: Text(
            displayName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _getFlagColor(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: $userId',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$age years',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.work_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profession,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Language indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 16, color: Colors.purple.shade700),
              const SizedBox(width: 4),
              Text(
                languagePreference,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIssueSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_information,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Reason for Session',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            issueReason,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (detailedReason != null) ...[
            const SizedBox(height: 8),
            Text(
              detailedReason!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // 5. Chat button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onChatPressed,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 6. Call button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onCallPressed,
            icon: const Icon(Icons.phone),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 8. Feedback button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onFeedbackPressed,
            icon: const Icon(Icons.feedback_outlined),
            label: const Text('Feedback'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Information',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (additionalLanguages != null && additionalLanguages!.isNotEmpty) ...[
          _buildInfoRow(
            Icons.translate,
            'Additional Languages',
            additionalLanguages!.join(', '),
            Colors.purple,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildFlagStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getFlagColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getFlagColor(), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getFlagIcon(), color: _getFlagColor(), size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flagStatus.toUpperCase()} FLAG',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getFlagColor(),
                    ),
                  ),
                  Text(
                    _getFlagDescription(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
          if (flagReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(flagReason!, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionDetails(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.grey.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Session History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  'Total Sessions',
                  totalSessions.toString(),
                  Icons.event,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Total Minutes',
                  totalMinutes.toString(),
                  Icons.timer,
                  Colors.green,
                ),
              ),
            ],
          ),
          if (lastSessionDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last Session: $lastSessionDate',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Insights & Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'RETURNING CLIENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (insights != null) ...[
            const SizedBox(height: 12),
            Text(insights!, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
          if (progressNotes != null && progressNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Progress Notes:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...progressNotes!.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(note, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Emergency Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.person, 'Contact', emergencyContact!, Colors.red),
          if (emergencyPhone != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Phone', emergencyPhone!, Colors.red),
          ],
          if (supportResources != null && supportResources!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Support Resources:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...supportResources!.map(
              (resource) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.support, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resource,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Color _getFlagColor() {
    switch (flagStatus.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getFlagIcon() {
    switch (flagStatus.toLowerCase()) {
      case 'green':
        return Icons.check_circle;
      case 'yellow':
        return Icons.warning_amber;
      case 'red':
        return Icons.error;
      default:
        return Icons.flag;
    }
  }

  String _getFlagDescription() {
    switch (flagStatus.toLowerCase()) {
      case 'green':
        return 'Low risk - No immediate concerns';
      case 'yellow':
        return 'Moderate risk - Monitoring required';
      case 'red':
        return 'High risk - Immediate attention needed';
      default:
        return 'Status unknown';
    }
  }
}
