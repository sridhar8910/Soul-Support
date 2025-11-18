import 'package:flutter/material.dart';

class GuidelinesPage extends StatelessWidget {
  const GuidelinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guidelines'),
        backgroundColor: const Color(0xFF8B5FBF),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Community & Usage Guidelines',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1B41),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Our Commitment to a Safe, Supportive Environment',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B8E),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Respect & Confidentiality',
              '• Treat all members with dignity and respect\n'
              '• Never share personal information without consent\n'
              '• Maintain strict confidentiality of others\' stories\n'
              '• What is shared in the community stays in the community',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Responsible Communication',
              '• Use kind and supportive language\n'
              '• Avoid judgment, criticism, or dismissive comments\n'
              '• Listen actively and empathetically\n'
              '• Share personal experiences, not medical advice',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Content Standards',
              '• No hate speech, discrimination, or harassment\n'
              '• No self-harm, suicide, or crisis content\n'
              '• No spam, advertisements, or commercial promotion\n'
              '• No illegal content or activities',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Crisis Support',
              '• If experiencing a crisis, contact emergency services\n'
              '• Call our 24/7 crisis hotline for immediate help\n'
              '• Book an urgent counselling session\n'
              '• Crisis support is not a replacement for professional help',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Privacy & Data Protection',
              '• Your data is encrypted and protected\n'
              '• We never sell or share personal information\n'
              '• You can request data deletion anytime\n'
              '• Anonymous usage options are available',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Counsellor Conduct',
              '• All counsellors are certified professionals\n'
              '• Sessions are confidential and private\n'
              '• Report any inappropriate behavior immediately\n'
              '• Professional ethics are strictly enforced',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Session Etiquette',
              '• Arrive on time or notify in advance of cancellations\n'
              '• Ensure a quiet, private space for sessions\n'
              '• Be honest and open with your counsellor\n'
              '• Cancel with at least 24 hours notice when possible',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Consequences of Violations',
              '• First violation: Warning and educational message\n'
              '• Repeated violations: Temporary suspension\n'
              '• Severe violations: Permanent account removal\n'
              '• Legal action for criminal content',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBFF),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: Color(0xFF8B5FBF), width: 4),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5FBF),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'If you have questions about these guidelines or need to report a violation, contact our support team at support@soulsupport.com or use the in-app help feature.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1B41),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B5FBF),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1B41),
            height: 1.8,
          ),
        ),
      ],
    );
  }
}

