import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'silky_scroll_mouse_pointer_manager.dart';
import 'silky_scroll_controller.dart';
import 'BlockedScrollPhysics.dart';

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
  late ScrollPhysics widgetScrollPhysics;
  final BlockedScrollPhysics kDisableScrollPhysics =
      const BlockedScrollPhysics();
  late final Function(PointerDeviceKind) setPointerDeviceKind;

  late ScrollPhysics currentScrollPhysics;
  bool prevDeltaPositive = false;
  Future<void>? _animationEnd;
  bool isOnSilkyScrolling = false;
  bool isRecoilScroll = false;
  final bool isVertical;
  final Duration edgeLockingDelay;
  double lastDelta = 0;
  Timer scrollSetDisableTimer = Timer(Duration.zero, () {});
  Timer scrollEnableTimer = Timer(Duration.zero, () {});

  SilkyScrollState({
    ScrollController? scrollController,
    this.widgetScrollPhysics = const ScrollPhysics(),
    required this.edgeLockingDelay,
    required this.silkyScrollDuration,
    required this.animationCurve,
    required this.isVertical,
    required Function(PointerDeviceKind)? setManualPointerDeviceKind,
  }) {
    currentScrollPhysics = widgetScrollPhysics;
    try {
      if (Platform.isMacOS || Platform.isIOS) {
        isPlatformBouncingScrollPhysics = true;
      } else {
        isPlatformBouncingScrollPhysics = false;
      }
    } catch (e) {
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
    if (isAlive == false) {
      return;
    }
    final double delta;
    if (lastDelta.isNegative) {
      delta = -1;
    } else {
      delta = 1;
    }
    lastDelta = 0;
    if (checkOffsetAtEdge(delta, clientController)) {
      if (currentScrollPhysics != kDisableScrollPhysics) {
        scrollEnableTimer.cancel();
        currentScrollPhysics = kDisableScrollPhysics;
        notifyListeners();
        scrollEnableTimer = Timer(edgeLockingDelay, unlockScroll);
      }
    }
  }

  void unlockScroll() {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isAlive) {
        currentScrollPhysics = widgetScrollPhysics;
        notifyListeners();
      }
    });
  }

  void handleTouchScroll(double delta) {
    if (scrollEnableTimer.isActive) {
      return;
    }
    //터치스크롤의 델타는 마우스와 반대
    //트랙패드는 마우스와 동일
    lastDelta += delta;

    if (scrollSetDisableTimer.isActive) {
      return;
    } else {
      scrollSetDisableTimer =
          Timer(const Duration(milliseconds: 90), checkNeedLocking);
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
    final bool isEdge = checkOffsetAtEdge(scrollDelta, clientController);
    if (widgetScrollPhysics is NeverScrollableScrollPhysics) {
      needBlocking = true;
    } else {
      needBlocking = isEdge;
    }

    if (pointKey == SilkyScrollMousePointerManager().reserveKey) {
      if (isOnSilkyScrolling == false) {
        if (needBlocking) {
          SilkyScrollMousePointerManager().reservingKey(pointKey);
          return;
        }
        SilkyScrollMousePointerManager().reserveKey = null;
        SilkyScrollMousePointerManager().enteredKey(pointKey);
      }
    }
    if (isOnSilkyScrolling == false) {
      if (needBlocking) {
        SilkyScrollMousePointerManager().reservingKey(pointKey);
        return;
      }
    }

    if (SilkyScrollMousePointerManager().keyStack.isNotEmpty) {
      if (pointKey != SilkyScrollMousePointerManager().keyStack.last) {
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
    }
  }

  //void emptyCallback() {}

  @override
  void dispose() {
    scrollSetDisableTimer.cancel();
    scrollEnableTimer.cancel();
    isAlive = false;
    clientController.removeListener(onScrollUpdate);
    silkyScrollController.dispose();
    SilkyScrollMousePointerManager().detachKey(pointKey);

    if (isControllerOwn) {
      clientController.dispose();
    }
    super.dispose();
  }
}

bool checkOffsetAtEdge(double verticalDelta, ScrollController controller) {
  if (controller.hasClients == false) {
    return false;
  }
  if (verticalDelta.isNegative) {
    final int dest = (max(verticalDelta, -2) + controller.offset).toInt();
    if (dest < 0) {
      return true;
    } else {
      return false;
    }
  } else {
    final int dest = (min(verticalDelta, 2) + controller.offset).toInt();
    final int maxScrollExtent = controller.position.maxScrollExtent.toInt();
    if (dest > maxScrollExtent) {
      return true;
    } else {
      return false;
    }
  }
}
