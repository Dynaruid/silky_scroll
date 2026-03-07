import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_controller.dart';
import 'blocked_scroll_physics.dart';
import 'silky_edge_detector.dart';
import 'silky_scroll_animator.dart';
import 'silky_input_handler.dart';
import 'scroll_delta_sample.dart';
import 'scroll_delta_sample_analyzer.dart';

/// Magic number constants for scroll behavior tuning.
const int _kScrollDisableCheckDelayMs = 100;
const double _kMaxBounceOvershoot = 120;
const double _kInwardVelocityThresholdPxS = 5.0;
const int _kDeltaSampleRetentionMs = 1000;

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
    required this.debugMode,
    this.decayLogFactor = kDefaultDecayLogFactor,
    this.recoilDurationSec = kDefaultRecoilDurationSec,
    this.onScroll,
    this.onEdgeOverScroll,
    required Function(PointerDeviceKind)? setManualPointerDeviceKind,
    required this.silkyScrollMousePointerManager,
    required TickerProvider vsync,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
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

    _animator = SilkyScrollAnimator(
      this,
      vsync,
      maxBounceOvershoot: _kMaxBounceOvershoot,
      decayLogFactor: decayLogFactor,
      recoilDurationSec: recoilDurationSec,
    );
    _inputHandler = SilkyInputHandler(this);
  }

  bool _disposed = false;
  final int Function() _clock;
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

  final double decayLogFactor;
  final double recoilDurationSec;

  late ScrollPhysics currentScrollPhysics;
  late ScrollPhysics widgetScrollPhysics;
  final BlockedScrollPhysics _blockedPhysics = const BlockedScrollPhysics();

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
  bool isOverScrolling = false;
  bool _isTouchActive = false;
  int _lockedEdgeDirection = 0;

  // ── Scroll delta samples ──────────────────────────────────────────
  final List<ScrollDeltaSample> _recentDeltaSamples = [];

  // Speed cache — reused within the same ~16 ms frame.
  double? _cachedScrollSpeed;
  int _cachedSpeedTimeMs = 0;

  /// Current scroll speed in logical-pixels / second.
  ///
  /// Computed from recent delta samples using time-window grouping.
  /// The result is cached for ~16 ms (one frame) to avoid redundant
  /// recalculation across multiple call-sites per event.
  double get currentScrollSpeed {
    final int now = _clock();
    if (_cachedScrollSpeed != null && now - _cachedSpeedTimeMs < 16) {
      return _cachedScrollSpeed!;
    }
    _cachedScrollSpeed = ScrollDeltaSampleAnalyzer.calculateAverageSpeed(
      _recentDeltaSamples,
    );
    _cachedSpeedTimeMs = now;
    return _cachedScrollSpeed!;
  }

  void _recordDelta(double delta) {
    final int now = _clock();
    _recentDeltaSamples.add(ScrollDeltaSample(delta, now));
    // Trim old samples — exploit time-sorted order.
    final int cutoff = now - _kDeltaSampleRetentionMs;
    int removeCount = 0;
    for (final sample in _recentDeltaSamples) {
      if (sample.timeMs >= cutoff) break;
      removeCount++;
    }
    if (removeCount > 0) {
      _recentDeltaSamples.removeRange(0, removeCount);
    }
  }

  // ── Composed helpers ──────────────────────────────────────────────
  late final SilkyScrollAnimator _animator;
  late final SilkyInputHandler _inputHandler;
  final SilkyEdgeDetector _edgeDetector = const SilkyEdgeDetector();

  // ── SilkyScrollAnimatorDelegate ──────────────────────────────────
  @override
  void onAnimationStateChanged() {
    if (isRecoilScroll) {
      // Block physics during recoil so BouncingScrollPhysics does not
      // trigger overscroll visual effects while jumpTo() overshoots.
      if (currentScrollPhysics is! BlockedScrollPhysics) {
        currentScrollPhysics = _blockedPhysics;
        notifyListeners();
      }
    } else {
      // Recoil finished — restore normal physics only after the
      // position has fully returned to within scroll bounds.
      if (currentScrollPhysics is BlockedScrollPhysics &&
          _physicsPhase != ScrollPhysicsPhase.edgeLocked) {
        currentScrollPhysics = widgetScrollPhysics;
        notifyListeners();
      }
    }
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

  /// Called when a touch pointer goes down.
  ///
  /// Keeps an active edge lock so that repeated outward drags at the
  /// same edge remain blocked.  Inward unlock is handled separately
  /// by [tryGestureUnlock] from the [Listener].
  void onTouchDown() {
    _isTouchActive = true;
    if (debugMode) {
      debugPrint(
        '[SilkyScroll] onTouchDown | phase=$_physicsPhase '
        'lockedEdge=$_lockedEdgeDirection',
      );
    }
  }

  /// Called when a touch pointer goes up.
  ///
  /// If the scroll is at an edge, activates a direction-aware edge lock
  /// for [edgeLockingDelay].
  void onTouchUp() {
    _isTouchActive = false;
    if (debugMode) {
      debugPrint(
        '[SilkyScroll] onTouchUp | phase=$_physicsPhase '
        'lockedEdge=$_lockedEdgeDirection',
      );
    }
    _checkEdgeLockOnTouchUp();
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
    final double speed = currentScrollSpeed;
    if (_disposed || !clientController.hasClients || speed.abs() < 0.5) {
      _transitionTo(ScrollPhysicsPhase.normal);
      return;
    }

    if (clientController.position.maxScrollExtent < 0.5) {
      _transitionTo(ScrollPhysicsPhase.normal);
      return;
    }

    final int edgeResult = _edgeDetector.checkOffsetAtEdge(
      speed,
      clientController,
    );
    if (edgeResult != 0 &&
        currentScrollPhysics is! BlockedScrollPhysics &&
        !isOverScrolling) {
      currentScrollPhysics = _blockedPhysics;
      notifyListeners();

      _transitionTo(
        ScrollPhysicsPhase.edgeLocked,
        edgeLockingDelay,
        _unlockScroll,
      );

      return;
    }

    _transitionTo(ScrollPhysicsPhase.normal);
  }

  void _checkEdgeLockOnTouchUp() {
    if (_disposed || !clientController.hasClients) return;
    if (clientController.position.maxScrollExtent < 0.5) return;
    if (_physicsPhase != ScrollPhysicsPhase.normal &&
        _physicsPhase != ScrollPhysicsPhase.edgeCheckPending &&
        _physicsPhase != ScrollPhysicsPhase.overscrollLocked) {
      return;
    }

    final int edgeResult = _edgeDetector.checkOffsetAtEdge(
      currentScrollSpeed,
      clientController,
    );
    if (edgeResult == 0) return;

    _lockedEdgeDirection = edgeResult;
    if (debugMode) {
      debugPrint(
        '[SilkyScroll] _checkEdgeLockOnTouchUp → LOCKED '
        'edge=$_lockedEdgeDirection (${edgeResult == -1 ? "top" : "bottom"})'
        ' currentScrollSpeed=$currentScrollSpeed',
      );
    }

    currentScrollPhysics = _blockedPhysics;
    notifyListeners();

    _transitionTo(
      ScrollPhysicsPhase.edgeLocked,
      edgeLockingDelay,
      _unlockScroll,
    );
  }

  /// Checks whether the pointer gesture has moved enough in the
  /// inward direction (away from the locked edge) to release the lock.
  ///
  /// Called from [Listener.onPointerMove] while the touch is active
  /// and the scroll is edge-locked.  Returns `true` if the lock was
  /// released.
  bool _tryGestureUnlock() {
    if (_physicsPhase != ScrollPhysicsPhase.edgeLocked ||
        _lockedEdgeDirection == 0) {
      return false;
    }

    // Velocity sign indicates direction in screen coordinates:
    //   top edge  (-1): inward velocity is negative → product < 0
    //   bottom edge (1): inward velocity is positive → product < 0
    final bool isInward =
        currentScrollSpeed.abs() >= _kInwardVelocityThresholdPxS &&
        _lockedEdgeDirection * currentScrollSpeed.toInt() < 0;

    if (debugMode) {
      debugPrint(
        '[SilkyScroll] tryGestureUnlock | '
        'edge=$_lockedEdgeDirection velocity=${currentScrollSpeed.toStringAsFixed(1)} '
        'inward=$isInward',
      );
    }

    if (isInward) {
      if (debugMode) debugPrint('[SilkyScroll] ★ UNLOCKED by gesture');
      _unlockScroll();
      return true;
    }
    return false;
  }

  void _unlockScroll() {
    if (!_disposed) {
      _lockedEdgeDirection = 0;
      currentScrollPhysics = widgetScrollPhysics;
      _transitionTo(ScrollPhysicsPhase.normal);
      notifyListeners();
    }
  }

  // ── Touch scroll ─────────────────────────────────────────────────

  @override
  void handleTouchScroll(double delta) {
    _recordDelta(delta);

    final int edgeResult = _edgeDetector.checkOffsetAtEdge(
      delta,
      clientController,
    );
    if (edgeResult != 0) {
      onEdgeOverScroll?.call(delta);
    }

    _tryGestureUnlock();
    // ── Touch-active: no locking, just edge notification ──
    if (_isTouchActive) {
      //Touch에서는 onTouchUp에서 edge lock이 걸림
      return;
    }

    // ── Original trackpad edge-locking behavior ──
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
    _recordDelta(delta);

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

    // 2. Cancel all pending timers and clear samples.
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _recentDeltaSamples.clear();

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
