# Silky Scroll

`SilkyScroll` is a Flutter package that provides natural and smooth scroll animations for mouse wheel, trackpad, and touch inputs.

<p align="center">
  <img src="https://raw.githubusercontent.com/Dynaruid/silky_scroll/refs/heads/main/assets/scroll.webp" width="600" alt="✨ SilkyScroll vs ↔ Default comparison"/>
</p>

<p align="center">
  <b>✨ SilkyScroll</b>&nbsp;&nbsp;&nbsp;↔&nbsp;&nbsp;&nbsp;<b>Default</b>
</p>

---

## Features

- **Smooth Scroll Animation** — Interpolates mouse wheel input for seamless scrolling
- **Smart Input Detection** — Automatically detects mouse, trackpad, and touch to apply appropriate physics
- **Edge Locking & Nested Forwarding** — Locks scrolling at boundaries and automatically forwards touch/trackpad deltas to the parent scroll view
- **Stretch Effect** — Supports Android stretch and iOS bounce overscroll effects
- **Horizontal Scroll** — Supports both horizontal and vertical directions
- **All Platforms** — Android, iOS, Web, Windows, macOS, Linux

---

## Getting Started

```bash
flutter pub add silky_scroll
```

---

## Basic Usage

Simply wrap your scrollable widget with `SilkyScroll`.

```dart
SilkyScroll(
  builder: (context, controller, physics, pointerDeviceKind) => ListView(
    controller: controller,
    physics: physics,
    children: [...],
  ),
)
```

---

## Custom Usage

You can connect an external `ScrollController` and fine-tune animation properties.

```dart
class _ScrollExampleState extends State<ScrollExample> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SilkyScroll(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        silkyScrollDuration: const Duration(milliseconds: 2000),
        scrollSpeed: 1.5,
        animationCurve: Curves.easeOutQuart,
        direction: Axis.vertical,
        builder: (context, controller, physics, pointerDeviceKind) {
          return ListView.builder(
            controller: controller,
            physics: physics,
            itemCount: 50,
            itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
          );
        },
      ),
    );
  }
}
```

---

## Using SilkyScrollConfig

You can share the same configuration across multiple `SilkyScroll` widgets.

```dart
const config = SilkyScrollConfig(
  silkyScrollDuration: Duration(milliseconds: 1000),
  scrollSpeed: 1.5,
  animationCurve: Curves.easeOutCubic,
  enableStretchEffect: true,
);

SilkyScroll.fromConfig(
  config: config,
  builder: (context, controller, physics, pointerDeviceKind) => ListView(...),
)
```

---

## Web: Overscroll Behavior Control

On web, `SilkyScroll` automatically sets `overscroll-behavior-x: none` to block browser back/forward swipe gestures.

If you need to restore or change this behavior, use `SilkyScrollGlobalManager`:

```dart
import 'package:silky_scroll/silky_scroll.dart';

// Restore browser default (allow swipe navigation)
SilkyScrollGlobalManager.instance
    .setOverscrollBehaviorX(OverscrollBehaviorX.auto);

// Block swipe gestures (default)
SilkyScrollGlobalManager.instance
    .setOverscrollBehaviorX(OverscrollBehaviorX.none);

// Prevent scroll chaining but keep glow/bounce effect
SilkyScrollGlobalManager.instance
    .setOverscrollBehaviorX(OverscrollBehaviorX.contain);
```

> On non-web platforms this is a no-op.

---

## Parameters

| Parameter                    | Type                   | Default                          | Description                            |
| ---------------------------- | ---------------------- | -------------------------------- | -------------------------------------- |
| `controller`                 | `ScrollController?`    | `null`                           | External scroll controller             |
| `silkyScrollDuration`        | `Duration`             | `850ms`                          | Scroll animation duration              |
| `scrollSpeed`                | `double`               | `1`                              | Scroll speed multiplier                |
| `animationCurve`             | `Curve`                | `Curves.easeOutQuart`            | Animation curve                        |
| `direction`                  | `Axis`                 | `vertical`                       | Scroll direction                       |
| `physics`                    | `ScrollPhysics`        | `ScrollPhysics()`                | Scroll physics                         |
| `edgeLockingDelay`           | `Duration`             | `650ms`                          | Lock delay after reaching edge         |
| `overScrollingLockingDelay`  | `Duration`             | `700ms`                          | Overscroll lock delay                  |
| `enableStretchEffect`        | `bool`                 | `true`                           | Overscroll stretch effect              |
| `edgeForwardingMode`         | `EdgeForwardingMode`   | `EdgeForwardingMode.sameAxisOnly`| Edge delta forwarding to ancestor      |
| `decayLogFactor`             | `double`               | `12`                             | Smooth-scroll convergence speed        |
| `setManualPointerDeviceKind` | `Function?`            | `null`                           | Manual pointer device override         |
| `onScroll`                   | `Function(double)?`    | `null`                           | Scroll event callback                  |
| `onEdgeOverScroll`           | `Function(double)?`    | `null`                           | Edge overscroll callback               |
| `debugMode`                  | `bool`                 | `false`                          | Debug logging                          |

---

## License

MIT
