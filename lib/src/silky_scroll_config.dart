import 'package:flutter/material.dart';

/// Configuration data class that groups [SilkyScroll] scroll-behavior
/// parameters into a single object.
///
/// Use this to share a common scroll configuration across multiple
/// [SilkyScroll] instances, or to simplify widget construction when
/// many parameters need to be customized.
///
/// ```dart
/// const config = SilkyScrollConfig(
///   silkyScrollDuration: Duration(milliseconds: 1000),
///   scrollSpeed: 1.5,
/// );
///
/// SilkyScroll.fromConfig(
///   config: config,
///   builder: (context, controller, physics) => ListView(...),
/// )
/// ```
@immutable
final class SilkyScrollConfig {
  const SilkyScrollConfig({
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
  });

  /// Duration of the smooth scroll animation.
  final Duration silkyScrollDuration;

  /// Multiplier for the scroll delta.
  final double scrollSpeed;

  /// The animation curve applied to smooth scrolling.
  final Curve animationCurve;

  /// How long the scroll is locked after reaching an edge.
  final Duration edgeLockingDelay;

  /// How long the overscroll effect is suppressed after touch-up.
  final Duration overScrollingLockingDelay;

  /// Whether to allow the platform stretch / glow overscroll effect.
  final bool enableStretchEffect;

  /// Whether nested scroll views should bubble scroll momentum
  /// to the parent when they reach their edge.
  final bool enableScrollBubbling;

  /// Enables debug logging.
  final bool debugMode;

  /// The scroll direction.
  final Axis direction;

  /// The [ScrollPhysics] applied to the scrollable child.
  final ScrollPhysics physics;

  /// Creates a copy of this config with the given fields replaced.
  SilkyScrollConfig copyWith({
    Duration? silkyScrollDuration,
    double? scrollSpeed,
    Curve? animationCurve,
    Axis? direction,
    ScrollPhysics? physics,
    Duration? edgeLockingDelay,
    Duration? overScrollingLockingDelay,
    bool? enableStretchEffect,
    bool? enableScrollBubbling,
    bool? debugMode,
  }) {
    return SilkyScrollConfig(
      silkyScrollDuration: silkyScrollDuration ?? this.silkyScrollDuration,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      animationCurve: animationCurve ?? this.animationCurve,
      direction: direction ?? this.direction,
      physics: physics ?? this.physics,
      edgeLockingDelay: edgeLockingDelay ?? this.edgeLockingDelay,
      overScrollingLockingDelay:
          overScrollingLockingDelay ?? this.overScrollingLockingDelay,
      enableStretchEffect: enableStretchEffect ?? this.enableStretchEffect,
      enableScrollBubbling: enableScrollBubbling ?? this.enableScrollBubbling,
      debugMode: debugMode ?? this.debugMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SilkyScrollConfig &&
          runtimeType == other.runtimeType &&
          silkyScrollDuration == other.silkyScrollDuration &&
          scrollSpeed == other.scrollSpeed &&
          animationCurve == other.animationCurve &&
          direction == other.direction &&
          physics == other.physics &&
          edgeLockingDelay == other.edgeLockingDelay &&
          overScrollingLockingDelay == other.overScrollingLockingDelay &&
          enableStretchEffect == other.enableStretchEffect &&
          enableScrollBubbling == other.enableScrollBubbling &&
          debugMode == other.debugMode;

  @override
  int get hashCode => Object.hash(
    silkyScrollDuration,
    scrollSpeed,
    animationCurve,
    direction,
    physics,
    edgeLockingDelay,
    overScrollingLockingDelay,
    enableStretchEffect,
    enableScrollBubbling,
    debugMode,
  );

  @override
  String toString() =>
      'SilkyScrollConfig('
      'silkyScrollDuration: $silkyScrollDuration, '
      'scrollSpeed: $scrollSpeed, '
      'animationCurve: $animationCurve, '
      'direction: $direction, '
      'edgeLockingDelay: $edgeLockingDelay, '
      'enableStretchEffect: $enableStretchEffect, '
      'enableScrollBubbling: $enableScrollBubbling, '
      'debugMode: $debugMode)';
}
