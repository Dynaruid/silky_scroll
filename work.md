# 마우스 ↔ 트랙패드 전환 시 스크롤 지연 문제 해결 방안

## 문제 요약

| 시나리오                         | 증상                                   |
| -------------------------------- | -------------------------------------- |
| 마우스 스크롤 중 → 트랙패드 전환 | 트랙패드 스크롤이 ~1초 후에야 동작     |
| 트랙패드 스크롤 중 → 마우스 전환 | 부드러운 스크롤이 ~1초간 동작하지 않음 |

## 근본 원인

`SilkyScrollMousePointerManager`의 **2초짜리 상호배타 타이머**(`_kDeviceCheckTimeoutMs = 2000`)가 디바이스 전환을 차단한다.

### 원인 1: `_onPointerSignal` 우선순위 구조

```
현재 순서:
1. signalEvent.kind == trackpad?     → 트랙패드  (Windows에서 대부분 실패)
2. trackpadCheckTimer 활성?          → 트랙패드  ← mouse→trackpad 전환 차단
3. mouseCheckTimer 활성?             → 마우스    ← trackpad→mouse 전환 차단
4. 휴리스틱 (수평 delta, 작은 delta)    → 트랙패드  (타이머에 의해 도달 불가)
5. 기본값                            → 마우스
```

**마우스 → 트랙패드**: mouseCheckTimer가 2초간 활성 → step 3에서 마우스로 잘못 분류 → 트랙패드 입력이 `triggerMouseAction`으로 라우팅 → `SilkyScrollPosition.kind`가 `mouse`로 유지 → `super.pointerScroll()` 차단됨

**트랙패드 → 마우스**: trackpadCheckTimer가 2초간 활성 → step 2에서 트랙패드로 잘못 분류 → 마우스 입력이 `triggerTouchAction`으로 라우팅 → `animateToScroll()` 미호출 → 부드러운 스크롤 없음

### 원인 2: 진행 중인 마우스 애니메이션 미취소

마우스 스크롤 중 `controller.animateTo()`가 실행 중인데, 트랙패드로 전환해도 이 애니메이션이 계속 구동되어 트랙패드의 직접 스크롤(`super.pointerScroll`)을 덮어쓴다.

### 원인 3: `onPointerPanZoomUpdate`에서 상태 갱신 누락

```dart
// 현재 코드: setPointerDeviceKind, resetTrackpadCheckTimer 호출 없음
onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent event) {
  silkyScrollState.triggerTouchAction(event.panDelta, PointerDeviceKind.trackpad);
},
```

PanZoom 경로로 트랙패드 입력이 들어와도 `SilkyScrollPosition.kind`가 이전 `mouse` 상태로 남는다.

---

## 해결 방안

### 변경 1: `SilkyScrollMousePointerManager` — PanZoom 추적 추가

네이티브 플랫폼에서 `PointerPanZoomUpdate`는 **트랙패드만 생성하는 신뢰할 수 있는 신호**이다. 이를 단기 플래그로 추적하여, `PointerScrollEvent`가 애매할 때 트랙패드 판별에 활용한다.

```dart
// silky_scroll_mouse_pointer_manager.dart

Timer? _panZoomTimer;
static const int _kPanZoomTimeoutMs = 150;

/// 최근 150ms 이내에 PointerPanZoomUpdate를 수신했는지 여부
bool get isRecentlyPanZoom => _panZoomTimer?.isActive ?? false;

/// PanZoom 이벤트 수신 시 호출
void markPanZoomActivity() {
  _panZoomTimer?.cancel();
  _panZoomTimer = Timer(
    const Duration(milliseconds: _kPanZoomTimeoutMs),
    () {},
  );
}
```

`resetForTesting`에도 `_panZoomTimer` 정리를 추가한다.

---

### 변경 2: `_onPointerSignal` 우선순위 재구성

**핵심: 휴리스틱 체크를 타이머 체크보다 위로 이동**시켜 디바이스 전환을 즉시 감지한다.

```dart
// silky_scroll_widget.dart — _SilkyScrollState

void _onPointerSignal(PointerSignalEvent signalEvent) {
    if (signalEvent is! PointerScrollEvent) return;

    // ── Step 1: 플랫폼이 직접 trackpad로 보고 ──
    if (_handleTrackpadCheck(signalEvent.kind)) {
      _ensureTrackpadMode();
      silkyScrollState.triggerTouchAction(
        signalEvent.scrollDelta,
        PointerDeviceKind.trackpad,
      );
      return;
    }

    final double scrollDeltaY = signalEvent.scrollDelta.dy;
    final double scrollDeltaX = signalEvent.scrollDelta.dx;

    // ── Step 2: 휴리스틱 — 수평 delta 또는 작은 수직 delta → 트랙패드 ──
    // ★ 타이머 체크보다 먼저 실행 → 디바이스 전환 즉시 감지 ★
    if ((scrollDeltaX * 10).toInt() != 0 || scrollDeltaY.abs() < 4) {
      _handleTrackpadCheck(PointerDeviceKind.trackpad);
      _ensureTrackpadMode();
      silkyScrollState.triggerTouchAction(
        signalEvent.scrollDelta,
        PointerDeviceKind.trackpad,
      );
      return;
    }

    // ── Step 3: 최근 PanZoom 수신 → 트랙패드 (빠른 수직 스와이프 대응) ──
    // PanZoomUpdate는 네이티브 트랙패드만 생성하므로 신뢰도 높음.
    // 기존 trackpadCheckTimer(2초) 대신 150ms PanZoom 플래그 사용.
    if (silkyScrollMousePointerManager.isRecentlyPanZoom) {
      silkyScrollState.triggerTouchAction(
        signalEvent.scrollDelta,
        PointerDeviceKind.trackpad,
      );
      return;
    }

    // ── Step 4: 마우스로 처리 ──
    // mouseCheckTimer 체크 제거: step 2~3에서 트랙패드가 아닌 이벤트는
    // 즉시 마우스로 분류하여 트랙패드→마우스 전환 지연 제거.
    silkyScrollState.triggerMouseAction(scrollDeltaY);
}

/// 트랙패드 모드 전환 시 진행 중인 마우스 애니메이션 취소
void _ensureTrackpadMode() {
    silkyScrollState.cancelSilkyScroll();
}
```

**변경 전후 비교:**

| 시나리오                       | 변경 전                               | 변경 후                                             |
| ------------------------------ | ------------------------------------- | --------------------------------------------------- |
| mouse→trackpad (휴리스틱 매칭) | step 3에서 마우스로 분류 (2초 대기)   | step 2에서 즉시 트랙패드 감지                       |
| mouse→trackpad (PanZoom 경로)  | onPointerPanZoomUpdate 상태 미갱신    | 변경 3에서 해결                                     |
| trackpad→mouse                 | step 2에서 트랙패드로 분류 (2초 대기) | step 3 PanZoom 150ms 확인 → 불일치 시 step 4 마우스 |
| 빠른 트랙패드 수직 스와이프    | step 2 trackpadCheckTimer 2초         | step 3 isRecentlyPanZoom 150ms                      |

---

### 변경 3: `onPointerPanZoomUpdate` 보완

```dart
// silky_scroll_widget.dart — build() 내부

onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent event) {
  // ★ 추가: 상태 갱신 ★
  silkyScrollState.setPointerDeviceKind(PointerDeviceKind.trackpad);
  silkyScrollMousePointerManager.resetTrackpadCheckTimer();
  silkyScrollMousePointerManager.markPanZoomActivity();
  silkyScrollState.cancelSilkyScroll();

  silkyScrollState.triggerTouchAction(
    event.panDelta,
    PointerDeviceKind.trackpad,
  );
},
```

---

### 변경 4: `SilkyScrollState` — 애니메이션 취소 메서드 추가

마우스→트랙패드 전환 시 진행 중인 `animateTo()`를 즉시 중단하여, 트랙패드의 직접 스크롤이 즉시 동작하도록 한다.

```dart
// silky_scroll_state.dart

/// 진행 중인 부드러운 스크롤 애니메이션을 즉시 취소한다.
/// 마우스→트랙패드 전환 시 호출되어 트랙패드 직접 스크롤이 즉시 반응하도록 한다.
void cancelSilkyScroll() {
  if (isOnSilkyScrolling && clientController.hasClients) {
    // jumpTo는 현재 진행 중인 animateTo를 취소한다
    clientController.jumpTo(clientController.offset);
    isOnSilkyScrolling = false;
    futurePosition = clientController.offset;
  }
}
```

`jumpTo(currentOffset)`는 Flutter 프레임워크에서 `DrivenScrollActivity`를 취소하고 `IdleScrollActivity`로 전환시킨다. 이후 트랙패드의 `super.pointerScroll(delta)`가 즉시 반영된다.

---

### 변경 5 (선택): 웹 플랫폼 트랙패드 감지 보강

웹에서는 `PointerPanZoomUpdate`가 생성되지 않으므로 `isRecentlyPanZoom`이 항상 false이다. 웹 전용 fallback이 필요하면:

```dart
// step 3 뒤에 추가

// ── Step 3b: 웹 전용 — trackpadCheckTimer fallback ──
if (silkyScrollMousePointerManager.silkyScrollWebManager.isWebPlatform &&
    (silkyScrollMousePointerManager.trackpadCheckTimer?.isActive ?? false)) {
  silkyScrollState.triggerTouchAction(
    signalEvent.scrollDelta,
    PointerDeviceKind.trackpad,
  );
  return;
}
```

이 경우 웹에서 트랙패드→마우스 전환은 여전히 타이머 만료를 기다려야 한다. 타이머를 **500ms**로 단축하면 체감 지연을 줄일 수 있다:

```dart
// 웹 전용 타이머 시간
static const int _kDeviceCheckTimeoutMs = 500; // 기존 2000 → 500
```

---

## 변경 파일 요약

| 파일                                      | 변경 내용                                                                                     |
| ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| `silky_scroll_mouse_pointer_manager.dart` | `markPanZoomActivity()`, `isRecentlyPanZoom` 추가                                             |
| `silky_scroll_widget.dart`                | `_onPointerSignal` 우선순위 재구성, `_ensureTrackpadMode` 추가, `onPointerPanZoomUpdate` 보완 |
| `silky_scroll_state.dart`                 | `cancelSilkyScroll()` 메서드 추가                                                             |

---

## 전환 흐름 검증

### 마우스 → 트랙패드 (PointerScrollEvent 경로, Windows)

1. 마우스 스크롤 중 → `triggerMouseAction` → `resetMouseCheckTimer` → `mouseCheckTimer` 활성
2. 트랙패드 시작 → `PointerScrollEvent` (kind: mouse)
3. Step 1: kind != trackpad → skip
4. Step 2: `scrollDeltaX != 0` 또는 `|scrollDeltaY| < 4` → **즉시 트랙패드 감지** ✅
5. `_ensureTrackpadMode()` → 마우스 애니메이션 취소 ✅
6. `triggerTouchAction()` → 트랙패드 스크롤 처리 ✅

### 마우스 → 트랙패드 (PanZoom 경로)

1. 마우스 스크롤 중 → `isOnSilkyScrolling = true`
2. 트랙패드 시작 → `PointerPanZoomUpdateEvent`
3. `onPointerPanZoomUpdate` → `setPointerDeviceKind(trackpad)` ✅
4. `cancelSilkyScroll()` → 마우스 애니메이션 취소 ✅
5. `triggerTouchAction()` → 트랙패드 스크롤 처리 ✅

### 트랙패드 → 마우스

1. 트랙패드 스크롤 중 → `trackpadCheckTimer` 활성, PanZoom 이벤트 수신
2. 마우스 시작 → `PointerScrollEvent` (kind: mouse)
3. Step 1: kind != trackpad → skip
4. Step 2: 마우스 휠 = `scrollDeltaX == 0`, `|scrollDeltaY| ≥ 20` → 휴리스틱 불일치 → skip
5. Step 3: `isRecentlyPanZoom` → PanZoom 마지막 수신 후 150ms 경과 시 false → skip ✅
6. Step 4: **즉시 마우스로 처리** → `triggerMouseAction` → 부드러운 스크롤 시작 ✅
