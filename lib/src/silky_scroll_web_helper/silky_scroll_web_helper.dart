import 'dart:async';
import 'package:web/web.dart' as web;
import 'silky_scroll_web_helper_interface.dart';

/// Duration before resetting `overscroll-behavior-x` to `auto`.
const Duration _kOverscrollBehaviorXResetDelay = Duration(milliseconds: 700);

class SilkyScrollWebManager implements SilkyScrollWebManagerInterface {
  SilkyScrollWebManager() {
    rootBodyElement = web.window.document.body;
  }
  Timer? _overscrollBehaviorXTimer;
  late final web.HTMLElement? rootBodyElement;

  @override
  bool get isWebPlatform => true;

  void resetOverscrollBehaviorX() {
    rootBodyElement?.style.overscrollBehaviorX = 'auto';
  }

  @override
  void blockOverscrollBehaviorXHtml() {
    if (rootBodyElement != null) {
      if (_overscrollBehaviorXTimer?.isActive ?? false) {
        _overscrollBehaviorXTimer?.cancel();
        _overscrollBehaviorXTimer = Timer(
          _kOverscrollBehaviorXResetDelay,
          resetOverscrollBehaviorX,
        );
      } else {
        rootBodyElement!.style.overscrollBehaviorX = 'none';
        _overscrollBehaviorXTimer = Timer(
          _kOverscrollBehaviorXResetDelay,
          resetOverscrollBehaviorX,
        );
      }
    }
  }
}
