import 'dart:async';

abstract class SilkyScrollWebManagerAbstract {
  Timer overscrollBehaviorXTimer = Timer(Duration.zero, () {});

  void blockOverscrollBehaviorXHtml() {}
}
