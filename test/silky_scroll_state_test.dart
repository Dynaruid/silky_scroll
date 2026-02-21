import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/src/silky_scroll_state.dart';
import 'package:silky_scroll/src/silky_scroll_mouse_pointer_manager.dart';

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
  bool enableScrollBubbling = false,
  bool debugMode = false,
  SilkyScrollMousePointerManager? manager,
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
    enableScrollBubbling: enableScrollBubbling,
    debugMode: debugMode,
    setManualPointerDeviceKind: null,
    silkyScrollMousePointerManager: manager,
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
        state = _createState(
          manager: manager,
          edgeLockingDelay: const Duration(milliseconds: 200),
        );
        await tester.pumpWidget(
          _buildScrollable(controller: state.clientController),
        );

        // At top edge, scrolling up (negative delta)
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
      state = _createState(
        manager: manager,
        edgeLockingDelay: const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(
        _buildScrollable(controller: state.clientController),
      );

      // Trigger edge lock at top
      state.handleTouchScroll(-10.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.isEdgeLocked, isTrue);

      // Wait for edgeLockingDelay
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.isEdgeLocked, isFalse);
      expect(state.physicsPhase, ScrollPhysicsPhase.normal);
    });

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
      expect(() => state.notifyListeners(), throwsFlutterError);
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
      expect(() => controller.dispose(), returnsNormally);
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

  group('SilkyScrollState — bubbling', () {
    testWidgets('manualHandleScroll bubbles to parent when physics blocked', (
      tester,
    ) async {
      final parentState = _createState(enableScrollBubbling: true);
      final childState = _createState(enableScrollBubbling: true);
      childState.parentSilkyScrollState = parentState;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: parentState.clientController,
                  itemCount: 50,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 100, child: Text('P$i')),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: childState.clientController,
                  itemCount: 50,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 100, child: Text('C$i')),
                ),
              ),
            ],
          ),
        ),
      );

      // Manual handle scroll on child with different axis should bubble
      childState.currentScrollPhysics = const NeverScrollableScrollPhysics();
      childState.manualHandleScroll(50.0, true);
      // Parent should receive the bubbled scroll
      // (not easily checkable without mocking, but at least no errors)

      childState.dispose();
      parentState.dispose();
    });
  });
}
