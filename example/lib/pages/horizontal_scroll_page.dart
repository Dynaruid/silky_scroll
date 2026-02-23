import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';

/// Horizontal scrolling demo.
///
/// The page scrolls vertically via [SilkyScroll] and contains horizontal
/// carousels, each also powered by [SilkyScroll]. Toggle controls let
/// users see the effect of **stretch** and different **scroll speeds**
/// on the horizontal axis.
class HorizontalScrollPage extends StatefulWidget {
  const HorizontalScrollPage({super.key});

  @override
  State<HorizontalScrollPage> createState() => _HorizontalScrollPageState();
}

class _HorizontalScrollPageState extends State<HorizontalScrollPage> {
  bool _stretch = true;
  double _speed = 1.0;

  static const _categories = <(String, IconData, MaterialColor)>[
    ('Featured', Icons.star, Colors.amber),
    ('Recent', Icons.access_time, Colors.blue),
    ('Popular', Icons.trending_up, Colors.deepOrange),
    ('Collections', Icons.folder_special, Colors.teal),
    ('Favorites', Icons.favorite, Colors.pink),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horizontal Scroll'),
        actions: [
          // Speed chip
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: const Icon(Icons.speed, size: 18),
              label: Text('×${_speed.toStringAsFixed(1)}'),
              onPressed: () {
                setState(() {
                  // Cycle: 0.5 → 1.0 → 2.0 → 3.0 → 0.5
                  const speeds = [0.5, 1.0, 2.0, 3.0];
                  final idx = speeds.indexOf(_speed);
                  _speed = speeds[(idx + 1) % speeds.length];
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              avatar: Icon(_stretch ? Icons.expand : Icons.compress, size: 18),
              label: const Text('Stretch'),
              selected: _stretch,
              onSelected: (v) => setState(() => _stretch = v),
            ),
          ),
        ],
      ),
      body: SilkyScroll(
        key: ValueKey('outer_v_${_stretch}_$_speed'),
        physics: const BouncingScrollPhysics(),
        enableStretchEffect: _stretch,
        scrollSpeed: _speed,
        builder: (context, controller, physics) {
          return ListView.builder(
            controller: controller,
            physics: physics,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final (label, icon, accent) = _categories[index];
              return _CategorySection(
                label: label,
                icon: icon,
                accent: accent,
                stretch: _stretch,
                speed: _speed,
              );
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// One category section: title + horizontal carousel
// ──────────────────────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.label,
    required this.icon,
    required this.accent,
    required this.stretch,
    required this.speed,
  });

  final String label;
  final IconData icon;
  final MaterialColor accent;
  final bool stretch;
  final double speed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Horizontal carousel
        SizedBox(
          height: 180,
          child: SilkyScroll(
            direction: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            enableStretchEffect: stretch,
            scrollSpeed: speed,
            builder: (context, controller, physics) {
              return ListView.builder(
                controller: controller,
                physics: physics,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 15,
                itemBuilder: (context, index) {
                  return _CarouselCard(index: index, accent: accent);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Individual carousel card
// ──────────────────────────────────────────────────────────────────────────────

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.index, required this.accent});

  final int index;
  final MaterialColor accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.shade100, accent.shade300],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.shade50.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: accent.shade800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Card ${index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: accent.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Horizontal',
            style: TextStyle(fontSize: 12, color: accent.shade700),
          ),
        ],
      ),
    );
  }
}
