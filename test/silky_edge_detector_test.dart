import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/src/silky_edge_detector.dart';

void main() {
  group('SilkyEdgeDetector.checkOffsetAtEdge', () {
    late ScrollController controller;
    const edgeDetector = SilkyEdgeDetector();

    setUp(() {
      controller = ScrollController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('returns 0 when controller has no clients', (tester) async {
      // Controller without attached scrollable — hasClients is false.
      expect(edgeDetector.checkOffsetAtEdge(1, controller), 0);
      expect(edgeDetector.checkOffsetAtEdge(-1, controller), 0);
    });

    testWidgets('returns -1 when at start edge scrolling up', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      // offset = 0, scrolling up → at start edge
      expect(edgeDetector.checkOffsetAtEdge(-1, controller), -1);
    });

    testWidgets('returns 0 when in the middle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      controller.jumpTo(500);
      await tester.pump();

      expect(edgeDetector.checkOffsetAtEdge(1, controller), 0);
      expect(edgeDetector.checkOffsetAtEdge(-1, controller), 0);
    });

    testWidgets('returns 1 when at end edge scrolling down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      expect(edgeDetector.checkOffsetAtEdge(1, controller), 1);
    });
  });
}
