# Changelog

All notable changes to this project will be documented in this file.

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
