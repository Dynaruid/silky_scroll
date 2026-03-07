# Changelog

All notable changes to this project will be documented in this file.

## 2.2.2

### Fixed

- Removed stray `print` call in `SilkyScrollMousePointerManager.setOverscrollBehaviorX()`.
- Renamed local variable `_flushWindow` → `flushWindow` in `ScrollDeltaSampleAnalyzer` to satisfy `no_leading_underscores_for_local_identifiers` lint.

## 2.2.1

### Changed

- Added `Web: Overscroll Behavior Control` section to README documenting `setOverscrollBehaviorX()` API and `OverscrollBehaviorX` enum usage.

## 2.2.0

### Breaking

- **`SilkyScrollMousePointerManager` access changed**: Replaced factory constructor with `SilkyScrollMousePointerManager.instance` static field for explicit singleton semantics.
- **`overscroll-behavior-x` default behavior changed**: Now permanently set to `none` on both `<html>` and `<body>` elements at initialization, instead of temporarily blocking per scroll event via Timer.

### Added

- `OverscrollBehaviorX` enum — type-safe CSS values (`auto`, `none`, `contain`) for the `overscroll-behavior-x` property, exported from the barrel file.
- `SilkyScrollMousePointerManager.setOverscrollBehaviorX()` — allows manually overriding the `overscroll-behavior-x` CSS property at runtime.

### Changed

- **`blockOverscrollBehaviorX` call timing**: Now invoked only for `PointerDeviceKind.trackpad`, and before the delta threshold check instead of inside it.
- **Web helper simplified**: Removed `Timer`-based delay/reset logic; `overscroll-behavior-x` is applied once at init and can be changed explicitly via `setOverscrollBehaviorX()`.
- **Web helper targets both root elements**: `overscroll-behavior-x` is now set on both `<html>` and `<body>` (previously only `<body>`).

### Fixed

- Fixed `_lockedEdgeDirection` not being assigned when entering `BlockedScrollPhysics`, which could cause incorrect edge-lock direction tracking.

## 2.1.1

### Changed

- **`currentScrollSpeed` caching**: Results are now cached for ~16 ms (one frame), eliminating redundant `calculateAverageSpeed` calls from `_checkNeedLocking`, `_checkEdgeLockOnTouchUp`, and `_tryGestureUnlock` within the same frame.
- **`_recordDelta` trimming optimization**: Replaced `removeWhere` O(n) full-scan with `removeRange(0, count)` exploiting the time-sorted order of samples.
- **`calculateAverageSpeed` allocation reduction**: Rewrote to single-pass inline aggregation, removing 5+ intermediate list allocations (`List.of`, `windowGroups`, `windowAggregates`, `windowSpeeds`, `movementSpeeds`) per call.
- **`blockOverscrollBehaviorXHtml` Timer reuse**: Replaced per-event cancel+recreate pattern with timestamp tracking and a single reusable Timer, reducing Timer object churn during rapid trackpad scrolling.
- **`scrollDeltaX` comparison**: Replaced `(scrollDeltaX * 10).toInt() != 0` with `scrollDeltaX.abs() >= 0.1` for clarity and to avoid unnecessary float-to-int conversion.

### Removed

- Removed `recentDeltaSamples` public getter (unused externally).

## 2.1.0

### Breaking

- **Builder signature changed**: `SilkyScrollWidgetBuilder` now receives a 4th parameter `PointerDeviceKind? pointerDeviceKind`, allowing widgets to adapt their behavior based on the detected input device.
- **Removed bubbling option**: Scroll bubbling to parent views is now seamlessly integrated into the default edge-locking logic, providing a much more natural nested-scroll experience without any configuration.

### Added

- `decayLogFactor` parameter — controls the exponential-decay log factor for smooth-scroll convergence speed (default: `12`).
- `recoilDurationSec` parameter — controls the duration of the bounce-back (recoil) animation in seconds (default: `0.2`).
- `setManualPointerDeviceKind` callback — allows manually overriding the detected pointer device kind for custom input handling.
- Exported `kDefaultDecayLogFactor` and `kDefaultRecoilDurationSec` constants from barrel file.

### Changed

- Scroll bubbling is now handled automatically within the core edge-locking state machine, eliminating the need for a separate configuration option and delivering smoother transitions in nested scroll views.
- Recoil (bounce-back) animation and overshoot clamping now only activate when the widget's scroll physics is `BouncingScrollPhysics`. Non-bouncing physics (e.g. `ClampingScrollPhysics`) no longer overshoot scroll extents or trigger recoil.

## 2.0.3

### Fixed

- Fixed `include_file_not_found` warning in example `analysis_options.yaml` by replacing deprecated `flutter_lints` with `lints`.
- Removed unnecessary `package:flutter/scheduler.dart` import in `SilkyScrollState` (already provided by `material.dart`).
- Removed unused `package:flutter/foundation.dart` import in input handler tests.
- Replaced unnecessary lambdas with tear-offs in state tests.

## 2.0.2

### Changed

- **Ticker-based animation engine**: Replaced per-event `controller.animateTo()` with a single `Ticker` + `jumpTo()` loop using frame-rate-independent exponential smoothing. Eliminates the stutter caused by repeatedly cancelling and restarting easing curves on rapid mouse-wheel input.
- **Targeted rebuild**: Replaced `ListenableBuilder` (which rebuilt the entire widget subtree on every `notifyListeners()`) with a dedicated `_onPhysicsChanged` listener that calls `setState` only when the `ScrollPhysics` reference actually changes.
- **Recoil animation**: Bounce-back (recoil) to edge now runs inside the same Ticker using `Curves.easeInOutSine` interpolation, avoiding a separate `animateTo()` call that could conflict with ongoing scroll animations.

### Fixed

- **Overscroll bounce-back stutter**: Added `silkyTickerActive` flag to `SilkyScrollPosition` that suppresses `goBallistic()` while the Ticker is running. Previously, each `jumpTo()` during overscroll triggered Flutter's `BouncingScrollPhysics` spring simulation, which fought with the Ticker every frame — causing visible jitter at both top and bottom edges.

## 2.0.1

### Fixed

- `onScroll` and `onEdgeOverScroll` callbacks were not passed from `SilkyScroll` widget to `SilkyScrollState`, causing them to always be `null`.
- `onEdgeOverScroll` was never invoked; it is now called when mouse-wheel or touch/trackpad scroll reaches an edge.

## 2.0.0

### Breaking

- Removed `provider` dependency; replaced with `InheritedWidget` + `ListenableBuilder`.
- Applied Dart 3 `final class` / `abstract interface class` modifiers to all public classes. External `extends` / `implements` is no longer permitted for concrete types.
- Exported `ScrollPhysicsPhase` enum from barrel file.

### Added

- `SilkyScrollConfig.copyWith`, `==`, `hashCode`, and `toString`.
- `SilkyScrollMousePointerManager.resetForTesting` (`@visibleForTesting`).
- `SilkyScrollWebManagerInterface.isWebPlatform` for conditional-import–based platform detection.
- `SilkyEdgeDetector`: sub-pixel edge detection using threshold instead of `toInt()`.
- State machine `_transitionTo` now guards against Timer creation after dispose.
- `SilkyScrollController.attach`/`detach` guard against duplicate position registration.
- Test infrastructure: `test/helpers/test_helpers.dart` shared utilities.
- New tests for `SilkyScrollAnimator`, `SilkyInputHandler`, `SilkyScrollConfig`, and integration tests (67 total, up from 24).

### Changed

- `kIsWeb` runtime branching in `SilkyInputHandler` replaced with conditional-import pattern via `isWebPlatform`.
- `ListenableBuilder` rebuild scope reduced: `onAnimationStateChanged` no longer triggers unnecessary widget rebuilds for recoil state.
- Dispose order in `SilkyScrollState` made deterministic and safe.
- Edge-detection refactored to switch expression / pattern matching (Dart 3).
- `SilkyScrollAnimator._handleRecoil` refactored to switch expression.
- Web helper magic number `Duration(milliseconds: 700)` extracted to `_kOverscrollBehaviorXResetDelay` constant.
- Lint configuration upgraded from `flutter_lints` to `package:lints/recommended.yaml` with custom rules.
- Example restructured to `example/lib/main.dart` + `example/pubspec.yaml` (pub.dev guideline).
- README image paths updated from `Bluebar1/dyn_mouse_scroll` to `Dynaruid/silky_scroll`.

### Removed

- Legacy duplicate source files under `lib/` root (moved to `lib/src/` in Phase 1).

### Fixed

- `_unlockScroll` now correctly transitions `_physicsPhase` back to `ScrollPhysicsPhase.normal`.
- `_transitionTo` checks `_disposed` before creating a new Timer.

## 1.0.16

### Added

- Support for Android's scroll stretch effect.

## 1.0.15

### Changed

- Applied dart format.

## 1.0.14

### Fixed

- Removed usage of `Platform` from `dart:io` due to compatibility issues causing errors on Safari in iOS 18.2.

## 1.0.13

### Fixed

- Fixed bug about web import.

## 1.0.12

### Added

- Added an option to configure whether scroll bubbling is propagated when an inner scroll view reaches its edge within nested scroll views.

## 1.0.11

### Changed

- General updates.

## 1.0.10

### Changed

- Updated README.

## 1.0.9

### Fixed

- Fixed drag bug.

## 1.0.8

### Changed

- Adjusted duration of scroll momentum.

## 1.0.7

### Changed

- Adjusted duration of scroll momentum.

## 1.0.6

### Changed

- The duration of scroll momentum transferred to the parent widget has been adjusted to behave more naturally.

## 1.0.5

### Added

- Enhanced scroll behavior for touch interfaces. When the scrollable content reaches the edge during an ongoing scroll gesture, if the parent widget is also scrollable, the scroll momentum is seamlessly transferred to the parent widget.

## 1.0.4

### Changed

- Changed the method of specifying the scroll duration.

## 1.0.3

### Changed

- Adjusted the interval of the scroll lock timer.

## 1.0.2

### Added

- Web support improvements.

## 1.0.1

### Added

- Web support.

## 1.0.0

### Added

- Initial release.
