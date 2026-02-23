import 'package:flutter/material.dart';
import 'package:silky_scroll/silky_scroll.dart';

/// Nested (inner + outer) scrolling demo.
///
/// The outer [SilkyScroll] list contains cards, some with inner
/// [SilkyScroll] lists. A **Bubbling** toggle lets users see the
/// difference: when on, inner lists that reach their edge pass
/// scroll momentum to the outer list.
class NestedScrollPage extends StatefulWidget {
  const NestedScrollPage({super.key});

  @override
  State<NestedScrollPage> createState() => _NestedScrollPageState();
}

class _NestedScrollPageState extends State<NestedScrollPage> {
  bool _bubbling = false;
  bool _stretch = true;
  double _outerEdgeDelta = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nested Scroll'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(_stretch ? Icons.expand : Icons.compress, size: 18),
              label: const Text('Stretch'),
              selected: _stretch,
              onSelected: (v) => setState(() => _stretch = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              avatar: Icon(
                _bubbling ? Icons.bubble_chart : Icons.bubble_chart_outlined,
                size: 18,
              ),
              label: const Text('Bubbling'),
              selected: _bubbling,
              onSelected: (v) => setState(() => _bubbling = v),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Info banner ────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: _bubbling ? cs.primaryContainer : cs.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _bubbling ? Icons.swap_vert : Icons.block,
                  size: 18,
                  color: _bubbling
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _bubbling
                        ? 'Bubbling ON — inner list at edge passes momentum to outer list'
                        : 'Bubbling OFF — inner list stops at edge, outer list stays still',
                    style: TextStyle(
                      fontSize: 13,
                      color: _bubbling
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_outerEdgeDelta != 0)
                  Chip(
                    avatar: Icon(Icons.bolt, size: 16, color: cs.error),
                    label: Text(
                      'edge: ${_outerEdgeDelta.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11, color: cs.error),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Outer scrollable ──────────────────────────────────────────
          Expanded(
            child: SilkyScroll(
              key: ValueKey('outer_${_bubbling}_$_stretch'),
              physics: const BouncingScrollPhysics(),
              enableStretchEffect: _stretch,
              enableScrollBubbling: _bubbling,
              onEdgeOverScroll: (delta) {
                setState(() => _outerEdgeDelta = delta);
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) setState(() => _outerEdgeDelta = 0);
                });
              },
              builder: (context, controller, physics) {
                return ListView.builder(
                  controller: controller,
                  physics: physics,
                  padding: const EdgeInsets.all(16),
                  itemCount: 20,
                  itemBuilder: (context, index) {
                    // Every 3rd item is a nested-scroll card
                    if (index % 3 == 1) {
                      return _NestedCard(
                        index: index,
                        bubbling: _bubbling,
                        stretch: _stretch,
                      );
                    }
                    return _SimpleCard(index: index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Simple card (non-scrollable)
// ──────────────────────────────────────────────────────────────────────────────

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(Icons.article, color: cs.primary),
        title: Text('Regular item #$index'),
        subtitle: const Text('This card does not scroll internally.'),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Nested scrollable card
// ──────────────────────────────────────────────────────────────────────────────

class _NestedCard extends StatefulWidget {
  const _NestedCard({
    required this.index,
    required this.bubbling,
    required this.stretch,
  });

  final int index;
  final bool bubbling;
  final bool stretch;

  @override
  State<_NestedCard> createState() => _NestedCardState();
}

class _NestedCardState extends State<_NestedCard> {
  double _innerEdgeDelta = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: cs.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.layers, color: cs.onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nested list #${widget.index}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                if (_innerEdgeDelta != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.bubbling ? 'bubbling ↑' : 'edge hit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Inner scrollable area
          SizedBox(
            height: 220,
            child: SilkyScroll(
              key: ValueKey(
                'inner_${widget.index}_${widget.bubbling}_${widget.stretch}',
              ),
              physics: const BouncingScrollPhysics(),
              enableScrollBubbling: widget.bubbling,
              enableStretchEffect: widget.stretch,
              onEdgeOverScroll: (delta) {
                setState(() => _innerEdgeDelta = delta);
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) setState(() => _innerEdgeDelta = 0);
                });
              },
              builder: (context, controller, physics) {
                return ListView.separated(
                  controller: controller,
                  physics: physics,
                  padding: const EdgeInsets.all(8),
                  itemCount: 25,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, inner) {
                    final color = inner.isEven
                        ? cs.secondaryContainer
                        : cs.tertiaryContainer;
                    return Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Inner item $inner',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
