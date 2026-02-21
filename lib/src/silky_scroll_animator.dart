import 'dart:math';
import 'package:flutter/material.dart';

const double _kScrollDeltaFactor = 0.5;
const double _kMaxBounceOvershoot = 150;
const double _kRecoilDurationRatio = 0.8;

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
}

/// Handles smooth-scroll animation and bounce-back (recoil) logic.
///
/// Extracted from [SilkyScrollState] to follow the Single
/// Responsibility Principle.
final class SilkyScrollAnimator {
  SilkyScrollAnimator(this._delegate)
    : recoilDurationMs =
          (_delegate.silkyScrollDuration.inMilliseconds * _kRecoilDurationRatio)
              .toInt();

  final SilkyScrollAnimatorDelegate _delegate;
  final int recoilDurationMs;

  Future<void>? _animationEnd;

  /// Animates the scroll to a new position based on [scrollDelta].
  void animateToScroll(double scrollDelta, double scrollSpeed) {
    final controller = _delegate.clientController;

    if (scrollDelta > 0 != _delegate.prevDeltaPositive) {
      _delegate.prevDeltaPositive = !_delegate.prevDeltaPositive;
      _delegate.futurePosition =
          controller.offset + (scrollDelta * scrollSpeed * _kScrollDeltaFactor);
    } else {
      _delegate.futurePosition =
          _delegate.futurePosition +
          (scrollDelta * scrollSpeed * _kScrollDeltaFactor);
    }

    final Duration duration;
    if (_delegate.futurePosition > controller.position.maxScrollExtent) {
      _delegate.futurePosition = _delegate.isPlatformBouncingScrollPhysics
          ? min(
              controller.position.maxScrollExtent + _kMaxBounceOvershoot,
              _delegate.futurePosition,
            )
          : controller.position.maxScrollExtent;
      duration = Duration(
        milliseconds: _delegate.silkyScrollDuration.inMilliseconds ~/ 2,
      );
    } else if (_delegate.futurePosition < controller.position.minScrollExtent) {
      _delegate.futurePosition = _delegate.isPlatformBouncingScrollPhysics
          ? max(
              controller.position.minScrollExtent - _kMaxBounceOvershoot,
              _delegate.futurePosition,
            )
          : controller.position.minScrollExtent;
      duration = Duration(
        milliseconds: _delegate.silkyScrollDuration.inMilliseconds ~/ 2,
      );
    } else {
      duration = _delegate.silkyScrollDuration;
    }

    _delegate.isOnSilkyScrolling = true;
    final Future<void> animationEnd = _animationEnd = controller.animateTo(
      _delegate.futurePosition,
      duration: duration,
      curve: _delegate.animationCurve,
    );

    animationEnd.whenComplete(() {
      if (animationEnd == _animationEnd) {
        _delegate.isOnSilkyScrolling = false;
        if (!controller.hasClients) return;

        _handleRecoil(controller);
      }
    });
  }

  void _handleRecoil(ScrollController controller) {
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
      controller
          .animateTo(
            edgePosition,
            duration: Duration(milliseconds: recoilDurationMs),
            curve: Curves.easeInOutSine,
          )
          .whenComplete(() {
            if (!_delegate.isDisposed) {
              _delegate.isRecoilScroll = false;
              _delegate.onAnimationStateChanged();
            }
          });
    }
  }
}
