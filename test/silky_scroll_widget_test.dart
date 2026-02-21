import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/silky_scroll.dart';

void main() {
  group('SilkyScroll widget', () {
    testWidgets('renders child via builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll(
            builder: (context, controller, physics) => ListView(
              controller: controller,
              physics: physics,
              children: const [Text('Hello Silky')],
            ),
          ),
        ),
      );

      expect(find.text('Hello Silky'), findsOneWidget);
    });

    testWidgets('passes controller to builder', (tester) async {
      ScrollController? capturedController;

      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll(
            builder: (context, controller, physics) {
              capturedController = controller;
              return ListView(
                controller: controller,
                physics: physics,
                children: const [SizedBox(height: 100)],
              );
            },
          ),
        ),
      );

      expect(capturedController, isNotNull);
      expect(capturedController, isA<SilkyScrollController>());
    });

    testWidgets('respects external ScrollController', (tester) async {
      final externalController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll(
            controller: externalController,
            builder: (context, controller, physics) => ListView.builder(
              controller: controller,
              physics: physics,
              itemCount: 50,
              itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
            ),
          ),
        ),
      );

      // The external controller should be linked
      expect(externalController.hasClients, isTrue);

      externalController.dispose();
    });

    testWidgets('SilkyScroll.fromConfig applies config', (tester) async {
      const config = SilkyScrollConfig(
        scrollSpeed: 2.0,
        enableStretchEffect: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll.fromConfig(
            config: config,
            builder: (context, controller, physics) => ListView(
              controller: controller,
              physics: physics,
              children: const [Text('Config Test')],
            ),
          ),
        ),
      );

      expect(find.text('Config Test'), findsOneWidget);
    });

    testWidgets('disposes without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll(
            builder: (context, controller, physics) => ListView(
              controller: controller,
              physics: physics,
              children: const [SizedBox(height: 100)],
            ),
          ),
        ),
      );

      // Replace with a different widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      // No errors expected
    });
  });
}
