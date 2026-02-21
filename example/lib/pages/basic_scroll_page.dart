import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';

/// Basic vertical scrolling demo.
///
/// Shows a [ListView] wrapped in [SilkyScroll] with live scroll-event
/// feedback: offset, delta, and edge-overscroll indicators are all
/// displayed in real time so the user can observe the smooth animation
/// pipeline.
class BasicScrollPage extends StatefulWidget {
  const BasicScrollPage({super.key});

  @override
  State<BasicScrollPage> createState() => _BasicScrollPageState();
}

class _BasicScrollPageState extends State<BasicScrollPage> {
  late final ScrollController _controller;
  double _offset = 0;
  double _lastDelta = 0;
  double _edgeOverscrollDelta = 0;

  /// Rolling log of recent scroll events (newest first).
  final _log = ListQueue<_ScrollEvent>(30);

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(() {
      setState(() => _offset = _controller.offset);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll(double delta) {
    setState(() {
      _lastDelta = delta;
      _log.addFirst(_ScrollEvent('scroll', delta));
      if (_log.length > 28) _log.removeLast();
    });
  }

  void _onEdgeOverScroll(double delta) {
    setState(() {
      _edgeOverscrollDelta = delta;
      _log.addFirst(_ScrollEvent('edge', delta));
      if (_log.length > 28) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Basic Scroll')),
      body: Column(
        children: [
          // ── Live indicators ──────────────────────────────────────────
          Material(
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _Indicator(
                    icon: Icons.straighten,
                    label: 'offset',
                    value: _offset.toStringAsFixed(1),
                    color: cs.primary,
                  ),
                  const SizedBox(width: 16),
                  _Indicator(
                    icon: Icons.speed,
                    label: 'delta',
                    value: _lastDelta.toStringAsFixed(1),
                    color: cs.secondary,
                  ),
                  const SizedBox(width: 16),
                  _Indicator(
                    icon: Icons.border_top,
                    label: 'edge',
                    value: _edgeOverscrollDelta.toStringAsFixed(1),
                    color: _edgeOverscrollDelta != 0
                        ? cs.error
                        : cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Scrollable content ───────────────────────────────────────
          Expanded(
            child: SilkyScroll(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              enableStretchEffect: true,
              onScroll: _onScroll,
              onEdgeOverScroll: _onEdgeOverScroll,
              builder: (context, controller, physics) {
                return ListView.builder(
                  controller: controller,
                  physics: physics,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: 60,
                  itemBuilder: (context, index) {
                    return Card(
                      color: cs.surfaceContainerHighest,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          child: Text('${index + 1}'),
                        ),
                        title: Text('Item ${index + 1}'),
                        subtitle: const Text(
                          'Smooth scrolling with SilkyScroll',
                        ),
                        trailing: Icon(Icons.chevron_right, color: cs.outline),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Event log ────────────────────────────────────────────────
          Material(
            color: cs.surfaceContainerLowest,
            child: SizedBox(
              height: 100,
              child: _log.isEmpty
                  ? Center(
                      child: Text(
                        'Scroll to see events…',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: _log.length,
                      itemBuilder: (context, i) {
                        final e = _log.elementAt(i);
                        final isEdge = e.type == 'edge';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            '${isEdge ? "⚡" : "→"} ${e.type}  '
                            'delta: ${e.delta.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: isEdge ? cs.error : cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

class _ScrollEvent {
  _ScrollEvent(this.type, this.delta);
  final String type;
  final double delta;
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
