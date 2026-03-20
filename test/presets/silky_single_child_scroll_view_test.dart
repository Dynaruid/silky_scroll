import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/silky_scroll.dart';

void main() {
  group('SilkySingleChildScrollView', () {
    setUp(SilkyScrollGlobalManager.instance.resetForTesting);
    tearDown(SilkyScrollGlobalManager.instance.resetForTesting);

    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SilkySingleChildScrollView(child: Text('Hello Single')),
        ),
      );

      expect(find.text('Hello Single'), findsOneWidget);
    });

    testWidgets('respects external ScrollController', (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: SilkySingleChildScrollView(
            controller: controller,
            child: Column(
              children: List.generate(
                50,
                (i) => SizedBox(height: 100, child: Text('$i')),
              ),
            ),
          ),
        ),
      );

      expect(controller.hasClients, isTrue);
      controller.dispose();
    });

    testWidgets('silkyConfig overrides individual params', (tester) async {
      const config = SilkyScrollConfig(scrollSpeed: 2.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: SilkySingleChildScrollView(
            silkyConfig: config,
            scrollSpeed: 5.0,
            child: Text('Configured'),
          ),
        ),
      );

      expect(find.text('Configured'), findsOneWidget);
    });

    testWidgets('passes scrollDirection and padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SilkySingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 1000, child: Text('Wide')),
          ),
        ),
      );

      expect(find.text('Wide'), findsOneWidget);
    });
  });
}
