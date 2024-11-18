library silky_scroll;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_state.dart';

class SilkyScroll extends StatefulWidget {
  final ScrollController? controller;
  final int durationMS;
  final double scrollSpeed;
  final Curve animationCurve;
  final Axis direction;
  final ScrollPhysics physics;
  final SilkyScrollWidgetBuilder builder;
  final Duration edgeLockingDelay;
  final void Function(double delta)? scrollCallback;
  final Function(PointerDeviceKind)? setManualPointerDeviceKind;

  const SilkyScroll({
    super.key,
    this.controller,
    this.durationMS = 350,
    this.scrollSpeed = 1,
    this.animationCurve = Curves.easeOutQuart,
    this.direction = Axis.vertical,
    this.physics = const ScrollPhysics(),
    this.edgeLockingDelay = const Duration(milliseconds: 650),
    this.setManualPointerDeviceKind,
    this.scrollCallback,
    required this.builder,
  });

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
        durationMS: widget.durationMS,
        animationCurve: widget.animationCurve,
        edgeLockingDelay: widget.edgeLockingDelay,
        setManualPointerDeviceKind: widget.setManualPointerDeviceKind,
        isVertical: widget.direction == Axis.vertical);
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

  void triggerTouchAction(Offset delta, PointerDeviceKind kind) {
    final double scrollDelta;
    if (kind == PointerDeviceKind.trackpad) {
      if (kIsWeb) {
        if (widget.direction == Axis.vertical) {
          scrollDelta = delta.dy;
        } else {
          scrollDelta = delta.dx;
        }
      } else {
        if (widget.direction == Axis.vertical) {
          scrollDelta = -delta.dy;
        } else {
          scrollDelta = -delta.dx;
        }
      }
    } else {
      if (widget.direction == Axis.vertical) {
        scrollDelta = -delta.dy;
      } else {
        scrollDelta = -delta.dx;
      }
    }
    if (scrollDelta.toInt() != 0) {
      silkyScrollState.handleTouchScroll(scrollDelta);
      silkyScrollMousePointerManager.silkyScrollWebManager
          .blockOverscrollBehaviorXHtml();
    }
    if (widget.scrollCallback != null) {
      widget.scrollCallback!(scrollDelta);
    }
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

  void triggerMouseAction(double scrollDeltaY) {
    silkyScrollState.setPointerDeviceKind(PointerDeviceKind.mouse);
    if (widget.scrollCallback != null) {
      widget.scrollCallback!(scrollDeltaY);
    }
    silkyScrollState.handleMouseScroll(scrollDeltaY, widget.scrollSpeed);
    silkyScrollMousePointerManager.resetMouseCheckTimer();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: silkyScrollState,
      builder: (BuildContext context, Widget? child) {
        final controller = silkyScrollState.silkyScrollController;
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
                    triggerTouchAction(
                        signalEvent.scrollDelta, PointerDeviceKind.trackpad);
                  } else {
                    if (silkyScrollMousePointerManager
                        .trackpadCheckTimer.isActive) {
                      triggerTouchAction(
                          signalEvent.scrollDelta, PointerDeviceKind.trackpad);
                    } else {
                      final double scrollDeltaY = signalEvent.scrollDelta.dy;
                      if (silkyScrollMousePointerManager
                          .mouseCheckTimer.isActive) {
                        triggerMouseAction(scrollDeltaY);
                      } else {
                        final double scrollDeltaX = signalEvent.scrollDelta.dx;
                        if ((scrollDeltaX * 10).toInt() != 0 ||
                            scrollDeltaY.abs() < 4) {
                          checkTrackpad(PointerDeviceKind.trackpad);
                          return;
                        }
                        triggerMouseAction(scrollDeltaY);
                      }
                    }
                  }
                }
              },
              onPointerMove: (PointerMoveEvent event) {
                silkyScrollState.setPointerDeviceKind(PointerDeviceKind.touch);
                triggerTouchAction(event.delta, PointerDeviceKind.touch);
              },
              onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent event) {
                triggerTouchAction(event.panDelta, PointerDeviceKind.trackpad);
              },
              child: widget.builder(context, controller, currentPhysics)),
        );
      },
    );
  }
}

typedef SilkyScrollWidgetBuilder = Widget Function(
    BuildContext context, ScrollController controller, ScrollPhysics physics);
