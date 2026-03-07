import 'scroll_delta_sample.dart';

/// Default retention window for scroll-delta samples.
const int kDefaultSampleRetentionMs = 1000;

/// Default time-window size for grouping samples in V3 speed calc.
const int kDefaultWindowMs = 100;

/// Default minimum speed threshold (px/s) below which a segment
/// is considered stationary and excluded from the average.
const double kDefaultMinSpeedThresholdPxS = 1.0;

/// Stateless utility that analyses [ScrollDeltaSample] lists.
///
/// Modelled after `PositionSampleAnalyzer` (Kotlin) but adapted for
/// scroll-delta semantics: samples carry a *delta* (px per event)
/// rather than an absolute position, so "speed" is derived by
/// accumulating deltas over time.
///
/// All methods are static — the class holds no mutable state.
abstract final class ScrollDeltaSampleAnalyzer {
  // ── Filtering ─────────────────────────────────────────────────

  /// Removes samples older than [retentionMs] relative to [currentTimeMs].
  static List<ScrollDeltaSample> filterSamples(
    List<ScrollDeltaSample> samples,
    int currentTimeMs, [
    int retentionMs = kDefaultSampleRetentionMs,
  ]) {
    final int cutoff = currentTimeMs - retentionMs;
    return samples.where((s) => s.timeMs >= cutoff).toList();
  }

  // ── Speed calculation ─────────────────────────────────────────

  /// Returns the average scroll speed in **logical-pixels / second**.
  ///
  /// Groups samples into [windowMs]-wide buckets, computes per-window
  /// speeds, and filters out stationary segments.
  /// Positive = forward / down.
  static double calculateAverageSpeed(
    List<ScrollDeltaSample> samples, {
    int windowMs = kDefaultWindowMs,
    double minSpeedThresholdPxS = kDefaultMinSpeedThresholdPxS,
  }) {
    if (samples.length < 2) return 0.0;

    final sorted = List.of(samples)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    final int totalTimeDiffMs = sorted.last.timeMs - sorted.first.timeMs;
    if (totalTimeDiffMs <= 0) return 0.0;

    // Group into time windows.
    final List<List<ScrollDeltaSample>> windowGroups = [];
    int windowStart = sorted.first.timeMs;
    List<ScrollDeltaSample> currentGroup = [];

    for (final sample in sorted) {
      if (sample.timeMs < windowStart + windowMs) {
        currentGroup.add(sample);
      } else {
        if (currentGroup.isNotEmpty) windowGroups.add(currentGroup);
        currentGroup = [sample];
        windowStart = sample.timeMs;
      }
    }
    if (currentGroup.isNotEmpty) windowGroups.add(currentGroup);

    // Compute per-window aggregate (sum of deltas, avg time).
    final windowAggregates = windowGroups.map((group) {
      final double sumDelta = group.fold(0.0, (s, e) => s + e.delta);
      final double avgTime =
          group.map((e) => e.timeMs).reduce((a, b) => a + b) / group.length;
      return (delta: sumDelta, timeMs: avgTime);
    }).toList();

    if (windowAggregates.length < 2) {
      final double totalDelta = sorted.fold(0.0, (s, e) => s + e.delta);
      return (totalDelta / totalTimeDiffMs) * 1000.0;
    }

    // Inter-window speeds.
    final List<double> windowSpeeds = [];
    for (int i = 1; i < windowAggregates.length; i++) {
      final prev = windowAggregates[i - 1];
      final curr = windowAggregates[i];
      final double dt = curr.timeMs - prev.timeMs;
      if (dt <= 0) continue;
      // Speed based on cumulative delta between windows.
      windowSpeeds.add((curr.delta / dt) * 1000.0);
    }

    if (windowSpeeds.isEmpty) {
      final double totalDelta = sorted.fold(0.0, (s, e) => s + e.delta);
      return (totalDelta / totalTimeDiffMs) * 1000.0;
    }

    // Remove stationary segments.
    final movementSpeeds = windowSpeeds
        .where((s) => s.abs() > minSpeedThresholdPxS)
        .toList();

    if (movementSpeeds.isEmpty) return _mean(windowSpeeds);

    return _mean(movementSpeeds);
  }

  // ── Internal helpers ──────────────────────────────────────────

  static double _mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}
