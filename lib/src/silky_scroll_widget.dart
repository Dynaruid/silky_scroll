import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'silky_scroll_config.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_state.dart';

/// A widget that provides smooth, animated scrolling on all platforms.
///
/// Wraps any scrollable child and automatically handles mouse wheel, trackpad,
/// and touch input to deliver a silky-smooth scrolling experience.
///
/// Example:
/// ```dart
/// SilkyScroll(
///   builder: (context, controller, physics) => ListView(
///     controller: controller,
///     physics: physics,
///     children: [...],
///   ),
/// )
/// ```
class SilkyScroll extends StatefulWidget {
  const SilkyScroll({
    super.key,
    this.controller,
    this.silkyScrollDuration = const Duration(milliseconds: 700),
    this.scrollSpeed = 1,
    this.animationCurve = Curves.easeOutQuart,
    this.direction = Axis.vertical,
    this.physics = const ScrollPhysics(),
    this.edgeLockingDelay = const Duration(milliseconds: 650),
    this.overScrollingLockingDelay = const Duration(milliseconds: 700),
    this.enableStretchEffect = true,
    this.enableScrollBubbling = false,
    this.debugMode = false,
    this.setManualPointerDeviceKind,
    this.onScroll,
    this.onEdgeOverScroll,
    required this.builder,
  });

  /// Creates a [SilkyScroll] from a [SilkyScrollConfig] object.
  ///
  /// This is convenient when sharing the same configuration across
  /// multiple scroll widgets.
  SilkyScroll.fromConfig({
    super.key,
    required SilkyScrollConfig config,
    this.controller,
    this.setManualPointerDeviceKind,
    this.onScroll,
    this.onEdgeOverScroll,
    required this.builder,
  }) : silkyScrollDuration = config.silkyScrollDuration,
       scrollSpeed = config.scrollSpeed,
       animationCurve = config.animationCurve,
       direction = config.direction,
       physics = config.physics,
       edgeLockingDelay = config.edgeLockingDelay,
       overScrollingLockingDelay = config.overScrollingLockingDelay,
       enableStretchEffect = config.enableStretchEffect,
       enableScrollBubbling = config.enableScrollBubbling,
       debugMode = config.debugMode;

  /// An optional external [ScrollController].
  ///
  /// If not provided, an internal controller is created and managed
  /// automatically.
  final ScrollController? controller;

  /// Duration of the smooth scroll animation.
  ///
  /// Defaults to 700 ms.
  final Duration silkyScrollDuration;

  /// Multiplier for the scroll delta. Higher values scroll faster.
  ///
  /// Defaults to `1`.
  final double scrollSpeed;

  /// The animation curve applied to smooth scrolling.
  ///
  /// Defaults to [Curves.easeOutQuart].
  final Curve animationCurve;

  /// The scroll direction. Defaults to [Axis.vertical].
  final Axis direction;

  /// The [ScrollPhysics] applied to the scrollable child.
  final ScrollPhysics physics;

  /// Builder that provides a [ScrollController] and [ScrollPhysics]
  /// for the scrollable child widget.
  final SilkyScrollWidgetBuilder builder;

  /// How long the scroll is locked after reaching an edge.
  ///
  /// Prevents accidental parent-scroll activation. Defaults to 650 ms.
  final Duration edgeLockingDelay;

  /// How long the overscroll effect is suppressed after touch-up.
  ///
  /// Defaults to 700 ms.
  final Duration overScrollingLockingDelay;

  /// Whether nested scroll views should bubble scroll momentum
  /// to the parent when they reach their edge.
  ///
  /// Defaults to `false`.
  final bool enableScrollBubbling;

  /// Whether to allow the platform stretch / glow overscroll effect.
  ///
  /// Defaults to `true`.
  final bool enableStretchEffect;

  /// Called on every scroll delta (both mouse and touch).
  final void Function(double delta)? onScroll;

  /// Called when the user scrolls past the edge.
  final void Function(double delta)? onEdgeOverScroll;

  /// Allows manually overriding the detected pointer device kind.
  final Function(PointerDeviceKind)? setManualPointerDeviceKind;

  /// Enables debug logging. Defaults to `false`.
  final bool debugMode;

  @override
  State<SilkyScroll> createState() => _SilkyScrollState();
}

class _SilkyScrollState extends State<SilkyScroll> {
  late final SilkyScrollState silkyScrollState;
  late final SilkyScrollMousePointerManager silkyScrollMousePointerManager;
  late ScrollPhysics currentPhysics;
  @override
  void initState() {
    super.initState();
    silkyScrollMousePointerManager = SilkyScrollMousePointerManager();
    silkyScrollState = SilkyScrollState(
      scrollController: widget.controller,
      widgetScrollPhysics: widget.physics,
      silkyScrollDuration: widget.silkyScrollDuration,
      animationCurve: widget.animationCurve,
      edgeLockingDelay: widget.edgeLockingDelay,
      scrollSpeed: widget.scrollSpeed,
      setManualPointerDeviceKind: widget.setManualPointerDeviceKind,
      isVertical: widget.direction == Axis.vertical,
      enableScrollBubbling: widget.enableScrollBubbling,
      silkyScrollMousePointerManager: silkyScrollMousePointerManager,
      onScroll: widget.onScroll,
      onEdgeOverScroll: widget.onEdgeOverScroll,
      debugMode: widget.debugMode,
    );
    currentPhysics = widget.physics;
  }

  @override
  void didUpdateWidget(covariant SilkyScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.physics != widget.physics) {
      silkyScrollState.setWidgetScrollPhysics(scrollPhysics: widget.physics);
    }
  }

  @override
  void dispose() {
    silkyScrollState.dispose();
    super.dispose();
  }

  bool _handleTrackpadCheck(PointerDeviceKind kind) {
    if (kind == PointerDeviceKind.trackpad) {
      silkyScrollState.setPointerDeviceKind(PointerDeviceKind.trackpad);
      silkyScrollMousePointerManager.markTrackpadHeuristic();
      return true;
    } else {
      return false;
    }
  }

  void _onPointerSignal(PointerSignalEvent signalEvent) {
    if (signalEvent is! PointerScrollEvent) return;

    // ── Step 1: Platform directly reports trackpad ──
    if (_handleTrackpadCheck(signalEvent.kind)) {
      _ensureTrackpadMode();
      silkyScrollState.triggerTouchAction(
        signalEvent.scrollDelta,
        PointerDeviceKind.trackpad,
      );
      return;
    }

    final double scrollDeltaY = signalEvent.scrollDelta.dy;
    final double scrollDeltaX = signalEvent.scrollDelta.dx;

    // ── Step 2: Heuristic — horizontal delta or tiny vertical delta → trackpad ──
    // ★ Runs before timer checks → detects device switch immediately ★
    if ((scrollDeltaX * 10).toInt() != 0 || scrollDeltaY.abs() < 4) {
      _handleTrackpadCheck(PointerDeviceKind.trackpad);
      _ensureTrackpadMode();
      silkyScrollState.triggerTouchAction(
        signalEvent.scrollDelta,
        PointerDeviceKind.trackpad,
      );
      return;
    }

    // ── Step 3: Recent trackpad activity → trackpad (fast vertical swipe) ──
    // Unified check that combines two platform-specific signals:
    //   • Native: PanZoom activity within _kPanZoomTimeoutMs (high-confidence)
    //   • Web:    Heuristic match within _kHeuristicTrackpadTimeoutMs (no PanZoom on web)
    //
    // Why we don't filter out signalEvent.kind == mouse here:
    //   On Flutter Web, trackpad scroll events report kind == trackpad only
    //   at the *start* of the gesture. Subsequent frames arrive with
    //   kind == mouse and only carry a delta — no device kind update.
    //   The _kHeuristicTrackpadTimeoutMs heuristic window exists precisely to cover these
    //   "headless" follow-up frames, so excluding mouse would break
    //   web trackpad detection entirely.
    //
    //   On native, this branch is guarded by _panZoomTimer (_kPanZoomTimeoutMs),
    //   which is short enough that a real mouse event within that
    //   window is extremely unlikely.
    if (silkyScrollMousePointerManager.isRecentlyTrackpad) {
      silkyScrollState.triggerTouchAction(
        signalEvent.scrollDelta,
        PointerDeviceKind.trackpad,
      );
      return;
    }

    // ── Step 4: Treat as mouse ──
    silkyScrollState.triggerMouseAction(scrollDeltaY);
  }

  /// Cancel any in-progress mouse animation when switching to trackpad mode.
  void _ensureTrackpadMode() {
    silkyScrollState.cancelSilkyScroll();
  }

  @override
  Widget build(BuildContext context) {
    silkyScrollState.parentSilkyScrollState = _SilkyScrollScope.maybeOf(
      context,
    );
    return _SilkyScrollScope(
      state: silkyScrollState,
      child: ListenableBuilder(
        listenable: silkyScrollState,
        builder: (BuildContext context, Widget? child) {
          currentPhysics = silkyScrollState.currentScrollPhysics;
          return MouseRegion(
            onEnter: (e) {
              silkyScrollMousePointerManager.enteredKey(
                silkyScrollState.instanceKey,
              );
            },
            onExit: (e) {
              silkyScrollMousePointerManager.exitKey(
                silkyScrollState.instanceKey,
              );
            },
            opaque: false,
            child: NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (OverscrollIndicatorNotification overscroll) {
                if (silkyScrollState.isEdgeLocked ||
                    silkyScrollState.isOverscrollLocked ||
                    !widget.enableStretchEffect) {
                  overscroll.disallowIndicator();
                  return false;
                }
                silkyScrollState.isOverScrolling = true;
                return true;
              },
              child: Listener(
                onPointerHover: (PointerHoverEvent signalEvent) {
                  _handleTrackpadCheck(signalEvent.kind);
                },
                onPointerSignal: _onPointerSignal,
                onPointerMove: (PointerMoveEvent event) {
                  if (event.kind == PointerDeviceKind.touch) {
                    silkyScrollState.setPointerDeviceKind(
                      PointerDeviceKind.touch,
                    );
                    silkyScrollState.triggerTouchAction(
                      event.delta,
                      PointerDeviceKind.touch,
                    );
                  }
                },
                onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent event) {
                  silkyScrollState.setPointerDeviceKind(
                    PointerDeviceKind.trackpad,
                  );
                  silkyScrollMousePointerManager.markPanZoomActivity();
                  silkyScrollState.cancelSilkyScroll();

                  silkyScrollState.triggerTouchAction(
                    event.panDelta,
                    PointerDeviceKind.trackpad,
                  );
                },
                onPointerPanZoomEnd: (PointerPanZoomEndEvent event) {
                  silkyScrollMousePointerManager.clearPanZoomMemory();
                },
                onPointerUp: (PointerUpEvent event) {
                  if (event.kind == PointerDeviceKind.touch) {
                    if (silkyScrollState.isOverScrolling) {
                      silkyScrollState.beginOverscrollLock(
                        widget.overScrollingLockingDelay,
                      );
                    }
                  }
                },
                child: widget.builder(
                  context,
                  silkyScrollState.silkyScrollController,
                  currentPhysics,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Signature for the builder callback used by [SilkyScroll].
///
/// Receives a managed [ScrollController] and [ScrollPhysics] that must
/// be forwarded to the scrollable child.
typedef SilkyScrollWidgetBuilder =
    Widget Function(
      BuildContext context,
      ScrollController controller,
      ScrollPhysics physics,
    );

/// InheritedWidget to propagate [SilkyScrollState] down the widget tree,
/// replacing the previous `provider` dependency.
class _SilkyScrollScope extends InheritedWidget {
  const _SilkyScrollScope({required this.state, required super.child});

  final SilkyScrollState? state;

  static SilkyScrollState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SilkyScrollScope>()
        ?.state;
  }

  @override
  bool updateShouldNotify(_SilkyScrollScope oldWidget) {
    return state != oldWidget.state;
  }
}
