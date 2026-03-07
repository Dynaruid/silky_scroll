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
  int _lastBlockTimeMs = 0;
  late final web.HTMLElement? rootBodyElement;

  @override
  bool get isWebPlatform => true;

  void resetOverscrollBehaviorX() {
    rootBodyElement?.style.overscrollBehaviorX = 'auto';
  }

  @override
  void blockOverscrollBehaviorXHtml() {
    if (rootBodyElement == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastBlockTimeMs = now;
    if (_overscrollBehaviorXTimer?.isActive ?? false) return;
    rootBodyElement!.style.overscrollBehaviorX = 'none';
    _overscrollBehaviorXTimer = Timer(_kOverscrollBehaviorXResetDelay, () {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _lastBlockTimeMs;
      if (elapsed >= _kOverscrollBehaviorXResetDelay.inMilliseconds) {
        resetOverscrollBehaviorX();
      } else {
        _overscrollBehaviorXTimer = Timer(
          Duration(
            milliseconds:
                _kOverscrollBehaviorXResetDelay.inMilliseconds - elapsed,
          ),
          resetOverscrollBehaviorX,
        );
      }
    });
  }
}
