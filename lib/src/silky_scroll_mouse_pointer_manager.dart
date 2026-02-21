import 'dart:async';

import 'package:flutter/foundation.dart';
import 'silky_scroll_web_helper/silky_scroll_non_web_helper.dart'
    if (dart.library.js_interop) 'silky_scroll_web_helper/silky_scroll_web_helper.dart';

final class SilkyScrollMousePointerManager {
  SilkyScrollMousePointerManager._internal() {
    silkyScrollWebManager = SilkyScrollWebManager();
  }

  factory SilkyScrollMousePointerManager() {
    return _instance;
  }

  static final SilkyScrollMousePointerManager _instance =
      SilkyScrollMousePointerManager._internal();

  UniqueKey? reserveKey;
  final List<UniqueKey> keyStack = [];
  late final SilkyScrollWebManager silkyScrollWebManager;
  Timer? trackpadCheckTimer;
  Timer? mouseCheckTimer;

  static const int _kDeviceCheckTimeoutMs = 2000;

  void resetTrackpadCheckTimer() {
    mouseCheckTimer?.cancel();
    trackpadCheckTimer?.cancel();
    trackpadCheckTimer = Timer(
      const Duration(milliseconds: _kDeviceCheckTimeoutMs),
      () {},
    );
  }

  void resetMouseCheckTimer() {
    trackpadCheckTimer?.cancel();
    mouseCheckTimer?.cancel();
    mouseCheckTimer = Timer(
      const Duration(milliseconds: _kDeviceCheckTimeoutMs),
      () {},
    );
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

  /// Resets all mutable state for test isolation.
  ///
  /// Only intended for use in test tearDown/setUp.
  @visibleForTesting
  void resetForTesting() {
    reserveKey = null;
    keyStack.clear();
    trackpadCheckTimer?.cancel();
    trackpadCheckTimer = null;
    mouseCheckTimer?.cancel();
    mouseCheckTimer = null;
  }
}
