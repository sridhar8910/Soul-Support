import 'package:flutter/material.dart';

class ExpertConnectPage extends StatefulWidget {
  const ExpertConnectPage({super.key});

  @override
  State<ExpertConnectPage> createState() => _ExpertConnectPageState();
}

class _ExpertConnectPageState extends State<ExpertConnectPage> {
  final List<Counsellor> _counsellors = const [
    Counsellor(
      name: 'Dr. Aisha Khan',
      expertise: ['Stress', 'Anxiety'],
      rating: 4.8,
      languages: ['English', 'Hindi'],
      tagline: 'Helping you find calm and clarity.',
      isAvailableNow: true,
    ),
    Counsellor(
      name: 'Rahul Mehta',
      expertise: ['Career', 'Relationship'],
      rating: 4.5,
      languages: ['English', 'Hindi'],
      tagline: 'Guiding you through life’s big decisions.',
      isAvailableNow: false,
    ),
    Counsellor(
      name: 'Sofia Fernandez',
      expertise: ['Depression', 'Stress'],
      rating: 4.9,
      languages: ['English'],
      tagline: 'Compassionate support for brighter days.',
      isAvailableNow: true,
    ),
    Counsellor(
      name: 'Ananya Rao',
      expertise: ['Anxiety', 'Relationship'],
      rating: 4.2,
      languages: ['English', 'Telugu'],
      tagline: 'Empowering you to thrive emotionally.',
      isAvailableNow: true,
    ),
    Counsellor(
      name: 'Vijay Patel',
      expertise: ['Stress', 'Career'],
      rating: 4.0,
      languages: ['Hindi', 'English'],
      tagline: 'Practical tools to manage stress and grow.',
      isAvailableNow: false,
    ),
    Counsellor(
      name: 'Dr. Meera Iyer',
      expertise: ['Depression', 'Anxiety'],
      rating: 5.0,
      languages: ['English', 'Hindi', 'Telugu'],
      tagline: 'Personalized care for your mental wellness.',
      isAvailableNow: true,
    ),
  ];

  String _searchQuery = '';
  String? _selectedExpertise;
  String? _selectedRating;
  String? _selectedLanguage;
  bool _availableNowOnly = false;

  static const List<String> _expertiseOptions = [
    'Stress',
    'Anxiety',
    'Depression',
    'Relationship',
    'Career',
  ];

  static const List<String> _ratingOptions = ['4.0+', '4.5+', '4.8+', '5.0'];

  static const List<String> _languageOptions = ['English', 'Hindi', 'Telugu'];

  double? _minRatingFromSelection() {
    switch (_selectedRating) {
      case '4.0+':
        return 4.0;
      case '4.5+':
        return 4.5;
      case '4.8+':
        return 4.8;
      case '5.0':
        return 5.0;
      default:
        return null;
    }
  }

  List<Counsellor> get _filteredCounsellors {
    final double? minRating = _minRatingFromSelection();

    return _counsellors.where((counsellor) {
      final bool matchesSearch =
          _searchQuery.isEmpty ||
              counsellor.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final bool matchesExpertise =
          _selectedExpertise == null ||
              counsellor.expertise.contains(_selectedExpertise);
      final bool matchesRating =
          minRating == null || counsellor.rating >= minRating;
      final bool matchesLanguage =
          _selectedLanguage == null ||
              counsellor.languages.contains(_selectedLanguage);
      final bool matchesAvailability =
          !_availableNowOnly || counsellor.isAvailableNow;

      return matchesSearch &&
          matchesExpertise &&
          matchesRating &&
          matchesLanguage &&
          matchesAvailability;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF008D8D),
        title: const Text('Expert Connect'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find counsellors who match your needs, expertise areas, and preferred language. Use the filters below to connect with the right professional for you.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF0B4A4A),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFiltersCard(context),
                    const SizedBox(height: 24),
                    Text(
                      'Counsellors',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0B4A4A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FilteredCounsellorList(
                      counsellors: _filteredCounsellors,
                      onConnect: _handleConnect,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersCard(BuildContext context) {
    final Color cardColor = Colors.white;
    return Card(
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B4A4A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Search counsellor',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF008D8D)),
                filled: true,
                fillColor: const Color(0xFFF2FBFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                labelStyle: const TextStyle(color: Color(0xFF0B4A4A)),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    value: _selectedExpertise,
                    items: _buildDropdownMenuItems(_expertiseOptions),
                    onChanged: (value) =>
                        setState(() => _selectedExpertise = value),
                    decoration: _dropdownDecoration(label: 'Expertise'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedRating,
                    items: _buildDropdownMenuItems(_ratingOptions),
                    onChanged: (value) =>
                        setState(() => _selectedRating = value),
                    decoration: _dropdownDecoration(label: 'Rating'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    items: _buildDropdownMenuItems(_languageOptions),
                    onChanged: (value) =>
                        setState(() => _selectedLanguage = value),
                    decoration: _dropdownDecoration(label: 'Language'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available Now'),
              value: _availableNowOnly,
              activeColor: const Color(0xFF008D8D),
              onChanged: (value) => setState(() => _availableNowOnly = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedExpertise = null;
                    _selectedRating = null;
                    _selectedLanguage = null;
                    _availableNowOnly = false;
                  });
                },
                icon: const Icon(Icons.refresh, color: Color(0xFF008D8D)),
                label: const Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFF008D8D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF2FBFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: Color(0xFF0B4A4A)),
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownMenuItems(List<String> options) {
    return options
        .map(
          (option) =>
              DropdownMenuItem<String>(value: option, child: Text(option)),
        )
        .toList();
  }

  Future<void> _handleConnect(Counsellor counsellor) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text('Connect with ${counsellor.name}'),
          content: const Text(
            'We will connect you to the counsellor shortly. You can also visit their profile for more details.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('View Profile'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008D8D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

class _FilteredCounsellorList extends StatelessWidget {
  const _FilteredCounsellorList({
    required this.counsellors,
    required this.onConnect,
  });

  final List<Counsellor> counsellors;
  final ValueChanged<Counsellor> onConnect;

  @override
  Widget build(BuildContext context) {
    if (counsellors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.psychology, size: 48, color: Colors.teal.shade200),
              const SizedBox(height: 16),
              const Text('No counsellors match your filters right now.'),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: counsellors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final counsellor = counsellors[index];
        return _CounsellorCard(
          counsellor: counsellor,
          onConnect: () => onConnect(counsellor),
        );
      },
    );
  }
}

class _CounsellorCard extends StatelessWidget {
  const _CounsellorCard({required this.counsellor, required this.onConnect});

  final Counsellor counsellor;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.shade100,
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              counsellor.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B4A4A),
                              ),
                            ),
                          ),
                          if (counsellor.isAvailableNow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Available Now',
                                style: TextStyle(
                                  color: Color(0xFF008D8D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        counsellor.expertise.join(' • '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF117575),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < counsellor.rating.floor()
                                  ? Icons.star
                                  : (i + 0.5) <= counsellor.rating
                                      ? Icons.star_half
                                      : Icons.star_border,
                              size: 18,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${counsellor.rating.toStringAsFixed(1)} / 5'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: counsellor.languages
                  .map(
                    (language) => Chip(
                      label: Text(language),
                      backgroundColor: const Color(0xFFE6F7F7),
                      labelStyle: const TextStyle(color: Color(0xFF0B4A4A)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              counsellor.tagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008D8D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Counsellor {
  const Counsellor({
    required this.name,
    required this.expertise,
    required this.rating,
    required this.languages,
    required this.tagline,
    required this.isAvailableNow,
  });

  final String name;
  final List<String> expertise;
  final double rating;
  final List<String> languages;
  final String tagline;
  final bool isAvailableNow;
}

