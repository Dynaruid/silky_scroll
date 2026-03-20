import 'package:flutter/gestures.dart';
import 'silky_scroll_global_manager.dart';

/// Callback interface used by [SilkyInputHandler] to communicate
/// input events back to the owning [SilkyScrollState].
abstract interface class SilkyInputHandlerDelegate {
  bool get isVertical;
  double get scrollSpeed;
  bool get isWebPlatform;

  void handleTrackpadScroll(double delta);
  void handleTouchDragScroll(double delta);
  void handleMouseScroll(double delta, double scrollSpeed);

  void Function(double delta)? get onScroll;
  Function(PointerDeviceKind) get setPointerDeviceKind;

  SilkyScrollGlobalManager get silkyScrollGlobalManager;
}

/// Routes mouse, trackpad, and touch input to the correct scroll handler.
///
/// Extracted from [SilkyScrollState] to follow the Single
/// Responsibility Principle.
final class SilkyInputHandler {
  const SilkyInputHandler(this._delegate);

  final SilkyInputHandlerDelegate _delegate;

  /// Processes touch or trackpad scroll input.
  ///
  /// Routes to [handleTrackpadScroll] or [handleTouchDragScroll]
  /// based on [kind].
  void triggerTouchAction(Offset delta, PointerDeviceKind kind) {
    final double scrollDelta;
    if (kind == PointerDeviceKind.trackpad && _delegate.isWebPlatform) {
      scrollDelta = _delegate.isVertical ? delta.dy : delta.dx;
    } else {
      scrollDelta = _delegate.isVertical ? -delta.dy : -delta.dx;
    }

    if (kind == PointerDeviceKind.trackpad) {
      _delegate.handleTrackpadScroll(scrollDelta);
    } else {
      _delegate.handleTouchDragScroll(scrollDelta);
    }

    _delegate.onScroll?.call(scrollDelta);
  }

  /// Processes mouse-wheel scroll input.
  void triggerMouseAction(double scrollDeltaY) {
    _delegate.setPointerDeviceKind(PointerDeviceKind.mouse);
    _delegate.onScroll?.call(scrollDeltaY);
    _delegate.handleMouseScroll(scrollDeltaY, _delegate.scrollSpeed);
    _delegate.silkyScrollGlobalManager.clearTrackpadMemory();
  }
}
