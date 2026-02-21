# Silky Scroll — Phase 2 남은 작업

> Phase 1 완료일: 2026-02-21
> Phase 2 중간점검일: 2026-02-21
> 기준 문서: work.md

---

## Phase 1 완료 요약

### P0 (전부 완료)

- [x] 2-1. 주석 처리된 코드 제거
- [x] 2-5. 네이밍/오타 수정 (`currentsSilkyScrollPosition` → `currentSilkyScrollPosition`, `pointKey` → `instanceKey` 등)
- [x] 2-6. non_web_helper 반환 타입(`void`) 명시
- [x] 5-2. CHANGELOG.md Keep a Changelog 형식 재작성

### P1 (전부 완료)

- [x] 6-3. rootBodyElement null safety (`!` → `?.`)
- [x] 2-2. 매직 넘버 상수화 (9개 상수)
- [x] 2-3. Timer nullable 패턴 적용
- [x] ~~3-2. `toInt()` 비교 → `.abs() < threshold` 개선~~ ⚠️ **`lib/src/silky_edge_detector.dart`에 미적용 확인 → Phase 2 §0-2로 이관**
- [x] 2-4. `isAlive` 패턴 → `_disposed` 플래그 전환

### P2 (전부 완료)

- [x] 4-2. dartdoc 문서화 (모든 공개 API)
- [x] 1-2. Provider 의존성 제거 → `InheritedWidget` + `ListenableBuilder`
- [x] 1-3. 배럴 파일 구성 (`lib/silky_scroll.dart` → `lib/src/`) ⚠️ **구버전 파일 `lib/` 루트에 잔존 → Phase 2 §0-1로 이관**
- [x] 3-3. 이벤트 핸들러 평탄화 (`_onPointerSignal` early return 패턴)
- [x] 6-1. Web Helper interface 순수 abstract 전환
- [x] 3-1. 불필요한 `notifyListeners` 최적화
- [x] 4-1. 파라미터 네이밍 정리 (`enableStretchEffect`, `enableScrollBubbling`, `debugMode` 등)

### P3 (전부 완료)

- [x] 1-1. SilkyScrollState SRP 분해 → `SilkyScrollAnimator`, `SilkyEdgeDetector`, `SilkyInputHandler`
- [x] 4-3. `SilkyScrollConfig` 데이터 클래스 도입
- [x] 5-1. 테스트 추가 (4개 파일, 24개 테스트 통과) ⚠️ **`silky_scroll_state_test.dart.bak` 12개 테스트 미실행 → Phase 2 §0-3으로 이관**
- [x] 7-1. 타이머 상태 머신 (`ScrollPhysicsPhase` enum, `beginOverscrollLock`/`isOverscrollLocked`)

---

## Phase 2 — 남은 작업

### 0. Phase 1 잔여 긴급 수정 (🔴 최우선)

> 중간점검에서 발견된 Phase 1 미완료/후속 이슈. 다른 작업보다 먼저 처리.

#### 0-1. `lib/` 루트 구버전 소스 파일 삭제

- **현재**: 배럴 파일 리팩토링 후 `lib/` 루트에 구버전 파일 7개가 삭제되지 않고 남아 있음
  - `lib/silky_scroll_controller.dart` — dartdoc 없는 구버전
  - `lib/silky_scroll_state.dart` — **SRP 분해 이전의 구버전** (SilkyScrollAnimator/EdgeDetector/InputHandler 미사용, 구 `checkOffsetAtEdge` 전역 함수 포함)
  - `lib/silky_scroll_mouse_pointer_manager.dart` — `lib/src/` 버전과 중복
  - `lib/silky_scroll_web_helper/` (3개 파일) — `lib/src/silky_scroll_web_helper/`와 중복
- **리스크**: `pub publish` 시 패키지에 포함되어 용량 증가. 외부 사용자가 배럴 파일을 우회해 직접 import할 위험
- **작업**: 전부 삭제
- **난이도**: 쉬움

#### 0-2. `toInt()` edge 감지 수정 — `lib/src/` 미적용 보완

- **현재**: Phase 1 P1 3-2 완료 표시되어 있으나 `lib/src/silky_edge_detector.dart`에서 여전히 `toInt()` 비교 사용 중
- **리스크**: 서브픽셀 offset(예: 4999.7 vs 5000.0)에서 edge 감지 실패
- **작업**: `.abs() < threshold` 패턴으로 수정
- **난이도**: 쉬움

#### 0-3. `.bak` 테스트 파일 복원

- **현재**: `test/silky_scroll_state_test.dart.bak` (316줄, 12개 테스트)가 `.bak` 확장자로 인해 테스트 러너에서 제외
- **리스크**: `ScrollPhysicsPhase` 전이, dispose 안전성, bubbling 등 핵심 테스트 미실행
- **작업**: `.bak` → `.dart` 로 복원, 실행 확인
- **난이도**: 쉬움

#### 0-4. web helper 매직 넘버 상수화 누락

- **현재**: `lib/src/silky_scroll_web_helper/silky_scroll_web_helper.dart`에 `Duration(milliseconds: 700)` 하드코딩
- **작업**: Phase 1 P1 2-2(매직 넘버 상수화)와 동일 기준으로 상수화
- **난이도**: 쉬움

---

### 1. 프로젝트 구조 & 패키지 품질 (P4)

#### 1-1. README.md 이미지 경로 수정

- **현재**: GIF가 `Bluebar1/dyn_mouse_scroll` 리포지토리를 참조
- **작업**: `assets/` 폴더에 자체 GIF 추가, 경로를 `silky_scroll` 리포지토리 기준으로 변경
- **난이도**: 쉬움

#### 1-2. Example 구조 개선

- **현재**: `example/example.dart` 단일 파일
- **작업**: pub.dev 가이드라인에 맞게 `example/lib/main.dart` + `example/pubspec.yaml` 구성
- **난이도**: 쉬움

#### 1-3. 린트 규칙 강화

- **현재**: `flutter_lints` 기본 설정만 사용
- **변경**: `flutter_lints` → `package:lints/recommended.yaml` 직접 사용 + 커스텀 규칙
- **추가 권장 린트**:

  ```yaml
  include: package:lints/recommended.yaml

  linter:
    rules:
      prefer_const_constructors: true
      prefer_const_declarations: true
      avoid_print: true
      prefer_final_locals: true
      always_declare_return_types: true
      unawaited_futures: true
      sort_constructors_first: true
      prefer_single_quotes: true
      use_super_parameters: true
      unnecessary_lambdas: true
  ```

- **난이도**: 쉬움 (린트 위반 수정까지 포함하면 보통)

---

### 2. 플랫폼 & 호환성

#### 2-1. kIsWeb 런타임 분기와 조건부 import 일관성 (work.md 6-2)

- **현재**: `silky_scroll_input_handler.dart`의 `triggerTouchAction`에서 `kIsWeb` 런타임 분기를 사용. 한편 web helper는 조건부 import 패턴 사용. 두 방식 혼용
- **작업**: 웹 관련 분기를 모두 조건부 import 파일로 통합하여 일관성 확보
- **효과**: tree-shaking 가능, 플랫폼별 코드 분리 명확화
- **난이도**: 보통

---

### 3. 잠재적 버그 리스크

#### 3-1. clientController.attach 이중 등록 검증 (work.md 7-2)

- **현재**: `SilkyScrollController.attach`에서 `clientController.attach(position)` + `super.attach(position)` 호출
- **리스크**: 동일 position이 두 controller에 attach → 예기치 않은 동작 가능
- **작업**: 실제 이중 등록이 문제를 일으키는지 테스트로 검증, 필요 시 수정
- **난이도**: 보통

#### 3-2. dispose 순서 안전성 확인 (work.md 7-3)

- **현재**: `SilkyScrollState.dispose()`에서 listener 제거 → controller dispose → 조건부 clientController dispose 순서
- **리스크**: dispose 중 position detach 시 이미 제거된 listener에 접근 가능성
- **작업**: dispose 순서를 그래프로 정리하고 edge case 테스트 추가
- **난이도**: 보통

#### 3-3. `_transitionTo` Timer 생성 시 `_disposed` 체크 누락 _(신규)_

- **현재**: `SilkyScrollState._transitionTo`에서 `_phaseTimer?.cancel()` 후 즉시 새 Timer 생성. dispose 직전에 transition 호출 시 Timer가 disposed 객체에서 실행될 수 있음
- **작업**: Timer 생성 전 `_disposed` 체크 추가
- **난이도**: 쉬움

---

### 4. 테스트 확장

#### 4-1. SilkyScrollState 통합 테스트

- 현재 단위 테스트 24개 통과 (+ `.bak` 복원 시 36개). `SilkyScrollState` 자체(timer 전이, physics 전환 등) 통합 테스트 추가 필요
- `ScrollPhysicsPhase` 상태 전이 시나리오별 테스트

#### 4-2. SilkyScrollAnimator / SilkyInputHandler 단위 테스트

- 분해된 delegate 클래스들에 대한 개별 단위 테스트 추가
- 현재 두 클래스 모두 **테스트 0개**

#### 4-3. 위젯 테스트 확장

- 현재 위젯 테스트는 기본 렌더링, 빌더 호출, 중첩 scope 전파만 검증
- 실제 스크롤 이벤트 시뮬레이션, edge locking 동작, overscroll lock 동작 테스트 추가

#### 4-4. 테스트 인프라 개선 _(신규)_

- `test/helpers/` 공유 유틸리티 디렉토리 구성 (`pump_silky_scroll`, `create_test_state` 등)
- `SilkyScrollMousePointerManager`에 `@visibleForTesting` reset 메서드 추가 (싱글톤 테스트 격리)
- `FakeScrollController`, mock 객체 등 테스트 더블 정리

---

### 5. Dart 3+ 모던화 _(신규 섹션)_

> SDK 제약 `^3.10.7` / Flutter `>=3.38.0`에서 사용 가능한 최신 문법 적용.

#### 5-1. `final` / `interface` class modifier 일괄 적용

- **대상** (외부 확장 의도 없는 구체 클래스):
  | class modifier | 대상 클래스 |
  |---|---|
  | `final class` | `SilkyScrollConfig`, `BlockedScrollPhysics`, `SilkyEdgeDetector`, `SilkyScrollAnimator`, `SilkyInputHandler`, `SilkyScrollMousePointerManager`, `SilkyScrollPosition` |
  | `abstract interface class` | `SilkyScrollAnimatorDelegate`, `SilkyInputHandlerDelegate`, `SilkyScrollWebManagerInterface` |
- **효과**: API surface 명확화, 외부 extends/implements 방지, 컴파일러 최적화
- **난이도**: 쉬움

#### 5-2. `@immutable` / `@protected` / `@visibleForTesting` annotation 보강

- `@immutable`: `SilkyScrollConfig`, `SilkyEdgeDetector` (const constructor, 무상태)
- `@visibleForTesting`: `SilkyScrollMousePointerManager` reset 메서드
- **난이도**: 쉬움

#### 5-3. switch expression / pattern matching 리팩토링

- **대상**:
  - `SilkyEdgeDetector.checkOffsetAtEdge` — if 체인 → switch expression
  - `SilkyScrollAnimator._handleRecoil` — edgePosition 결정 로직 → switch expression
  - `SilkyInputHandler.triggerTouchAction` — kIsWeb 분기 → 조건부 import (2-1 항목과 연계)
- **효과**: 선언적 코드, exhaustiveness check
- **난이도**: 쉬움

#### 5-4. `SilkyScrollConfig` API 보강 _(신규)_

- **현재**: `copyWith`, `==`, `hashCode`, `toString` 미구현
- **작업**: `copyWith` 메서드 추가, `==`/`hashCode` 구현 (또는 `Equatable` 사용), `toString` 오버라이드
- **효과**: config 변형 편의성, 동등성 비교 가능, 디버깅 개선
- **난이도**: 쉬움

---

### 6. 성능 최적화 _(신규 섹션)_

#### 6-1. `ListenableBuilder` rebuild 범위 축소 검토

- **현재**: `ChangeNotifier`의 모든 `notifyListeners()` 호출에서 `ListenableBuilder` 하위 전체 위젯 서브트리 rebuild
- **실제 변경**: `currentScrollPhysics` 값만 변경됨
- **검토**: `ValueNotifier<ScrollPhysics>`로 대체하여 rebuild 범위 축소 가능 여부 확인
- **난이도**: 보통

#### 6-2. `ScrollPhysicsPhase` enum export 검토 _(신규)_

- **현재**: `ScrollPhysicsPhase`는 배럴 파일에서 export되지 않음
- **작업**: 위젯 사용자가 edge lock 상태를 쿼리할 필요가 있는지 판단 후 export 여부 결정
- **난이도**: 쉬움

---

### 7. 기타

#### 7-1. pubspec.yaml 버전 업데이트

- Phase 1 변경사항을 반영한 CHANGELOG 항목 추가 및 버전 범프 (1.0.16 → 2.0.0 또는 1.1.0)
- Provider 의존성 제거는 breaking change → semver 검토 필요

#### 7-2. pub.dev 점수 최적화

- `dart pub publish --dry-run`으로 점수 확인
- dartdoc coverage 100% 달성 여부 점검

---

## 우선순위 정리

| 순위  | 항목                                          | 영향도               | 난이도 |
| ----- | --------------------------------------------- | -------------------- | ------ |
| 🔴 1  | 0-1. `lib/` 루트 구버전 파일 삭제             | 높음 (정합성)        | 쉬움   |
| 🔴 2  | 0-2. `toInt()` edge 감지 수정 (`src/` 미적용) | 높음 (서브픽셀 버그) | 쉬움   |
| 🔴 3  | 0-3. `.bak` 테스트 파일 복원                  | 높음 (커버리지)      | 쉬움   |
| 🔴 4  | 0-4. web helper 매직 넘버 상수화              | 중간 (일관성)        | 쉬움   |
| 🟠 5  | 3-1. clientController.attach 이중 등록 검증   | 높음 (버그)          | 보통   |
| 🟠 6  | 3-2. dispose 순서 안전성 확인                 | 높음 (버그)          | 보통   |
| 🟠 7  | 3-3. `_transitionTo` disposed 체크            | 중간 (버그)          | 쉬움   |
| 🟡 8  | 5-1. Dart 3 class modifiers 일괄 적용         | 중간 (API 안전)      | 쉬움   |
| 🟡 9  | 2-1. kIsWeb 조건부 import 통합                | 중간                 | 보통   |
| 🟡 10 | 5-3. switch expression 리팩토링               | 중간 (가독성)        | 쉬움   |
| 🟡 11 | 4-1~4-4. 테스트 확장 + 인프라                 | 높음                 | 어려움 |
| 🟡 12 | 5-4. `SilkyScrollConfig` API 보강             | 중간                 | 쉬움   |
| 🟡 13 | 6-1. `ListenableBuilder` rebuild 범위 축소    | 중간 (성능)          | 보통   |
| ⚪ 14 | 5-2. annotation 보강 (`@immutable` 등)        | 낮음                 | 쉬움   |
| ⚪ 15 | 6-2. `ScrollPhysicsPhase` export 검토         | 낮음                 | 쉬움   |
| ⚪ 16 | 1-1. README 이미지                            | 낮음                 | 쉬움   |
| ⚪ 17 | 1-2. Example 구조                             | 낮음                 | 쉬움   |
| ⚪ 18 | 1-3. 린트 규칙 (`lints` + 커스텀)             | 낮음                 | 쉬움   |
| ⚪ 19 | 7-1~7-2. 배포 준비                            | 중간                 | 쉬움   |
