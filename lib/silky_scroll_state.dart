import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_controller.dart';
import 'blocked_scroll_physics.dart';

class SilkyScrollState with ChangeNotifier {
  bool isAlive = true;
  late final ScrollController clientController;
  late final SilkyScrollController silkyScrollController;
  late final bool isControllerOwn;
  final UniqueKey pointKey = UniqueKey();
  double futurePosition = 0;
  final Curve animationCurve;
  final Duration silkyScrollDuration;
  late final int recoilDurationMS;
  late final bool isPlatformBouncingScrollPhysics;
  late ScrollPhysics currentScrollPhysics;
  late ScrollPhysics widgetScrollPhysics;
  final BlockedScrollPhysics kDisableScrollPhysics =
      const BlockedScrollPhysics();
  final bool isNeedScrollEventBubbling;
  final void Function(double delta)? scrollCallback;
  late final Function(PointerDeviceKind) setPointerDeviceKind;
  final bool isDebug;

  bool prevDeltaPositive = false;
  Future<void>? _animationEnd;
  bool isOnSilkyScrolling = false;
  bool isRecoilScroll = false;
  final bool isVertical;
  final Duration edgeLockingDelay;
  final double scrollSpeed;
  double lastDelta = 0;
  Timer scrollSetDisableTimer = Timer(Duration.zero, () {});
  Timer scrollEnableTimer = Timer(Duration.zero, () {});
  final SilkyScrollMousePointerManager silkyScrollMousePointerManager;
  SilkyScrollState? parentSilkyScrollState;
  bool _isInnerScrollNegative = true;

  //VoidCallback? reserveCallbackScrollOnEdge;

  SilkyScrollState({
    ScrollController? scrollController,
    this.widgetScrollPhysics = const ScrollPhysics(),
    required this.edgeLockingDelay,
    required this.scrollSpeed,
    required this.silkyScrollDuration,
    required this.animationCurve,
    required this.isVertical,
    required this.isNeedScrollEventBubbling,
    required this.isDebug,
    this.scrollCallback,
    required Function(PointerDeviceKind)? setManualPointerDeviceKind,
    required this.silkyScrollMousePointerManager,
  }) {
    currentScrollPhysics = widgetScrollPhysics;
    if (widgetScrollPhysics is BouncingScrollPhysics) {
      isPlatformBouncingScrollPhysics = true;
    } else {
      isPlatformBouncingScrollPhysics = false;
    }

    if (scrollController != null) {
      clientController = scrollController;
      isControllerOwn = false;
    } else {
      clientController = ScrollController();
      isControllerOwn = true;
    }
    silkyScrollController =
        SilkyScrollController(clientController: clientController);

    clientController.addListener(onScrollUpdate);
    recoilDurationMS = (silkyScrollDuration.inMilliseconds * 0.8).toInt();
    if (setManualPointerDeviceKind == null) {
      setPointerDeviceKind = silkyScrollController.setPointerDeviceKind;
    } else {
      setPointerDeviceKind = setManualPointerDeviceKind;
    }
  }

  void checkNeedLocking() {
    if (isAlive == false ||
        clientController.hasClients == false ||
        lastDelta.toInt() == 0) {
      return;
    }
    final double delta;
    if (lastDelta.isNegative) {
      delta = -1;
    } else {
      delta = 1;
    }
    if (clientController.position.maxScrollExtent.toInt() == 0) {
      lastDelta = 0;
      return;
    }
    final int checkedOffsetAtEdge = checkOffsetAtEdge(delta, clientController);
    if (checkedOffsetAtEdge != 0) {
      if ((currentScrollPhysics is BlockedScrollPhysics) == false) {
        scrollEnableTimer.cancel();
        currentScrollPhysics = kDisableScrollPhysics;
        notifyListeners();
        scrollEnableTimer = Timer(edgeLockingDelay, unlockScroll);

        // if (currentScrollPhysics is BouncingScrollPhysics) {
        //   reserveCallbackScrollOnEdge = () {
        //     final int offset = clientController.offset.toInt();
        //     if (offset > -10) {
        //       reserveCallbackScrollOnEdge = null;
        //       currentScrollPhysics = BlockedScrollPhysics(
        //           parent: currentScrollPhysics); //kDisableScrollPhysics;
        //       notifyListeners();
        //       scrollEnableTimer = Timer(edgeLockingDelay, unlockScroll);
        //     } else if (offset <
        //         clientController.position.maxScrollExtent + 10) {
        //       reserveCallbackScrollOnEdge = null;
        //       currentScrollPhysics =
        //           BlockedScrollPhysics(parent: currentScrollPhysics);
        //       notifyListeners();
        //       scrollEnableTimer = Timer(edgeLockingDelay, unlockScroll);
        //     }
        //   };
        // } else {
        //   currentScrollPhysics = kDisableScrollPhysics;
        //   notifyListeners();
        //   scrollEnableTimer = Timer(edgeLockingDelay, unlockScroll);
        // }

        if (parentSilkyScrollState != null && isNeedScrollEventBubbling) {
          parentSilkyScrollState!
              .manualHandleScroll(lastDelta * 2.8, isVertical);
        }

        lastDelta = 0;
        return;
      }
    }
    // else {
    //   reserveCallbackScrollOnEdge = null;
    //   currentScrollPhysics = widgetScrollPhysics;
    // }

    lastDelta = 0;
  }

  void manualHandleScroll(double delta, bool callIsVertical) {
    if (isAlive == false) {
      return;
    }
    if ((currentScrollPhysics is NeverScrollableScrollPhysics) == false &&
        callIsVertical == isVertical) {
      //print(delta);
      if (delta.isNegative == _isInnerScrollNegative) {
        futurePosition = min(max(0, futurePosition + delta),
            clientController.position.maxScrollExtent);
      } else {
        _isInnerScrollNegative = delta.isNegative;
        futurePosition = min(max(0, clientController.offset + delta),
            clientController.position.maxScrollExtent);
      }

      //decelerationManualHandleScroll(delta);
      final Duration duration = Duration(
          milliseconds:
              min(800, max(250, ((delta.abs() / 150) * 250).toInt())));
      clientController.animateTo(
        futurePosition,
        duration: duration,
        curve: Curves.easeOutQuad,
      );
    } else {
      if (parentSilkyScrollState != null) {
        parentSilkyScrollState!.manualHandleScroll(delta, callIsVertical);
      }
    }
  }

  void triggerTouchAction(Offset delta, PointerDeviceKind kind) {
    final double scrollDelta;
    if (kind == PointerDeviceKind.trackpad && kIsWeb) {
      if (isVertical) {
        scrollDelta = delta.dy;
      } else {
        scrollDelta = delta.dx;
      }
    } else {
      if (isVertical) {
        scrollDelta = -delta.dy;
      } else {
        scrollDelta = -delta.dx;
      }
    }

    if (scrollDelta.toInt() != 0) {
      handleTouchScroll(scrollDelta);
      silkyScrollMousePointerManager.silkyScrollWebManager
          .blockOverscrollBehaviorXHtml();
    }
    if (scrollCallback != null) {
      scrollCallback!(scrollDelta);
    }
  }

  void triggerMouseAction(double scrollDeltaY) {
    setPointerDeviceKind(PointerDeviceKind.mouse);
    if (scrollCallback != null) {
      scrollCallback!(scrollDeltaY);
    }
    handleMouseScroll(scrollDeltaY, scrollSpeed);
    silkyScrollMousePointerManager.resetMouseCheckTimer();
  }

  void unlockScroll() {
    if (isAlive) {
      currentScrollPhysics = widgetScrollPhysics;
      notifyListeners();
    }
    // WidgetsBinding.instance.scheduleFrame();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (isAlive) {
    //     currentScrollPhysics = widgetScrollPhysics;
    //     notifyListeners();
    //   }
    // });
  }

  void handleTouchScroll(double delta) {
    //터치스크롤의 델타는 마우스와 반대
    //트랙패드는 마우스와 동일

    lastDelta += delta;
    if (scrollSetDisableTimer.isActive) {
      return;
    } else {
      scrollSetDisableTimer =
          Timer(const Duration(milliseconds: 80), checkNeedLocking);
    }
  }

  void handleMouseScroll(
    double delta,
    double scrollSpeed,
  ) {
    if (isRecoilScroll) {
      return;
    }

    if (currentScrollPhysics != widgetScrollPhysics) {
      currentScrollPhysics = widgetScrollPhysics;
      notifyListeners();
    }
    final double scrollDelta = delta;
    final bool needBlocking;
    final bool isEdge = checkOffsetAtEdge(scrollDelta, clientController) != 0;
    if (widgetScrollPhysics is BlockedScrollPhysics) {
      needBlocking = true;
    } else {
      needBlocking = isEdge;
    }

    if (pointKey == silkyScrollMousePointerManager.reserveKey) {
      if (isOnSilkyScrolling == false) {
        if (needBlocking) {
          silkyScrollMousePointerManager.reservingKey(pointKey);
          return;
        }
        silkyScrollMousePointerManager.reserveKey = null;
        silkyScrollMousePointerManager.enteredKey(pointKey);
      }
    }
    if (isOnSilkyScrolling == false) {
      if (needBlocking) {
        silkyScrollMousePointerManager.reservingKey(pointKey);
        return;
      }
    }

    if (silkyScrollMousePointerManager.keyStack.isNotEmpty) {
      if (pointKey != silkyScrollMousePointerManager.keyStack.last) {
        return;
      }
    }

    animateToScroll(scrollDelta, scrollSpeed);
  }

  void animateToScroll(
    double scrollDelta,
    double scrollSpeed,
  ) {
    if (scrollDelta > 0 != prevDeltaPositive) {
      prevDeltaPositive = !prevDeltaPositive;
      futurePosition =
          clientController.offset + (scrollDelta * scrollSpeed * 0.5);
    } else {
      futurePosition = futurePosition + (scrollDelta * scrollSpeed * 0.5);
    }

    final Duration duration;
    if (futurePosition > clientController.position.maxScrollExtent) {
      futurePosition = isPlatformBouncingScrollPhysics
          ? min(clientController.position.maxScrollExtent + 150, futurePosition)
          : clientController.position.maxScrollExtent;
      duration =
          Duration(milliseconds: silkyScrollDuration.inMilliseconds ~/ 2);
    } else if (futurePosition < clientController.position.minScrollExtent) {
      futurePosition = isPlatformBouncingScrollPhysics
          ? max(clientController.position.minScrollExtent - 150, futurePosition)
          : clientController.position.minScrollExtent;
      duration =
          Duration(milliseconds: silkyScrollDuration.inMilliseconds ~/ 2);
    } else {
      duration = silkyScrollDuration;
    }
    isOnSilkyScrolling = true;
    final Future<void> animationEnd =
        _animationEnd = clientController.animateTo(
      futurePosition,
      duration: duration,
      curve: animationCurve,
    );
    animationEnd.whenComplete(() {
      if (animationEnd == _animationEnd) {
        isOnSilkyScrolling = false;
        if (clientController.hasClients == false) {
          return;
        }

        double edgePosition = 0;
        if (clientController.offset >
            clientController.position.maxScrollExtent) {
          isRecoilScroll = true;
          edgePosition = clientController.position.maxScrollExtent;
        } else if (clientController.offset <
            clientController.position.minScrollExtent) {
          isRecoilScroll = true;
          edgePosition = clientController.position.minScrollExtent;
        }

        if (isRecoilScroll) {
          notifyListeners();
          clientController
              .animateTo(
            edgePosition,
            duration: Duration(milliseconds: recoilDurationMS),
            curve: Curves.easeInOutSine,
          )
              .whenComplete(() {
            if (isAlive) {
              isRecoilScroll = false;
              notifyListeners();
            }
          });
        }
      }
    });
  }

  void setWidgetScrollPhysics({required ScrollPhysics scrollPhysics}) {
    scrollEnableTimer.cancel();
    scrollSetDisableTimer.cancel();
    widgetScrollPhysics = scrollPhysics;
    currentScrollPhysics = scrollPhysics;
    notifyListeners();
  }

  void onScrollUpdate() {
    if (isOnSilkyScrolling == false) {
      futurePosition = clientController.offset;
      // if (reserveCallbackScrollOnEdge != null) {
      //   reserveCallbackScrollOnEdge!();
      // }
    }
  }

  @override
  void dispose() {
    scrollSetDisableTimer.cancel();
    scrollEnableTimer.cancel();
    isAlive = false;
    clientController.removeListener(onScrollUpdate);
    silkyScrollController.dispose();
    silkyScrollMousePointerManager.detachKey(pointKey);

    if (isControllerOwn) {
      clientController.dispose();
    }
    super.dispose();
  }
}

int checkOffsetAtEdge(double verticalDelta, ScrollController controller) {
  if (controller.hasClients == false) {
    return 0;
  }
  if (verticalDelta.isNegative) {
    final int dest = (max(verticalDelta, -2) + controller.offset).toInt();
    if (dest < 0) {
      return -1;
    } else {
      return 0;
    }
  } else {
    final int dest = (min(verticalDelta, 2) + controller.offset).toInt();
    final int maxScrollExtent = controller.position.maxScrollExtent.toInt();
    if (dest > maxScrollExtent) {
      return 1;
    } else {
      return 0;
    }
  }
}
