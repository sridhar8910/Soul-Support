import 'package:flutter/material.dart';

import 'package:common/api/api_client.dart';

class ReportsAnalyticsPage extends StatefulWidget {
  const ReportsAnalyticsPage({super.key});

  @override
  State<ReportsAnalyticsPage> createState() => _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends State<ReportsAnalyticsPage>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String? _error;
  AnalyticsReport? _report;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _api.fetchAnalyticsReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load analytics. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
          backgroundColor: const Color(0xFF8B5FBF),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
          backgroundColor: const Color(0xFF8B5FBF),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final report = _report!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF8B5FBF),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5FBF), Color(0xFF9E8BE3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visual insights about your progress.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Wallet minutes available: ${report.walletMinutes}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMoodSection(report),
                  const SizedBox(height: 20),
                  _buildTasksSection(report),
                  const SizedBox(height: 20),
                  _buildSessionsSection(report),
                  const SizedBox(height: 20),
                  _buildInsightCard(report),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSection(AnalyticsReport report) {
    final weekly = report.weeklyMood;
    final monthly = report.monthlyMood;

    return _SectionCard(
      title: 'Mood Trends',
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF8B5FBF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF8B5FBF),
            tabs: const [
              Tab(text: '7 Days'),
              Tab(text: '30 Days'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                weekly.isEmpty
                    ? const _EmptyChartPlaceholder(message: 'No mood updates yet.')
                    : MoodChart(points: weekly),
                monthly.isEmpty
                    ? const _EmptyChartPlaceholder(message: 'No mood data for last month.')
                    : MoodChart(points: monthly),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(AnalyticsReport report) {
    final tasks = report.tasks;
    final completionRate = tasks.completionRate.clamp(0.0, 1.0);
    return _SectionCard(
      title: 'Wellness Tasks',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion rate: ${(completionRate * 100).round()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: completionRate,
                backgroundColor: const Color(0xFFEDE7F6),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5FBF)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${tasks.completed} out of ${tasks.total} tasks completed',
              style: const TextStyle(color: Color(0xFF555555)),
            ),
            const SizedBox(height: 16),
            Text(
              'Top routines',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            if (tasks.topTasks.isEmpty)
              const Text(
                'No data yet. Complete tasks to see insights here.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...tasks.topTasks.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline,
                      color: Color(0xFF8B5FBF)),
                  title: Text(item.title),
                  trailing: Text('×${item.total}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsSection(AnalyticsReport report) {
    final sessions = report.sessions;
    return _SectionCard(
      title: 'Sessions summary',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _SessionsStat(
                value: sessions.upcoming,
                label: 'Upcoming',
                icon: Icons.calendar_today,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SessionsStat(
                value: sessions.completed,
                label: 'Completed',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SessionsStat(
                value: sessions.total,
                label: 'Total',
                icon: Icons.timeline,
                color: const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(AnalyticsReport report) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5FBF), Color(0xFF9E8BE3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.insights, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            report.insight,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class MoodChart extends StatelessWidget {
  const MoodChart({super.key, required this.points});

  final List<AnalyticsMoodPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: MoodChartPainter(points),
    );
  }
}

class MoodChartPainter extends CustomPainter {
  MoodChartPainter(this.points);

  final List<AnalyticsMoodPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF8B5FBF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final maxMood = 5.0;

    final divisor = points.length <= 1 ? 1 : (points.length - 1);
    final dx = width / divisor;

    double moodToDy(double mood) {
      final clamped = mood.clamp(0, maxMood);
      return height - (clamped / maxMood) * height;
    }

    path.moveTo(0, moodToDy(points[0].average));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(dx * i, moodToDy(points[i].average));
    }

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;
    for (var i = 1; i <= 5; i++) {
      final y = height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF8B5FBF),
          Color(0xFF9E8BE3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill
      ..colorFilter =
          const ColorFilter.mode(Color(0x558B5FBF), BlendMode.srcATop);

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SessionsStat extends StatelessWidget {
  const _SessionsStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

