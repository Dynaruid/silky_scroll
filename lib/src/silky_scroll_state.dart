import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_controller.dart';
import 'blocked_scroll_physics.dart';
import 'silky_edge_detector.dart';
import 'silky_scroll_animator.dart';
import 'silky_input_handler.dart';

/// Magic number constants for scroll behavior tuning.
const double _kBubblingDeltaMultiplier = 2;
const int _kScrollDisableCheckDelayMs = 80;
const int _kMinManualScrollDurationMs = 250;
const int _kMaxManualScrollDurationMs = 800;
const double _kMaxBounceOvershoot = 150;

/// Describes the current physics-management phase.
///
/// Only one timer-driven phase is active at any time, preventing
/// race conditions between independent timers.
enum ScrollPhysicsPhase {
  /// Default — no timer is active, physics == widgetScrollPhysics.
  normal,

  /// A short delay before edge-checking (touch scroll).
  edgeCheckPending,

  /// Physics are blocked because the scroll is at an edge.
  edgeLocked,

  /// Overscroll stretch indicator is suppressed after touch-up.
  overscrollLocked,
}

/// Central state management for a [SilkyScroll] widget.
///
/// Composes [SilkyScrollAnimator], [SilkyEdgeDetector], and
/// [SilkyInputHandler] to keep itself a thin coordination layer.
class SilkyScrollState extends ChangeNotifier
    implements SilkyScrollAnimatorDelegate, SilkyInputHandlerDelegate {
  SilkyScrollState({
    ScrollController? scrollController,
    this.widgetScrollPhysics = const ScrollPhysics(),
    required this.edgeLockingDelay,
    required this.scrollSpeed,
    required this.silkyScrollDuration,
    required this.animationCurve,
    required this.isVertical,
    required this.enableScrollBubbling,
    required this.debugMode,
    this.onScroll,
    this.onEdgeOverScroll,
    required Function(PointerDeviceKind)? setManualPointerDeviceKind,
    required this.silkyScrollMousePointerManager,
    required TickerProvider vsync,
  }) {
    currentScrollPhysics = widgetScrollPhysics;
    isPlatformBouncingScrollPhysics =
        widgetScrollPhysics is BouncingScrollPhysics;

    if (scrollController != null) {
      clientController = scrollController;
      isControllerOwn = false;
    } else {
      clientController = ScrollController();
      isControllerOwn = true;
    }
    silkyScrollController = SilkyScrollController(
      clientController: clientController,
    );

    clientController.addListener(_onScrollUpdate);

    if (setManualPointerDeviceKind == null) {
      setPointerDeviceKind = silkyScrollController.setPointerDeviceKind;
    } else {
      setPointerDeviceKind = setManualPointerDeviceKind;
    }

    _animator = SilkyScrollAnimator(this, vsync);
    _inputHandler = SilkyInputHandler(this);
  }

  bool _disposed = false;
  @override
  late final ScrollController clientController;
  late final SilkyScrollController silkyScrollController;
  late final bool isControllerOwn;
  final UniqueKey instanceKey = UniqueKey();

  @override
  final Curve animationCurve;
  @override
  final Duration silkyScrollDuration;
  @override
  late final bool isPlatformBouncingScrollPhysics;

  late ScrollPhysics currentScrollPhysics;
  late ScrollPhysics widgetScrollPhysics;
  final BlockedScrollPhysics _blockedPhysics = const BlockedScrollPhysics();

  @override
  final bool enableScrollBubbling;
  @override
  final void Function(double delta)? onScroll;
  final void Function(double delta)? onEdgeOverScroll;
  @override
  late final Function(PointerDeviceKind) setPointerDeviceKind;
  final bool debugMode;

  @override
  bool prevDeltaPositive = false;
  @override
  bool isOnSilkyScrolling = false;
  @override
  bool isRecoilScroll = false;
  @override
  final bool isVertical;
  final Duration edgeLockingDelay;
  @override
  final double scrollSpeed;
  @override
  double futurePosition = 0;

  double lastDelta = 0;
  Timer? _phaseTimer;
  ScrollPhysicsPhase _physicsPhase = ScrollPhysicsPhase.normal;

  /// The current physics-management phase.
  ScrollPhysicsPhase get physicsPhase => _physicsPhase;

  /// Whether the scroll is currently locked at an edge.
  bool get isEdgeLocked => _physicsPhase == ScrollPhysicsPhase.edgeLocked;

  /// Whether the overscroll indicator is temporarily suppressed.
  bool get isOverscrollLocked =>
      _physicsPhase == ScrollPhysicsPhase.overscrollLocked;

  @override
  bool get isDisposed => _disposed;

  @override
  final SilkyScrollMousePointerManager silkyScrollMousePointerManager;
  SilkyScrollState? parentSilkyScrollState;
  bool _lastScrollDirectionNegative = true;
  bool isOverScrolling = false;

  // ── Composed helpers ──────────────────────────────────────────────
  late final SilkyScrollAnimator _animator;
  late final SilkyInputHandler _inputHandler;
  final SilkyEdgeDetector _edgeDetector = const SilkyEdgeDetector();

  // ── SilkyScrollAnimatorDelegate ──────────────────────────────────
  @override
  void onAnimationStateChanged() {
    // Recoil state changes do not affect the widget tree;
    // only physics changes need notifyListeners.
  }

  @override
  void setSilkyTickerActive(bool active) {
    silkyScrollController.currentSilkyScrollPosition?.silkyTickerActive =
        active;
  }

  // ── SilkyInputHandlerDelegate ────────────────────────────────────
  @override
  bool get isWebPlatform =>
      silkyScrollMousePointerManager.silkyScrollWebManager.isWebPlatform;

  @override
  void blockOverscrollBehaviorX() {
    silkyScrollMousePointerManager.silkyScrollWebManager
        .blockOverscrollBehaviorXHtml();
  }

  // ── Public API (delegated) ───────────────────────────────────────

  /// Routes touch/trackpad input through [SilkyInputHandler].
  void triggerTouchAction(Offset delta, PointerDeviceKind kind) =>
      _inputHandler.triggerTouchAction(delta, kind);

  /// Routes mouse input through [SilkyInputHandler].
  void triggerMouseAction(double scrollDeltaY) =>
      _inputHandler.triggerMouseAction(scrollDeltaY);

  /// Immediately cancels any in-progress smooth scroll animation.
  ///
  /// Called on mouse→trackpad switch so that trackpad direct scrolling
  /// takes effect immediately.
  void cancelSilkyScroll() {
    if (isOnSilkyScrolling && clientController.hasClients) {
      _animator.cancel();
      futurePosition = clientController.offset;
    }
  }

  // ── State machine transitions ─────────────────────────────────────

  void _transitionTo(
    ScrollPhysicsPhase phase, [
    Duration? timerDuration,
    VoidCallback? onTimeout,
  ]) {
    _phaseTimer?.cancel();
    _physicsPhase = phase;

    if (timerDuration != null && !_disposed) {
      _phaseTimer = Timer(timerDuration, () {
        if (!_disposed) {
          onTimeout?.call();
        }
      });
    }
  }

  // ── Edge locking ─────────────────────────────────────────────────

  void _checkNeedLocking() {
    if (_disposed || !clientController.hasClients || lastDelta.abs() < 0.5) {
      _transitionTo(ScrollPhysicsPhase.normal);
      return;
    }

    final double delta = lastDelta.isNegative ? -1 : 1;

    if (clientController.position.maxScrollExtent < 0.5) {
      lastDelta = 0;
      _transitionTo(ScrollPhysicsPhase.normal);
      return;
    }

    final int edgeResult = _edgeDetector.checkOffsetAtEdge(
      delta,
      clientController,
    );
    if (edgeResult != 0 &&
        currentScrollPhysics is! BlockedScrollPhysics &&
        !isOverScrolling) {
      onEdgeOverScroll?.call(lastDelta);
      currentScrollPhysics = _blockedPhysics;
      notifyListeners();

      _transitionTo(
        ScrollPhysicsPhase.edgeLocked,
        edgeLockingDelay,
        _unlockScroll,
      );

      if (parentSilkyScrollState != null && enableScrollBubbling) {
        parentSilkyScrollState!.manualHandleScroll(
          lastDelta * _kBubblingDeltaMultiplier,
          isVertical,
        );
      }

      lastDelta = 0;
      return;
    }

    lastDelta = 0;
    _transitionTo(ScrollPhysicsPhase.normal);
  }

  void _unlockScroll() {
    if (!_disposed) {
      currentScrollPhysics = widgetScrollPhysics;
      _transitionTo(ScrollPhysicsPhase.normal);
      notifyListeners();
    }
  }

  // ── Touch scroll ─────────────────────────────────────────────────

  @override
  void handleTouchScroll(double delta) {
    lastDelta += delta;
    // Don't start a new edge-check timer when an edge-lock or
    // overscroll-lock timer is already running — doing so would cancel
    // the pending _unlockScroll callback and leave currentScrollPhysics
    // permanently stuck as BlockedScrollPhysics (NeverScrollableScrollPhysics),
    // completely disabling touch and trackpad scrolling.
    if (_physicsPhase != ScrollPhysicsPhase.normal) return;

    _transitionTo(
      ScrollPhysicsPhase.edgeCheckPending,
      const Duration(milliseconds: _kScrollDisableCheckDelayMs),
      _checkNeedLocking,
    );
  }

  // ── Mouse scroll ─────────────────────────────────────────────────

  @override
  void handleMouseScroll(double delta, double scrollSpeed) {
    if (isRecoilScroll) return;

    if (currentScrollPhysics != widgetScrollPhysics) {
      currentScrollPhysics = widgetScrollPhysics;
      notifyListeners();
    }

    final double scrollDelta = delta;
    final bool isEdge =
        _edgeDetector.checkOffsetAtEdge(scrollDelta, clientController) != 0;
    final bool needBlocking =
        widgetScrollPhysics is BlockedScrollPhysics || isEdge;

    if (instanceKey == silkyScrollMousePointerManager.reserveKey) {
      if (!isOnSilkyScrolling) {
        if (needBlocking) {
          if (isEdge) onEdgeOverScroll?.call(delta);
          silkyScrollMousePointerManager.reservingKey(instanceKey);
          return;
        }
        silkyScrollMousePointerManager.reserveKey = null;
        silkyScrollMousePointerManager.enteredKey(instanceKey);
      }
    }
    if (!isOnSilkyScrolling && needBlocking) {
      if (isEdge) onEdgeOverScroll?.call(delta);
      silkyScrollMousePointerManager.reservingKey(instanceKey);
      return;
    }

    if (silkyScrollMousePointerManager.keyStack.isNotEmpty &&
        instanceKey != silkyScrollMousePointerManager.keyStack.last) {
      return;
    }

    _animator.animateToScroll(scrollDelta, scrollSpeed);
  }

  // ── Manual handle scroll (bubbling from child) ───────────────────

  void manualHandleScroll(double delta, bool callIsVertical) {
    if (_disposed) return;

    if (currentScrollPhysics is! NeverScrollableScrollPhysics &&
        callIsVertical == isVertical) {
      if (delta.isNegative == _lastScrollDirectionNegative) {
        futurePosition = min(
          max(0, futurePosition + delta),
          clientController.position.maxScrollExtent,
        );
      } else {
        _lastScrollDirectionNegative = delta.isNegative;
        futurePosition = min(
          max(0, clientController.offset + delta),
          clientController.position.maxScrollExtent,
        );
      }

      final Duration duration = Duration(
        milliseconds: min(
          _kMaxManualScrollDurationMs,
          max(
            _kMinManualScrollDurationMs,
            ((delta.abs() / _kMaxBounceOvershoot) * _kMinManualScrollDurationMs)
                .toInt(),
          ),
        ),
      );
      clientController.animateTo(
        futurePosition,
        duration: duration,
        curve: Curves.easeOutQuad,
      );
    } else {
      parentSilkyScrollState?.manualHandleScroll(delta, callIsVertical);
    }
  }

  // ── Physics management ───────────────────────────────────────────

  void setWidgetScrollPhysics({required ScrollPhysics scrollPhysics}) {
    _transitionTo(ScrollPhysicsPhase.normal);
    widgetScrollPhysics = scrollPhysics;
    currentScrollPhysics = scrollPhysics;
  }

  /// Activate overscroll-lock phase for [duration].
  ///
  /// While active, the overscroll stretch indicator is suppressed.
  void beginOverscrollLock(Duration duration) {
    isOverScrolling = false;
    _transitionTo(
      ScrollPhysicsPhase.overscrollLocked,
      duration,
      () => _transitionTo(ScrollPhysicsPhase.normal),
    );
  }

  // ── Scroll position sync ────────────────────────────────────────

  void _onScrollUpdate() {
    if (!isOnSilkyScrolling) {
      futurePosition = clientController.offset;
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void dispose() {
    // 1. Mark as disposed first to guard all timer/listener callbacks.
    _disposed = true;

    // 2. Cancel all pending timers.
    _phaseTimer?.cancel();
    _phaseTimer = null;

    // 3. Remove our listener *before* disposing controllers, so that
    //    any position detach during dispose does not trigger our callback.
    clientController.removeListener(_onScrollUpdate);

    // 4. Detach our key from the pointer manager.
    silkyScrollMousePointerManager.detachKey(instanceKey);

    // 5. Dispose the animator (stops Ticker).
    _animator.dispose();

    // 6. Dispose silkyScrollController (detaches positions from both
    //    controllers via the guarded attach/detach overrides).
    silkyScrollController.dispose();

    // 7. Only dispose the client controller if we own it.
    if (isControllerOwn) {
      clientController.dispose();
    }

    super.dispose();
  }
}
