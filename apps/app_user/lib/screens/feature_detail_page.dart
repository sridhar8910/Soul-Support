import 'package:flutter/material.dart';

class FeatureDetailPage extends StatelessWidget {
  final String title;
  final List<FeatureSection> sections;

  const FeatureDetailPage({
    super.key,
    required this.title,
    required this.sections,
  });

  factory FeatureDetailPage.fromBulletPoints({
    Key? key,
    required String title,
    required Map<String, List<String>> bulletsBySection,
  }) {
    final sections = bulletsBySection.entries
        .map(
          (e) => FeatureSection(
            heading: e.key,
            paragraphs: const [],
            bullets: e.value,
          ),
        )
        .toList();
    return FeatureDetailPage(key: key, title: title, sections: sections);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final s = sections[index];
          return _SectionCard(section: s);
        },
      ),
    );
  }
}

class FeatureSection {
  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<String> chips;

  FeatureSection({
    required this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
    this.chips = const [],
  });
}

class _SectionCard extends StatelessWidget {
  final FeatureSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.heading,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (section.chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: section.chips
                    .map(
                      (c) => Chip(
                        label: Text(
                          c,
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            ...section.paragraphs.expand(
              (p) => [
                const SizedBox(height: 12),
                Text(
                  p,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            if (section.bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...section.bullets.map((b) => _Bullet(text: b)).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

