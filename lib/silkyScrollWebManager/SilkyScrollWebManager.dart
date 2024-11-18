import 'dart:async';
import 'package:web/web.dart' as web;
import 'SilkyScrollWebManagerAbstract.dart';

class SilkyScrollWebManager extends SilkyScrollWebManagerAbstract {
  SilkyScrollWebManager() {
    rootBodyElement = web.window.document.body;
  }

  late final web.HTMLElement? rootBodyElement;

  void resetOverscrollBehaviorX() {
    rootBodyElement!.style.overscrollBehaviorX = "auto";
  }

  @override
  void blockOverscrollBehaviorXHtml() {
    if (rootBodyElement != null) {
      if (overscrollBehaviorXTimer.isActive) {
        overscrollBehaviorXTimer.cancel();
        overscrollBehaviorXTimer =
            Timer(const Duration(milliseconds: 700), resetOverscrollBehaviorX);
      } else {
        rootBodyElement!.style.overscrollBehaviorX = "none";
        overscrollBehaviorXTimer =
            Timer(const Duration(milliseconds: 700), resetOverscrollBehaviorX);
      }
    }
  }
}
