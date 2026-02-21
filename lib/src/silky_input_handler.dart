import 'package:flutter/gestures.dart';
import 'silky_scroll_mouse_pointer_manager.dart';

/// Callback interface used by [SilkyInputHandler] to communicate
/// input events back to the owning [SilkyScrollState].
abstract interface class SilkyInputHandlerDelegate {
  bool get isVertical;
  double get scrollSpeed;
  bool get isWebPlatform;

  void handleTouchScroll(double delta);
  void handleMouseScroll(double delta, double scrollSpeed);
  void blockOverscrollBehaviorX();

  void Function(double delta)? get onScroll;
  Function(PointerDeviceKind) get setPointerDeviceKind;

  SilkyScrollMousePointerManager get silkyScrollMousePointerManager;
}

/// Routes mouse, trackpad, and touch input to the correct scroll handler.
///
/// Extracted from [SilkyScrollState] to follow the Single
/// Responsibility Principle.
final class SilkyInputHandler {
  const SilkyInputHandler(this._delegate);

  final SilkyInputHandlerDelegate _delegate;

  /// Processes touch or trackpad scroll input.
  void triggerTouchAction(Offset delta, PointerDeviceKind kind) {
    final double scrollDelta;
    if (kind == PointerDeviceKind.trackpad && _delegate.isWebPlatform) {
      scrollDelta = _delegate.isVertical ? delta.dy : delta.dx;
    } else {
      scrollDelta = _delegate.isVertical ? -delta.dy : -delta.dx;
    }

    if (scrollDelta.abs() >= 0.5) {
      _delegate.handleTouchScroll(scrollDelta);
      _delegate.blockOverscrollBehaviorX();
    }
    _delegate.onScroll?.call(scrollDelta);
  }

  /// Processes mouse-wheel scroll input.
  void triggerMouseAction(double scrollDeltaY) {
    _delegate.setPointerDeviceKind(PointerDeviceKind.mouse);
    _delegate.onScroll?.call(scrollDeltaY);
    _delegate.handleMouseScroll(scrollDeltaY, _delegate.scrollSpeed);
    _delegate.silkyScrollMousePointerManager.clearTrackpadMemory();
  }
}
