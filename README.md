# Silky Scroll

**Flutter 스크롤을 부드럽게. 코드 한 줄로.**

`SilkyScroll`은 마우스 휠, 트랙패드, 터치 입력 모두에 대해 자연스럽고 매끄러운 스크롤 애니메이션을 제공하는 Flutter 패키지입니다.

<p align="center">
  <img src="https://raw.githubusercontent.com/Dynaruid/silky_scroll/main/assets/scroll.webp" width="600" alt="✨ SilkyScroll vs ↔ Default comparison"/>
</p>

<p align="center">
  <b>✨ SilkyScroll</b>&nbsp;&nbsp;&nbsp;↔&nbsp;&nbsp;&nbsp;<b>Default</b>
</p>

---

## Features

- **Smooth Scroll Animation** — 마우스 휠 입력을 보간하여 끊김 없는 스크롤 제공
- **Smart Input Detection** — 마우스, 트랙패드, 터치를 자동으로 감지하여 각각에 맞는 물리 적용
- **Edge Locking** — 스크롤 끝에서 부모 뷰로의 의도치 않은 스크롤 전파 방지
- **Stretch Effect** — Android 스트레치 / iOS 바운스 오버스크롤 효과 지원
- **Nested Scroll** — 중첩 스크롤 뷰에서의 모멘텀 버블링 제어
- **Horizontal Scroll** — 수평·수직 방향 모두 지원
- **All Platforms** — Android, iOS, Web, Windows, macOS, Linux

---

## Getting Started

```bash
flutter pub add silky_scroll
```

---

## Basic Usage

스크롤 가능한 위젯을 `SilkyScroll`으로 감싸기만 하면 됩니다.

```dart
SilkyScroll(
  builder: (context, controller, physics) => ListView(
    controller: controller,
    physics: physics,
    children: [...],
  ),
)
```

---

## Custom Usage

외부 `ScrollController`를 연결하고, 애니메이션 속성을 세밀하게 조정할 수 있습니다.

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
        builder: (context, controller, physics) {
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

여러 `SilkyScroll` 위젯에 동일한 설정을 공유할 수 있습니다.

```dart
const config = SilkyScrollConfig(
  silkyScrollDuration: Duration(milliseconds: 1000),
  scrollSpeed: 1.5,
  animationCurve: Curves.easeOutCubic,
  enableStretchEffect: true,
);

SilkyScroll.fromConfig(
  config: config,
  builder: (context, controller, physics) => ListView(...),
)
```

---

## Parameters

| Parameter                   | Type                | Default               | Description                 |
| --------------------------- | ------------------- | --------------------- | --------------------------- |
| `controller`                | `ScrollController?` | `null`                | 외부 스크롤 컨트롤러        |
| `silkyScrollDuration`       | `Duration`          | `700ms`               | 스크롤 애니메이션 지속 시간 |
| `scrollSpeed`               | `double`            | `1`                   | 스크롤 속도 배율            |
| `animationCurve`            | `Curve`             | `Curves.easeOutQuart` | 애니메이션 커브             |
| `direction`                 | `Axis`              | `vertical`            | 스크롤 방향                 |
| `physics`                   | `ScrollPhysics`     | `ScrollPhysics()`     | 스크롤 물리                 |
| `edgeLockingDelay`          | `Duration`          | `650ms`               | 엣지 도달 후 잠금 시간      |
| `overScrollingLockingDelay` | `Duration`          | `700ms`               | 오버스크롤 잠금 시간        |
| `enableStretchEffect`       | `bool`              | `true`                | 오버스크롤 스트레치 효과    |
| `enableScrollBubbling`      | `bool`              | `false`               | 중첩 스크롤 모멘텀 전파     |
| `onScroll`                  | `Function(double)?` | `null`                | 스크롤 이벤트 콜백          |
| `onEdgeOverScroll`          | `Function(double)?` | `null`                | 엣지 오버스크롤 콜백        |
| `debugMode`                 | `bool`              | `false`               | 디버그 로깅                 |

---

## License

MIT
