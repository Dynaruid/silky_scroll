import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/src/blocked_scroll_physics.dart';
import 'package:silky_scroll/src/silky_scroll_state.dart';
import 'package:silky_scroll/src/silky_scroll_mouse_pointer_manager.dart';

/// Minimal [TickerProvider] for tests.
class _TestVSync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Helper to build a minimal widget tree with a [SilkyScrollState].
Widget _buildScrollable({
  required ScrollController controller,
  int itemCount = 50,
  double itemHeight = 100,
}) {
  return MaterialApp(
    home: ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemBuilder: (_, i) => SizedBox(height: itemHeight, child: Text('$i')),
    ),
  );
}

SilkyScrollState _createState({
  ScrollController? scrollController,
  ScrollPhysics physics = const ScrollPhysics(),
  Duration edgeLockingDelay = const Duration(milliseconds: 650),
  double scrollSpeed = 1,
  Duration silkyScrollDuration = const Duration(milliseconds: 700),
  Curve animationCurve = Curves.easeOutQuart,
  bool isVertical = true,
  bool debugMode = false,
  SilkyScrollMousePointerManager? manager,
  TickerProvider? vsync,
  int Function()? clock,
}) {
  manager ??= SilkyScrollMousePointerManager();
  return SilkyScrollState(
    scrollController: scrollController,
    widgetScrollPhysics: physics,
    edgeLockingDelay: edgeLockingDelay,
    scrollSpeed: scrollSpeed,
    silkyScrollDuration: silkyScrollDuration,
    animationCurve: animationCurve,
    isVertical: isVertical,
    debugMode: debugMode,
    setManualPointerDeviceKind: null,
    silkyScrollMousePointerManager: manager,
    vsync: vsync ?? _TestVSync(),
    clock: clock,
  );
}

void main() {
  group('SilkyScrollState — ScrollPhysicsPhase transitions', () {
    late SilkyScrollState state;
    late SilkyScrollMousePointerManager manager;

    setUp(() {
      manager = SilkyScrollMousePointerManager();
      manager.keyStack.clear();
      manager.reserveKey = null;
    });

    tearDown(() {
      if (!state.isDisposed) {
        state.dispose();
      }
    });

    test('initial phase is normal', () {
      state = _createState(manager: manager);
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
      expect(state.isEdgeLocked, isFalse);
      expect(state.isOverscrollLocked, isFalse);
    });

    testWidgets('handleTouchScroll transitions to edgeCheckPending', (
      tester,
    ) async {
      state = _createState(manager: manager);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.handleTouchScroll(10.0);
      expect(state.physicsPhase, ScrollPhysicsPhase.edgeCheckPending);

      // Dispose within test body to cancel pending timer.
      state.dispose();
    });

    testWidgets(
      'handleTouchScroll at edge transitions to edgeLocked after delay',
      (tester) async {
        int fakeTime = 1000;
        state = _createState(
          manager: manager,
          edgeLockingDelay: const Duration(milliseconds: 200),
          clock: () => fakeTime,
        );
        await tester.pumpWidget(
          _buildScrollable(controller: state.clientController),
        );

        // At top edge, scrolling up (negative delta)
        state.handleTouchScroll(-10.0);
        fakeTime += 50;
        state.handleTouchScroll(-10.0);
        expect(state.physicsPhase, ScrollPhysicsPhase.edgeCheckPending);

        // Wait for the 80ms edge check delay
        await tester.pump(const Duration(milliseconds: 100));

        // After check, should be edgeLocked
        expect(state.physicsPhase, ScrollPhysicsPhase.edgeLocked);
        expect(state.isEdgeLocked, isTrue);

        // Dispose within test body to cancel pending edgeLockingDelay timer.
        state.dispose();
      },
    );

    testWidgets('edgeLocked unlocks after edgeLockingDelay', (tester) async {
      int fakeTime = 1000;
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 200),
        clock: () => fakeTime,
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Trigger edge lock at top
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.isEdgeLocked, isTrue);

      // Wait for edgeLockingDelay
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.isEdgeLocked, isFalse);
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
    });

    testWidgets(
      'continued touch scroll during edgeLocked does not cancel unlock timer',
      (tester) async {
        int fakeTime = 1000;
        state = _createState(
          manager: manager,
          edgeLockingDelay: const Duration(milliseconds: 300),
          clock: () => fakeTime,
        );
        await tester.pumpWidget(
          _buildScrollable(controller: state.clientController),
        );

        // Trigger edge lock at top
        state.handleTouchScroll(-10.0);
        fakeTime += 50;
        state.handleTouchScroll(-10.0);
        await tester.pump(const Duration(milliseconds: 100));
        expect(state.isEdgeLocked, isTrue);

        // Simulate continued touch scrolling while locked — this previously
        // cancelled the unlock timer, leaving physics permanently blocked.
        state.handleTouchScroll(-5.0);
        state.handleTouchScroll(-8.0);
        await tester.pump(const Duration(milliseconds: 50));
        state.handleTouchScroll(-3.0);

        // Phase should still be edgeLocked, not edgeCheckPending
        expect(state.physicsPhase, ScrollPhysicsPhase.edgeLocked);

        // Wait for the original edgeLockingDelay to expire
        await tester.pump(const Duration(milliseconds: 300));

        // Must unlock — previously this would stay locked forever
        expect(state.isEdgeLocked, isFalse);
        expect(state.physicsPhase, ScrollPhysicsPhase.normal);
      },
    );

    testWidgets(
      'continued touch scroll during overscrollLocked does not cancel timer',
      (tester) async {
        state = _createState(manager: manager);
        await tester.pumpWidget(
          _buildScrollable(controller: state.clientController),
        );

        state.isOverScrolling = true;
        state.beginOverscrollLock(const Duration(milliseconds: 200));
        expect(state.isOverscrollLocked, isTrue);

        // Simulate touch scrolling during overscroll lock
        state.handleTouchScroll(5.0);
        state.handleTouchScroll(3.0);

        // Should remain overscrollLocked
        expect(state.physicsPhase, ScrollPhysicsPhase.overscrollLocked);

        // Wait for overscroll lock to expire
        await tester.pump(const Duration(milliseconds: 250));
        expect(state.physicsPhase, ScrollPhysicsPhase.normal);
      },
    );

    testWidgets('beginOverscrollLock transitions to overscrollLocked', (
      tester,
    ) async {
      state = _createState(manager: manager);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.isOverScrolling = true;
      state.beginOverscrollLock(const Duration(milliseconds: 200));
      expect(state.physicsPhase, ScrollPhysicsPhase.overscrollLocked);
      expect(state.isOverscrollLocked, isTrue);
      expect(state.isOverScrolling, isFalse);

      // Dispose within test body to cancel pending timer.
      state.dispose();
    });

    testWidgets('overscrollLock returns to normal after timeout', (
      tester,
    ) async {
      state = _createState(manager: manager);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.beginOverscrollLock(const Duration(milliseconds: 200));
      expect(state.isOverscrollLocked, isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
      expect(state.isOverscrollLocked, isFalse);
    });

    testWidgets('setWidgetScrollPhysics resets phase to normal', (
      tester,
    ) async {
      state = _createState(manager: manager);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Force into a non-normal state
      state.handleTouchScroll(-10.0);
      expect(state.physicsPhase, isNot(ScrollPhysicsPhase.normal));

      state.setWidgetScrollPhysics(
        scrollPhysics: const BouncingScrollPhysics(),
      );
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
    });
  });

  group('SilkyScrollState — touch-aware edge locking', () {
    late SilkyScrollState state;
    late SilkyScrollMousePointerManager manager;

    setUp(() {
      manager = SilkyScrollMousePointerManager();
      manager.keyStack.clear();
      manager.reserveKey = null;
    });

    tearDown(() {
      if (!state.isDisposed) {
        state.dispose();
      }
    });

    testWidgets('handleTouchScroll during active touch does not lock at edge', (
      tester,
    ) async {
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Simulate finger down
      state.onTouchDown();

      // Scroll up at top edge — should NOT lock
      state.handleTouchScroll(-10.0);
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);

      await tester.pump(const Duration(milliseconds: 100));
      // Should still be normal — no timer was started
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);

      state.dispose();
    });

    testWidgets('onEdgeOverScroll fires during active touch at edge', (
      tester,
    ) async {
      final List<double> edgeDeltas = [];
      state = _createState(manager: manager);
      // Need to recreate with callback — use a fresh state
      state.dispose();
      state = SilkyScrollState(
        widgetScrollPhysics: const ScrollPhysics(),
        edgeLockingDelay: const Duration(milliseconds: 200),
        scrollSpeed: 1,
        silkyScrollDuration: const Duration(milliseconds: 700),
        animationCurve: Curves.easeOutQuart,
        isVertical: true,
        debugMode: false,
        onEdgeOverScroll: edgeDeltas.add,
        setManualPointerDeviceKind: null,
        silkyScrollMousePointerManager: manager,
        vsync: _TestVSync(),
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.onTouchDown();
      state.handleTouchScroll(-10.0); // top edge, scroll up
      expect(edgeDeltas, [-10.0]);

      state.dispose();
    });

    testWidgets('onTouchUp locks at edge with directional awareness', (
      tester,
    ) async {
      int fakeTime = 1000;
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 300),
        clock: () => fakeTime,
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Simulate touch scroll at top edge then lift
      state.onTouchDown();
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);

      state.onTouchUp();
      // Should now be edge locked
      expect(state.physicsPhase, ScrollPhysicsPhase.edgeLocked);
      expect(state.isEdgeLocked, isTrue);

      state.dispose();
    });

    testWidgets('onTouchUp does not lock when not at edge', (tester) async {
      state = _createState(manager: manager);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Move away from edge
      state.clientController.jumpTo(500);
      await tester.pump();

      state.onTouchDown();
      state.handleTouchScroll(10.0);
      state.onTouchUp();

      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
      expect(state.isEdgeLocked, isFalse);
    });

    testWidgets('touch-up edge lock uses BlockedScrollPhysics', (tester) async {
      int fakeTime = 1000;
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 300),
        clock: () => fakeTime,
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Lock at top edge via touch-up
      state.onTouchDown();
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);
      state.onTouchUp();
      expect(state.isEdgeLocked, isTrue);
      expect(state.currentScrollPhysics, isA<BlockedScrollPhysics>());
      // Fully blocked — unlock is handled by tryGestureUnlock
      expect(state.currentScrollPhysics, isA<NeverScrollableScrollPhysics>());

      state.dispose();
    });

    testWidgets('onTouchDown preserves edge lock for outward blocking', (
      tester,
    ) async {
      int fakeTime = 1000;
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 300),
        clock: () => fakeTime,
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Lock at top edge via touch-up
      state.onTouchDown();
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);
      state.onTouchUp();
      expect(state.isEdgeLocked, isTrue);

      // New touch preserves lock (BlockedScrollPhysics;
      // unlock is handled by tryGestureUnlock)
      state.onTouchDown();
      expect(state.isEdgeLocked, isTrue);
      expect(state.currentScrollPhysics, isA<BlockedScrollPhysics>());

      state.dispose();
    });

    testWidgets('edge lock expires after edgeLockingDelay', (tester) async {
      int fakeTime = 1000;
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 200),
        clock: () => fakeTime,
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.onTouchDown();
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);
      state.onTouchUp();
      expect(state.isEdgeLocked, isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      expect(state.isEdgeLocked, isFalse);
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
    });

    testWidgets('onTouchDown keeps edge lock, touchUp renews it at edge', (
      tester,
    ) async {
      int fakeTime = 1000;
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 300),
        clock: () => fakeTime,
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Lock at top edge
      state.onTouchDown();
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);
      state.onTouchUp();
      expect(state.isEdgeLocked, isTrue);

      // New touch keeps the lock
      state.onTouchDown();
      expect(state.isEdgeLocked, isTrue);

      // Touch up at the same edge renews the lock
      state.onTouchUp();
      expect(state.isEdgeLocked, isTrue);

      state.dispose();
    });

    testWidgets('onTouchUp applies edge lock even when overscrollLocked', (
      tester,
    ) async {
      int fakeTime = 1000;
      state = _createState(manager: manager, clock: () => fakeTime);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.onTouchDown();
      state.handleTouchScroll(-10.0);
      fakeTime += 50;
      state.handleTouchScroll(-10.0);

      // Simulate overscroll lock (from widget's onPointerUp)
      state.isOverScrolling = true;
      state.beginOverscrollLock(const Duration(milliseconds: 200));
      expect(state.isOverscrollLocked, isTrue);

      // onTouchUp should apply edge lock, overriding overscrollLocked
      state.onTouchUp();
      expect(state.physicsPhase, ScrollPhysicsPhase.edgeLocked);

      state.dispose();
    });
  });

  group('SilkyScrollState — dispose safety', () {
    test('dispose sets _disposed flag', () {
      final state = _createState();
      expect(state.isDisposed, isFalse);
      state.dispose();
      expect(state.isDisposed, isTrue);
    });

    testWidgets('dispose cancels active phase timer', (tester) async {
      final state = _createState();
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.handleTouchScroll(10.0);
      expect(state.physicsPhase, ScrollPhysicsPhase.edgeCheckPending);

      state.dispose();
      // Should not throw after dispose, timer should be cancelled
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('notifyListeners throws after dispose', (tester) async {
      final state = _createState();
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      bool listenerCalled = false;
      state.addListener(() => listenerCalled = true);
      state.dispose();

      // ChangeNotifier throws FlutterError when notifyListeners
      // is called after dispose.
      expect(state.notifyListeners, throwsFlutterError);
      expect(listenerCalled, isFalse);
    });

    testWidgets('double dispose does not throw', (tester) async {
      final controller = ScrollController();
      final state = _createState(scrollController: controller);
      await tester.pumpWidget(_buildScrollable(controller: controller));

      state.dispose();
      // Second dispose should not crash
      // (ChangeNotifier.dispose may assert, but in test mode we verify
      // our guards prevent cascading failures)
      controller.dispose();
    });
  });

  group('SilkyScrollState — controller ownership', () {
    test('creates own controller when none provided', () {
      final state = _createState();
      expect(state.isControllerOwn, isTrue);
      state.dispose();
    });

    test('uses provided controller without ownership', () {
      final controller = ScrollController();
      final state = _createState(scrollController: controller);
      expect(state.isControllerOwn, isFalse);
      state.dispose();
      // External controller should still be usable after state dispose
      expect(controller.dispose, returnsNormally);
    });
  });

  group('SilkyScrollState — scroll position sync', () {
    testWidgets('futurePosition syncs with clientController offset', (
      tester,
    ) async {
      final state = _createState();
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.clientController.jumpTo(200);
      await tester.pump();
      expect(state.futurePosition, 200);

      state.dispose();
    });

    testWidgets('futurePosition does not sync during silky scrolling', (
      tester,
    ) async {
      final state = _createState();
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.isOnSilkyScrolling = true;
      state.clientController.jumpTo(200);
      await tester.pump();
      // futurePosition should stay at 0 because silky scrolling is active
      expect(state.futurePosition, 0);

      state.dispose();
    });
  });

  group('SilkyScrollState — recoil physics blocking', () {
    late SilkyScrollState state;
    late SilkyScrollMousePointerManager manager;

    setUp(() {
      manager = SilkyScrollMousePointerManager();
      manager.keyStack.clear();
      manager.reserveKey = null;
    });

    tearDown(() {
      if (!state.isDisposed) {
        state.dispose();
      }
    });

    testWidgets('onAnimationStateChanged blocks physics during recoil', (
      tester,
    ) async {
      state = _createState(
        manager: manager,
        physics: const BouncingScrollPhysics(),
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Simulate recoil start
      state.isRecoilScroll = true;
      state.onAnimationStateChanged();

      expect(state.currentScrollPhysics, isA<BlockedScrollPhysics>());
    });

    testWidgets('onAnimationStateChanged restores physics when recoil ends', (
      tester,
    ) async {
      state = _createState(
        manager: manager,
        physics: const BouncingScrollPhysics(),
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Start and end recoil
      state.isRecoilScroll = true;
      state.onAnimationStateChanged();
      expect(state.currentScrollPhysics, isA<BlockedScrollPhysics>());

      state.isRecoilScroll = false;
      state.onAnimationStateChanged();
      expect(state.currentScrollPhysics, isA<BouncingScrollPhysics>());
    });

    testWidgets(
      'onAnimationStateChanged preserves edge lock after recoil ends',
      (tester) async {
        int fakeTime = 1000;
        state = _createState(
          manager: manager,
          edgeLockingDelay: const Duration(milliseconds: 500),
          clock: () => fakeTime,
        );
        await tester.pumpWidget(
          _buildScrollable(controller: state.clientController),
        );

        // Trigger edge lock at top
        state.onTouchDown();
        state.handleTouchScroll(-10.0);
        fakeTime += 50;
        state.handleTouchScroll(-10.0);
        state.onTouchUp();
        expect(state.physicsPhase, ScrollPhysicsPhase.edgeLocked);
        expect(state.currentScrollPhysics, isA<BlockedScrollPhysics>());

        // Simulate recoil end while edge is locked — should NOT restore
        state.isRecoilScroll = false;
        state.onAnimationStateChanged();
        expect(state.currentScrollPhysics, isA<BlockedScrollPhysics>());

        state.dispose();
      },
    );
  });

  group('SilkyScrollState — cancelSilkyScroll', () {
    late SilkyScrollState state;
    late SilkyScrollMousePointerManager manager;

    setUp(() {
      manager = SilkyScrollMousePointerManager();
      manager.resetForTesting();
    });

    tearDown(() {
      if (!state.isDisposed) {
        state.dispose();
      }
    });

    testWidgets(
      'cancelSilkyScroll resets isOnSilkyScrolling and futurePosition',
      (tester) async {
        state = _createState(manager: manager);
        await tester.pumpWidget(
          _buildScrollable(controller: state.clientController),
        );

        // Simulate an in-progress silky scroll
        state.isOnSilkyScrolling = true;
        state.futurePosition = 500.0;

        state.cancelSilkyScroll();

        expect(state.isOnSilkyScrolling, isFalse);
        expect(state.futurePosition, state.clientController.offset);
      },
    );

    testWidgets('cancelSilkyScroll is no-op when not scrolling', (
      tester,
    ) async {
      state = _createState(manager: manager);
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      state.isOnSilkyScrolling = false;
      state.futurePosition = 0.0;

      // Should not throw
      state.cancelSilkyScroll();

      expect(state.isOnSilkyScrolling, isFalse);
    });
  });
}
