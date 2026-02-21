import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';

/// Config-driven scrolling demo — **side-by-side comparison**.
///
/// The left column uses [SilkyScroll] with the user-tweaked config,
/// while the right column uses Flutter's default scrolling.
/// This makes the difference immediately visible.
class ConfigScrollPage extends StatefulWidget {
  const ConfigScrollPage({super.key});

  @override
  State<ConfigScrollPage> createState() => _ConfigScrollPageState();
}

class _ConfigScrollPageState extends State<ConfigScrollPage> {
  double _speed = 1.0;
  double _durationMs = 700;
  double _edgeLockMs = 650;
  bool _stretch = true;
  Curve _curve = Curves.easeOutQuart;

  static const _curveOptions = <String, Curve>{
    'easeOutQuart': Curves.easeOutQuart,
    'easeOutCubic': Curves.easeOutCubic,
    'easeInOut': Curves.easeInOut,
    'decelerate': Curves.decelerate,
    'linear': Curves.linear,
    'bounceOut': Curves.bounceOut,
  };

  String get _curveName => _curveOptions.entries
      .firstWhere(
        (e) => e.value == _curve,
        orElse: () => _curveOptions.entries.first,
      )
      .key;

  SilkyScrollConfig get _config => SilkyScrollConfig(
    scrollSpeed: _speed,
    silkyScrollDuration: Duration(milliseconds: _durationMs.round()),
    animationCurve: _curve,
    edgeLockingDelay: Duration(milliseconds: _edgeLockMs.round()),
    enableStretchEffect: _stretch,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Config Playground')),
      body: Column(
        children: [
          // ── Controls ───────────────────────────────────────────────────
          Material(
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  _SliderRow(
                    label: 'Speed',
                    value: _speed,
                    min: 0.2,
                    max: 5.0,
                    display: '×${_speed.toStringAsFixed(1)}',
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                  _SliderRow(
                    label: 'Duration',
                    value: _durationMs,
                    min: 100,
                    max: 3000,
                    display: '${_durationMs.round()} ms',
                    onChanged: (v) => setState(() => _durationMs = v),
                  ),
                  _SliderRow(
                    label: 'Edge Lock',
                    value: _edgeLockMs,
                    min: 0,
                    max: 2000,
                    display: '${_edgeLockMs.round()} ms',
                    onChanged: (v) => setState(() => _edgeLockMs = v),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Stretch'),
                        selected: _stretch,
                        onSelected: (v) => setState(() => _stretch = v),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _curveName,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: _curveOptions.keys
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (name) {
                          if (name != null) {
                            setState(() => _curve = _curveOptions[name]!);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Side-by-side comparison ────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // Left: SilkyScroll
                Expanded(
                  child: _ComparisonPane(
                    label: 'SilkyScroll',
                    accent: cs.primary,
                    config: _config,
                  ),
                ),

                VerticalDivider(width: 1, color: cs.outlineVariant),

                // Right: Default Flutter scroll
                Expanded(
                  child: _DefaultScrollPane(
                    label: 'Default',
                    accent: cs.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SilkyScroll side
// ──────────────────────────────────────────────────────────────────────────────

class _ComparisonPane extends StatelessWidget {
  const _ComparisonPane({
    required this.label,
    required this.accent,
    required this.config,
  });

  final String label;
  final Color accent;
  final SilkyScrollConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaneHeader(label: label, accent: accent, icon: Icons.auto_awesome),
        Expanded(
          child: SilkyScroll.fromConfig(
            key: ValueKey(config),
            config: config,
            builder: (context, controller, physics) {
              return ListView.builder(
                controller: controller,
                physics: physics,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: 80,
                itemBuilder: (context, index) =>
                    _ColorTile(index: index, accent: accent),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Default Flutter scroll side
// ──────────────────────────────────────────────────────────────────────────────

class _DefaultScrollPane extends StatelessWidget {
  const _DefaultScrollPane({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaneHeader(label: label, accent: accent, icon: Icons.compare_arrows),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: 80,
            itemBuilder: (context, index) =>
                _ColorTile(index: index, accent: accent),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ──────────────────────────────────────────────────────────────────────────────

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.label,
    required this.accent,
    required this.icon,
  });

  final String label;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: accent.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.index, required this.accent});

  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hue = (index * 7) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), .55, .8).toColor();
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Item ${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color.computeLuminance() > 0.35
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF5F5F5),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reusable slider row
// ──────────────────────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 64,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
