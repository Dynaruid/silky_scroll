library silky_scroll;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_state.dart';

class SilkyScroll extends StatefulWidget {
  final ScrollController? controller;
  final Duration silkyScrollDuration;
  final double scrollSpeed;
  final Curve animationCurve;
  final Axis direction;
  final ScrollPhysics physics;
  final SilkyScrollWidgetBuilder builder;
  final Duration edgeLockingDelay;
  final void Function(double delta)? scrollCallback;
  final Function(PointerDeviceKind)? setManualPointerDeviceKind;
  final bool isDebug;

  const SilkyScroll(
      {super.key,
      this.controller,
      this.silkyScrollDuration = const Duration(milliseconds: 700),
      this.scrollSpeed = 1,
      this.animationCurve = Curves.easeOutQuart,
      this.direction = Axis.vertical,
      this.physics = const ScrollPhysics(),
      this.edgeLockingDelay = const Duration(milliseconds: 650),
      this.setManualPointerDeviceKind,
      this.scrollCallback,
      required this.builder,
      this.isDebug = false});

  @override
  State<SilkyScroll> createState() => _SilkyScrollState();
}

class _SilkyScrollState extends State<SilkyScroll> {
  late final SilkyScrollState silkyScrollState;
  late final SilkyScrollMousePointerManager silkyScrollMousePointerManager;

  @override
  void initState() {
    super.initState();
    silkyScrollMousePointerManager = SilkyScrollMousePointerManager();
    silkyScrollState = SilkyScrollState(
        scrollController: widget.controller,
        widgetScrollPhysics: widget.physics,
        silkyScrollDuration: widget.silkyScrollDuration,
        animationCurve: widget.animationCurve,
        edgeLockingDelay: widget.edgeLockingDelay,
        scrollSpeed: widget.scrollSpeed,
        setManualPointerDeviceKind: widget.setManualPointerDeviceKind,
        isVertical: widget.direction == Axis.vertical,
        silkyScrollMousePointerManager: silkyScrollMousePointerManager,
        isDebug: widget.isDebug);
  }

  @override
  void didUpdateWidget(covariant SilkyScroll oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.physics != widget.physics) {
      silkyScrollState.setWidgetScrollPhysics(scrollPhysics: widget.physics);
    }
  }

  @override
  void dispose() {
    silkyScrollState.dispose();
    super.dispose();
  }

  bool checkTrackpad(PointerDeviceKind kind) {
    if (kind == PointerDeviceKind.trackpad) {
      silkyScrollState.setPointerDeviceKind(PointerDeviceKind.trackpad);
      silkyScrollMousePointerManager.resetTrackpadCheckTimer();
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    silkyScrollState.parentSilkyScrollState = context.read<SilkyScrollState?>();
    return ChangeNotifierProvider.value(
      value: silkyScrollState,
      builder: (BuildContext context, Widget? child) {
        context.select((SilkyScrollState state) => state.widgetScrollPhysics);
        final currentPhysics = context
            .select((SilkyScrollState state) => state.currentScrollPhysics);
        return MouseRegion(
          onEnter: (e) {
            silkyScrollMousePointerManager
                .enteredKey(silkyScrollState.pointKey);
          },
          onExit: (e) {
            silkyScrollMousePointerManager.exitKey(silkyScrollState.pointKey);
          },
          opaque: false,
          child: Listener(
              onPointerHover: (PointerHoverEvent signalEvent) {
                checkTrackpad(signalEvent.kind);
              },
              onPointerSignal: (PointerSignalEvent signalEvent) {
                if (signalEvent is PointerScrollEvent) {
                  if (checkTrackpad(signalEvent.kind)) {
                    silkyScrollState.triggerTouchAction(
                        signalEvent.scrollDelta, PointerDeviceKind.trackpad);
                  } else {
                    if (silkyScrollMousePointerManager
                        .trackpadCheckTimer.isActive) {
                      silkyScrollState.triggerTouchAction(
                          signalEvent.scrollDelta, PointerDeviceKind.trackpad);
                    } else {
                      final double scrollDeltaY = signalEvent.scrollDelta.dy;
                      if (silkyScrollMousePointerManager
                          .mouseCheckTimer.isActive) {
                        silkyScrollState.triggerMouseAction(scrollDeltaY);
                      } else {
                        final double scrollDeltaX = signalEvent.scrollDelta.dx;
                        if ((scrollDeltaX * 10).toInt() != 0 ||
                            scrollDeltaY.abs() < 4) {
                          checkTrackpad(PointerDeviceKind.trackpad);
                          return;
                        }
                        silkyScrollState.triggerMouseAction(scrollDeltaY);
                      }
                    }
                  }
                }
              },
              onPointerMove: (PointerMoveEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  silkyScrollState
                      .setPointerDeviceKind(PointerDeviceKind.touch);
                  silkyScrollState.triggerTouchAction(
                      event.delta, PointerDeviceKind.touch);
                }
              },
              onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent event) {
                silkyScrollState.triggerTouchAction(
                    event.panDelta, PointerDeviceKind.trackpad);
              },
              child: widget.builder(context,
                  silkyScrollState.silkyScrollController, currentPhysics)),
        );
      },
    );
  }
}

typedef SilkyScrollWidgetBuilder = Widget Function(
    BuildContext context, ScrollController controller, ScrollPhysics physics);
