import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/src/silky_scroll_mouse_pointer_manager.dart';

void main() {
  group('SilkyScrollMousePointerManager', () {
    late SilkyScrollMousePointerManager manager;

    setUp(() {
      // SilkyScrollMousePointerManager is a singleton; reset its state.
      manager = SilkyScrollMousePointerManager();
      manager.keyStack.clear();
      manager.reserveKey = null;
    });

    test('enteredKey adds key to stack', () {
      final key = UniqueKey();
      manager.enteredKey(key);
      expect(manager.keyStack, contains(key));
    });

    test('enteredKey moves existing key to end', () {
      final key1 = UniqueKey();
      final key2 = UniqueKey();
      manager.enteredKey(key1);
      manager.enteredKey(key2);
      manager.enteredKey(key1);
      expect(manager.keyStack.last, key1);
      expect(manager.keyStack.length, 2);
    });

    test('exitKey removes key from stack', () {
      final key = UniqueKey();
      manager.enteredKey(key);
      manager.exitKey(key);
      expect(manager.keyStack, isNot(contains(key)));
    });

    test('reservingKey sets reserveKey and removes from stack', () {
      final key = UniqueKey();
      manager.enteredKey(key);
      manager.reservingKey(key);
      expect(manager.reserveKey, key);
      expect(manager.keyStack, isNot(contains(key)));
    });

    test('detachKey clears reserveKey if matching', () {
      final key = UniqueKey();
      manager.reservingKey(key);
      expect(manager.reserveKey, key);
      manager.detachKey(key);
      expect(manager.reserveKey, isNull);
    });

    test('trackpadCheckTimer is initially inactive', () {
      expect(manager.trackpadCheckTimer?.isActive ?? false, isFalse);
    });

    test('resetTrackpadCheckTimer activates trackpad timer', () {
      manager.resetTrackpadCheckTimer();
      expect(manager.trackpadCheckTimer?.isActive, isTrue);
      expect(manager.mouseCheckTimer?.isActive ?? false, isFalse);
    });

    test('resetMouseCheckTimer activates mouse timer', () {
      manager.resetMouseCheckTimer();
      expect(manager.mouseCheckTimer?.isActive, isTrue);
      expect(manager.trackpadCheckTimer?.isActive ?? false, isFalse);
    });
  });
}
