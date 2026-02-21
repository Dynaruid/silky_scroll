import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/src/silky_scroll_animator.dart';

/// Minimal delegate for testing [SilkyScrollAnimator] in isolation.
class _FakeAnimatorDelegate implements SilkyScrollAnimatorDelegate {
  _FakeAnimatorDelegate({required this.clientController});

  @override
  final ScrollController clientController;

  @override
  final Curve animationCurve = Curves.easeOutQuart;

  @override
  final Duration silkyScrollDuration = const Duration(milliseconds: 700);

  @override
  final bool isPlatformBouncingScrollPhysics = false;

  @override
  double futurePosition = 0;

  @override
  bool prevDeltaPositive = false;

  @override
  bool isOnSilkyScrolling = false;

  @override
  bool isRecoilScroll = false;

  @override
  bool isDisposed = false;

  int animationStateChangedCount = 0;

  @override
  void onAnimationStateChanged() {
    animationStateChangedCount++;
  }
}

void main() {
  group('SilkyScrollAnimator', () {
    late ScrollController controller;
    late _FakeAnimatorDelegate delegate;
    late SilkyScrollAnimator animator;

    setUp(() {
      controller = ScrollController();
      delegate = _FakeAnimatorDelegate(clientController: controller);
      animator = SilkyScrollAnimator(delegate);
    });

    tearDown(() {
      controller.dispose();
    });

    test('recoilDurationMs is computed from silkyScrollDuration', () {
      // 700 * 0.8 = 560
      expect(animator.recoilDurationMs, 560);
    });

    testWidgets('animateToScroll sets isOnSilkyScrolling to true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      animator.animateToScroll(100, 1.0);
      expect(delegate.isOnSilkyScrolling, isTrue);

      // Let animation complete
      await tester.pumpAndSettle();
      expect(delegate.isOnSilkyScrolling, isFalse);
    });

    testWidgets('animateToScroll updates futurePosition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      animator.animateToScroll(100, 1.0);
      // futurePosition = offset(0) + 100 * 1.0 * 0.5 = 50
      expect(delegate.futurePosition, 50.0);

      await tester.pumpAndSettle();
    });

    testWidgets(
      'futurePosition is clamped to maxScrollExtent for non-bouncing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
            ),
          ),
        );

        final maxExtent = controller.position.maxScrollExtent;
        // Scroll way past max
        animator.animateToScroll(maxExtent * 10, 1.0);
        expect(delegate.futurePosition, maxExtent);

        await tester.pumpAndSettle();
      },
    );

    testWidgets('direction reversal resets futurePosition from offset', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      // Scroll down
      animator.animateToScroll(100, 1.0);
      expect(delegate.prevDeltaPositive, isTrue);

      await tester.pumpAndSettle();

      // Scroll up (direction change)
      animator.animateToScroll(-50, 1.0);
      expect(delegate.prevDeltaPositive, isFalse);

      await tester.pumpAndSettle();
    });
  });
}
