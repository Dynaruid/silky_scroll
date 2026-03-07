import 'silky_scroll_web_helper_interface.dart';

class SilkyScrollWebManager implements SilkyScrollWebManagerInterface {
  @override
  bool get isWebPlatform => false;

  @override
  void blockOverscrollBehaviorXHtml() {
    // No-op on non-web platforms.
  }

  @override
  void setOverscrollBehaviorX(OverscrollBehaviorX value) {
    // No-op on non-web platforms.
  }
}
