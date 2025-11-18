import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AffirmationsPage extends StatefulWidget {
  const AffirmationsPage({super.key});

  @override
  State<AffirmationsPage> createState() => _AffirmationsPageState();
}

class _AffirmationsPageState extends State<AffirmationsPage> {
  final List<String> _affirmations = [
    'I am worthy of care and respect.',
    'I breathe in calm and exhale tension.',
    'I am capable of handling what comes my way.',
    'I give myself permission to rest and heal.',
  ];

  int _index = 0;

  void _next() {
    setState(() => _index = (_index + 1) % _affirmations.length);
  }

  void _prev() {
    setState(() => _index = (_index - 1 + _affirmations.length) % _affirmations.length);
  }

  void _copyCurrent() {
    Clipboard.setData(ClipboardData(text: _affirmations[_index]));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Affirmation copied')));
  }

  void _shareMock() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share (demo)'),
        content: Text('Share this affirmation:\n\n"${_affirmations[_index]}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _affirmations[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Affirmations'),
        backgroundColor: const Color(0xFF8B5FBF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    const Text(
                      'Daily Affirmation',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      a,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(onPressed: _prev, icon: const Icon(Icons.arrow_back, color: Colors.black)),
                        const SizedBox(width: 8),
                        IconButton(onPressed: _copyCurrent, icon: const Icon(Icons.copy, color: Colors.black)),
                        const SizedBox(width: 8),
                        IconButton(onPressed: _shareMock, icon: const Icon(Icons.share, color: Colors.black)),
                        const SizedBox(width: 8),
                        IconButton(onPressed: _next, icon: const Icon(Icons.arrow_forward, color: Colors.black)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _affirmations.length,
                itemBuilder: (context, idx) => ListTile(
                  title: Text(
                    _affirmations[idx],
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  leading: idx == _index
                      ? const Icon(Icons.circle, size: 12, color: Color(0xFF8B5FBF))
                      : null,
                  onTap: () => setState(() => _index = idx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

