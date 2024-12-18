import 'dart:async';

import 'package:flutter/foundation.dart';
import 'silky_scroll_web_helper/silky_scroll_non_web_helper.dart'
    if (dart.library.js) 'silky_scroll_web_helper/silky_scroll_web_helper.dart';

class SilkyScrollMousePointerManager {
  static final SilkyScrollMousePointerManager _instance =
      SilkyScrollMousePointerManager._internal();

  SilkyScrollMousePointerManager._internal() {
    silkyScrollWebManager = SilkyScrollWebManager();
  }

  factory SilkyScrollMousePointerManager() {
    return _instance;
  }

  UniqueKey? reserveKey;
  final List<UniqueKey> keyStack = [];
  late final SilkyScrollWebManager silkyScrollWebManager;
  Timer trackpadCheckTimer = Timer(Duration.zero, () {});
  Timer mouseCheckTimer = Timer(Duration.zero, () {});

  void resetTrackpadCheckTimer() {
    mouseCheckTimer.cancel();
    trackpadCheckTimer.cancel();
    trackpadCheckTimer = Timer(const Duration(milliseconds: 2000), () {});
  }

  void resetMouseCheckTimer() {
    trackpadCheckTimer.cancel();
    mouseCheckTimer.cancel();
    mouseCheckTimer = Timer(const Duration(milliseconds: 2000), () {});
  }

  void reservingKey(UniqueKey key) {
    reserveKey = key;
    exitKey(key);
  }

  void enteredKey(UniqueKey key) {
    if (keyStack.contains(key)) {
      keyStack.remove(key);
    }
    keyStack.add(key);
  }

  void exitKey(UniqueKey key) {
    keyStack.removeWhere((item) => item == key);
  }

  void detachKey(UniqueKey key) {
    if (reserveKey == key) {
      reserveKey = null;
    }
    exitKey(key);
  }
}
