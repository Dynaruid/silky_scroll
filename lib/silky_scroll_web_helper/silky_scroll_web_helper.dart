import 'dart:async';
import 'package:web/web.dart' as web;
import 'silky_scroll_web_helper_interface.dart';

class SilkyScrollWebManager extends SilkyScrollWebManagerInterface {
  SilkyScrollWebManager() {
    rootBodyElement = web.window.document.body;
  }
  Timer overscrollBehaviorXTimer = Timer(Duration.zero, () {});
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
