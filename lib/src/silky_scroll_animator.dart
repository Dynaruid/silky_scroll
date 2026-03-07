import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

const double _kScrollDeltaFactor = 0.5;

/// Snap threshold: when the remaining distance is below this value
/// (in logical pixels), the scroll jumps to the target and stops.
const double _kSnapThreshold = 0.9;

/// Default value for [SilkyScrollAnimator.decayLogFactor].
///
/// Used to derive an exponential-decay rate from [silkyScrollDuration].
/// Higher values make the scroll converge faster toward [futurePosition].
const double kDefaultDecayLogFactor = 12;

/// Default value for [SilkyScrollAnimator.recoilDurationSec].
///
/// Duration of the recoil (bounce-back) animation in seconds.
const double kDefaultRecoilDurationSec = 0.2;

/// Callback interface used by [SilkyScrollAnimator] to communicate
/// state changes back to the owning [SilkyScrollState].
abstract interface class SilkyScrollAnimatorDelegate {
  ScrollController get clientController;

  Curve get animationCurve;

  Duration get silkyScrollDuration;

  bool get isPlatformBouncingScrollPhysics;

  double get futurePosition;

  set futurePosition(double value);

  bool get prevDeltaPositive;

  set prevDeltaPositive(bool value);

  bool get isOnSilkyScrolling;

  set isOnSilkyScrolling(bool value);

  bool get isRecoilScroll;

  set isRecoilScroll(bool value);

  bool get isDisposed;

  void onAnimationStateChanged();

  /// Toggle the ballistic-suppression flag on the scroll position.
  ///
  /// While `true`, [SilkyScrollPosition.goBallistic] is a no-op,
  /// preventing Flutter's physics from fighting with our Ticker.
  void setSilkyTickerActive(bool active);
}

/// Handles smooth-scroll animation using a single [Ticker].
///
/// Instead of calling `controller.animateTo()` per wheel event (which
/// cancels the previous animation and restarts the easing curve from
/// its slow start), this class runs a **single [Ticker]** that
/// interpolates towards [futurePosition] every frame using
/// frame-rate-independent exponential smoothing.
///
/// New wheel events simply update [futurePosition] — the Ticker
/// naturally tracks the moving target without any restart, producing
/// the silky-smooth feel of browser smooth-scroll implementations
/// (Chrome, Firefox).
final class SilkyScrollAnimator {
  SilkyScrollAnimator(
    this._delegate,
    TickerProvider vsync, {
    required this.maxBounceOvershoot,
    this.decayLogFactor = kDefaultDecayLogFactor,
    this.recoilDurationSec = kDefaultRecoilDurationSec,
  }) : _smoothingFactor =
           decayLogFactor /
           (_delegate.silkyScrollDuration.inMilliseconds / 1000.0) {
    _ticker = vsync.createTicker(_onTick);
  }

  final SilkyScrollAnimatorDelegate _delegate;
  final double maxBounceOvershoot;

  /// Used to derive an exponential-decay rate from [silkyScrollDuration].
  /// Higher values make the scroll converge faster toward [futurePosition].
  final double decayLogFactor;

  /// Duration of the recoil (bounce-back) animation in seconds.
  final double recoilDurationSec;

  /// Exponential decay rate derived from [silkyScrollDuration].
  /// Higher values → faster convergence to [futurePosition].
  final double _smoothingFactor;

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // ── Recoil (bounce-back to edge) state ────────────────────────
  double? _recoilTarget;
  double _recoilStartOffset = 0;
  double _recoilElapsedSec = 0;

  /// Animates the scroll towards a new position based on [scrollDelta].
  ///
  /// Unlike the previous `animateTo()`-based approach, this merely
  /// updates [futurePosition] and ensures the Ticker is running.
  /// The per-frame [_onTick] callback handles the actual interpolation.
  void animateToScroll(double scrollDelta, double scrollSpeed) {
    final controller = _delegate.clientController;

    // ── Update futurePosition ───────────────────────────────────
    if (scrollDelta > 0 != _delegate.prevDeltaPositive) {
      _delegate.prevDeltaPositive = !_delegate.prevDeltaPositive;
      _delegate.futurePosition =
          controller.offset + (scrollDelta * scrollSpeed * _kScrollDeltaFactor);
    } else {
      _delegate.futurePosition =
          _delegate.futurePosition +
          (scrollDelta * scrollSpeed * _kScrollDeltaFactor);
    }

    // ── Clamp to edges ± maxBounceOvershoot ─────────────────────
    final double overshoot = _delegate.isPlatformBouncingScrollPhysics
        ? maxBounceOvershoot
        : 0;
    _delegate.futurePosition = _delegate.futurePosition.clamp(
      controller.position.minScrollExtent - overshoot,
      controller.position.maxScrollExtent + overshoot,
    );

    // Clear any recoil in progress — new scroll input takes priority.
    _recoilTarget = null;

    // Start the ticker if not already running.
    _delegate.isOnSilkyScrolling = true;
    _ensureTickerRunning();
  }

  // ── Ticker lifecycle ──────────────────────────────────────────

  void _ensureTickerRunning() {
    if (!_ticker.isActive && !_delegate.isDisposed) {
      _lastElapsed = Duration.zero;
      _delegate.setSilkyTickerActive(true);
      _ticker.start();
    }
  }

  void _stopTicker() {
    _delegate.setSilkyTickerActive(false);
    if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  // ── Per-frame callback ────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_delegate.isDisposed || !_delegate.clientController.hasClients) {
      _stopTicker();
      return;
    }

    final double dt = _lastElapsed == Duration.zero
        ? 1.0 /
              60.0 // assume 60 fps for the very first frame
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    // Guard against bad frame times (tab switch, debugger pause, etc.)
    if (dt <= 0 || dt > 0.1) return;

    final controller = _delegate.clientController;

    // ── Recoil phase (bounce-back to edge) ──
    if (_recoilTarget != null) {
      _tickRecoil(controller, dt);
      return;
    }

    // ── Normal smooth-scroll phase ──
    _tickScroll(controller, dt);
  }

  void _tickScroll(ScrollController controller, double dt) {
    final double target = _delegate.futurePosition;
    final double current = controller.offset;
    final double diff = target - current;

    if (diff.abs() < _kSnapThreshold) {
      controller.jumpTo(target);
      _delegate.isOnSilkyScrolling = false;
      _checkRecoil(controller);
      if (_recoilTarget == null) {
        _stopTicker();
      }
      return;
    }

    // Exponential smoothing: move a proportional fraction of the
    // remaining distance each frame.  The formula
    //   factor = 1 - e^(-smoothingFactor * dt)
    // guarantees frame-rate independence.
    final double factor = 1.0 - exp(-_smoothingFactor * dt);
    controller.jumpTo(current + diff * factor);
  }

  void _tickRecoil(ScrollController controller, double dt) {
    _recoilElapsedSec += dt;
    final double t = (_recoilElapsedSec / recoilDurationSec).clamp(0.0, 1.0);
    final double curved = Curves.easeInOutSine.transform(t);
    final double newPos =
        _recoilStartOffset + (_recoilTarget! - _recoilStartOffset) * curved;

    controller.jumpTo(newPos);

    if (t >= 1.0) {
      controller.jumpTo(_recoilTarget!);
      _recoilTarget = null;
      _delegate.isRecoilScroll = false;
      _delegate.onAnimationStateChanged();
      _delegate.futurePosition = controller.offset;
      _stopTicker();
    }
  }

  void _checkRecoil(ScrollController controller) {
    if (!_delegate.isPlatformBouncingScrollPhysics) return;

    final double? edgePosition = switch (controller.offset) {
      final o when o > controller.position.maxScrollExtent =>
        controller.position.maxScrollExtent,
      final o when o < controller.position.minScrollExtent =>
        controller.position.minScrollExtent,
      _ => null,
    };

    if (edgePosition != null) {
      _delegate.isRecoilScroll = true;
      _delegate.onAnimationStateChanged();
      _recoilTarget = edgePosition;
      _recoilStartOffset = controller.offset;
      _recoilElapsedSec = 0;
      _ensureTickerRunning();
    }
  }

  /// Immediately cancels any in-progress animation (scroll or recoil).
  void cancel() {
    _stopTicker();
    _recoilTarget = null;
    if (_delegate.isOnSilkyScrolling) {
      _delegate.isOnSilkyScrolling = false;
    }
    if (_delegate.isRecoilScroll) {
      _delegate.isRecoilScroll = false;
      _delegate.onAnimationStateChanged();
    }
  }

  /// Disposes the internal [Ticker].
  void dispose() {
    _stopTicker();
    _ticker.dispose();
  }
}
