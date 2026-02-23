import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/src/silky_input_handler.dart';
import 'package:silky_scroll/src/silky_scroll_mouse_pointer_manager.dart';

/// Minimal delegate for testing [SilkyInputHandler] in isolation.
class _FakeInputDelegate implements SilkyInputHandlerDelegate {
  @override
  bool isVertical = true;

  @override
  double scrollSpeed = 1.0;

  @override
  bool isWebPlatform = false;

  double? lastTouchDelta;
  double? lastMouseDelta;
  double? lastMouseSpeed;
  bool blockCalled = false;
  double? lastOnScrollDelta;
  PointerDeviceKind? lastPointerDeviceKind;

  @override
  void handleTouchScroll(double delta) {
    lastTouchDelta = delta;
  }

  @override
  void handleMouseScroll(double delta, double scrollSpeed) {
    lastMouseDelta = delta;
    lastMouseSpeed = scrollSpeed;
  }

  @override
  void blockOverscrollBehaviorX() {
    blockCalled = true;
  }

  @override
  void Function(double delta)? onScroll;

  @override
  late Function(PointerDeviceKind) setPointerDeviceKind = (kind) {
    lastPointerDeviceKind = kind;
  };

  @override
  final SilkyScrollMousePointerManager silkyScrollMousePointerManager =
      SilkyScrollMousePointerManager();
}

void main() {
  group('SilkyInputHandler', () {
    late _FakeInputDelegate delegate;
    late SilkyInputHandler handler;

    setUp(() {
      delegate = _FakeInputDelegate();
      handler = SilkyInputHandler(delegate);
    });

    group('triggerTouchAction', () {
      test('vertical touch inverts delta.dy', () {
        delegate.isVertical = true;
        handler.triggerTouchAction(
          const Offset(0, 10),
          PointerDeviceKind.touch,
        );
        // Non-web: -delta.dy = -10
        expect(delegate.lastTouchDelta, -10.0);
      });

      test('horizontal touch inverts delta.dx', () {
        delegate.isVertical = false;
        handler.triggerTouchAction(
          const Offset(10, 0),
          PointerDeviceKind.touch,
        );
        expect(delegate.lastTouchDelta, -10.0);
      });

      test('trackpad on web uses delta directly (no inversion)', () {
        delegate.isWebPlatform = true;
        delegate.isVertical = true;
        handler.triggerTouchAction(
          const Offset(0, 10),
          PointerDeviceKind.trackpad,
        );
        expect(delegate.lastTouchDelta, 10.0);
      });

      test('trackpad on non-web inverts delta', () {
        delegate.isWebPlatform = false;
        delegate.isVertical = true;
        handler.triggerTouchAction(
          const Offset(0, 10),
          PointerDeviceKind.trackpad,
        );
        expect(delegate.lastTouchDelta, -10.0);
      });

      test('calls blockOverscrollBehaviorX when delta >= 0.5', () {
        handler.triggerTouchAction(
          const Offset(0, -5),
          PointerDeviceKind.touch,
        );
        expect(delegate.blockCalled, isTrue);
      });

      test('does not call handleTouchScroll when delta < 0.5', () {
        handler.triggerTouchAction(
          const Offset(0, 0.1),
          PointerDeviceKind.touch,
        );
        expect(delegate.lastTouchDelta, isNull);
        expect(delegate.blockCalled, isFalse);
      });

      test('calls onScroll callback', () {
        double? scrolledDelta;
        delegate.onScroll = (delta) => scrolledDelta = delta;
        handler.triggerTouchAction(
          const Offset(0, -5),
          PointerDeviceKind.touch,
        );
        expect(scrolledDelta, 5.0); // inverted: -(-5) = 5
      });
    });

    group('triggerMouseAction', () {
      test('sets pointer device kind to mouse', () {
        handler.triggerMouseAction(10.0);
        expect(delegate.lastPointerDeviceKind, PointerDeviceKind.mouse);
      });

      test('forwards delta and scrollSpeed to handleMouseScroll', () {
        handler.triggerMouseAction(42.0);
        expect(delegate.lastMouseDelta, 42.0);
        expect(delegate.lastMouseSpeed, 1.0);
      });

      test('calls onScroll callback', () {
        double? scrolledDelta;
        delegate.onScroll = (delta) => scrolledDelta = delta;
        handler.triggerMouseAction(10.0);
        expect(scrolledDelta, 10.0);
      });
    });
  });
}
