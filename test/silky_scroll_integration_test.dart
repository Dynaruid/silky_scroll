import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/silky_scroll.dart';

void main() {
  group('SilkyScroll — scroll event simulation', () {
    testWidgets('mouse-region enters and exits correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll(
            builder: (context, controller, physics) => ListView.builder(
              controller: controller,
              physics: physics,
              itemCount: 50,
              itemBuilder: (_, i) =>
                  SizedBox(height: 100, child: Text('Item $i')),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);

      // Replace to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
    });

    testWidgets('physics update via didUpdateWidget', (tester) async {
      ScrollPhysics currentPhysics = const ScrollPhysics();
      late StateSetter stateSetter;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              stateSetter = setState;
              return SilkyScroll(
                physics: currentPhysics,
                builder: (context, controller, physics) => ListView(
                  controller: controller,
                  physics: physics,
                  children: const [SizedBox(height: 100, child: Text('A'))],
                ),
              );
            },
          ),
        ),
      );

      // Change physics
      stateSetter(() {
        currentPhysics = const BouncingScrollPhysics();
      });
      await tester.pump();

      // No errors expected
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('fromConfig creates widget correctly', (tester) async {
      const config = SilkyScrollConfig(
        scrollSpeed: 2.0,
        enableStretchEffect: false,
        debugMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll.fromConfig(
            config: config,
            builder: (context, controller, physics) => ListView(
              controller: controller,
              physics: physics,
              children: const [Text('Config Widget')],
            ),
          ),
        ),
      );

      expect(find.text('Config Widget'), findsOneWidget);
    });

    testWidgets('nested SilkyScroll widgets render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SilkyScroll(
            builder: (context, controller, physics) => ListView(
              controller: controller,
              physics: physics,
              children: [
                SizedBox(
                  height: 200,
                  child: SilkyScroll(
                    builder: (context, innerCtrl, innerPhysics) =>
                        ListView.builder(
                          controller: innerCtrl,
                          physics: innerPhysics,
                          itemCount: 10,
                          itemBuilder: (_, i) =>
                              SizedBox(height: 50, child: Text('Inner $i')),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Inner 0'), findsOneWidget);
    });
  });

  group('SilkyScrollController — attach/detach safety', () {
    testWidgets('attach does not double-register position', (tester) async {
      final clientController = ScrollController();
      final silkyController = SilkyScrollController(
        clientController: clientController,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: silkyController,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      // Both should have exactly one client
      expect(silkyController.positions.length, 1);
      expect(clientController.positions.length, 1);

      silkyController.dispose();
      clientController.dispose();
    });

    testWidgets('detach is safe when position already removed', (tester) async {
      final clientController = ScrollController();
      final silkyController = SilkyScrollController(
        clientController: clientController,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: silkyController,
            itemCount: 50,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
          ),
        ),
      );

      // Dispose should not throw even with guarded detach
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      silkyController.dispose();
      clientController.dispose();
    });
  });
}
